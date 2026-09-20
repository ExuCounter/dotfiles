#!/usr/bin/env bash
# Stop hook: fires on every completed turn, in every Claude Code session. If
# the session is running inside a worktree spawned by spawn-worktree (marked
# by a .herdr-worktree-meta file at the worktree root), checks the assistant's
# last message for a [worktree-status: ...] marker and relays it via
# herdr-worktree-wake.sh. Everywhere else — including the user's own main
# session — this is a fast no-op.
#
# Deterministic by design: unlike a background poller a model has to remember
# to relaunch after every reply, this runs every single turn regardless of
# what any session does or forgets to do.

set -eu

hook_input="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0
command -v herdr-worktree-wake.sh >/dev/null 2>&1 || exit 0

cwd="$(printf '%s' "$hook_input" | jq -r '.cwd // empty')"
[ -n "$cwd" ] || exit 0

# The meta file lives at the worktree root; walk up from cwd in case the
# session's cwd is a subdirectory of it.
meta_dir="$cwd"
meta_file=""
for _ in 1 2 3 4 5 6 7 8; do
  if [ -f "$meta_dir/.herdr-worktree-meta" ]; then
    meta_file="$meta_dir/.herdr-worktree-meta"
    break
  fi
  parent="$(dirname "$meta_dir")"
  [ "$parent" = "$meta_dir" ] && break
  meta_dir="$parent"
done
[ -n "$meta_file" ] || exit 0

branch=""
pane_id=""
main_pane_id=""
IFS=$'\t' read -r branch pane_id main_pane_id < "$meta_file"
[ -n "$branch" ] && [ -n "$main_pane_id" ] || exit 0

message="$(printf '%s' "$hook_input" | jq -r '.last_assistant_message // empty')"
[ -n "$message" ] || exit 0

# Delivery can retry for up to a minute if the main pane is busy — this hook
# has a short timeout, so hand off to the background instead of blocking here.
msg_file="$(mktemp)"
printf '%s' "$message" > "$msg_file"
nohup bash -c "herdr-worktree-wake.sh notify '$branch' '$pane_id' '$main_pane_id' < '$msg_file'; rm -f '$msg_file'" >/dev/null 2>&1 &
disown
exit 0
