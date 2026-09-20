# End-to-end through the real Stop hook (claude/hooks/herdr-worktree-notify.sh):
# a synthetic Claude Code hook payload in, a relay file and a delivered
# notification out. This is the path that actually runs in production; the
# wake-script tests cover its behavior in isolation.

setup_hook_sandbox() {
  setup_sandbox
  # The hook resolves the wake script off PATH.
  ln -sf "$WAKE" "$MOCK_BIN/herdr-worktree-wake.sh"
  WORKTREE="$SANDBOX/worktrees/fix-demo"
  mkdir -p "$WORKTREE/src"
  printf '%s\t%s\t%s\n' "fix/demo" "wA:p1" "wZ:p1" > "$WORKTREE/.herdr-worktree-meta"
}

# The hook backgrounds delivery (it has a 5s harness timeout and delivery can
# retry), so poll briefly instead of assuming it finished synchronously.
await_relay() {
  local i=0
  while [ "$i" -lt 100 ]; do
    [ -n "$(find "$HERDR_WAKE_RELAY_DIR" -type f -name '*.md' 2>/dev/null)" ] && return 0
    i=$((i + 1)); sleep 0.05
  done
  return 1
}

payload() {
  # cwd, last_assistant_message — the two fields the hook reads.
  jq -n --arg cwd "$1" --arg msg "$2" '{cwd: $cwd, last_assistant_message: $msg}'
}

MSG='Full round of questions.

Q1 - first thing
Q2 - second thing

[worktree-status: needs-decision] 2 questions ready, see above'

# ---------------------------------------------------------------------------

it "carries the complete message from hook stdin through to a relay file"
setup_hook_sandbox
payload "$WORKTREE/src" "$MSG" | bash "$NOTIFY_HOOK"
if ! await_relay; then
  fail "hook never produced a relay file"
else
  body="$(cat $(find "$HERDR_WAKE_RELAY_DIR" -type f -name '*.md'))"
  assert_contains "$body" "Q1 - first thing" "relay file" &&
  assert_contains "$body" "Q2 - second thing" "relay file" && pass
fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "finds the meta file when the session cwd is a subdirectory of the worktree"
setup_hook_sandbox
mkdir -p "$WORKTREE/src/deep/deeper"
payload "$WORKTREE/src/deep/deeper" "$MSG" | bash "$NOTIFY_HOOK"
await_relay && pass || fail "hook did not walk up to the worktree root"
teardown_sandbox

# ---------------------------------------------------------------------------

it "is a no-op in an ordinary session with no worktree meta file"
setup_hook_sandbox
plain="$SANDBOX/not-a-worktree"; mkdir -p "$plain"
payload "$plain" "$MSG" | bash "$NOTIFY_HOOK"
sleep 0.3
if [ -n "$(find "$HERDR_WAKE_RELAY_DIR" -type f -name '*.md' 2>/dev/null)" ]; then
  fail "hook acted on a session outside any worktree"
elif [ -s "$HERDR_WAKE_QUEUE" ]; then
  fail "hook queued an entry outside any worktree"
else pass; fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "delivers a notification naming the relay file and the reply command"
setup_hook_sandbox
payload "$WORKTREE" "$MSG" | bash "$NOTIFY_HOOK"
await_relay
i=0; while [ "$i" -lt 100 ] && [ "$(herdr_prompt_count)" = "0" ]; do i=$((i+1)); sleep 0.05; done
call="$(herdr_prompt_calls | head -1)"
f="$(find "$HERDR_WAKE_RELAY_DIR" -type f -name '*.md' | head -1)"
if [ -z "$call" ]; then fail "no notification was delivered"; else
  assert_contains "$call" "2 questions ready" "delivered prompt" &&
  assert_contains "$call" "$f" "delivered prompt" &&
  assert_contains "$call" "herdr agent prompt wA:p1" "delivered prompt" && pass
fi
teardown_sandbox
