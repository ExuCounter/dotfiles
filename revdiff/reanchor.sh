#!/usr/bin/env bash
# Carry a review's notes onto a changed copy of the document (review.sh calls
# this on a reload).
#
# Usage: reanchor.sh OLD_COPY NEW_COPY HISTORY_MD SENT
#
# HISTORY_MD is revdiff's snapshot of the notes (a `## name:LINE[-END] (side)`
# record each, body below). Each note moves to the line whose text equals the
# text of the line it was written on, the nearest one if several; if no line
# does, it keeps its number (or the last line, if the file got shorter) and its body starts with `[moved, was line N] `.
# Prints the notes as a file for revdiff's --annotations. SENT (one JSON note
# per line, as send.sh records) is rewritten the same way, so a sent note stays
# sent at its new place.

set -u

old="${1:-}" new="${2:-}" history="${3:-}" sent="${4:-/dev/null}"

out="$(jq -nc --rawfile old "$old" --rawfile new "$new" --rawfile hist "$history" \
    --slurpfile sent <(cat "$sent" 2>/dev/null) '
  ($old | split("\n")) as $o | ($new | split("\n")) as $n
  | ([($n | length) - (if $n[-1] == "" then 1 else 0 end), 1] | max) as $last
  | def move:
      if .from == null then .
      else (.from | tonumber) as $f
        | ($o[$f - 1] // null) as $t
        | ([range(0; $n | length) | select($n[.] == $t) | . + 1] | sort_by((. - $f) | fabs) | first) as $hit
        | if $hit != null then
            .to = (if .to == null then null else ($hit + ((.to | tonumber) - $f)) | tostring end)
            | .from = ($hit | tostring)
          else
            .from = ([$f, $last] | min | tostring)
            | .to = (if .to == null then null else [(.to | tonumber), $last] | min | tostring end)
            | if (.body | startswith("[moved, was line ")) then .
              else .body = "[moved, was line \($f)] " + .body end
          end
      end;
  ([ $hist | split("\n")[] ] | reduce .[] as $l ([];
      ([$l | capture("^## (?<name>.*?)(:(?<from>[0-9]+)(-(?<to>[0-9]+))?)? \\((?<side>[^)]*)\\)$")] | first) as $h
      | if $h then . + [$h + {body: []}]
        elif length > 0 then .[-1].body += [$l]
        else . end)
    | map(.body |= (join("\n") | sub("^\\s+"; "") | sub("\\s+$"; "")))
    | map(move)) as $notes
  | { md: (($notes | map("## \(.name)\(if .from then ":\(.from)" + (if .to and .to != .from then "-\(.to)" else "" end) else "" end) (\(.side))\n\(.body)\n") | join("\n"))),
      sent: ($sent | map(move)) }' 2>/dev/null)" || exit 1

jq -c '.sent[]' <<< "$out" > "$sent.new" && mv "$sent.new" "$sent"
jq -r '.md' <<< "$out"
