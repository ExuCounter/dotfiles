# main-session-notify.sh must notify from the main checkout and stay silent in
# a worktree. Getting that backwards is invisible until a day of worktree pings
# proves it, so both directions are pinned here against a real git worktree.

HOOK="$REPO_ROOT/claude/hooks/main-session-notify.sh"

# A sandbox whose PATH holds a fake terminal-notifier that logs its argv, plus a
# real git repo with a real linked worktree under worktrees/.
setup_notify_sandbox() {
  setup_sandbox
  export NOTIFY_LOG="$SANDBOX/notified.log"
  : > "$NOTIFY_LOG"
  cat > "$MOCK_BIN/terminal-notifier" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NOTIFY_LOG"
exit 0
MOCK
  chmod +x "$MOCK_BIN/terminal-notifier"

  MAIN="$SANDBOX/repo"
  mkdir -p "$MAIN"
  git -C "$MAIN" init -q
  git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$MAIN" worktree add -q "$MAIN/worktrees/feat-x" -b feat-x
}

it "notifies from the main checkout"
setup_notify_sandbox
CLAUDE_PROJECT_DIR="$MAIN" bash "$HOOK" stop </dev/null
assert_contains "$(cat "$NOTIFY_LOG")" "Turn finished" "notifier log" && pass
teardown_sandbox

it "stays silent in a linked worktree"
setup_notify_sandbox
CLAUDE_PROJECT_DIR="$MAIN/worktrees/feat-x" bash "$HOOK" stop </dev/null
if [ -s "$NOTIFY_LOG" ]; then
  fail "worktree session notified: $(cat "$NOTIFY_LOG")"
else
  pass
fi
teardown_sandbox

it "carries the Notification hook's own message"
setup_notify_sandbox
printf '%s' '{"message":"Claude needs your permission to use Bash"}' \
  | CLAUDE_PROJECT_DIR="$MAIN" bash "$HOOK" notification
assert_contains "$(cat "$NOTIFY_LOG")" "needs your permission" "notifier log" && pass
teardown_sandbox

it "MAIN_SESSION_NOTIFY=0 disables it"
setup_notify_sandbox
MAIN_SESSION_NOTIFY=0 CLAUDE_PROJECT_DIR="$MAIN" bash "$HOOK" stop </dev/null
if [ -s "$NOTIFY_LOG" ]; then fail "notified while disabled"; else pass; fi
teardown_sandbox

it "exits 0 even outside a git repo"
setup_notify_sandbox
CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" stop </dev/null
assert_equals "$?" "0" "exit code" && pass
teardown_sandbox
