# revdiff/review.sh runs revdiff on one Markdown file in its review tab and,
# when revdiff quits with notes (q), sends the ones E has not sent. Each case
# runs it against a mock revdiff that acts out a way the review ends, and a mock
# herdr that records the prompt.

REVIEW="$REPO_ROOT/revdiff/review.sh"

setup_review_sandbox() {
  setup_sandbox
  export MOCK_PROMPT="$SANDBOX/prompt.txt"
  unset MOCK_PROMPT_FAIL MOCK_REVDIFF
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
if [ "$1 $2" = "agent prompt" ]; then
  [ -s "${MOCK_PROMPT_FAIL_ONCE:-/nonexistent}" ] && { : > "$MOCK_PROMPT_FAIL_ONCE"; echo '{"error":{"code":"agent_blocked"}}' >&2; exit 1; }
  [ -n "${MOCK_PROMPT_FAIL:-}" ] && { printf '{"error":{"code":"%s"}}\n' "$MOCK_PROMPT_FAIL" >&2; exit 1; }
  printf '%s' "$4" >> "$MOCK_PROMPT"
fi
exit 0
MOCK
  # MOCK_REVDIFF: quit (q with a note), flush-then-discard (E, then Q),
  # flush-then-quit (E, then q with the same note), crash.
  cat > "$MOCK_BIN/revdiff" <<'MOCK'
#!/usr/bin/env bash
flush="" output=/dev/stdout
for a in "$@"; do
  case "$a" in --post-flush-command=*) flush="${a#*=}" ;; --output=*) output="${a#*=}" ;; esac
done
note=$'## spec.md:2 ( )\nfix this'
flush() { [ "$output" = /dev/stdout ] || printf '%s\n' "$note" > "$output"; printf '%s\n' "$note" | "$flush" >/dev/null; }
case "$MOCK_REVDIFF" in
  quit) printf '%s\n' "$note" > "$output" ;;
  flush-then-discard) flush ;;
  flush-then-quit) flush; printf '%s\n' "$note" > "$output" ;;
  crash) echo "revdiff: bad theme" >&2; exit 1 ;;
esac
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/revdiff"
  DOC="$SANDBOX/spec.md"
  printf '# A spec\nfirst line\n' > "$DOC"
}

review() { out="$(bash "$REVIEW" "$DOC" w1:p2 < /dev/null 2>&1)"; status=$?; }

it "sends the notes revdiff prints when quit with q"
setup_review_sandbox
MOCK_REVDIFF=quit review
assert_equals "$status" 0 "exit status" \
  && assert_contains "$(cat "$MOCK_PROMPT")" "- line 2 \`first line\`: fix this" "the prompt" \
  && pass
teardown_sandbox

it "sends nothing more on Q after a flush"
setup_review_sandbox
MOCK_REVDIFF=flush-then-discard review
assert_equals "$status" 0 "exit status" \
  && assert_equals "$(grep -c 'fix this' "$MOCK_PROMPT")" 1 "times the note was sent" \
  && pass
teardown_sandbox

it "sends on q a note whose E failed"
setup_review_sandbox
echo 1 > "$SANDBOX/fail-once"
MOCK_PROMPT_FAIL_ONCE="$SANDBOX/fail-once" MOCK_REVDIFF=flush-then-quit review
assert_equals "$status" 0 "exit status" \
  && assert_equals "$(grep -c 'fix this' "$MOCK_PROMPT")" 1 "times the note was sent" \
  && pass
teardown_sandbox

it "does not send again on q what E already sent"
setup_review_sandbox
MOCK_REVDIFF=flush-then-quit review
assert_equals "$(grep -c 'fix this' "$MOCK_PROMPT")" 1 "times the note was sent" && pass
teardown_sandbox

it "holds the tab with the reason when the notes cannot be sent on quit"
setup_review_sandbox
MOCK_PROMPT_FAIL=agent_blocked MOCK_REVDIFF=quit review
assert_contains "$out" "waiting on a prompt" "the output" \
  && assert_contains "$out" "Press any key to close." "the output" \
  && pass
teardown_sandbox

it "holds the tab when revdiff fails to start"
setup_review_sandbox
MOCK_REVDIFF=crash review
assert_equals "$status" 1 "exit status" \
  && assert_contains "$out" "revdiff failed" "the output" \
  && assert_contains "$out" "Press any key to close." "the output" \
  && pass
teardown_sandbox

it "refuses a file holding control characters"
setup_review_sandbox
printf '# hi\033[31m\n' > "$DOC"
MOCK_REVDIFF=quit review
assert_equals "$status" 1 "exit status" && assert_no_file "$MOCK_PROMPT" && pass
teardown_sandbox
