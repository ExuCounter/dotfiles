#!/bin/bash
#
# @raycast.schemaVersion 1
# @raycast.title Focus Blocked Herdr Agent
# @raycast.mode silent
# @raycast.packageName Herdr
# @raycast.icon 🔴
# @raycast.description Jump to the oldest agent waiting for input.

set -u

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

target="$(herdr agent list 2>/dev/null \
  | jq -r '[.result.agents[] | select(.agent_status=="blocked")]
           | sort_by(.state_change_seq) | .[0].pane_id // empty')"

[ -n "$target" ] || exit 0

open -a kitty
herdr agent focus "$target"
