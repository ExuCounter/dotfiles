#!/usr/bin/env bash
# After a Herdr update: commit the newly shipped spaces main.js onto the
# `upstream` branch, which holds Herdr's file unchanged, and merge upstream
# into the branch checked out, so spaces-smart's own changes merge three-way
# (the DarkoKuzmanovic/herdr-mods way). It never switches branches: upstream
# moves by plumbing. A conflict stops the merge for you to finish.
#
# Usage: spaces-smart-merge.sh [shipped main.js]
#   default: ~/.config/herdr-app/mods/spaces/main.js
set -euo pipefail

SHIPPED="${1:-$HOME/.config/herdr-app/mods/spaces/main.js}"
MOD="herdr-app/mods/spaces-smart/main.js"
REPO="$(git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)"
git() { command git -C "$REPO" "$@"; }

[ -f "$SHIPPED" ] || { echo "spaces-smart-merge: no shipped file at $SHIPPED" >&2; exit 1; }
git rev-parse -q --verify upstream >/dev/null || { echo "spaces-smart-merge: $REPO has no upstream branch" >&2; exit 1; }

version="$(herdr-app --version 2>/dev/null | awk '{print $2}' || true)"
from="herdr-app ${version:-update}"

if [ "$(git hash-object "$SHIPPED")" != "$(git rev-parse "upstream:$MOD")" ]; then
  index="$(mktemp)"
  trap 'rm -f "$index"' EXIT
  blob="$(git hash-object -w "$SHIPPED")"
  GIT_INDEX_FILE="$index" git read-tree upstream
  GIT_INDEX_FILE="$index" git update-index --cacheinfo "100644,$blob,$MOD"
  tree="$(GIT_INDEX_FILE="$index" git write-tree)"
  commit="$(git commit-tree "$tree" -p upstream -m "chore(herdr-app): Herdr's shipped spaces main.js ($from), unchanged")"
  git update-ref refs/heads/upstream "$commit"
  echo "spaces-smart-merge: upstream has the spaces main.js from $from"
elif git merge-base --is-ancestor upstream HEAD; then
  echo "spaces-smart-merge: Herdr's spaces main.js is already in; nothing to merge"
  exit 0
fi

if ! git merge --no-edit -m "Merge Herdr's shipped spaces ($from) into spaces-smart" upstream; then
  echo "spaces-smart-merge: conflict in $REPO: resolve it, git commit, then touch -h ~/.config/herdr-app/mods/spaces-smart" >&2
  exit 1
fi
# The app doesn't see an edit behind the mod's link; touching the link reloads it.
link="$HOME/.config/herdr-app/mods/spaces-smart"
[ -L "$link" ] && touch -h "$link"
echo "spaces-smart-merge: merged; run herdr-app check $link"
