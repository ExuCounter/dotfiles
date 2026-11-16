#!/usr/bin/env bash
# Primes a new worktree from the main checkout so it builds without a cold start:
# clones the build folders copy-on-write (APFS clonefile: instant, no extra space until a
# file changes) and links the local env file, which is gitignored and so never checked out.
# Usage: prime.sh <main checkout> <worktree>. Output goes to stderr.
set -euo pipefail

main=$1
wt=$2

# One clonefile(2) call clones a whole tree; cp -c clones file by file, many times slower.
clone() {
  python3 -c 'import ctypes, sys; sys.exit(ctypes.CDLL("libc.dylib").clonefile(*map(str.encode, sys.argv[1:]), 0))' "$1" "$2" ||
    cp -cR "$1" "$2"
}

for dir in deps _build node_modules "$main"/*/node_modules; do
  rel=${dir#"$main"/}
  if [ -d "$main/$rel" ] && [ ! -e "$wt/$rel" ]; then
    mkdir -p "$(dirname "$wt/$rel")"
    clone "$main/$rel" "$wt/$rel" && echo "cloned $rel" >&2
  fi
done

for env in .envrc .env; do
  if [ -f "$main/$env" ] && [ ! -e "$wt/$env" ]; then
    ln -s "$main/$env" "$wt/$env" && echo "linked $env" >&2
  fi
done

# Project skills kept in the main checkout but not in git never get checked out either.
for skill in "$main"/.claude/skills/*/; do
  rel=.claude/skills/$(basename "$skill")
  if [ ! -e "$wt/$rel" ] && [ -z "$(git -C "$main" ls-files "$rel")" ]; then
    mkdir -p "$wt/.claude/skills"
    ln -s "$main/$rel" "$wt/$rel" && echo "linked $rel" >&2
  fi
done

if [ -e "$wt/.envrc" ] && command -v direnv >/dev/null; then
  direnv allow "$wt" >&2
fi
