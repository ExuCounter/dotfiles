#!/usr/bin/env bash
# Smart pane navigation.
#   Usage: smart_pane_nav.sh <left|right|up|down>
#
# 1. Try to focus a neighbor pane in the given direction.
# 2. If no neighbor:
#      left/right -> previous/next agent (wraps)
#      up/down    -> previous/next workspace (wraps)

set -uo pipefail

dir="${1:?direction required: left|right|up|down}"

focus_json=$(herdr pane focus --direction "$dir" 2>/dev/null)
changed=$(printf '%s' "$focus_json" | jq -r '.result.focus.changed // false')
[ "$changed" = "true" ] && exit 0

case "$dir" in
  up|down)
    current_ws=$(herdr pane current | jq -r '.result.pane.workspace_id')
    mapfile -t ids < <(
      herdr workspace list \
        | jq -r '.result.workspaces | sort_by(.number) | .[].workspace_id'
    )
    focus_cmd() { herdr workspace focus "$1" >/dev/null; }
    current_id="$current_ws"
    ;;
  left|right)
    mapfile -t ids < <(
      herdr agent list \
        | jq -r '.result.agents | sort_by(.workspace_id, .pane_id) | .[].pane_id'
    )
    current_id=$(
      herdr agent list \
        | jq -r '.result.agents[] | select(.focused == true) | .pane_id' \
        | head -n1
    )
    focus_cmd() { herdr agent focus "$1" >/dev/null; }
    ;;
esac

count=${#ids[@]}
[ "$count" -eq 0 ] && exit 0

if [ -z "$current_id" ]; then
  case "$dir" in
    right|down) target=0 ;;
    left|up)    target=$(( count - 1 )) ;;
  esac
else
  idx=-1
  for i in "${!ids[@]}"; do
    [ "${ids[$i]}" = "$current_id" ] && idx=$i && break
  done
  if [ "$idx" -lt 0 ]; then
    target=0
  else
    case "$dir" in
      left|up)    target=$(( (idx - 1 + count) % count )) ;;
      right|down) target=$(( (idx + 1) % count )) ;;
    esac
  fi
fi

focus_cmd "${ids[$target]}"
