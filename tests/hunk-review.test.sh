# hunk-review.sh opens a review tab, in the main checkout's workspace, only when
# a worktree session ends a turn finished, and the review covers the whole
# branch, not just uncommitted work. Tabs are named for the branch, never
# duplicated, never focused, and closed once their worktree is dropped.
# Each case feeds the hook a Stop payload the way Claude Code does, inside a
# real git repo with a real linked worktree, and reads back what it asked
# herdr and hunk to do.

HOOK="$REPO_ROOT/claude/hooks/hunk-review.sh"

DONE='⁣⁣⁣'
QUESTION='⁣⁣'

# A sandbox whose PATH holds a mock herdr that answers `tab list` from
# $MOCK_TABS, `pane list` from $MOCK_PANES, `pane process-info` from
# $MOCK_PROCESS, `workspace list` with the main checkout as workspace wm and the
# worktree as w1, and `tab create` with a fixed tab, and a mock hunk whose
# `session reload` fails when MOCK_HUNK_RELOAD_FAIL=1. Both log their argv.
# MAIN is a repo on master; WT a linked worktree on feat-x under worktrees/.
setup_review_sandbox() {
  setup_sandbox
  export HUNK_LOG="$SANDBOX/hunk-calls.log"
  export MOCK_WORKSPACES="$SANDBOX/workspaces.json" MOCK_TABS="$SANDBOX/tabs.json" MOCK_PANES="$SANDBOX/panes.json" MOCK_PROCESS="$SANDBOX/process.json"
  : > "$HUNK_LOG"
  echo '[]' > "$MOCK_TABS"
  echo '[{"pane_id":"w1:p4","tab_id":"w1:t4"}]' > "$MOCK_PANES"
  pane_running hunk
  unset MOCK_HUNK_RELOAD_FAIL

  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
case "$1 $2" in
  "tab list") printf '{"result":{"tabs":%s}}\n' "$(cat "$MOCK_TABS")" ;;
  "workspace list") cat "$MOCK_WORKSPACES" ;;
  "pane list") printf '{"result":{"panes":%s}}\n' "$(cat "$MOCK_PANES")" ;;
  "pane process-info") printf '{"result":{"process_info":%s}}\n' "$(cat "$MOCK_PROCESS")" ;;
  "tab create") echo '{"result":{"tab":{"tab_id":"w1:t9"},"root_pane":{"pane_id":"w1:p9"}}}' ;;
esac
exit 0
MOCK
  cat > "$MOCK_BIN/hunk" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HUNK_LOG"
[ "$1 $2" = "session reload" ] && [ "${MOCK_HUNK_RELOAD_FAIL:-0}" = 1 ] && exit 1
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/hunk"

  MAIN="$SANDBOX/repo"
  mkdir -p "$MAIN"
  git -C "$MAIN" init -q -b master
  echo one > "$MAIN/a.txt"
  git -C "$MAIN" add a.txt
  git_commit "$MAIN" init
  git -C "$MAIN" worktree add -q "$MAIN/worktrees/feat-x" -b feat-x
  # git answers with the resolved path (/private/var, not /var), and so does the hook.
  MAIN="$(git -C "$MAIN" rev-parse --show-toplevel)"
  WT="$(git -C "$MAIN/worktrees/feat-x" rev-parse --show-toplevel)"
  cat > "$MOCK_WORKSPACES" <<JSON
{"result":{"workspaces":[
{"workspace_id":"wm","worktree":{"is_linked_worktree":false,"repo_root":"$MAIN"}},
{"workspace_id":"w1","worktree":{"is_linked_worktree":true,"repo_root":"$MAIN"}},
{"workspace_id":"wo","worktree":{"is_linked_worktree":false,"repo_root":"$SANDBOX/other"}}]}}
JSON
}

# What the open review tab's pane has in the foreground: a process name, or
# "shell" for an idle prompt.
pane_running() {
  if [ "$1" = shell ]; then
    echo '{"shell_pid":100,"foreground_process_group_id":100,"foreground_processes":[{"name":"zsh","pid":100}]}' > "$MOCK_PROCESS"
  else
    printf '{"shell_pid":100,"foreground_process_group_id":200,"foreground_processes":[{"name":"%s","pid":200}]}\n' "$1" > "$MOCK_PROCESS"
  fi
}

git_commit() { git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -am "$2"; }

run_hook() {
  local dir=$1 message=$2
  printf '{"hook_event_name":"Stop","last_assistant_message":"%s"}' "$message" |
    HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 CLAUDE_PROJECT_DIR="$dir" bash "$HOOK" ||
    fail "hook exited non-zero"
}

herdr_calls() { cat "$MOCK_HERDR_LOG"; }
hunk_calls() { cat "$HUNK_LOG"; }

assert_no_tab() {
  if grep -q '^tab create' "$MOCK_HERDR_LOG"; then
    fail "opened a review tab: $(herdr_calls)"
    return 1
  fi
}

it "a finished turn opens the branch against where it left master"
setup_review_sandbox
echo two >> "$WT/a.txt"
git_commit "$WT" change
base="$(git -C "$WT" merge-base HEAD master)"
run_hook "$WT" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "tab create --workspace wm --label review: feat-x --cwd $WT --no-focus" "herdr calls" &&
  assert_contains "$(herdr_calls)" "pane run w1:p9 hunk diff $base --theme solarized-light --watch" "herdr calls" &&
  pass
teardown_sandbox

it "commits that landed on master after the branch was made stay out"
setup_review_sandbox
fork="$(git -C "$MAIN" rev-parse HEAD)"
echo two >> "$WT/a.txt"
git_commit "$WT" change
echo master-only > "$MAIN/a.txt"
git_commit "$MAIN" master-moved
run_hook "$WT" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "hunk diff $fork " "herdr calls" && pass
teardown_sandbox

it "a branch made from unpushed commits on master starts after them"
setup_review_sandbox
git init -q --bare "$SANDBOX/origin.git"
git -C "$MAIN" remote add origin "$SANDBOX/origin.git"
git -C "$MAIN" push -q origin master
git -C "$MAIN" remote set-head origin master
echo unpushed > "$MAIN/a.txt"
git_commit "$MAIN" unpushed
git -C "$MAIN" worktree add -q "$MAIN/worktrees/feat-y" -b feat-y
WT2="$(git -C "$MAIN/worktrees/feat-y" rev-parse --show-toplevel)"
fork="$(git -C "$MAIN" rev-parse master)"
echo two >> "$WT2/a.txt"
run_hook "$WT2" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "hunk diff $fork " "herdr calls" && pass
teardown_sandbox

it "a worktree made from the main checkout's own branch starts where it left that branch"
setup_review_sandbox
git -C "$MAIN" checkout -q -b feat/base
echo base-work > "$MAIN/b.txt"
git -C "$MAIN" add b.txt
git_commit "$MAIN" base-work
git -C "$MAIN" worktree add -q "$MAIN/worktrees/feat-z" -b feat-z
WT3="$(git -C "$MAIN/worktrees/feat-z" rev-parse --show-toplevel)"
fork="$(git -C "$MAIN" rev-parse feat/base)"
echo two >> "$WT3/a.txt"
run_hook "$WT3" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "hunk diff $fork " "herdr calls" && pass
teardown_sandbox

it "a new file not yet added to git is enough to open the review"
setup_review_sandbox
echo new > "$WT/new.txt"
run_hook "$WT" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "tab create" "herdr calls" && pass
teardown_sandbox

it "the marker still counts with blank lines and spaces after it"
setup_review_sandbox
echo two >> "$WT/a.txt"
run_hook "$WT" "Done.\n  $DONE  \n\n   \n"
assert_contains "$(herdr_calls)" "tab create" "herdr calls" && pass
teardown_sandbox

it "a turn that ends on a question opens nothing"
setup_review_sandbox
echo two >> "$WT/a.txt"
echo '[{"tab_id":"w1:t4","label":"review: feat-x"}]' > "$MOCK_TABS"
run_hook "$WT" "Which one?\nPick A or B, see above.\n$QUESTION"
assert_no_tab && assert_equals "$(hunk_calls)" "" "hunk calls" && pass
teardown_sandbox

it "a turn with no marker opens nothing"
setup_review_sandbox
echo two >> "$WT/a.txt"
run_hook "$WT" "All good."
assert_no_tab && pass
teardown_sandbox

it "a marker above a last line of prose does not count"
setup_review_sandbox
echo two >> "$WT/a.txt"
run_hook "$WT" "$DONE\nOne more thing."
assert_no_tab && pass
teardown_sandbox

it "the main checkout never gets a review tab"
setup_review_sandbox
echo two >> "$MAIN/a.txt"
run_hook "$MAIN" "Done.\n$DONE"
assert_no_tab && pass
teardown_sandbox

it "a branch with nothing changed against master opens nothing"
setup_review_sandbox
run_hook "$WT" "Researched, nothing to change.\n$DONE"
assert_no_tab && pass
teardown_sandbox

it "an open review tab is reloaded against the base, not duplicated"
setup_review_sandbox
echo two >> "$WT/a.txt"
base="$(git -C "$WT" merge-base HEAD master)"
echo '[{"tab_id":"w1:t4","label":"review: feat-x"}]' > "$MOCK_TABS"
run_hook "$WT" "Done.\n$DONE"
assert_contains "$(hunk_calls)" "session reload --repo $WT -- diff $base --theme solarized-light --watch" "hunk calls" &&
  assert_no_tab &&
  assert_not_contains "$(herdr_calls)" "tab close" "herdr calls" &&
  pass
teardown_sandbox

it "an open review tab whose hunk cannot be reached is replaced"
setup_review_sandbox
echo two >> "$WT/a.txt"
echo '[{"tab_id":"w1:t4","label":"review: feat-x"}]' > "$MOCK_TABS"
MOCK_HUNK_RELOAD_FAIL=1 run_hook "$WT" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "tab close w1:t4" "herdr calls" &&
  assert_contains "$(herdr_calls)" "tab create" "herdr calls" &&
  pass
teardown_sandbox

it "an open review tab left at an idle prompt is replaced"
setup_review_sandbox
echo two >> "$WT/a.txt"
echo '[{"tab_id":"w1:t4","label":"review: feat-x"}]' > "$MOCK_TABS"
pane_running shell
MOCK_HUNK_RELOAD_FAIL=1 run_hook "$WT" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "tab close w1:t4" "herdr calls" && pass
teardown_sandbox

it "an open review tab running something else is left alone"
setup_review_sandbox
echo two >> "$WT/a.txt"
echo '[{"tab_id":"w1:t4","label":"review: feat-x"}]' > "$MOCK_TABS"
pane_running vim
MOCK_HUNK_RELOAD_FAIL=1 run_hook "$WT" "Done.\n$DONE"
assert_not_contains "$(herdr_calls)" "tab close" "herdr calls" && assert_no_tab && pass
teardown_sandbox

it "outside herdr nothing happens"
setup_review_sandbox
echo two >> "$WT/a.txt"
printf '{"last_assistant_message":"Done.\\n%s"}' "$DONE" |
  HERDR_ENV= HERDR_WORKSPACE_ID=w1 CLAUDE_PROJECT_DIR="$WT" bash "$HOOK"
assert_equals "$(herdr_calls)" "" "herdr calls" && pass
teardown_sandbox

it "exits 0 and does nothing when hunk is not installed"
setup_review_sandbox
echo two >> "$WT/a.txt"
rm "$MOCK_BIN/hunk"
for tool in awk bash cat git jq perl; do ln -s "$(command -v "$tool")" "$MOCK_BIN/$tool"; done
printf '{"last_assistant_message":"Done.\\n%s"}' "$DONE" |
  PATH="$MOCK_BIN" HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 CLAUDE_PROJECT_DIR="$WT" /bin/bash "$HOOK"
status=$?
assert_equals "$status" "0" "exit code" && assert_equals "$(herdr_calls)" "" "herdr calls" && pass
teardown_sandbox

it "the tab is named for the branch without its fix/ or feat/ prefix"
setup_review_sandbox
git -C "$MAIN" worktree add -q "$MAIN/worktrees/fix/deep" -b fix/deep
WT4="$(git -C "$MAIN/worktrees/fix/deep" rev-parse --show-toplevel)"
echo two >> "$WT4/a.txt"
run_hook "$WT4" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "--label review: deep --cwd $WT4" "herdr calls" && pass
teardown_sandbox

it "the review tab never takes focus"
setup_review_sandbox
echo two >> "$WT/a.txt"
run_hook "$WT" "Done.\n$DONE"
assert_contains "$(herdr_calls)" "--no-focus" "herdr calls" &&
  assert_not_contains "$(herdr_calls)" "tab focus" "herdr calls" &&
  assert_not_contains "$(herdr_calls)" "workspace focus" "herdr calls" && pass
teardown_sandbox

it "the tab goes in the main workspace, never the worktree's own"
setup_review_sandbox
echo two >> "$WT/a.txt"
run_hook "$WT" "Done.\n$DONE"
assert_not_contains "$(herdr_calls)" "--workspace w1" "herdr calls" && pass
teardown_sandbox

it "a review tab whose worktree was dropped is closed on the next stop"
setup_review_sandbox
echo '[{"tab_id":"w1:t4","label":"review: feat-x"},{"tab_id":"w1:t5","label":"review: gone"},{"tab_id":"w1:t6","label":"notes"}]' > "$MOCK_TABS"
run_hook "$MAIN" "Hi.\n$DONE"
assert_contains "$(herdr_calls)" "tab close w1:t5" "herdr calls" &&
  assert_not_contains "$(herdr_calls)" "tab close w1:t4" "herdr calls" &&
  assert_not_contains "$(herdr_calls)" "tab close w1:t6" "herdr calls" &&
  assert_no_tab && pass
teardown_sandbox
