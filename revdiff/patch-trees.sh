#!/usr/bin/env bash
# Rebuild the before and after trees of a git patch as two commits in a fresh
# scratch repo, for revdiff to show as a diff (see review-diff.sh). revdiff
# reads refs, not patch files.
#
# Usage: patch-trees.sh PATCH REPO_DIR SCRATCH_REPO
# Prints "<old-commit> <new-commit>"; exits 1 when the patch cannot be rebuilt.
#
# The trees come from the blob ids on each section's `index` line, read from
# REPO_DIR's object store through the scratch repo's alternates file: nothing is
# written to REPO_DIR, and every file shows whole, binary ones included. A pure
# rename, copy or mode change carries no blob id, so it gets its source's blob
# when another section names it, else a one-line placeholder on both sides. A submodule's ids are commits of another repo, so they are
# taken whole from its `Subproject commit` lines. A section git quoted the paths of, one with no blob id that is
# neither, or a blob the repo lacks fails the rebuild.

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
# A partial clone's missing blob fails the rebuild rather than being fetched.
export GIT_NO_LAZY_FETCH=1

patch="${1:-}" repo_dir="${2:-}" scratch="${3:-}"
[ -f "$patch" ] && [ -n "$scratch" ] || exit 1

objects="$(git -C "$repo_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/objects"
[ -d "$objects" ] || exit 1
git init -q "$scratch" 2>/dev/null || exit 1
printf '%s\n' "$objects" > "$scratch/.git/objects/info/alternates"
sg() { git -C "$scratch" "$@"; }

# One record per section: old path, new path, old blob, new blob,
# old mode, new mode, copy flag, split by \037. A blob is empty when the section has no
# index line, all zeros on the side a new or deleted file lacks.
records="$(LC_ALL=C awk '
  function emit() {
    if (!open) return
    if (oldp == "" || newp == "") { bad = 1; return }
    if (ob == "" && (content || (oldp == newp && omode == nmode))) { bad = 1; return }
    if (omode == "") omode = mode
    if (nmode == "") nmode = mode
    if (omode == "160000") ob = osub
    if (nmode == "160000") nb = nsub
    printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\n", oldp, newp, ob, nb, omode, nmode, copy
  }
  /^diff --git / {
    emit()
    open = 1; header = 1; content = copy = 0; oldp = newp = ob = nb = omode = nmode = mode = osub = nsub = ""
    rest = substr($0, 12)
    if (rest ~ /^"/) { bad = 1; open = 0; next }
    # "a/X b/X": the two halves are the same path unless a rename says otherwise.
    n = (length(rest) - 1) / 2
    if (n == int(n) && substr(rest, 1, 2) == "a/" && substr(rest, n + 2, 2) == "b/" \
        && substr(rest, 3, n - 2) == substr(rest, n + 4)) oldp = newp = substr(rest, 3, n - 2)
    next
  }
  /^-Subproject commit [0-9a-f]+$/ { osub = $3; next }
  /^\+Subproject commit [0-9a-f]+$/ { nsub = $3; next }
  !header { next }
  /^(--- |\+\+\+ |@@ |Binary files |GIT binary patch)/ { header = 0; content = 1; next }
  /^copy from / { copy = 1 }
  /^(rename|copy) from / { oldp = substr($0, index($0, "from ") + 5); next }
  /^(rename|copy) to / { newp = substr($0, index($0, "to ") + 3); next }
  /^old mode / { omode = $3; next }
  /^new mode / { nmode = $3; next }
  /^new file mode / { nmode = $4; next }
  /^deleted file mode / { omode = $4; next }
  /^index / { split($2, ids, "\\.\\."); ob = ids[1]; nb = ids[2]; if (NF >= 3) mode = $3; next }
  END { emit(); if (bad) exit 1 }
' "$patch")" || exit 1
[ -n "$records" ] || exit 1

# Named after its source, so two unchanged renames do not swap partners.
placeholder() { printf '(%s: no content in the patch, renamed, copied or mode changed only)\n' "$1" | sg hash-object -w --stdin; }
blob() {
  case "$2:$1" in
    160000:*) [[ "$1" =~ ^[0-9a-f]{40}$ ]] && printf '%s' "$1" ;;
    *) sg rev-parse --verify --quiet "$1^{blob}" ;;
  esac
}
# The index-info line in $1 for path $2.
entry_for() { P="$2" awk -F'\t' '$2 == ENVIRON["P"] { print; exit }' <<< "$1"; }

# Sections with blob ids first; update-index keeps the last entry for a path,
# so these come after the placeholders and copy sources they override.
old_real="" new_real="" gone=""
while IFS=$'\037' read -r oldp newp ob nb omode nmode copy; do
  [ "$copy" = 1 ] || [ "$oldp" = "$newp" ] || gone+="$oldp"$'\n'
  [ -n "$ob" ] || continue
  case "$ob" in *[!0]*)
    o="$(blob "$ob" "$omode")" || exit 1
    old_real+="${omode:-100644} $o"$'\t'"$oldp"$'\n' ;;
  esac
  case "$nb" in *[!0]*)
    n="$(blob "$nb" "$nmode")" || exit 1
    new_real+="${nmode:-100644} $n"$'\t'"$newp"$'\n' ;;
  *) gone+="$oldp"$'\n' ;;
  esac
done <<< "$records"

# A section with no blob id is an unchanged rename, copy or mode change: both
# sides hold the source's blob when another section names it, else the placeholder.
old_info="" new_info="" copied_info=""
while IFS=$'\037' read -r oldp newp ob nb omode nmode copy; do
  if [ -z "$ob" ]; then
    o="$(entry_for "$old_real" "$oldp" | cut -d' ' -f2 | cut -f1)"
    [ -n "$o" ] || o="$(placeholder "$oldp")" || exit 1
    old_info+="${omode:-100644} $o"$'\t'"$oldp"$'\n'
    new_info+="${nmode:-100644} $o"$'\t'"$newp"$'\n'
  fi
  # A copy's source stays in the after tree unless another section moves it.
  if [ "$copy" = 1 ] && ! printf '%s' "$gone" | grep -Fxq -- "$oldp"; then
    c="$(entry_for "$old_real" "$oldp")"
    [ -n "$c" ] || c="${omode:-100644} $(placeholder "$oldp")"$'\t'"$oldp"
    copied_info+="$c"$'\n'
  fi
done <<< "$records"
old_info+="$old_real"
new_info+="$copied_info$new_real"

tree() {
  local index="$scratch/.git/index-$1"
  rm -f "$index"
  printf '%s' "$2" | GIT_INDEX_FILE="$index" sg update-index --add --index-info || return 1
  GIT_INDEX_FILE="$index" sg write-tree
}
commit() { sg -c user.name=review -c user.email=review@localhost commit-tree "$@"; }
old_tree="$(tree old "$old_info")" && new_tree="$(tree new "$new_info")" || exit 1
old="$(commit "$old_tree" -m before </dev/null)" && new="$(commit "$new_tree" -p "$old" -m after </dev/null)" || exit 1
printf '%s %s\n' "$old" "$new"
