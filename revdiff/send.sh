#!/usr/bin/env bash
# revdiff's post-flush command in a review tab (review.sh, review-diff.sh): read
# revdiff's snapshot of the person's notes on stdin and send the ones not yet
# sent in this review, as one message, to the agent pane the review was opened
# for. A snapshot is the whole current set, so each flush repeats earlier notes;
# $REVDIFF_SENT records what went, and an edited note goes again.
#
#   REVDIFF_REVIEW_FILE  absolute path of the file under review
#   REVDIFF_REVIEW_COPY  the copy revdiff showed, quoted from (default: the file)
#   REVDIFF_DELIVER_TO   herdr pane id of the agent, may be empty
#   REVDIFF_SENT         this review's record of sent notes, one JSON per line
#   REVDIFF_REVIEW_REPO  for a diff: the repo revdiff showed, notes then name
#                        their file and quote REVDIFF_REVIEW_OLD's side for a
#                        removed line, REVDIFF_REVIEW_NEW's for any other
#
# Prints one line for the person. Exits 0 when sent or nothing was new, 1 when
# nothing could be sent.

set -u
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

say() { printf '%s\n' "$*"; exit 1; }

file="${REVDIFF_REVIEW_FILE:-}"
copy="${REVDIFF_REVIEW_COPY:-$file}"
repo="${REVDIFF_REVIEW_REPO:-}"
target="${REVDIFF_DELIVER_TO:-}"
sent="${REVDIFF_SENT:-/dev/null}"

for tool in herdr jq; do
  command -v "$tool" >/dev/null 2>&1 || say "$tool is not installed. Nothing was sent."
done
[ -n "$file" ] || say "No file under review. Nothing was sent."
[ -n "$target" ] || say "No agent to send to. Nothing was sent."

snapshot="$(cat)"

# Records are `## <name>:<line>[-<end>] (<side>)` or `## <name> (file-level)`,
# each followed by its body up to the next record.
new="$(jq -nc --arg s "$snapshot" --slurpfile sent <(cat "$sent" 2>/dev/null) '
  [ $s | split("\n")[] ] | reduce .[] as $l ([];
      ([$l | capture("^## (?<name>.*?)(:(?<from>[0-9]+)(-(?<to>[0-9]+))?)? \\((?<side>[^)]*)\\)$")] | first) as $h
      | if $h then . + [{name: $h.name, from: $h.from, to: $h.to, side: $h.side, body: []}]
        elif length > 0 then .[-1].body += [$l]
        else . end)
  | map(.body |= (join("\n") | sub("\\s+$"; "")))
  | map(select(. as $n | $sent | index([$n]) | not))' 2>/dev/null)" ||
  say "Could not read revdiff's notes. Nothing was sent."
count="$(jq length <<< "$new")"
[ "$count" -gt 0 ] || { printf 'No new notes to send.\n'; exit 0; }

# A diff note's quote comes from its file on the side it was made on.
notes="$new"
if [ -n "$repo" ]; then
  quotes="$(mktemp)" || say "Could not read revdiff's notes. Nothing was sent."
  # A removed line of a renamed file is read from the old tree under its old name.
  renames="$(git -C "$repo" diff -z --name-status -M "${REVDIFF_REVIEW_OLD:-}" "${REVDIFF_REVIEW_NEW:-}" -- 2>/dev/null |
    jq 2>/dev/null -Rsc 'split("\u0000") | [recurse(.[(if .[0] | startswith("R") or startswith("C") then 3 else 2 end):];
      length > 1) | select(.[0] | startswith("R")) | {key: .[2], value: .[1]}] | from_entries')"
  while IFS=$'\037' read -r name from side; do
    rev="${REVDIFF_REVIEW_NEW:-}"
    [ "$side" = "-" ] && rev="${REVDIFF_REVIEW_OLD:-}"
    q=""
    path="$name"
    [ "$side" = "-" ] && path="$(jq -r --arg n "$name" '(. // {})[$n] // $n' <<< "${renames:-null}")"
    [ -z "$from" ] || q="$(git -C "$repo" show "$rev:$path" 2>/dev/null | sed -n "${from}p")"
    jq -R . <<< "$q"
  done < <(jq -r '.[] | [.name, .from // "", .side] | join("\u001f")' <<< "$new") > "$quotes"
  new="$(jq -c --slurpfile q "$quotes" '[., $q] | transpose | map(.[0] + {quote: .[1]})' <<< "$new")"
  rm -f "$quotes"
fi

# Control characters but newline and tab are dropped, so a note cannot end
# herdr's bracketed paste early and type the rest as keystrokes.
text="$(jq -r --arg file "$file" --rawfile doc "$copy" --arg repo "$repo" '
  ($doc | split("\n")) as $lines
  | def quote: (.quote // $lines[(.from | tonumber) - 1] // "" | gsub("^\\s+|\\s+$"; "")) as $q
      | if $q == "" then "" else " `\($q[0:100])`" end;
    def side: if $repo == "" then "" elif .side == "-" then " (old)" else " (new)" end;
    def place: if .from == null then "whole file"
      elif .to != null and .to != .from then "lines \(.from)-\(.to)\(side)\(quote)"
      else "line \(.from)\(side)\(quote)" end;
    def name: if $repo == "" then "" else "\(.name) " end;
  "Review notes on \($file):\n\n"
  + (map("- \(name)\(place): \(.body | gsub("\n"; "\n  "))") | join("\n"))
  | gsub("[\u0000-\u0008\u000b-\u001f\u007f-\u009f]"; "")' <<< "$new" 2>/dev/null)" &&
  [ -n "$text" ] || say "Could not read $copy. Nothing was sent."

if ! err="$(herdr agent prompt "$target" "$text" 2>&1 >/dev/null)"; then
  case "$(jq -r '.error.code // empty' <<< "$err" 2>/dev/null)" in
    agent_blocked) say "The agent is waiting on a prompt. Nothing was sent." ;;
    agent_not_found) say "No agent is running in that pane any more. Nothing was sent." ;;
    *) say "herdr refused: ${err:-no reason given}. Nothing was sent." ;;
  esac
fi

[ "$sent" = /dev/null ] || jq -c '.[]' <<< "$notes" >> "$sent"
[ "$count" = 1 ] && printf 'Sent 1 note to the agent.\n' || printf 'Sent %s notes to the agent.\n' "$count"
