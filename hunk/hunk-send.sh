#!/usr/bin/env bash
# Send the person's notes from the live hunk review of this folder's repo to the
# Claude session of the main checkout, as its next message, under a line naming
# the branch: the main session forwards them to the session building it. Run by
# the hunk-send extension's S key, with the review's folder as cwd.
#
# Delivery is the Annotate plugin's: `herdr agent prompt`, which refuses an
# agent waiting on a prompt. Each note goes once; one edited since goes again.
# Sent notes are kept per repo under $XDG_STATE_HOME/hunk-send.
#
# Prints one line for hunk to show. Exits 0 when sent, 1 when nothing was.

set -u

say() { printf '%s\n' "$*"; exit 1; }

for tool in herdr hunk jq git; do
  command -v "$tool" >/dev/null 2>&1 || say "$tool is not installed."
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || say "Not in a git repo."
branch="$(git branch --show-current 2>/dev/null)"
[ -n "$branch" ] || branch="detached at $(git rev-parse --short HEAD 2>/dev/null)"
common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
main_root="${common_dir%/.git}"

notes="$(hunk session comment list --repo "$root" --type user --json 2>/dev/null)" ||
  say "No live hunk session for $root."

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hunk-send"
state="$state_dir/$(printf '%s' "$root" | shasum | cut -c1-16).json"
sent_file="$state"
jq -e 'type == "array"' "$state" >/dev/null 2>&1 || sent_file=/dev/null

new="$(jq -c --slurpfile sent "$sent_file" '
  ($sent[0] // []) as $sent
  | [.comments[]? | select({noteId, body} as $n | $sent | index([$n]) | not)]' <<< "$notes")"
[ "$(jq length <<< "$new")" -gt 0 ] || say "No new notes to send."

main_ws="$(herdr workspace list 2>/dev/null \
  | jq -r --arg r "$main_root" '[.result.workspaces[]?
      | select(.worktree.is_linked_worktree == false and .worktree.repo_root == $r)
      | .workspace_id] | first // empty' 2>/dev/null)"
[ -n "$main_ws" ] || say "No herdr workspace for the main checkout."
main_pane="$(herdr pane list --workspace "$main_ws" 2>/dev/null \
  | jq -r --arg r "$main_root" '[.result.panes[]?
      | select((.agent // "") == "claude" and .cwd == $r) | .pane_id] | join(" ")' 2>/dev/null)"
[ -n "$main_pane" ] || say "No Claude session in the main checkout."
case "$main_pane" in *" "*) say "More than one Claude session in the main checkout. Nothing was sent." ;; esac

# Control characters but newline and tab are dropped, so a note cannot end
# herdr's bracketed paste early and type the rest as keystrokes.
text="$(jq -r --arg branch "$branch" --arg root "$root" '
  def place: if .newRange then .newRange elif .oldRange then .oldRange else null end
    | if . == null then "" elif .[0] == .[1] then ":\(.[0])" else ":\(.[0])-\(.[1])" end;
  def side: if (.newRange | not) and .oldRange then " (removed line)" else "" end;
  "Hunk review notes for branch \($branch) (worktree \($root)):\n\n"
  + (sort_by(.filePath, ((.newRange // .oldRange // [0])[0]))
     | map("- \(.filePath)\(place)\(side): \(.body | gsub("\n"; "\n  "))")
     | join("\n"))
  | gsub("[\u0000-\u0008\u000b-\u001f\u007f-\u009f]"; "")' <<< "$new")"

if ! err="$(herdr agent prompt "$main_pane" "$text" 2>&1 >/dev/null)"; then
  case "$(jq -r '.error.code // empty' <<< "$err" 2>/dev/null)" in
    agent_blocked) say "The main session is waiting on a prompt. Nothing was sent." ;;
    agent_not_found) say "No agent is running in the main session's pane. Nothing was sent." ;;
    *) say "herdr refused: ${err:-no reason given}. Nothing was sent." ;;
  esac
fi

mkdir -p "$state_dir" 2>/dev/null
jq -c --slurpfile sent "$sent_file" '($sent[0] // []) + map({noteId, body})' <<< "$new" > "$state.$$" 2>/dev/null &&
  mv "$state.$$" "$state" 2>/dev/null
count="$(jq length <<< "$new")"
[ "$count" = 1 ] && printf 'Sent 1 note to the main session.\n' ||
  printf 'Sent %s notes to the main session.\n' "$count"
