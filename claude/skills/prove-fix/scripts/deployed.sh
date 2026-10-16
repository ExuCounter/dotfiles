#!/usr/bin/env bash
# Waits until a deployed app's status page reports the given commit.
#   deployed.sh <status URL> <sha> [--timeout <seconds>] [--every <seconds>]
# The page answers JSON whose "commit" is the first 7 or more characters of <sha>, whose
# "status", when present, is "ok", and whose "pending_migrations", when present, is 0. Defaults: --timeout 1800, --every 15. It never echoes the page's own text
# beyond a sha and a short status word.
# Exit 0 once it does; 1 at the timeout, naming the commit and status last seen; 6 when the
# page never answered with JSON; 64 on bad arguments.
set -euo pipefail

usage() {
  echo "usage: deployed.sh <status URL> <sha> [--timeout <seconds>] [--every <seconds>]" >&2
  exit 64
}

[ $# -ge 2 ] || usage
url="$1"
sha="$2"
shift 2
timeout=1800
every=15
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) [ $# -ge 2 ] || usage; timeout="$2"; shift 2 ;;
    --every) [ $# -ge 2 ] || usage; every="$2"; shift 2 ;;
    *) usage ;;
  esac
done

exec python3 - "$url" "$sha" "$timeout" "$every" <<'PY'
import json, re, sys, time, urllib.request

url, sha, timeout, every = sys.argv[1], sys.argv[2].lower(), sys.argv[3], sys.argv[4]
if not re.fullmatch(r"https?://[^\s]+", url):
    sys.exit(print("deployed.sh: the status URL must be http or https", file=sys.stderr) or 64)
if not re.fullmatch(r"[0-9a-f]{7,40}", sha):
    sys.exit(print(f"deployed.sh: {sys.argv[2]} is not a commit sha", file=sys.stderr) or 64)
try:
    timeout, every = float(timeout), float(every)
except ValueError:
    sys.exit(print("deployed.sh: --timeout and --every take seconds", file=sys.stderr) or 64)

deadline = time.monotonic() + timeout
seen = None
error = "no answer yet"
while True:
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            page = json.loads(response.read())
        commit = str(page.get("commit") or "").lower()
        status = page.get("status")
        if not re.fullmatch(r"[0-9a-f]{0,40}", commit):
            commit = "<not a sha>"
        if status is not None and not re.fullmatch(r"[A-Za-z_]{1,20}", str(status)):
            status = "<unexpected>"
        pending = page.get("pending_migrations", 0)
        if not isinstance(pending, int):
            pending = "<unexpected>"
        seen = (commit, status, pending)
        if len(commit) >= 7 and sha.startswith(commit[:40]) and status in (None, "ok") and pending == 0:
            print(f"deployed {commit} ({status or 'no status'}) at {url}")
            sys.exit(0)
    except Exception as exception:
        error = f"{type(exception).__name__} {getattr(exception, 'code', '') or ''}".strip()
    if time.monotonic() + every > deadline:
        break
    time.sleep(every)

if seen is None:
    print(f"deployed.sh: {url} never answered with JSON: {error}", file=sys.stderr)
    sys.exit(6)
commit, status, pending = seen
print(f"deployed.sh: {url} still reports commit {commit or 'none'} with status {status} and {pending} pending migrations, not {sha[:8]}", file=sys.stderr)
sys.exit(1)
PY
