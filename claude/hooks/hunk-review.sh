#!/usr/bin/env bash
# Stop hook: when a worktree session ends a turn finished, show its branch in a
# `hunk-review` tab of its herdr workspace.
#
# Finished is Whiska's done marker: the last non-blank line of the final message
# is exactly three U+2063 characters. The review is everything since the branch
# left the default branch, committed or not; hunk adds untracked files itself.
#
# Hook JSON arrives on stdin. Never fails the hook: every path exits 0.

set -u
payload="$(cat 2>/dev/null || true)"

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_WORKSPACE_ID:-}" ] || exit 0
for tool in herdr hunk jq git perl; do
  command -v "$tool" >/dev/null 2>&1 || exit 0
done

finished="$(printf '%s' "$payload" | jq -r '
  (.last_assistant_message // "")
  | split("\n") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))
  | (last // "") == "⁣⁣⁣"' 2>/dev/null)"
[ "$finished" = "true" ] || exit 0

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || exit 0
[ "$git_dir" != "$common_dir" ] || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# A worktree branches from whatever the main checkout has checked out, which is
# not always the default branch. The fork point is the newest merge-base with
# any of those lines, local or remote.
main_checkout_branch="$(git worktree list --porcelain 2>/dev/null \
  | awk '/^$/ { exit } sub(/^branch refs\/heads\//, "")')"
default_branch="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
base=""
seen=" "
for name in "$main_checkout_branch" "${default_branch#origin/}" master main; do
  case "$seen" in *" $name "*) continue ;; esac
  seen="$seen$name "
  [ -n "$name" ] || continue
  for ref in "$name" "origin/$name"; do
    candidate="$(git merge-base HEAD "$ref" 2>/dev/null)" || continue
    if [ -z "$base" ] || git merge-base --is-ancestor "$base" "$candidate" 2>/dev/null; then
      base="$candidate"
    fi
  done
done
[ -n "$base" ] || exit 0

if git diff --quiet "$base" -- 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  exit 0
fi

tab_label="hunk-review"
review=(diff "$base" --theme solarized-light --watch)

existing_tab="$(herdr tab list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
  | jq -r --arg l "$tab_label" '[.result.tabs[]? | select(.label == $l) | .tab_id] | first // empty' 2>/dev/null)"

if [ -n "$existing_tab" ]; then
  # A hunk that was quit, or that predates the running hunk daemon, cannot be
  # reloaded; its tab is replaced. perl's alarm bounds a daemon that never answers.
  if perl -e 'alarm shift; exec @ARGV' 2 hunk session reload --repo "$root" -- "${review[@]}" >/dev/null 2>&1; then
    exit 0
  fi
  # The person may have quit hunk and used the tab's shell for something else.
  panes="$(herdr pane list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
    | jq -r --arg t "$existing_tab" '.result.panes[]? | select(.tab_id == $t) | .pane_id' 2>/dev/null)"
  [ -n "$panes" ] || exit 0
  for pane in $panes; do
    replaceable="$(herdr pane process-info --pane "$pane" 2>/dev/null | jq -r '.result.process_info
      | .foreground_process_group_id == .shell_pid
        or ([.foreground_processes[]?.name] | length > 0 and all(. == "hunk"))' 2>/dev/null)"
    [ "$replaceable" = "true" ] || exit 0
  done
  herdr tab close "$existing_tab" >/dev/null 2>&1 || exit 0
fi

# Unfocused: herdr's tab focus also switches the person's whole view to this workspace.
pane_id="$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --label "$tab_label" --cwd "$root" --no-focus 2>/dev/null \
  | jq -r '.result.root_pane.pane_id // empty' 2>/dev/null)"
[ -n "$pane_id" ] || exit 0

herdr pane run "$pane_id" "hunk ${review[*]}" >/dev/null 2>&1 || true
exit 0
