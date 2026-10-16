#!/usr/bin/env bash
# Shows a large caption at the bottom of the current page, or clears it.
#   caption.sh before|after "Title" ["Subtitle"]
#   caption.sh clear
# Acts on the session named in AGENT_BROWSER_SESSION.
set -euo pipefail

case "${AGENT_BROWSER_SESSION:-default}" in
  default) echo "caption.sh: export AGENT_BROWSER_SESSION=<work session> first" >&2; exit 64 ;;
esac

kind="${1:-}"
case "$kind" in
  before) colour="#b91c1c" ;;
  after) colour="#15803d" ;;
  clear) agent-browser eval "document.getElementById('__prove_fix_caption')?.remove()" >/dev/null; exit 0 ;;
  *) echo "usage: caption.sh before|after \"Title\" [\"Subtitle\"] | caption.sh clear" >&2; exit 64 ;;
esac
[ $# -ge 2 ] || { echo "caption.sh: a title is required" >&2; exit 64; }

script="$(python3 - "$colour" "$2" "${3:-}" <<'PY'
import json, sys
colour, title, subtitle = sys.argv[1:4]
style = (
    "position:fixed;left:50%;transform:translateX(-50%);bottom:32px;z-index:2147483647;"
    "pointer-events:none;max-width:1240px;width:max-content;padding:16px 30px;border-radius:12px;"
    "color:#fff;text-align:center;box-shadow:0 8px 28px rgba(0,0,0,.4);"
    "font:700 30px/1.25 -apple-system,Helvetica,Arial,sans-serif;background:" + colour
)
print(
    "(() => {"
    "let box = document.getElementById('__prove_fix_caption');"
    "if (!box) { box = document.createElement('div'); box.id = '__prove_fix_caption'; document.body.appendChild(box); }"
    "box.style.cssText = " + json.dumps(style) + ";"
    "box.textContent = " + json.dumps(title) + ";"
    "if (" + json.dumps(subtitle) + ") {"
    "const line = document.createElement('div');"
    "line.style.cssText = 'font-weight:500;font-size:21px;margin-top:6px;opacity:.95';"
    "line.textContent = " + json.dumps(subtitle) + ";"
    "box.appendChild(line); }"
    "})()"
)
PY
)"
agent-browser eval "$script" >/dev/null
