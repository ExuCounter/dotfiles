#!/usr/bin/env bash
# The branch's own open merge request in origin's GitLab project, reached through glab's stored login for that host.
#   mr.sh origin                     prints origin's <host>/<project path>
#   mr.sh find [<branch>]            prints its iid; exit 3 when there is none, 4 when there are several
#   mr.sh post [--on <origin>] <note.md> <file>...
#                                    uploads each file, posts the note, where and at which commit it was proven (locally
#                                    without --on) and each upload; prints the note's URL, then <file name><TAB><URL> per upload
#   mr.sh pipeline [--wait <seconds>]
#                                    prints HEAD's newest pipeline on the branch as <status> <URL>[ failed: <job>, ...];
#                                    exit 0 when it passed, 2 while it runs, 1 when it failed or stopped, 3 when HEAD has
#                                    none, 7 when glab fails. --wait asks again every 30 s while it runs, for at most that long.
# find, post and pipeline exit 5 on a GitHub origin before any call: GitHub has no API for attaching files to a PR comment.
# The MR must come from origin's project itself, at a commit the local branch contains.
# post takes <scratchpad>/run/<slug>/note.md and .mp4 or .png files from the same <scratchpad>/proof/<slug>/
# only, and defuses the note's quick actions, @mentions and references outside code.
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
FAILED=1

usage() {
  echo "usage: mr.sh origin | find [<branch>] | post [--on <origin>] <note.md> <file>... | pipeline [--wait <seconds>]" >&2
  exit 64
}

current_branch() {
  BRANCH="$(git branch --show-current)"
  [ -n "$BRANCH" ] || { echo "mr.sh: no branch checked out" >&2; exit 65; }
}

locate_origin() {
  local url location
  url="$(git remote get-url origin)" || exit "$FAILED"
  location="$(python3 - "$url" <<'PY'
import re, sys, urllib.parse
url = sys.argv[1]
if "://" in url:
    parts = urllib.parse.urlsplit(url)
    host, path = parts.hostname, parts.path
else:
    host_part, _, path = url.partition(":")
    host = host_part.rpartition("@")[2]
host = (host or "").strip("[]").rstrip(".").lower()
path = path.strip("/")
if path.endswith(".git"):
    path = path[:-4]
if not re.fullmatch(r"[a-z0-9][a-z0-9.-]*", host) or not re.fullmatch(r"[A-Za-z0-9_.~/-]+", path):
    sys.exit("mr.sh: cannot read a GitLab host and project from origin's URL")
print(host, urllib.parse.quote(path, safe=""), path)
PY
)" || exit "$FAILED"
  read -r HOST PROJECT PROJECT_PATH <<<"$location"
}

reach_gitlab() {
  case "$HOST" in
    *github*)
      echo "mr.sh: origin is on GitHub, which has no API for attaching files to a PR comment; nothing posted" >&2
      exit 5
      ;;
  esac
  gitlab auth status --hostname "$HOST" >/dev/null 2>&1 || { echo "mr.sh: glab has no stored login for $HOST; nothing posted" >&2; exit "$FAILED"; }
}

gitlab() {
  env -u GITLAB_TOKEN -u GITLAB_ACCESS_TOKEN -u OAUTH_TOKEN glab "$@"
}

find_merge_request() {
  local encoded listed found
  encoded="$(encode "$BRANCH")"
  listed="$(gitlab api --hostname "$HOST" "projects/$PROJECT/merge_requests?state=opened&source_branch=$encoded")" || exit $?
  found="$(python3 - "$BRANCH" "$listed" <<'PY'
import json, subprocess, sys
branch, listed = sys.argv[1], json.loads(sys.argv[2])
for request in listed:
    if request["source_project_id"] != request["project_id"] or not request.get("sha"):
        continue
    contained = subprocess.run(
        ["git", "merge-base", "--is-ancestor", request["sha"], "refs/heads/" + branch],
        capture_output=True,
    ).returncode == 0
    if contained:
        print(request["iid"], request["sha"], request["web_url"])
PY
)" || exit 1
  if [ -z "$found" ]; then
    echo "mr.sh: no open merge request for $BRANCH in $HOST/$PROJECT_PATH at a commit the branch contains" >&2
    exit 3
  fi
  if [ "$(printf '%s\n' "$found" | wc -l | tr -d ' ')" != 1 ]; then
    echo "mr.sh: several open merge requests for $BRANCH: $(printf '%s\n' "$found" | awk '{printf "!%s ", $1}')" >&2
    exit 4
  fi
  read -r IID MR_SHA WEB_URL <<<"$found"
}

encode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

UPLOADED=""
LINKS=""
report_uploads() {
  if [ -n "$UPLOADED" ]; then
    printf 'mr.sh: nothing posted; these uploads stay in the project:%s\n' "$UPLOADED" >&2
  fi
}

command="${1:-}"
[ $# -gt 0 ] && shift
case "$command" in
  origin)
    locate_origin
    printf '%s/%s\n' "$HOST" "$PROJECT_PATH"
    ;;
  find)
    if [ $# -gt 0 ]; then BRANCH="$1"; else current_branch; fi
    locate_origin
    reach_gitlab
    find_merge_request
    printf '%s\n' "$IID"
    ;;
  post)
    where=""
    if [ "${1:-}" = --on ]; then
      [ $# -ge 2 ] || usage
      where="$2"
      shift 2
      python3 -c 'import re, sys; sys.exit(not re.fullmatch(r"https?://[A-Za-z0-9.-]+(:[0-9]+)?", sys.argv[1]))' "${where%/}" \
        || { echo "mr.sh: --on takes an http or https origin, such as https://app.example" >&2; exit 64; }
      where="${where%/}"
    fi
    [ $# -ge 1 ] || usage
    note="$1"
    shift
    current_branch
    locate_origin
    reach_gitlab
    slug="$("$SCRIPTS/slug.sh" "$BRANCH")"
    python3 - "$slug" "$note" "$@" <<'PY' || exit $?
import os, sys
slug, note, files = sys.argv[1], sys.argv[2], sys.argv[3:]
def folder(path, kind):
    real = os.path.dirname(os.path.realpath(path))
    if os.path.basename(real) == slug and os.path.basename(os.path.dirname(real)) == kind:
        return os.path.dirname(os.path.dirname(real))
    return None
def refuse(message):
    print(f"mr.sh: {message}", file=sys.stderr)
    sys.exit(64)
scratchpad = folder(note, "run")
if not (os.path.isfile(note) and not os.path.islink(note) and os.path.basename(note) == "note.md" and scratchpad):
    refuse(f"the note must be run/{slug}/note.md, not {note}")
for file in files:
    ok = os.path.isfile(file) and not os.path.islink(file) and file.lower().endswith((".mp4", ".png"))
    if not (ok and folder(file, "proof") == scratchpad):
        refuse(f"only .mp4 and .png files in {os.path.join(scratchpad, 'proof', slug)} are attached, not {file}")
PY
    find_merge_request
    head="$(git rev-parse HEAD)"
    changes="$(git status --porcelain)" || { echo "mr.sh: git status failed" >&2; exit 1; }
    marks=""
    [ "$head" = "$MR_SHA" ] || marks="not pushed"
    [ -z "$changes" ] || marks="${marks:+$marks, }uncommitted changes"
    place="locally"
    [ -z "$where" ] || place="on $where"
    proven="Proven $place at \`${head:0:7}\`${marks:+ ($marks)}."
    for file in "$@"; do
      reply="$(gitlab api --hostname "$HOST" --method POST "projects/$PROJECT/uploads" --form "file=@$file")" || { status=$?; report_uploads; exit "$status"; }
      uploaded="$(python3 - "$reply" "$HOST" "$PROJECT_PATH" <<'PY'
import json, re, sys
reply, host, project_path = json.loads(sys.argv[1]), sys.argv[2], sys.argv[3]
path = reply.get("full_path") or "/" + project_path + reply["url"]
if not re.fullmatch(r"/\S+", path) or "\n" in reply["markdown"]:
    sys.exit(1)
print(reply["markdown"])
print(f"https://{host}{path}")
PY
)" || { echo "mr.sh: GitLab's reply to uploading $file has no markdown and URL" >&2; report_uploads; exit 1; }
      UPLOADED="$UPLOADED"$'\n'"${uploaded%%$'\n'*}"
      LINKS="$LINKS$(basename "$file")"$'\t'"${uploaded#*$'\n'}"$'\n'
    done
    body="$(mktemp)"
    trap 'rm -f "$body"' EXIT
    python3 - "$note" "$proven" "$UPLOADED" > "$body" <<'PY' || { report_uploads; exit 1; }
import json, re, sys
FENCE = re.compile(r"^ {0,3}(`{3,})[^`\n]*\n.*?^ {0,3}\1`*[ \t]*$", re.S | re.M)
SPAN = re.compile(r"(?<![`\\])(`+)(?!`)[^\n]+?(?<!`)\1(?!`)")
LINK = re.compile(r"https?://\S+?(?:/-)?/(?:merge_requests|issues|work_items|epics|commit)/\S*")
def pieces(text, pattern):
    position = 0
    for match in pattern.finditer(text):
        yield False, text[position:match.start()]
        yield True, match.group(0)
        position = match.end()
    yield False, text[position:]
def defuse_words(text):
    text = re.sub(r"(?m)^(\s*)/", r"\1\\/", text)
    text = re.sub(r"(?<![A-Za-z0-9_])@(?=[A-Za-z0-9_.])", "@\u200b", text)
    text = re.sub(r"([!#&])(?=\d)", "\\1\u200b", text)
    text = re.sub(r"\b(?=[0-9a-f]*[a-f])(?=[0-9a-f]*[0-9])[0-9a-f]{7,40}\b", lambda match: "`" + match.group(0) + "`", text)
    return re.sub(r"\b([A-Z][A-Z0-9_]+)-(\d+)\b", "\\1-\u2060\\2", text)
def defuse(text):
    return "".join("`" + piece + "`" if linked else defuse_words(piece) for linked, piece in pieces(text, LINK))
def code(text):
    return re.sub(r"(?m)^(\s*)/", "\\1\u200b/", text)
with open(sys.argv[1], encoding="utf-8", errors="replace") as note:
    source = note.read()
text = "".join(
    code(piece) if fenced else "".join(code(part) if spanned else defuse(part) for spanned, part in pieces(piece, SPAN))
    for fenced, piece in pieces(source, FENCE)
)
text += "\n" + sys.argv[2] + "\n"
for markdown in sys.argv[3].split("\n"):
    if markdown:
        text += "\n" + markdown + "\n"
json.dump({"body": text}, sys.stdout)
PY
    posted="$(gitlab api --hostname "$HOST" --method POST "projects/$PROJECT/merge_requests/$IID/notes" -H "Content-Type: application/json" --input "$body")" || { status=$?; report_uploads; exit "$status"; }
    id="$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["id"])' "$posted" 2>/dev/null)" || { echo "mr.sh: GitLab's reply has no note id, so no comment was made" >&2; report_uploads; exit 1; }
    printf '%s#note_%s\n%s' "$WEB_URL" "$id" "$LINKS"
    ;;
  pipeline)
    wait_for=0
    if [ "${1:-}" = --wait ]; then
      [ $# -eq 2 ] && [[ "$2" =~ ^[0-9]+$ ]] || usage
      wait_for="$2"
      shift 2
    fi
    [ $# -eq 0 ] || usage
    FAILED=7
    current_branch
    locate_origin
    reach_gitlab
    head="$(git rev-parse HEAD)"
    deadline=$((SECONDS + wait_for))
    while :; do
      listed="$(gitlab api --hostname "$HOST" "projects/$PROJECT/pipelines?sha=$head&ref=$(encode "$BRANCH")&order_by=id&sort=desc&per_page=1")" || exit 7
      newest="$(python3 -c 'import json, sys
for pipeline in json.loads(sys.argv[1])[:1]:
    print(pipeline["id"], pipeline["status"], pipeline["web_url"])' "$listed")" || { echo "mr.sh: GitLab's pipeline list is not JSON" >&2; exit 7; }
      status=missing
      [ -z "$newest" ] || read -r id status web_url <<<"$newest"
      case "$status" in
        created|waiting_for_resource|preparing|pending|running|scheduled) ;;
        *) break ;;
      esac
      [ "$SECONDS" -lt "$deadline" ] || break
      remaining=$((deadline - SECONDS))
      sleep $((remaining < 30 ? remaining : 30))
    done
    case "$status" in
      missing) echo "mr.sh: no pipeline for ${head:0:8} on $BRANCH yet; is it pushed?" >&2; exit 3 ;;
      success|manual) printf '%s %s\n' "$status" "$web_url"; exit 0 ;;
      created|waiting_for_resource|preparing|pending|running|scheduled) printf '%s %s\n' "$status" "$web_url"; exit 2 ;;
    esac
    failed=""
    if [ "$status" = failed ]; then
      jobs="$(gitlab api --hostname "$HOST" "projects/$PROJECT/pipelines/$id/jobs?scope%5B%5D=failed")" || exit 7
      failed="$(python3 -c 'import json, sys; print(", ".join(job["name"] for job in json.loads(sys.argv[1])))' "$jobs")" || exit 7
    fi
    printf '%s %s%s\n' "$status" "$web_url" "${failed:+ failed: $failed}"
    exit 1
    ;;
  *) usage ;;
esac
