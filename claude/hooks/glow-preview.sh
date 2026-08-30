#!/usr/bin/env bash
# PostToolUse hook: preview .md files Claude writes in a dedicated glow pane.
# Reuses the same pane across fires via herdr's durable pane title.
# No-ops outside a herdr session.

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
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_WORKSPACE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v glow >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

pane_title="glow-preview"
source_id="glow-preview-hook"

pane_id="$(herdr pane list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
  | jq -r --arg t "$pane_title" '.result.panes[]? | select(.title == $t) | .pane_id' \
  | head -1)"

if [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  pane_id="$(herdr pane split --pane "$HERDR_PANE_ID" --direction right --no-focus 2>/dev/null \
    | jq -r '.result.pane.pane_id // empty')"
  [ -n "$pane_id" ] || exit 0
  herdr pane report-metadata "$pane_id" --source "$source_id" --title "$pane_title" >/dev/null 2>&1 || true
fi

style="$HOME/.config/glow/solarized-light.json"
if [ -f "$style" ]; then
  herdr pane run "$pane_id" glow -s "$style" -p "$file_path" >/dev/null 2>&1 || true
else
  herdr pane run "$pane_id" glow -p "$file_path" >/dev/null 2>&1 || true
fi
