#!/usr/bin/env bash
# SessionStart hook: re-attach herdr-worktree-wake.sh watchers whose process
# died (machine slept/restarted, terminal closed) but whose target worktree
# pane is still alive. No-ops outside a herdr session. Kept separate from
# herdr's own managed hook file (herdr-agent-state.sh), which warns against
# editing it directly.

cat >/dev/null 2>&1  # drain hook stdin, we don't need the payload

[ "${HERDR_ENV:-}" = "1" ] || exit 0
command -v herdr-worktree-wake.sh >/dev/null 2>&1 || exit 0

nohup herdr-worktree-wake.sh resume >/dev/null 2>&1 &
disown
exit 0
