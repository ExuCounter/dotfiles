#!/usr/bin/env bash
# Claude Code's worktrees go where Herdr makes its own, ~/.herdr/worktrees/<repo>/<name>,
# so they show in its worktree lists. Git's output goes to stderr: Claude reads the path
# from stdout.
set -euo pipefail

input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")
name=$(jq -r '.name' <<<"$input")

common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir)
main=$(dirname "$common")
path="$HOME/.herdr/worktrees/$(basename "$main")/$name"
branch="worktree-$name"

if [ ! -d "$path" ]; then
  if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$main" worktree add "$path" "$branch" >&2
  else
    git -C "$main" worktree add -b "$branch" "$path" "$(git -C "$cwd" rev-parse HEAD)" >&2
  fi
  "$HOME/.claude/skills/spawn-worktree/prime.sh" "$main" "$path"
fi

echo "$path"
