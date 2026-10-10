#!/usr/bin/env bash
# kitty open action (open-actions.conf): open a clicked Markdown file in
# plannotator-tui, in a tab of its own in the herdr workspace of the file's main
# checkout: `review:<file>`, or `review:<branch>/<file>` from a worktree. Notes
# sent from the review arrive as the next message of the agent whose pane
# printed the link; with no such pane, of the focused pane's agent.
#
# Anything that goes wrong (herdr not running, no plugin, a file that could
# inject into an agent's prompt) falls back to `open`, the plain file opener.
# kitty starts this with a bare PATH, hence the line below.

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

file_path="${1:-}"
case "$file_path" in /*) ;; *) exit 0 ;; esac
[ -f "$file_path" ] || exit 0

fallback() { command -v open >/dev/null 2>&1 && open -- "$file_path"; exit 0; }

command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || fallback

# Notes quote the document into the agent's prompt, so a control character in
# it (an escape, or a carriage return that submits the prompt) could end herdr's
# paste early and type the rest as a new prompt. A sidecar
# beside the file is imported as the person's own pending notes.
LC_ALL=C grep -qa $'[\x01-\x08\x0b-\x1f\x7f]' "$file_path" 2>/dev/null && fallback
[ -e "$file_path.annotations.json" ] && fallback

panes="$(herdr pane list 2>/dev/null)" && [ -n "$panes" ] || fallback

# The agent that printed the link, the focused one first; else the focused agent.
# The path must stand alone in the pane text: /other/repo/spec.md is not it.
# Only the visible screen is read: the link was clicked, so it is on screen, and
# a longer read makes herdr scroll an idle full-screen agent through its history.
path_re="(^|[^A-Za-z0-9._~%/-]|file://)$(printf '%s' "$file_path" | sed 's/[][\.*^$+?(){}|\/-]/\\&/g')([^A-Za-z0-9._~%/-]|$)"
target=""
while IFS= read -r id; do
  [ -n "$id" ] || continue
  if herdr pane read "$id" --source visible 2>/dev/null | grep -qE -- "$path_re"; then
    target="$id"
    break
  fi
done < <(printf '%s' "$panes" | jq -r '[.result.panes[]? | select(.agent != null)] | sort_by(.focused | not) | .[].pane_id')
[ -n "$target" ] || target="$(printf '%s' "$panes" | jq -r '[.result.panes[]? | select(.agent != null and .focused)] | first | .pane_id // empty')"
target_ws="$(printf '%s' "$panes" | jq -r --arg t "$target" '[.result.panes[]? | select(.pane_id == $t)] | first | .workspace_id // empty')"

name="$(basename "$file_path")"
label="review:${name%.*}"
dir="$(dirname "$file_path")"
real_dir="$(cd "$dir" 2>/dev/null && pwd -P)"

# Review tabs go in the main checkout's workspace, not the worktree's.
workspace="$target_ws"
git_dir="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)"
common_dir="$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
if [ -n "$common_dir" ]; then
  if [ "$git_dir" != "$common_dir" ]; then
    branch="$(git -C "$dir" branch --show-current 2>/dev/null | sed -E 's#^(fix|feat)/##')"
    [ -n "$branch" ] && label="review:$branch/${name%.*}"
  fi
  main_ws="$(herdr workspace list 2>/dev/null \
    | jq -r --arg r "${common_dir%/.git}" '[.result.workspaces[]?
        | select(.worktree.is_linked_worktree == false and .worktree.repo_root == $r)
        | .workspace_id] | first // empty' 2>/dev/null)"
  [ -n "$main_ws" ] && workspace="$main_ws"
fi
[ -n "$workspace" ] || fallback

# This file's earlier reviews: tabs with its label whose plannotator pane was
# opened in its folder, since the label alone matches any file of that name.
old_tabs="$(jq -rn --arg label "$label" --arg dir "$dir" --arg real "$real_dir" \
    --argjson tabs "$(herdr tab list --workspace "$workspace" 2>/dev/null || echo '{}')" \
    --argjson panes "$(herdr pane list --workspace "$workspace" 2>/dev/null || echo '{}')" '
  [$panes.result.panes[]? | select(.label == "Annotate" and (.cwd == $dir or .cwd == $real)) | .tab_id] as $ours
  | $tabs.result.tabs[]? | select(.label == $label) | select(.tab_id as $t | any($ours[]; . == $t))
  | .tab_id' 2>/dev/null)"

deliver=()
[ -n "$target" ] && deliver=(--env "PLANNOTATOR_TUI_DELIVER_TO=$target")

new_tab_id="$(herdr plugin pane open --plugin annotate --entrypoint doc --placement tab \
    --workspace "$workspace" --focus --cwd "${real_dir:-$dir}" \
    --env "PLANNOTATOR_TUI_FILE=$file_path" ${deliver[@]+"${deliver[@]}"} 2>/dev/null \
  | jq -r '.result.plugin_pane.pane.tab_id // empty' 2>/dev/null)"
[ -n "$new_tab_id" ] || fallback
herdr tab rename "$new_tab_id" "$label" >/dev/null 2>&1

while IFS= read -r tab_id; do
  [ -n "$tab_id" ] && herdr tab close "$tab_id" >/dev/null 2>&1
done <<< "$old_tabs"
exit 0
