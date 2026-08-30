#!/usr/bin/env bash
# Stop hook: open hunk in a review pane against the current worktree diff.
# Reuses the same pane across fires via herdr's durable pane title.
# No-ops outside a herdr session or when there's nothing to diff.

set -eu

# Discard hook input; we only care that Claude stopped.
cat >/dev/null

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_WORKSPACE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v hunk >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

# Only inside a git repo with pending changes.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git status --porcelain 2>/dev/null)" ] || exit 0

pane_title="hunk-review"
source_id="hunk-review-hook"
cwd="$(pwd)"

pane_id="$(herdr pane list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
  | jq -r --arg t "$pane_title" '.result.panes[]? | select(.title == $t) | .pane_id' \
  | head -1)"

if [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  pane_id="$(herdr pane split --pane "$HERDR_PANE_ID" --direction down --no-focus --cwd "$cwd" 2>/dev/null \
    | jq -r '.result.pane.pane_id // empty')"
  [ -n "$pane_id" ] || exit 0
  herdr pane report-metadata "$pane_id" --source "$source_id" --title "$pane_title" >/dev/null 2>&1 || true
fi

herdr pane run "$pane_id" hunk diff --theme solarized-light --watch >/dev/null 2>&1 || true
