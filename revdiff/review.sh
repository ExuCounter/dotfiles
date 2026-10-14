#!/usr/bin/env bash
# Review one Markdown file in revdiff, in the tab kitty/open-markdown-link.sh
# opened for it. E sends the notes to the agent pane given here (send.sh is
# revdiff's post-flush command); quitting with q sends whatever E has not.
# Nothing sent stays on screen until a key is pressed; revdiff's history file
# under ~/.config/revdiff/history keeps the notes either way.
#
# Usage: review.sh FILE [PANE]
#
# revdiff takes file arguments as git refs, so the file goes in on stdin.

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

file="${1:-}"
pane="${2:-}"
here="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
stop() { printf '%s\nPress any key to close.\n' "$1"; read -rsn1; exit 1; }

session="$(mktemp -d "${TMPDIR:-/tmp}/revdiff-review.XXXXXX")"
trap 'rm -rf "$session"' EXIT
: > "$session/sent"

# One copy is both shown and quoted from, so a rewrite during the review cannot
# change what the notes point at, nor slip a control character past the check.
cp "$file" "$session/doc" 2>/dev/null || stop "Cannot read $file"
LC_ALL=C grep -qa $'[\x01-\x08\x0b-\x1f\x7f]' "$session/doc" &&
  stop "$file holds control characters, which could reach the agent's prompt. Not reviewed."
export REVDIFF_REVIEW_FILE="$file" REVDIFF_REVIEW_COPY="$session/doc" REVDIFF_DELIVER_TO="$pane" \
  REVDIFF_SENT="$session/sent"

# revdiff draws on the terminal and prints the notes on q, nothing on Q.
notes="$(revdiff --stdin --stdin-name="$(basename "$file")" --wrap --vim-motion \
  --post-flush-command="$here/send.sh" < "$session/doc")" || stop "revdiff failed (exit $?)."

[ -n "$notes" ] || exit 0
result="$(printf '%s\n' "$notes" | "$here/send.sh")" || stop "$result"
