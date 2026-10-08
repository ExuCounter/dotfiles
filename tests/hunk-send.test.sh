# hunk-send.sh sends the person's hunk review notes, as one message, to the
# Claude session of the main checkout, naming the branch they are about. Each
# note goes once; an edited note goes again. Each case runs the script in a real
# git repo with a linked worktree, against a mock hunk that answers
# `session comment list` from $MOCK_COMMENTS and a mock herdr that records the
# prompt it was asked to submit.

SEND="$REPO_ROOT/hunk/hunk-send.sh"

setup_send_sandbox() {
  setup_sandbox
  export XDG_STATE_HOME="$SANDBOX/state"
  export MOCK_WORKSPACES="$SANDBOX/workspaces.json" MOCK_PANES="$SANDBOX/panes.json"
  export MOCK_COMMENTS="$SANDBOX/comments.json" MOCK_PROMPT="$SANDBOX/prompt.txt"
  export MOCK_WORKTREE_PANES="$SANDBOX/worktree-panes.json"
  unset MOCK_PROMPT_FAIL MOCK_NO_SESSION
  echo '{"comments":[]}' > "$MOCK_COMMENTS"

  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$1 $2 $3" >> "$MOCK_HERDR_LOG"
case "$1 $2" in
  "workspace list") cat "$MOCK_WORKSPACES" ;;
  "pane list")
    panes="$MOCK_PANES"; [ "$4" = wm ] || panes="$MOCK_WORKTREE_PANES"
    printf '{"result":{"panes":%s}}\n' "$(cat "$panes")" ;;
  "agent prompt")
    if [ -n "${MOCK_PROMPT_FAIL:-}" ]; then
      printf '{"error":{"code":"%s","message":"no"}}\n' "$MOCK_PROMPT_FAIL" >&2
      exit 1
    fi
    printf '%s' "$4" > "$MOCK_PROMPT" ;;
esac
exit 0
MOCK
  cat > "$MOCK_BIN/hunk" <<'MOCK'
#!/usr/bin/env bash
[ -n "${MOCK_NO_SESSION:-}" ] && { echo 'No live Hunk session' >&2; exit 1; }
[ "$*" = "session comment list --repo $WT --type user --json" ] || exit 1
cat "$MOCK_COMMENTS"
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/hunk"

  MAIN="$SANDBOX/repo"
  mkdir -p "$MAIN"
  git -C "$MAIN" init -q -b master
  git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$MAIN" worktree add -q "$MAIN/worktrees/feat/x" -b feat/x
  MAIN="$(git -C "$MAIN" rev-parse --show-toplevel)"
  WT="$(git -C "$MAIN/worktrees/feat/x" rev-parse --show-toplevel)"
  export WT
  cat > "$MOCK_WORKSPACES" <<JSON
{"result":{"workspaces":[
{"workspace_id":"w1","worktree":{"is_linked_worktree":true,"repo_root":"$MAIN"}},
{"workspace_id":"wm","worktree":{"is_linked_worktree":false,"repo_root":"$MAIN"}}]}}
JSON
  echo "[{\"pane_id\":\"w1:p1\",\"agent\":\"claude\",\"cwd\":\"$MAIN\"}]" > "$MOCK_WORKTREE_PANES"
  # The main workspace holds the review tab (hunk, no agent), a Claude session
  # in some other folder, and the main session itself.
  cat > "$MOCK_PANES" <<JSON
[{"pane_id":"wm:p2","agent":null,"cwd":"$WT"},
 {"pane_id":"wm:p3","agent":"claude","cwd":"$SANDBOX"},
 {"pane_id":"wm:p1","agent":"claude","cwd":"$MAIN"}]
JSON
}

comments() { printf '{"comments":[%s]}\n' "$1" > "$MOCK_COMMENTS"; }
note() { printf '{"noteId":"user:%s","source":"user","filePath":"%s",%s,"body":"%s"}' "$1" "$2" "$3" "$4"; }

run_send() { (cd "${1:-$WT}" && bash "$SEND"); }
sent() { cat "$MOCK_PROMPT" 2>/dev/null; }
herdr_calls() { cat "$MOCK_HERDR_LOG"; }

it "sends every note to the main session, by file, under a line naming the branch"
setup_send_sandbox
comments "$(note 1 src/a.ts '"newRange":[12,12]' 'rename this'),$(note 2 b.md '"newRange":[3,5]' 'too long')"
out="$(run_send)" || fail "exited non-zero: $out"
assert_contains "$(herdr_calls)" "agent prompt wm:p1" "herdr calls" &&
  assert_equals "$(sent)" "Hunk review notes for branch feat/x (worktree $WT):

- b.md:3-5: too long
- src/a.ts:12: rename this" "sent text" &&
  assert_contains "$out" "Sent 2 notes" && pass
teardown_sandbox

it "a note on a removed line says so"
setup_send_sandbox
comments "$(note 1 a.ts '"oldRange":[7,7]' 'why drop this')"
run_send >/dev/null
assert_contains "$(sent)" "- a.ts:7 (removed line): why drop this" "sent text" && pass
teardown_sandbox

it "a note of several lines keeps them, indented under its bullet"
setup_send_sandbox
comments "$(note 1 a.ts '"newRange":[1,1]' 'first\nsecond')"
run_send >/dev/null
assert_contains "$(sent)" "- a.ts:1: first
  second" "sent text" && pass
teardown_sandbox

it "a second send carries only the notes added or edited since"
setup_send_sandbox
comments "$(note 1 a.ts '"newRange":[1,1]' 'old')"
run_send >/dev/null
comments "$(note 1 a.ts '"newRange":[1,1]' 'old'),$(note 2 a.ts '"newRange":[2,2]' 'new')"
run_send >/dev/null
second="$(sent)"
comments "$(note 1 a.ts '"newRange":[1,1]' 'old, edited'),$(note 2 a.ts '"newRange":[2,2]' 'new')"
run_send >/dev/null
assert_not_contains "$second" "a.ts:1" "second send" &&
  assert_contains "$second" "a.ts:2: new" "second send" &&
  assert_contains "$(sent)" "a.ts:1: old, edited" "sent text" &&
  assert_not_contains "$(sent)" "a.ts:2" "sent text" && pass
teardown_sandbox

it "with nothing new it sends nothing and says so"
setup_send_sandbox
comments "$(note 1 a.ts '"newRange":[1,1]' 'x')"
run_send >/dev/null
: > "$MOCK_HERDR_LOG"
out="$(run_send)" && fail "exited zero with nothing to send"
assert_not_contains "$(herdr_calls)" "agent prompt" "herdr calls" &&
  assert_contains "$out" "No new notes" && pass
teardown_sandbox

it "a refused send is reported, and the notes stay unsent"
setup_send_sandbox
comments "$(note 1 a.ts '"newRange":[1,1]' 'x')"
out="$(MOCK_PROMPT_FAIL=agent_blocked run_send)" && fail "exited zero on a refused send"
refusal="$out"
run_send >/dev/null
assert_contains "$refusal" "waiting on a prompt" &&
  assert_contains "$(sent)" "a.ts:1: x" "sent text" && pass
teardown_sandbox

it "with no Claude session in the main checkout it sends nothing"
setup_send_sandbox
comments "$(note 1 a.ts '"newRange":[1,1]' 'x')"
echo '[{"pane_id":"wm:p2","agent":null,"cwd":"/elsewhere"}]' > "$MOCK_PANES"
out="$(run_send)" && fail "exited zero with no main session"
assert_not_contains "$(herdr_calls)" "agent prompt" "herdr calls" &&
  assert_contains "$out" "No Claude session" && pass
teardown_sandbox

it "with two Claude sessions in the main checkout it sends to neither"
setup_send_sandbox
comments "$(note 1 a.ts '"newRange":[1,1]' 'x')"
echo "[{\"pane_id\":\"wm:p1\",\"agent\":\"claude\",\"cwd\":\"$MAIN\"},{\"pane_id\":\"wm:p4\",\"agent\":\"claude\",\"cwd\":\"$MAIN\"}]" > "$MOCK_PANES"
out="$(run_send)" && fail "exited zero with two candidate sessions"
assert_not_contains "$(herdr_calls)" "agent prompt" "herdr calls" &&
  assert_contains "$out" "More than one Claude session" && pass
teardown_sandbox

it "with no live hunk session it says so"
setup_send_sandbox
out="$(MOCK_NO_SESSION=1 run_send)" && fail "exited zero with no hunk session"
assert_contains "$out" "No live hunk session" && pass
teardown_sandbox

it "escape characters in a note never reach the prompt"
setup_send_sandbox
comments "$(note 1 a.ts '"newRange":[1,1]' 'a\u001b[201~b')"
run_send >/dev/null
assert_contains "$(sent)" "a.ts:1: a[201~b" "sent text" && pass
teardown_sandbox

it "other control characters in a note or a file name never reach the prompt"
setup_send_sandbox
comments "$(note 1 'a\u0003.ts' '"newRange":[1,1]' 'x\u009b201~y\u0015z\tw')"
run_send >/dev/null
assert_contains "$(sent)" "- a.ts:1: x201~yz	w" "sent text" && pass
teardown_sandbox
