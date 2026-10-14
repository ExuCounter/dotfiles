#!/usr/bin/env bash
# Review one Markdown file in revdiff, in the tab kitty/open-markdown-link.sh
# opened for it. E sends the notes to the agent pane given here (send.sh is
# revdiff's post-flush command); quitting with q sends whatever E has not.
# Nothing sent stays on screen until a key is pressed; revdiff's history file
# under ~/.config/revdiff/history keeps the notes either way.
#
# Usage: review.sh FILE [PANE]
#
# revdiff takes file arguments as git refs, and refuses --stdin together with
# --annotations, so the copy is committed to a throwaway repo and browsed there
# (-A), which is the one view that can preload notes.
#
# In a herdr pane (HERDR_PANE_ID set) the review follows the file: when it
# changes, revdiff is stopped with SIGTERM, which makes it write its notes to
# its history; they are moved to the matching lines of the fresh copy
# (reanchor.sh) and revdiff starts again with them. A reload sends nothing.

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

file="${1:-}"
pane="${2:-}"
here="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
stop() { printf '%s\nPress any key to close.\n' "$1"; read -rsn1; exit 1; }

session="$(mktemp -d "${TMPDIR:-/tmp}/revdiff-review.XXXXXX")"
trap 'rm -rf "$session"' EXIT
: > "$session/sent"
history="$session/history"

has_control() { LC_ALL=C grep -qa $'[\x01-\x08\x0b-\x1f\x7f]' "$1"; }

# src is the file as read, doc the aligned copy. One copy is both shown and
# quoted from, so a rewrite during the review cannot change what the notes point
# at, nor slip a control character past the check. Pipe tables are padded so
# their columns line up in revdiff's raw view; only spaces change inside lines,
# so line numbers and note anchors stay exact.
align() { LC_ALL=C awk -f "$here/align-tables.awk" "$1" > "$2.tmp" && mv "$2.tmp" "$2"; }

cp "$file" "$session/src" 2>/dev/null || stop "Cannot read $file"
has_control "$session/src" &&
  stop "$file holds control characters, which could reach the agent's prompt. Not reviewed."
repo="$session/repo"
doc="$repo/$(basename "$file")"
git init -q "$repo" 2>/dev/null || stop "Cannot create a scratch repository for the review."
commit() {
  env -u GIT_DIR -u GIT_WORK_TREE git -C "$repo" add -- "$doc" &&
    env -u GIT_DIR -u GIT_WORK_TREE git -C "$repo" -c user.name=review -c user.email=review@localhost \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q --allow-empty -m review
}
cp "$session/src" "$doc"
align "$doc" "$doc"
commit || stop "Cannot create a scratch repository for the review."
export REVDIFF_REVIEW_FILE="$file" REVDIFF_REVIEW_COPY="$doc" REVDIFF_DELIVER_TO="$pane" \
  REVDIFF_SENT="$session/sent"

# Stops revdiff (pid $1) once the file differs from the copy shown and the
# difference is safe to show. A file with control characters is left alone.
watch() {
  while kill -0 "$1" 2>/dev/null; do
    sleep "${REVDIFF_POLL:-1}"
    cmp -s "$file" "$session/src" && continue
    cp "$file" "$session/probe" 2>/dev/null || continue
    cmp -s "$session/probe" "$session/src" && continue
    has_control "$session/probe" && continue
    kill -TERM "$1" 2>/dev/null && : > "$session/reload"
    return
  done
}

# The newest note snapshot revdiff left in its history, carried onto the
# changed file. An unreadable or unsafe file keeps the copy being shown.
reload() {
  local snap="" f
  while IFS= read -r f; do
    [ -z "$snap" ] || [ "$f" -nt "$snap" ] && snap="$f"
  done < <(find "$history" -type f -name '*.md' 2>/dev/null)
  if cp "$file" "$session/next" 2>/dev/null && ! has_control "$session/next"; then
    align "$session/next" "$session/next.doc"
    cp "$session/next" "$session/src"
  else
    cp "$doc" "$session/next.doc"
  fi
  : > "$session/annotations"
  [ -z "$snap" ] || "$here/reanchor.sh" "$doc" "$session/next.doc" "$snap" "$session/sent" \
    > "$session/annotations" || : > "$session/annotations"
  mv "$session/next.doc" "$doc"
  commit
}

annotations=()
while :; do
  rm -rf "$history" "$session/notes" "$session/reload"
  # revdiff draws on the terminal and writes the notes on q, nothing on Q.
  (cd "$repo" && exec revdiff -A --no-tree --wrap --vim-motion \
    --output="$session/notes" --history-dir="$history" ${annotations[@]+"${annotations[@]}"} \
    --post-flush-command="$here/send.sh") &
  rpid=$!
  wpid=""
  [ -z "${HERDR_PANE_ID:-}" ] || { watch "$rpid" & wpid=$!; }
  wait "$rpid"; rstatus=$?
  [ -z "$wpid" ] || { kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null; }
  # Quitting with q also writes the history, so a quit that raced the reload
  # loses no note.
  if [ -e "$session/reload" ]; then
    reload
    annotations=(--annotations="$session/annotations")
    continue
  fi
  break
done
[ "$rstatus" = 0 ] || stop "revdiff failed (exit $rstatus)."

[ -s "$session/notes" ] || exit 0
result="$("$here/send.sh" < "$session/notes")" || stop "$result"
