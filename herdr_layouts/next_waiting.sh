#!/usr/bin/env bash
# Jump to the next project whose main session has a Whiska question waiting.
#   Usage: next_waiting.sh
#
# Each press moves on to the next waiting project (oldest wait first, wraps),
# counted from the project of the focused pane, so repeated presses go
# through all of them instead of landing on the same one.

set -uo pipefail
# Runs under macOS /bin/bash 3.2 with herdr's PATH, which lacks ~/.local/bin.
PATH="$HOME/.local/bin:$PATH"
# Without a UTF-8 locale whiska writes "…" as \x{2026}, which is not JSON.
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

repos=()
mains=()
while IFS=$'\t' read -r repo main; do
  repos+=("$repo")
  mains+=("$main")
done < <(
  whiska jump --list --json 2>/dev/null \
    | jq -r 'map(select(.waiting > 0)) | sort_by(-.oldest_wait_seconds) | .[] | [.repo, .main_checkout] | @tsv'
)

count=${#repos[@]}
[ "$count" -eq 0 ] && exit 0

# The focused pane's project: a mouse counts as its own main checkout.
current_ws=$(herdr pane current | jq -r '.result.pane.workspace_id')
current_main=$(
  herdr workspace list | jq -r --arg ws "$current_ws" '
    .result.workspaces[] | select(.workspace_id == $ws)
    | .worktree.repo_key // "" | sub("/\\.git$"; "")'
)

target=0
for i in "${!mains[@]}"; do
  if [ "${mains[$i]}" = "$current_main" ]; then
    target=$(( (i + 1) % count ))
    break
  fi
done

whiska jump "${repos[$target]}" >/dev/null
