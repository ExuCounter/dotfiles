#!/usr/bin/env bash
# kitty open action (open-actions.conf): open a clicked Markdown file or git
# patch in revdiff, in a tab of its own in the herdr workspace of the file's
# main checkout. A Markdown file goes to ~/.config/revdiff/review.sh as
# `review:<file>`, or `review:<branch>/<file>` from a worktree; a .diff or
# .patch to ~/.config/revdiff/review-diff.sh as `diff:<name>`, the name without
# the hash Whiska ends a branch's diff file with. Notes sent from the review (E) arrive as the next message of the
# agent whose pane printed the link; with no such pane, of the focused pane's
# agent. The tab starts in the main checkout, never in a worktree: a tab inside
# a worktree stops Whiska removing it.
#
# Anything that goes wrong (herdr or revdiff missing, a file that could inject
# into an agent's prompt) falls back to `open`, the plain file opener.
# kitty starts this with a bare PATH, hence the line below.

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

file_path="${1:-}"
case "$file_path" in /*) ;; *) exit 0 ;; esac
[ -f "$file_path" ] || exit 0
case "$file_path" in
  *.md|*.markdown) reviewer=review.sh ;;
  *.diff|*.patch) reviewer=review-diff.sh ;;
  *) exit 0 ;;
esac

fallback() { command -v open >/dev/null 2>&1 && open -- "$file_path"; exit 0; }

for tool in herdr jq revdiff; do command -v "$tool" >/dev/null 2>&1 || fallback; done

# Notes quote the document into the agent's prompt, so a control character in
# it (an escape, or a carriage return that submits the prompt) could end herdr's
# paste early and type the rest as a new prompt. The path is typed into the
# review tab's shell, where a control character could submit the line early.
LC_ALL=C grep -qa $'[\x01-\x08\x0b-\x1f\x7f]' "$file_path" 2>/dev/null && fallback
[[ "$file_path" == *[[:cntrl:]]* ]] && fallback

panes="$(herdr pane list 2>/dev/null)" && [ -n "$panes" ] || fallback

# The agent that printed the link, the focused one first; else the focused agent.
# The path must stand alone in the pane text: /other/repo/spec.md is not it.
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
if [ "$reviewer" = review-diff.sh ]; then
  label="diff:$(printf '%s' "${name%.*}" | sed -E 's/-[0-9a-f]{32}$//')"
fi
dir="$(dirname "$file_path")"
real_dir="$(cd "$dir" 2>/dev/null && pwd -P)"

# Review tabs go in the main checkout's workspace, not the worktree's.
workspace="$target_ws"
cwd="${real_dir:-$dir}"
git_dir="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)"
common_dir="$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
if [ -n "$common_dir" ]; then
  cwd="${common_dir%/.git}"
  if [ "$git_dir" != "$common_dir" ] && [ "$reviewer" = review.sh ]; then
    branch="$(git -C "$dir" branch --show-current 2>/dev/null | sed -E 's#^(fix|feat)/##')"
    [ -n "$branch" ] && label="review:$branch/${name%.*}"
  fi
  main_ws="$(herdr workspace list 2>/dev/null \
    | jq -r --arg r "$cwd" '[.result.workspaces[]?
        | select(.worktree.is_linked_worktree == false and .worktree.repo_root == $r)
        | .workspace_id] | first // empty' 2>/dev/null)"
  [ -n "$main_ws" ] && workspace="$main_ws"
fi
[ -n "$workspace" ] || fallback

old_tabs="$(herdr tab list --workspace "$workspace" 2>/dev/null \
  | jq -r --arg l "$label" '.result.tabs[]? | select(.label == $l) | .tab_id' 2>/dev/null)"

created="$(herdr tab create --workspace "$workspace" --label "$label" --cwd "$cwd" --no-focus 2>/dev/null)"
new_tab_id="$(printf '%s' "$created" | jq -r '.result.tab.tab_id // .result.root_pane.tab_id // empty' 2>/dev/null)"
pane_id="$(printf '%s' "$created" | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null)"
[ -n "$new_tab_id" ] && [ -n "$pane_id" ] || fallback

# Each word is single-quoted, so the tab's shell applies no glob or expansion.
# The shell exits with the review, which closes the tab.
quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
command_line="$(quote "$HOME/.config/revdiff/$reviewer") $(quote "$file_path") $(quote "$target"); exit"
if ! herdr pane run "$pane_id" "$command_line" >/dev/null 2>&1; then
  herdr tab close "$new_tab_id" >/dev/null 2>&1
  fallback
fi
herdr tab focus "$new_tab_id" >/dev/null 2>&1

while IFS= read -r tab_id; do
  [ -n "$tab_id" ] && herdr tab close "$tab_id" >/dev/null 2>&1
done <<< "$old_tabs"
exit 0
