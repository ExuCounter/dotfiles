#!/usr/bin/env bash
# Stop hook: open hunk in a review tab against the current worktree diff.
# Fires only when:
#   - Claude edited files this turn (mark-edit.sh dropped a marker), AND
#   - a `hunk-review` tab isn't already open in this workspace.
# The tab uses `--watch` so subsequent edits auto-refresh in place.

set -eu
cat >/dev/null

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_WORKSPACE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v hunk >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

marker="/tmp/hunk-mark-$HERDR_WORKSPACE_ID"
[ -f "$marker" ] || exit 0
rm -f "$marker"

# Only inside a git repo with pending changes.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git status --porcelain 2>/dev/null)" ] || exit 0

tab_label="hunk-review"
cwd="$(pwd)"

existing_tab="$(herdr tab list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
  | jq -r --arg l "$tab_label" '.result.tabs[]? | select(.label == $l) | .tab_id' \
  | head -1)"

[ -z "$existing_tab" ] || exit 0

pane_id="$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --label "$tab_label" --cwd "$cwd" 2>/dev/null \
  | jq -r '.result.root_pane.pane_id // empty')"
[ -n "$pane_id" ] || exit 0

herdr pane run "$pane_id" hunk diff --theme solarized-light --watch >/dev/null 2>&1 || true
