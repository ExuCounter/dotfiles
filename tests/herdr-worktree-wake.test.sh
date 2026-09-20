# Behavior of bin/herdr-worktree-wake.sh — the durable wake-queue that relays a
# worktree session's [worktree-status: ...] turn to the user's main pane.
#
# The bug these cover: the full assistant message arrives on stdin and used to
# be reduced to the single marker line, so a grilling round's actual questions
# never reached the main session and could not be recovered afterwards (the
# worktree pane runs Claude on the terminal's alternate screen, which herdr
# cannot scroll back).

BRANCH="fix/demo"
PANE="wA:p1"
MAIN="wZ:p1"

FIVE_QUESTIONS='Here is where we are.

Q1 - transport: file path, inline, or both?
Q2 - queue drops: keep drop-to-latest?
Q3 - answer path: baked command or new subcommand?
Q4 - retention: prune after 7 days?
Q5 - tests: plain runner or bats?

[worktree-status: needs-decision] 5 questions ready, see above'

run_notify() {
  printf '%s' "$1" | "$WAKE" notify "$BRANCH" "$PANE" "$MAIN"
}

relay_files() {
  find "$HERDR_WAKE_RELAY_DIR" -type f -name '*.md' 2>/dev/null | sort
}

# ---------------------------------------------------------------------------

it "persists the full assistant message, not just the marker line"
setup_sandbox
run_notify "$FIVE_QUESTIONS"
files="$(relay_files)"
if [ -z "$files" ]; then
  fail "no relay file was written under $HERDR_WAKE_RELAY_DIR"
else
  body="$(cat $files)"
  assert_contains "$body" "Q1 - transport" "relay file" &&
  assert_contains "$body" "Q5 - tests" "relay file" &&
  assert_contains "$body" "Here is where we are." "relay file" &&
  pass
fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "files the relay under a path derived from the branch name"
setup_sandbox
run_notify "$FIVE_QUESTIONS"
f="$(relay_files | head -1)"
if [ -z "$f" ]; then fail "no relay file written"; else
  assert_contains "$f" "fix-demo" "relay file path" && pass
fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "delivers a notification carrying the marker, the relay path, and a reply command"
setup_sandbox
run_notify "$FIVE_QUESTIONS"
call="$(herdr_prompt_calls | head -1)"
f="$(relay_files | head -1)"
if [ -z "$call" ]; then fail "no herdr agent prompt call was made"; else
  assert_contains "$call" "$MAIN" "prompt call (delivered to main pane)" &&
  assert_contains "$call" "$BRANCH" "prompt text" &&
  assert_contains "$call" "5 questions ready" "prompt text (marker inline)" &&
  assert_contains "$call" "$f" "prompt text (relay file path)" &&
  assert_contains "$call" "herdr agent prompt $PANE" "prompt text (ready-to-run reply command)" &&
  pass
fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "ignores a turn with no [worktree-status] marker"
setup_sandbox
run_notify "Just some ordinary mid-task chatter, nothing to report."
if [ -n "$(relay_files)" ]; then fail "wrote a relay file for an unmarked turn"
elif [ "$(herdr_prompt_count)" != "0" ]; then fail "delivered a notification for an unmarked turn"
else pass; fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "clears the queue once delivery succeeds"
setup_sandbox
run_notify "$FIVE_QUESTIONS"
if [ -s "$HERDR_WAKE_QUEUE" ]; then
  fail "queue still holds entries after a successful delivery: $(cat "$HERDR_WAKE_QUEUE")"
else pass; fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "keeps an entry queued when delivery fails"
setup_sandbox
herdr_fail_next 99
run_notify "$FIVE_QUESTIONS"
if [ ! -s "$HERDR_WAKE_QUEUE" ]; then
  fail "undelivered entry was dropped from the queue"
else pass; fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "delivers every queued entry for a branch, oldest first — never just the latest"
setup_sandbox
herdr_fail_next 99   # both notifies fail to deliver and stay queued
first="round one questions
[worktree-status: needs-decision] ROUND-ONE"
second="round two questions
[worktree-status: needs-decision] ROUND-TWO"
run_notify "$first"
run_notify "$second"
echo 0 > "$MOCK_HERDR_FAIL_FILE"   # main pane reachable again
: > "$MOCK_HERDR_LOG"
"$WAKE" resume >/dev/null 2>&1
calls="$(herdr_prompt_calls)"
n="$(printf '%s\n' "$calls" | grep -c 'ROUND-' || true)"
if [ "$n" != "2" ]; then
  fail "expected both queued rounds to be delivered, got $n:
       $calls"
else
  order="$(printf '%s\n' "$calls" | grep -o 'ROUND-[A-Z]*' | tr '\n' ' ')"
  assert_equals "$order" "ROUND-ONE ROUND-TWO " "delivery order (oldest first)" && pass
fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "keeps both rounds' relay files distinct rather than overwriting"
setup_sandbox
herdr_fail_next 99
run_notify "alpha content
[worktree-status: needs-decision] A"
run_notify "beta content
[worktree-status: needs-decision] B"
count="$(relay_files | grep -c . || true)"
if [ "$count" != "2" ]; then
  fail "expected 2 distinct relay files, got $count"
else
  all="$(cat $(relay_files))"
  assert_contains "$all" "alpha content" "relay files" &&
  assert_contains "$all" "beta content" "relay files" && pass
fi
teardown_sandbox

# ---------------------------------------------------------------------------

it "prunes relay files older than 7 days and keeps recent ones"
setup_sandbox
mkdir -p "$HERDR_WAKE_RELAY_DIR/old-branch"
stale="$HERDR_WAKE_RELAY_DIR/old-branch/ancient.md"
fresh="$HERDR_WAKE_RELAY_DIR/old-branch/yesterday.md"
echo stale > "$stale"; echo fresh > "$fresh"
touch -t "$(date -v-30d +%Y%m%d%H%M 2>/dev/null || date -d '30 days ago' +%Y%m%d%H%M)" "$stale"
touch -t "$(date -v-1d +%Y%m%d%H%M 2>/dev/null || date -d '1 day ago' +%Y%m%d%H%M)" "$fresh"
run_notify "$FIVE_QUESTIONS"
assert_no_file "$stale" && assert_file_exists "$fresh" && pass
teardown_sandbox

# ---------------------------------------------------------------------------

it "status reports a stuck entry instantly, without attempting delivery"
setup_sandbox
herdr_fail_next 99
run_notify "$FIVE_QUESTIONS"
: > "$MOCK_HERDR_LOG"
out="$("$WAKE" status 2>&1)"
assert_contains "$out" "$BRANCH" "status output" &&
assert_equals "$(herdr_prompt_count)" "0" "delivery attempts during status" && pass
teardown_sandbox
