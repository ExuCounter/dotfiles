#!/usr/bin/env bash
# The hunk-docs action herdr runs on a Ctrl+clicked link, in
# $HERDR_PLUGIN_CLICKED_URL: a new tab in the clicked pane's workspace runs hunk
# on the document as a diff against an empty file, so every line takes a note.
# Only hunk is told the clicked pane and the document, for hunk-send's S, so they
# end with the review. An action's output shows nowhere, so a link it does not
# open is a herdr notification saying why.

set -u
# Bytes, whatever the locale: a multibyte locale lets an invalid byte hide a
# control character from the checks below.
export LC_ALL=C

refuse() {
  herdr notification show "hunk docs" --body "The document did not open: $*" --sound none >/dev/null 2>&1
  exit 1
}
# A C1 control in UTF-8, which [[:cntrl:]] does not match byte by byte.
c1=$'*[\xc2][\x80-\x9f]*'
quote() {
  local q="'\\''"
  printf "'%s'" "${1//\'/$q}"
}

url="${HERDR_PLUGIN_CLICKED_URL:-}"
for tool in hunk jq; do
  command -v "$tool" >/dev/null 2>&1 || refuse "$tool is not installed."
done

rest="${url#file://}"
[ "$rest" != "$url" ] || refuse "not a file:// link."
[[ "$rest" == */* ]] || refuse "no path in the link."
host="$(printf '%s' "${rest%%/*}" | tr '[:upper:]' '[:lower:]')"
case "$host" in
  "" | localhost | "$(hostname | tr '[:upper:]' '[:lower:]')") ;;
  *) refuse "the link names another host." ;;
esac
path="/${rest#*/}"

# Decoded with printf, so a backslash or an escape that is not two hex digits
# would be read as something else, and a NUL or line break would be lost.
[[ "$path" == *[[:cntrl:]]* || "$path" == $c1 || "$path" =~ %(0[0-9A-Fa-f]|1[0-9A-Fa-f]|7[Ff]) ]] &&
  refuse "the file name has a control character."
case "$path" in *\\*) refuse "the link has a backslash." ;; esac
[[ "$path" =~ %([^0-9A-Fa-f]|.[^0-9A-Fa-f]|.?$) ]] && refuse "the link has a broken % escape."
path="$(printf '%b' "${path//%/\\x}")"
[[ "$path" == *[[:cntrl:]]* || "$path" == $c1 ]] && refuse "the file name has a control character."
case "$path" in *\\*) refuse "the link has a backslash." ;; esac
[ -f "$path" ] || refuse "No such file: $path"

empty="${XDG_CACHE_HOME:-$HOME/.cache}/hunk-docs/empty"
mkdir -p "${empty%/*}" && : > "$empty" || refuse "could not write $empty."

args=(tab create)
[ -n "${HERDR_WORKSPACE_ID:-}" ] && args+=(--workspace "$HERDR_WORKSPACE_ID")
args+=(--label "doc:${path##*/}" --cwd "$HOME" --focus)
errors="${empty%/*}/herdr-errors"
tab="$(herdr "${args[@]}" 2>"$errors")" || refuse "herdr refused the tab: $(cat "$errors")"
pane="$(jq -r '.result.root_pane.pane_id // empty' <<< "$tab" 2>/dev/null)"
[[ "$pane" =~ ^[A-Za-z0-9][A-Za-z0-9_:-]*$ ]] || refuse "herdr opened no pane: $tab"

# A leading space keeps the line out of zsh's shared history.
line=" exec"
for word in env "HUNK_SEND_PANE=${HERDR_PANE_ID:-}" "HUNK_SEND_DOC=$path" \
  hunk diff --files "$empty" "$path" --watch --no-sidebar --mode unified; do
  line+=" $(quote "$word")"
done
herdr pane run "$pane" "$line" >/dev/null 2>&1 || refuse "herdr could not run hunk in pane $pane."
