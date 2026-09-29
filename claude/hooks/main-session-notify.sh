#!/usr/bin/env bash
#
# main-session-notify.sh — desktop notification, but only from the main checkout.
#
# herdr's own toasts and sounds have no per-workspace filter: they fire for any
# background workspace, and every worktree session is an agent of kind `claude`
# just like the main one, so `[ui.sound.agents]` cannot separate them either.
# With herdr's toasts turned off, this hook puts the ping back for the one
# session that should have it — the main checkout — and stays silent in every
# worktree, whose questions already arrive through Whiska.
#
#   main-session-notify.sh stop           # Stop hook: the turn finished
#   main-session-notify.sh notification   # Notification hook: Claude wants input
#
# Hook JSON arrives on stdin. Never fails the hook: every path exits 0.
#
# Env:
#   MAIN_SESSION_NOTIFY   set to 0 to disable entirely

set -u

[ "${MAIN_SESSION_NOTIFY:-1}" = "0" ] && exit 0

action="${1:-stop}"
payload="$(cat 2>/dev/null || true)"

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$dir" 2>/dev/null || exit 0

# --- main checkout, or a worktree? ------------------------------------------
# In a linked worktree `--git-dir` points at .git/worktrees/<name> while
# `--git-common-dir` still points at the main .git, so the two differ. This is
# the layout-independent check; the path test below catches the case where git
# is unavailable or the directory is not a repo at all.
git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null || true)"
if [ -n "$git_dir" ]; then
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$common_dir" ] && [ "$git_dir" != "$common_dir" ] && exit 0
fi
case "$dir" in */worktrees/*) exit 0 ;; esac

# --- what to say ------------------------------------------------------------
title="$(basename "$dir")"
case "$action" in
  notification)
    message=""
    if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
      message="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
    fi
    [ -n "$message" ] || message="Claude is waiting on you"
    ;;
  *)
    message="Turn finished"
    ;;
esac

# --- deliver ----------------------------------------------------------------
# terminal-notifier attributes the notification to itself and survives being
# called from a non-GUI process; osascript is the no-install fallback.
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$title" -message "$message" -sound default >/dev/null 2>&1
elif command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\" sound name \"Submarine\"" >/dev/null 2>&1
fi

exit 0
