#!/usr/bin/env bash
# Send the person's notes from one hunk window, as the next message, to the
# session the review was opened from. A document tab of the hunk-docs plugin
# names that pane in $HUNK_SEND_PANE and the document in $HUNK_SEND_DOC.
# Whiska's review tab names it in $WHISKA_PANE, with $WHISKA_BRANCH,
# $WHISKA_WORKTREE and $WHISKA_REPO; that tab's shell outlives hunk, so these
# count only for a review of that worktree, or of the repo once it is removed.
# Without either, to the Claude session of the main checkout, which forwards
# them to the session building the branch. Run by the hunk-send extension's S
# key, with the review's folder as cwd and the window's pid as $1: hunk runs
# extensions in its own process, and `hunk session list` reports that pid.
#
# Each note carries its id, so the agent can answer it in place. Delivery is
# `herdr agent prompt`, which refuses an agent waiting on a prompt. Each note
# goes once; one edited since goes again. Sent notes are kept per window, under
# $XDG_STATE_HOME/hunk-send, for a month.
#
# Prints one line for hunk to show. Exits 0 when sent, 1 when nothing was.

set -u

say() { printf '%s\n' "$*"; exit 1; }

doc="${HUNK_SEND_DOC:-}"
for tool in herdr hunk jq; do
  command -v "$tool" >/dev/null 2>&1 || say "$tool is not installed."
done
[ -n "$doc" ] || command -v git >/dev/null 2>&1 || say "git is not installed."

pid="${1:-}"
[[ "$pid" =~ ^[0-9]+$ ]] || say "hunk-send needs the hunk window's pid."

whiska=""
root="" branch="" main_root=""
if [ -z "$doc" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || say "Not in a git repo."
  here="$(cd "$root" && pwd -P)"
  if [ -n "${WHISKA_PANE:-}" ]; then
    dir="${WHISKA_WORKTREE:-${WHISKA_REPO:-}}"
    [ -n "$dir" ] && [ "$(cd -- "$dir" 2>/dev/null && pwd -P)" = "$here" ] && whiska=1
  fi
  branch="$(git branch --show-current 2>/dev/null)"
  [ -n "$whiska" ] && [ -n "${WHISKA_BRANCH:-}" ] && branch="$WHISKA_BRANCH"
  [ -n "$branch" ] || branch="detached at $(git rev-parse --short HEAD 2>/dev/null)"
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  main_root="${common_dir%/.git}"
fi

# The id names the state file and is an argument to hunk, so only a plain one.
session="$(hunk session list --json 2>/dev/null | jq -r --argjson pid "$pid" '
  [.sessions[]? | select(.pid == $pid) | .sessionId] | join(" ")' 2>/dev/null)"
case "$session" in *" "*) say "More than one hunk session claims this window. Nothing was sent." ;; esac
[[ "$session" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || say "No live hunk session for this window."
notes="$(hunk session comment list "$session" --type user --json 2>/dev/null)" ||
  say "No live hunk session for this window."

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hunk-send"
state="$state_dir/$session.json"
sent_file="$state"
jq -e 'type == "array"' "$state" >/dev/null 2>&1 || sent_file=/dev/null

new="$(jq -c --slurpfile sent "$sent_file" '
  ($sent[0] // []) as $sent
  | [.comments[]? | select({noteId, body} as $n | $sent | index([$n]) | not)]' <<< "$notes")"
[ "$(jq length <<< "$new")" -gt 0 ] || say "No new notes to send."

if [ -n "$doc$whiska" ]; then
  var=WHISKA_PANE
  [ -n "$doc" ] && var=HUNK_SEND_PANE
  target="${!var:-}"
  # A pane id, never a flag herdr would take instead.
  [[ "$target" =~ ^[A-Za-z0-9][A-Za-z0-9_:-]*$ ]] ||
    say "\$$var is not a herdr pane id. Nothing was sent."
  who="the session the review was opened from"
  blocked="The session the review was opened from is waiting on a prompt."
  gone="No agent is running in pane $target, where the review was opened from."
else
  main_ws="$(herdr workspace list 2>/dev/null \
    | jq -r --arg r "$main_root" '[.result.workspaces[]?
        | select(.worktree.is_linked_worktree == false and .worktree.repo_root == $r)
        | .workspace_id] | first // empty' 2>/dev/null)"
  [ -n "$main_ws" ] || say "No herdr workspace for the main checkout."
  target="$(herdr pane list --workspace "$main_ws" 2>/dev/null \
    | jq -r --arg r "$main_root" '[.result.panes[]?
        | select((.agent // "") == "claude" and .cwd == $r) | .pane_id] | join(" ")' 2>/dev/null)"
  [ -n "$target" ] || say "No Claude session in the main checkout."
  case "$target" in *" "*) say "More than one Claude session in the main checkout. Nothing was sent." ;; esac
  who="the main session"
  blocked="The main session is waiting on a prompt."
  gone="No agent is running in the main session's pane."
fi

# Control characters but newline and tab are dropped, so a note cannot end
# herdr's bracketed paste early and type the rest as keystrokes. A line break
# in a name stays as \n, so a file in the diff cannot forge a note.
text="$(jq -r --arg branch "$branch" --arg root "$root" --arg doc "$doc" --arg session "$session" '
  def oneline: gsub("[\n\u2028\u2029]"; "\\n");
  def place: if .newRange then .newRange elif .oldRange then .oldRange else null end
    | if . == null then "" elif .[0] == .[1] then ":\(.[0])" else ":\(.[0])-\(.[1])" end;
  def side: if (.newRange | not) and .oldRange then " (removed line)" else "" end;
  (if $doc != "" then "Hunk review notes on \($doc | oneline) (hunk session \($session)):\n\n"
   else "Hunk review notes for branch \($branch | oneline) (worktree \($root | oneline), hunk session \($session)):\n\n" end)
  + (sort_by(.filePath, ((.newRange // .oldRange // [0])[0]))
     | map("- \(.filePath // "" | oneline)\(place)\(side) [\(.noteId | oneline)]: \(.body | gsub("\n"; "\n  "))")
     | join("\n"))
  + "\n\nAnswer each note in place, the answer in a quoted heredoc so the shell expands nothing in it:\n"
  + "hunk session comment add \($session) --reply-to <note id> --summary \"$(cat <<'"'"'HUNK_REPLY_END'"'"'\n<answer>\nHUNK_REPLY_END\n)\""
  | gsub("[\u0000-\u0008\u000b-\u001f\u007f-\u009f]"; "")' <<< "$new" 2>/dev/null)"
[ -n "$text" ] || say "The notes could not be read. Nothing was sent."

if ! err="$(herdr agent prompt "$target" "$text" 2>&1 >/dev/null)"; then
  case "$(jq -r '.error.code // empty' <<< "$err" 2>/dev/null)" in
    agent_blocked) say "$blocked Nothing was sent." ;;
    agent_not_found) say "$gone Nothing was sent." ;;
    *) say "herdr refused: ${err:-no reason given}. Nothing was sent." ;;
  esac
fi

mkdir -p "$state_dir" 2>/dev/null
jq -c --slurpfile sent "$sent_file" '($sent[0] // []) + map({noteId, body})' <<< "$new" > "$state.$$" 2>/dev/null &&
  mv "$state.$$" "$state" 2>/dev/null
# A window's notes end with it, so a record a month old is never read again.
find "$state_dir/" -maxdepth 1 -name '*.json' -mtime +30 -delete 2>/dev/null
count="$(jq length <<< "$new")"
[ "$count" = 1 ] && printf 'Sent 1 note to %s.\n' "$who" ||
  printf 'Sent %s notes to %s.\n' "$count" "$who"
