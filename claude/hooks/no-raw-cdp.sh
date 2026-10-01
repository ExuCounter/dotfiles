#!/usr/bin/env bash
# Refuse to drive Chrome by hand over a TCP debugging port.
#
# The chrome-devtools MCP server already does this, over a pipe rather than a
# port, which is what makes it work on a machine whose policy disallows remote
# debugging - there, a hand-rolled socket is severed partway through a run and
# the failure looks like a crashing page. Headless Chrome also refuses a window
# narrower than 500px, so a port-driven "mobile" capture is not one.
#
# Fail open, loudly: a hook that cannot read its payload must not brick every
# Bash call in the session.

payload="$(cat)"

command="$(
  printf '%s' "$payload" | python3 -c '
import json
import sys

try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    sys.exit(1)
' 2>/dev/null
)" || exit 0

case "$command" in
  *--remote-debugging-port*)
    cat >&2 <<'MESSAGE'
Blocked: this drives Chrome over a TCP debugging port by hand.

Use the chrome-devtools MCP server instead - it is configured with --isolated,
so it takes a throwaway profile and never collides with a browser another
session left running.

  mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page
  mcp__plugin_chrome-devtools-mcp_chrome-devtools__click / fill / evaluate_script
  mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot

If it reports a browser already running for a profile, --isolated has gone
missing from its args - say so rather than reaching for a port.

For a still frame of a page at rest, frontend-preview-shot.sh is enough and
needs no browser of its own.
MESSAGE
    exit 2
    ;;
esac

exit 0
