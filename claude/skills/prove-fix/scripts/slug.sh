#!/usr/bin/env bash
# The branch as a folder and database name: lowercase a-z, 0-9 and _, at most 40 characters.
#   slug.sh [<branch>]             the current branch when none is given
#   slug.sh --gitlab [<branch>]    GitLab's CI_COMMIT_REF_SLUG of it instead, as CI names environments
set -euo pipefail

gitlab=""
if [ "${1:-}" = --gitlab ]; then
  gitlab=1
  shift
fi
branch="${1:-$(git branch --show-current)}"
[ -n "$branch" ] || { echo "slug.sh: no branch checked out" >&2; exit 65; }
if [ -n "$gitlab" ]; then
  slug="$(python3 -c 'import re, sys; print(re.sub(r"\A-+|-+\Z", "", re.sub(r"[^a-z0-9]", "-", sys.argv[1].lower())[:63]))' "$branch")"
else
  slug="$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | cut -c1-40 | sed 's/^_*//; s/_*$//')"
fi
[ -n "$slug" ] || { echo "slug.sh: $branch has no a-z or 0-9 to name it by" >&2; exit 65; }
printf '%s\n' "$slug"
