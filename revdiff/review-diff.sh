#!/usr/bin/env bash
# Review one git patch in revdiff, in the tab kitty/open-review-link.sh opened
# for it: the patch's before and after trees (patch-trees.sh, read from the repo
# the patch sits in) shown as a branch diff. E sends the notes to the agent pane
# given here (send.sh); quitting with q sends whatever E has not.
#
# Usage: review-diff.sh FILE [PANE]
#
# A patch whose trees cannot be rebuilt is reviewed as plain text (review.sh).

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

file="${1:-}"
pane="${2:-}"
here="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
stop() { printf '%s\nPress any key to close.\n' "$1"; read -rsn1; exit 1; }

session="$(mktemp -d "${TMPDIR:-/tmp}/revdiff-review.XXXXXX")"
trap 'rm -rf "$session"' EXIT
: > "$session/sent"

cp "$file" "$session/patch" 2>/dev/null || stop "Cannot read $file"
repo="$session/repo"
if ! revs="$("$here/patch-trees.sh" "$session/patch" "$(dirname "$file")" "$repo")"; then
  rm -rf "$session"
  trap - EXIT
  exec "$here/review.sh" "$file" "$pane"
fi
read -r old new <<< "$revs"

export REVDIFF_REVIEW_FILE="$file" REVDIFF_REVIEW_COPY="$session/patch" REVDIFF_REVIEW_REPO="$repo" \
  REVDIFF_REVIEW_OLD="$old" REVDIFF_REVIEW_NEW="$new" REVDIFF_DELIVER_TO="$pane" REVDIFF_SENT="$session/sent"

(cd "$repo" && exec revdiff "$old" "$new" --wrap --vim-motion \
  --output="$session/notes" --history-dir="$session/history" \
  --post-flush-command="$here/send.sh")
rstatus=$?
[ "$rstatus" = 0 ] || stop "revdiff failed (exit $rstatus)."

[ -s "$session/notes" ] || exit 0
result="$("$here/send.sh" < "$session/notes")" || stop "$result"
