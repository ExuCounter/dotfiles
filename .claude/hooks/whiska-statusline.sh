#!/usr/bin/env bash
# Whiska's project statusline (ADR-0051): a board, one row per mouse in
# this repo — its branch, what herdr says it is doing, and either the
# question waiting on you or its last action.
#
# A project-level statusLine replaces the global one rather than merging
# with it, so your global statusline runs first and the board goes under
# it.
#
# Nothing here starts Whiska. The owl writes the board to a file every
# couple of seconds and this prints it, which is what makes a two-second
# refresh affordable in every open session at once.
#
# Written by `whiska init`.

input="$(cat)"

global=""
if command -v jq >/dev/null 2>&1 && [ -r "$HOME/.claude/settings.json" ]; then
  global="$(jq -r '.statusLine.command // empty' "$HOME/.claude/settings.json" 2>/dev/null)"
fi

# A global statusLine that is Whiska's own is this script, or the copy in
# ~/.claude. The line that one displaced is kept beside it, and that is the
# one to run (ADR-0056).
case "$global" in
  *whiska-statusline.sh*) global="" ;;
esac
if [ -z "$global" ] && [ -r "$HOME/.claude/whiska-base-statusline" ]; then
  global="$(cat "$HOME/.claude/whiska-base-statusline")"
fi

base=""
[ -n "$global" ] && base="$(printf '%s' "$input" | bash -c "$global" 2>/dev/null)"

[ -n "$base" ] && printf '%s
' "$base"

dir=""
if command -v jq >/dev/null 2>&1; then
  dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .workspace.project_dir // .cwd // empty' 2>/dev/null)"
fi
[ -d "$dir" ] || dir="$PWD"

# A mouse's own pane never draws the board: it is the person's view of
# their mice, and a mouse has no use for its siblings' rows.
case "$dir" in
  */worktrees/*) exit 0 ;;
esac

# The board is named after the main checkout, so a session sitting in a
# subfolder walks up until it finds one.
home="${WHISKA_HOME:-$HOME/.whiska}"
board=""
probe="$dir"
while [ -n "$probe" ] && [ "$probe" != "/" ] && [ "$probe" != "." ]; do
  # LC_ALL=C so tr counts bytes: a path with a non-ASCII character in it
  # must be spelled the same here as the owl spells it.
  candidate="$home/board/$(printf '%s' "$probe" | LC_ALL=C tr -c 'A-Za-z0-9' '-')"
  if [ -f "$candidate" ]; then
    board="$candidate"
    break
  fi
  probe="$(dirname "$probe")"
done

[ -n "$board" ] && [ -s "$board" ] || exit 0

# BSD stat first, then GNU, and each answer is checked rather than trusted:
# `stat -f` on GNU means --file-system and prints a paragraph.
mtime="$(stat -f %m "$board" 2>/dev/null)"
case "$mtime" in
  "" | *[!0-9]*) mtime="$(stat -c %Y "$board" 2>/dev/null)" ;;
esac
case "$mtime" in
  "" | *[!0-9]*) exit 0 ;;
esac
age=$(( $(date +%s) - mtime ))

# A board nothing has refreshed is still mostly true for a little while,
# and hiding it the moment something goes wrong is the worse failure. Past
# a minute it stops being worth showing; herdr's tab bar says the owl is
# down either way (ADR-0048). Ten seconds, not five: a house waiting on a
# slow herdr can miss a couple of its own two-second writes without the owl
# being down at all.
if [ "$age" -le 10 ]; then
  cat "$board"
elif [ "$age" -le 60 ]; then
  printf '🦉 owl down · %ss stale
' "$age"
  awk '{ printf "%c[2m%s%c[0m%c", 27, $0, 27, 10 }' "$board"
fi
