# revdiff/send.sh is revdiff's post-flush command in a Markdown review tab: it
# reads revdiff's snapshot of the notes on stdin and sends the ones not sent yet
# in this review to the agent pane the review was opened for. Each case pipes a
# snapshot into it with a mock herdr that records the prompt it was asked to submit.

SEND="$REPO_ROOT/revdiff/send.sh"

setup_send_sandbox() {
  setup_sandbox
  export MOCK_PROMPT="$SANDBOX/prompt.txt"
  unset MOCK_PROMPT_FAIL
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$1 $2 $3" >> "$MOCK_HERDR_LOG"
if [ "$1 $2" = "agent prompt" ]; then
  if [ -n "${MOCK_PROMPT_FAIL:-}" ]; then
    printf '{"error":{"code":"%s","message":"no"}}\n' "$MOCK_PROMPT_FAIL" >&2
    exit 1
  fi
  printf '%s' "$4" > "$MOCK_PROMPT"
fi
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr"
  mkdir -p "$SANDBOX/repo"
  DOC="$SANDBOX/repo/spec.md"
  printf '# A spec\nfirst line\nsecond line\n' > "$DOC"
  export REVDIFF_REVIEW_FILE="$DOC" REVDIFF_DELIVER_TO=w1:p2 REVDIFF_SENT="$SANDBOX/sent"
  : > "$REVDIFF_SENT"
}

# Pipe snapshot $1 into the sender; its printed line lands in $out, its status in $status.
send() { out="$(printf '%s' "$1" | bash "$SEND")"; status=$?; }
prompt() { cat "$MOCK_PROMPT" 2>/dev/null; }

it "sends a flushed note to the given pane, naming the file and quoting its line"
setup_send_sandbox
send $'## spec.md:2 ( )\nfix this\n'
assert_equals "$status" 0 "exit status" \
  && assert_contains "$(cat "$MOCK_HERDR_LOG")" "agent prompt w1:p2" "herdr calls" \
  && assert_equals "$(prompt)" "Review notes on $DOC:

- line 2 \`first line\`: fix this" "the prompt" \
  && assert_contains "$out" "Sent 1 note" "the printed line" \
  && pass
teardown_sandbox

it "sends a note only once when the same snapshot is flushed again"
setup_send_sandbox
send $'## spec.md:2 ( )\nfix this\n'
: > "$MOCK_HERDR_LOG"
send $'## spec.md:2 ( )\nfix this\n\n## spec.md:3 ( )\nand this\n'
assert_equals "$(grep -c '^agent prompt' "$MOCK_HERDR_LOG")" 1 "prompt calls" \
  && assert_not_contains "$(prompt)" "fix this" "the prompt" \
  && assert_contains "$(prompt)" "- line 3 \`second line\`: and this" "the prompt" \
  && pass
teardown_sandbox

it "sends nothing and says so when every note was sent already"
setup_send_sandbox
send $'## spec.md:2 ( )\nfix this\n'
: > "$MOCK_HERDR_LOG"
send $'## spec.md:2 ( )\nfix this\n'
assert_equals "$status" 0 "exit status" \
  && assert_equals "$(grep -c '^agent prompt' "$MOCK_HERDR_LOG")" 0 "prompt calls" \
  && assert_contains "$out" "No new notes" "the printed line" \
  && pass
teardown_sandbox

it "sends an edited note again"
setup_send_sandbox
send $'## spec.md:2 ( )\nfix this\n'
send $'## spec.md:2 ( )\nfix this better\n'
assert_contains "$(prompt)" "fix this better" "the prompt" && pass
teardown_sandbox

it "keeps a multi-line note's lines, indented under it, and labels file-level and range notes"
setup_send_sandbox
send $'## spec.md (file-level)\noverall\nsecond thought\n\n## spec.md:2-3 (+)\nthis hunk\n'
assert_contains "$(prompt)" "- whole file: overall
  second thought" "the prompt" \
  && assert_contains "$(prompt)" "- lines 2-3 \`first line\`: this hunk" "the prompt" \
  && pass
teardown_sandbox

it "strips control characters, so a note cannot end herdr's paste early"
setup_send_sandbox
send $'## spec.md:2 ( )\nfix\033[31m this\rnow\n'
assert_not_contains "$(prompt)" $'\033' "the prompt" \
  && assert_not_contains "$(prompt)" $'\r' "the prompt" \
  && pass
teardown_sandbox

it "fails, says why and records nothing when the agent is waiting on a prompt"
setup_send_sandbox
MOCK_PROMPT_FAIL=agent_blocked send $'## spec.md:2 ( )\nfix this\n'
assert_equals "$status" 1 "exit status" \
  && assert_contains "$out" "waiting on a prompt" "the printed line" \
  && assert_equals "$(cat "$REVDIFF_SENT")" "" "the sent record" \
  && pass
teardown_sandbox

it "quotes the copy revdiff showed, not the file as it is now"
setup_send_sandbox
printf '# A spec\nshown line\n' > "$SANDBOX/shown.md"
printf '# A spec\nrewritten line\n' > "$DOC"
REVDIFF_REVIEW_COPY="$SANDBOX/shown.md" send $'## spec.md:2 ( )\nfix this\n'
assert_contains "$(prompt)" "- line 2 \`shown line\`: fix this" "the prompt" \
  && assert_contains "$(prompt)" "Review notes on $DOC:" "the prompt" \
  && pass
teardown_sandbox

it "fails and says so when the review has no agent to send to"
setup_send_sandbox
REVDIFF_DELIVER_TO="" send $'## spec.md:2 ( )\nfix this\n'
assert_equals "$status" 1 "exit status" \
  && assert_contains "$out" "No agent" "the printed line" \
  && assert_equals "$(grep -c '^agent prompt' "$MOCK_HERDR_LOG")" 0 "prompt calls" \
  && pass
teardown_sandbox
