#!/usr/bin/env bash
# Removes a worktree made by worktree-create.sh. Its branch stays unless it's merged.
set -euo pipefail

path=$(jq -r '.worktree_path' <<<"$(cat)")
[ -d "$path" ] || exit 0

branch=$(git -C "$path" branch --show-current)
common=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir)
main=$(dirname "$common")

git -C "$main" worktree remove --force "$path" >&2
[ -n "$branch" ] && git -C "$main" branch -d "$branch" >&2 2>/dev/null || true
