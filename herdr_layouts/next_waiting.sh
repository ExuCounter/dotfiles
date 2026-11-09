#!/usr/bin/env bash
# Focus the next agent blocked on you, in workspace order.
#   Usage: next_waiting.sh
#
# Each press moves on to the next blocked agent (wraps), counted from the focused
# pane, so repeated presses go through all of them instead of landing on the same
# one. A pane that runs no agent counts from the end of its workspace.

set -uo pipefail

current=$(herdr pane current | jq -c '.result.pane | {pane_id, workspace_id}')

target=$(
  jq -nr --argjson agents "$(herdr agent list)" --argjson spaces "$(herdr workspace list)" \
    --argjson current "$current" '
    ($spaces.result.workspaces | map({key: .workspace_id, value: .number}) | from_entries) as $num
    | [$agents.result.agents | to_entries[]
        | {pane: .value.pane_id, status: .value.agent_status,
           key: [($num[.value.workspace_id] // 1e9), .key]}]
    | sort_by(.key) as $all
    | ($all | map(select(.status == "blocked"))) as $blocked
    | (($all[] | select(.pane == $current.pane_id) | .key)
        // [($num[$current.workspace_id] // 1e9), 1e9]) as $here
    | (first($blocked[] | select(.key > $here)) // $blocked[0]) | .pane // empty'
)

[ -n "$target" ] && herdr agent focus "$target" >/dev/null
exit 0
