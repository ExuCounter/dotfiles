#!/usr/bin/env bash
# PostToolUse hook: preview the .md file Claude writes in a single, fixed
# herdr tab. Every write — regardless of which file — reloads that same tab
# instead of spawning a new one. No-ops outside a herdr session.

set -eu

hook_input="$(cat)"

file_path="$(printf '%s' "$hook_input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
[ -n "$file_path" ] || exit 0

case "$file_path" in
  *.md|*.markdown) ;;
  *) exit 0 ;;
esac

# Denylist: memory, agent docs, generated files.
case "$file_path" in
  */CLAUDE.md|*/AGENTS.md) exit 0 ;;
  */MEMORY.md) exit 0 ;;
  */.claude/*) exit 0 ;;
  */memory/*) exit 0 ;;
  */node_modules/*) exit 0 ;;
esac

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_WORKSPACE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v glow >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

label="glow-preview"

# Find an existing tab with this label.
tab_id="$(herdr tab list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
  | jq -r --arg l "$label" '.result.tabs[]? | select(.label == $l) | .tab_id' \
  | head -1)"

if [ -z "$tab_id" ] || [ "$tab_id" = "null" ]; then
  cwd_dir="$(dirname "$file_path")"
  tab_id="$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --label "$label" --cwd "$cwd_dir" --no-focus 2>/dev/null \
    | jq -r '.result.tab.tab_id // empty')"
  [ -n "$tab_id" ] || exit 0
fi

# Grab the (first) pane belonging to that tab.
pane_id="$(herdr pane list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
  | jq -r --arg t "$tab_id" '.result.panes[]? | select(.tab_id == $t) | .pane_id' \
  | head -1)"
[ -n "$pane_id" ] || exit 0

style="$HOME/.config/glow/solarized-light.json"

# If a previous glow left `less` open, exit it before reloading.
herdr pane send-keys "$pane_id" q enter 2>/dev/null || true
herdr pane run "$pane_id" clear 2>/dev/null || true

if [ -f "$style" ]; then
  herdr pane run "$pane_id" glow -s "$style" -p "$file_path" >/dev/null 2>&1 || true
else
  herdr pane run "$pane_id" glow -p "$file_path" >/dev/null 2>&1 || true
fi
