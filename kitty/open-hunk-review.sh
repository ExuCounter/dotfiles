#!/usr/bin/env bash
# kitty open action (open-actions.conf): open a clicked `hunk-review://<base>..<branch>`
# link as `hunk diff <base> <branch>` in a tab of its own, `hunk:<branch>`, in
# the herdr workspace of the main checkout. The tab starts in the main checkout,
# never in the branch's worktree: a tab inside a worktree stops Whiska removing it.
#
# The link is found on the screen of the agent pane that printed it, else the
# focused agent's, and that pane says which repo it is. Anything that goes wrong
# (a link that is not a pair of plain ref names, herdr not running) does nothing.
# kitty starts this with a bare PATH, hence the line below.

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

url="${1:-}"
spec="${url#hunk-review://}"
[ "$spec" != "$url" ] || exit 0
base="${spec%%..*}"
branch="${spec#*..}"
# Plain ref names only: the refs reach a shell command line in the new tab.
ref_re='^[A-Za-z0-9][A-Za-z0-9._/-]*$'
[[ "$base" =~ $ref_re && "$branch" =~ $ref_re && "$spec" == "$base..$branch" ]] || exit 0
[[ "$branch" != *..* ]] || exit 0

command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || exit 0
panes="$(herdr pane list 2>/dev/null)" && [ -n "$panes" ] || exit 0

link_re="$(printf '%s' "$url" | sed 's/[][\.*^$+?(){}|\/-]/\\&/g')([^A-Za-z0-9._/-]|$)"
target=""
while IFS= read -r id; do
  [ -n "$id" ] || continue
  if herdr pane read "$id" --source visible 2>/dev/null | grep -qE -- "$link_re"; then
    target="$id"
    break
  fi
done < <(printf '%s' "$panes" | jq -r '[.result.panes[]? | select(.agent != null)] | sort_by(.focused | not) | .[].pane_id')
[ -n "$target" ] || target="$(printf '%s' "$panes" | jq -r '[.result.panes[]? | select(.agent != null and .focused)] | first | .pane_id // empty')"
[ -n "$target" ] || exit 0

target_ws="$(printf '%s' "$panes" | jq -r --arg t "$target" '[.result.panes[]? | select(.pane_id == $t)] | first | .workspace_id // empty')"
target_cwd="$(printf '%s' "$panes" | jq -r --arg t "$target" '[.result.panes[]? | select(.pane_id == $t)] | first | .cwd // empty')"

# The main checkout: the repo root of the pane's workspace, else of its folder.
workspaces="$(herdr workspace list 2>/dev/null || echo '{}')"
root="$(printf '%s' "$workspaces" | jq -r --arg w "$target_ws" '[.result.workspaces[]? | select(.workspace_id == $w)] | first | .worktree.repo_root // empty' 2>/dev/null)"
if [ -z "$root" ] && [ -n "$target_cwd" ]; then
  common_dir="$(git -C "$target_cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$common_dir" ] && root="${common_dir%/.git}"
fi
[ -n "$root" ] || exit 0
workspace="$(printf '%s' "$workspaces" | jq -r --arg r "$root" '[.result.workspaces[]?
    | select(.worktree.is_linked_worktree == false and .worktree.repo_root == $r)
    | .workspace_id] | first // empty' 2>/dev/null)"
[ -n "$workspace" ] || workspace="$target_ws"
[ -n "$workspace" ] || exit 0

# hunk compares two files when both names are files, so both must be refs here.
for ref in "$base" "$branch"; do
  git -C "$root" rev-parse --verify --quiet "refs/heads/$ref^{commit}" >/dev/null 2>&1 \
    || git -C "$root" rev-parse --verify --quiet "refs/remotes/$ref^{commit}" >/dev/null 2>&1 \
    || exit 0
done

label="hunk:$branch"

# An earlier review of this branch is replaced, but only once the new one is up.
old_tabs="$(herdr tab list --workspace "$workspace" 2>/dev/null \
  | jq -r --arg l "$label" '.result.tabs[]? | select(.label == $l) | .tab_id' 2>/dev/null)"

created="$(herdr tab create --workspace "$workspace" --label "$label" --cwd "$root" --no-focus 2>/dev/null)"
new_tab_id="$(printf '%s' "$created" | jq -r '.result.tab.tab_id // .result.root_pane.tab_id // empty' 2>/dev/null)"
pane_id="$(printf '%s' "$created" | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null)"
[ -n "$new_tab_id" ] && [ -n "$pane_id" ] || exit 0

herdr pane run "$pane_id" "hunk diff $base $branch" >/dev/null 2>&1 || exit 0
herdr tab focus "$new_tab_id" >/dev/null 2>&1

while IFS= read -r tab_id; do
  [ -n "$tab_id" ] && herdr tab close "$tab_id" >/dev/null 2>&1
done <<< "$old_tabs"
exit 0
