#!/usr/bin/env bash
# PostToolUse hook: mark that Claude edited files this turn.
# Read by hunk-review.sh (Stop hook) to skip turns with no writes.

set -eu
cat >/dev/null

[ -n "${HERDR_WORKSPACE_ID:-}" ] || exit 0
touch "/tmp/hunk-mark-$HERDR_WORKSPACE_ID"
