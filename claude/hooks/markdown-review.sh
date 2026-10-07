#!/usr/bin/env bash
# PostToolUse hook: open the .md file Claude writes in plannotator-tui (the herdr
# Annotate plugin), in a tab of its own in the herdr workspace of the main
# checkout: `review:<file>`, or `review:<branch>/<file>` from a worktree. Notes
# sent from the review arrive as the next message of the session that wrote the
# file: delivery targets this session's herdr pane.
#
# plannotator-tui does not watch the file, so a rewrite replaces that file's tab.
# Annotations survive that: plannotator-tui keeps them per file path.
# No-ops outside a herdr session. Never fails the hook: every path exits 0.

set -u

hook_input="$(cat)"

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_WORKSPACE_ID:-}" ] && [ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

file_path="$(printf '%s' "$hook_input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)"
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

# Notes quote the document into the agent's prompt, so an escape sequence in it
# could end herdr's paste early and type the rest as a new prompt. A sidecar
# beside the file is imported as the person's own pending notes.
LC_ALL=C grep -q $'\x1b' "$file_path" 2>/dev/null && exit 0
[ -e "$file_path.annotations.json" ] && exit 0

name="$(basename "$file_path")"
label="review:${name%.*}"
workspace="$HERDR_WORKSPACE_ID"

# hunk-review.sh closes `review: <branch>` tabs, with a space, once their
# worktree is gone; these labels never take that form.
project="${CLAUDE_PROJECT_DIR:-$PWD}"
git_dir="$(git -C "$project" rev-parse --absolute-git-dir 2>/dev/null)"
common_dir="$(git -C "$project" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
if [ -n "$git_dir" ] && [ "$git_dir" != "$common_dir" ]; then
  branch="$(git -C "$project" branch --show-current 2>/dev/null | sed -E 's#^(fix|feat)/##')"
  [ -n "$branch" ] && label="review:$branch/${name%.*}"
  main_ws="$(herdr workspace list 2>/dev/null \
    | jq -r --arg r "${common_dir%/.git}" '[.result.workspaces[]?
        | select(.worktree.is_linked_worktree == false and .worktree.repo_root == $r)
        | .workspace_id] | first // empty' 2>/dev/null)"
  [ -n "$main_ws" ] && workspace="$main_ws"
fi

dir="$(dirname "$file_path")"
real_dir="$(cd "$dir" 2>/dev/null && pwd -P)"

# This file's earlier reviews: tabs with its label whose plannotator pane was
# opened in its folder, since the label alone matches any file of that name.
old_tabs="$(jq -rn --arg label "$label" --arg dir "$dir" --arg real "$real_dir" \
    --argjson tabs "$(herdr tab list --workspace "$workspace" 2>/dev/null)" \
    --argjson panes "$(herdr pane list --workspace "$workspace" 2>/dev/null)" '
  [$panes.result.panes[]? | select(.label == "Annotate" and (.cwd == $dir or .cwd == $real)) | .tab_id] as $ours
  | $tabs.result.tabs[]? | select(.label == $label) | select(.tab_id as $t | any($ours[]; . == $t))
  | "\(.tab_id)\t\(.focused // false)"' 2>/dev/null)"
focus="--no-focus"
case "$old_tabs" in *$'\t'true*) focus="--focus" ;; esac

new_tab_id="$(herdr plugin pane open --plugin annotate --entrypoint doc --placement tab \
    --workspace "$workspace" "$focus" --cwd "${real_dir:-$dir}" \
    --env "PLANNOTATOR_TUI_FILE=$file_path" --env "PLANNOTATOR_TUI_DELIVER_TO=$HERDR_PANE_ID" 2>/dev/null \
  | jq -r '.result.plugin_pane.pane.tab_id // empty' 2>/dev/null)"
[ -n "$new_tab_id" ] || exit 0
herdr tab rename "$new_tab_id" "$label" >/dev/null 2>&1

while IFS=$'\t' read -r tab_id _; do
  [ -n "$tab_id" ] && herdr tab close "$tab_id" >/dev/null 2>&1
done <<< "$old_tabs"
exit 0
