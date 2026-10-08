# markdown-review.sh opens each Markdown file Claude writes in plannotator-tui,
# in a review tab of its own in the main checkout's workspace, so the person can
# annotate it and send the notes back to the session that wrote it. Each case
# feeds the hook a PostToolUse payload the way Claude Code does and reads back
# what it asked herdr to do.

HOOK="$REPO_ROOT/claude/hooks/markdown-review.sh"

# A sandbox whose PATH holds a mock herdr that answers `tab list` from
# $MOCK_TABS, `pane list` from $MOCK_PANES, `workspace list` from
# $MOCK_WORKSPACES, and `plugin pane open` with a pane in tab w1:t9, or fails it
# when MOCK_PLUGIN_FAIL=1. Every call is logged.
setup_markdown_sandbox() {
  setup_sandbox
  export MOCK_TABS="$SANDBOX/tabs.json" MOCK_PANES="$SANDBOX/panes.json" MOCK_WORKSPACES="$SANDBOX/workspaces.json"
  echo '[]' > "$MOCK_TABS"
  echo '[]' > "$MOCK_PANES"
  echo '[]' > "$MOCK_WORKSPACES"
  unset MOCK_PLUGIN_FAIL
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
case "$1 $2 $3" in
  "tab list "*) printf '{"result":{"tabs":%s}}\n' "$(cat "$MOCK_TABS")" ;;
  "workspace list "*) printf '{"result":{"workspaces":%s}}\n' "$(cat "$MOCK_WORKSPACES")" ;;
  "pane list "*) printf '{"result":{"panes":%s}}\n' "$(cat "$MOCK_PANES")" ;;
  "plugin pane open")
    [ "${MOCK_PLUGIN_FAIL:-0}" = 1 ] && exit 1
    echo '{"result":{"plugin_pane":{"pane":{"pane_id":"w1:p9","tab_id":"w1:t9"}}}}' ;;
esac
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr"
  DOCS="$SANDBOX/repo/docs"
  mkdir -p "$DOCS"
}

# An earlier review in the workspace: tab $1 labelled $2, its plannotator pane
# opened in folder $3, and $4 whether the person is looking at it.
review_tab() {
  jq -c --arg t "$1" --arg l "$2" --argjson f "${4:-false}" '. + [{tab_id: $t, label: $l, focused: $f}]' \
    "$MOCK_TABS" > "$MOCK_TABS.new" && mv "$MOCK_TABS.new" "$MOCK_TABS"
  jq -c --arg t "$1" --arg d "$3" '. + [{pane_id: ($t + "-pane"), tab_id: $t, label: "Annotate", cwd: $d}]' \
    "$MOCK_PANES" > "$MOCK_PANES.new" && mv "$MOCK_PANES.new" "$MOCK_PANES"
}

# The session runs in $PROJECT: by default a folder outside git.
run_hook() {
  printf '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" |
    HERDR_ENV=1 HERDR_WORKSPACE_ID=w1 HERDR_PANE_ID="${PANE:-w1:p1}" \
      CLAUDE_PROJECT_DIR="${PROJECT:-$SANDBOX/repo}" bash "$HOOK" ||
    fail "hook exited non-zero"
}

# MAIN is a repo on master whose herdr workspace is wm; WT a linked worktree of
# it on feat/x, in workspace w1. herdr lists both after another project's wo.
setup_worktree() {
  MAIN="$SANDBOX/main"
  mkdir -p "$MAIN"
  git -C "$MAIN" init -q -b master
  git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$MAIN" worktree add -q "$MAIN/worktrees/feat/x" -b feat/x
  MAIN="$(git -C "$MAIN" rev-parse --show-toplevel)"
  WT="$(git -C "$MAIN/worktrees/feat/x" rev-parse --show-toplevel)"
  cat > "$MOCK_WORKSPACES" <<JSON
[{"workspace_id":"wo","worktree":{"is_linked_worktree":false,"repo_root":"$SANDBOX/other"}},
 {"workspace_id":"w1","worktree":{"is_linked_worktree":true,"repo_root":"$MAIN"}},
 {"workspace_id":"wm","worktree":{"is_linked_worktree":false,"repo_root":"$MAIN"}}]
JSON
}

herdr_calls() { cat "$MOCK_HERDR_LOG"; }

assert_renamed_to() {
  grep -qxF "tab rename w1:t9 $1" "$MOCK_HERDR_LOG" || { fail "expected the new tab renamed to $1: $(herdr_calls)"; return 1; }
}

assert_nothing_opened() {
  if grep -q '^plugin pane open' "$MOCK_HERDR_LOG"; then
    fail "opened a review: $(herdr_calls)"
    return 1
  fi
}

assert_nothing_closed() {
  if grep -q '^tab close' "$MOCK_HERDR_LOG"; then
    fail "closed a tab: $(herdr_calls)"
    return 1
  fi
}

it "a written Markdown file opens for review in an unfocused tab of the session's workspace"
setup_markdown_sandbox
run_hook "$DOCS/plan.md"
assert_contains "$(herdr_calls)" "plugin pane open --plugin annotate --entrypoint doc --placement tab --workspace w1 --no-focus --cwd $(cd "$DOCS" && pwd -P) --env PLANNOTATOR_TUI_FILE=$DOCS/plan.md" "herdr calls" &&
  assert_renamed_to review:plan &&
  pass
teardown_sandbox

it "notes sent from the review go to the pane of the session that wrote the file"
setup_markdown_sandbox
PANE=w1:p3 run_hook "$DOCS/plan.md"
assert_contains "$(herdr_calls)" "PLANNOTATOR_TUI_DELIVER_TO=w1:p3" "herdr calls" && pass
teardown_sandbox

it "a worktree session's review opens in the main checkout's workspace, named for its branch"
setup_markdown_sandbox
setup_worktree
PANE=w1:p3 PROJECT="$WT" run_hook "$WT/plan.md"
assert_contains "$(herdr_calls)" "plugin pane open --plugin annotate --entrypoint doc --placement tab --workspace wm --no-focus --cwd $WT" "herdr calls" &&
  assert_contains "$(herdr_calls)" "PLANNOTATOR_TUI_DELIVER_TO=w1:p3" "herdr calls" &&
  assert_contains "$(herdr_calls)" "tab list --workspace wm" "herdr calls" &&
  assert_contains "$(herdr_calls)" "pane list --workspace wm" "herdr calls" &&
  assert_renamed_to review:x/plan &&
  pass
teardown_sandbox

it "a worktree session's rewrite replaces its review tab in the main workspace"
setup_markdown_sandbox
setup_worktree
review_tab wm:t4 review:x/plan "$WT"
PROJECT="$WT" run_hook "$WT/plan.md"
assert_contains "$(herdr_calls)" "tab close wm:t4" "herdr calls" && pass
teardown_sandbox

it "the main checkout's own session names the tab for the file alone"
setup_markdown_sandbox
setup_worktree
PROJECT="$MAIN" run_hook "$MAIN/plan.md"
assert_renamed_to review:plan && pass
teardown_sandbox

it "with no workspace for the main checkout, a worktree's review opens in its own"
setup_markdown_sandbox
setup_worktree
echo '[]' > "$MOCK_WORKSPACES"
PROJECT="$WT" run_hook "$WT/plan.md"
assert_contains "$(herdr_calls)" "--placement tab --workspace w1 " "herdr calls" &&
  assert_renamed_to review:x/plan &&
  pass
teardown_sandbox

it "a Whiska spec opens nothing"
setup_markdown_sandbox
run_hook "$SANDBOX/repo/.whiska-spec.md"
assert_nothing_opened && pass
teardown_sandbox

it "a file that is not Markdown opens nothing"
setup_markdown_sandbox
run_hook "$DOCS/notes.txt"
assert_nothing_opened && pass
teardown_sandbox

it "agent instructions, memory and Claude's own files open nothing"
setup_markdown_sandbox
for f in "$SANDBOX/repo/CLAUDE.md" "$SANDBOX/repo/AGENTS.md" "$SANDBOX/repo/MEMORY.md" "$SANDBOX/memory/notes.md" \
  "$SANDBOX/home/.claude/skills/x/SKILL.md" "$SANDBOX/repo/node_modules/pkg/README.md"; do
  run_hook "$f"
done
assert_nothing_opened && pass
teardown_sandbox

it "a file holding a raw escape byte opens nothing"
setup_markdown_sandbox
printf 'fine\n\033[201~\r!echo pwned\r\n' > "$DOCS/plan.md"
run_hook "$DOCS/plan.md"
assert_nothing_opened && pass
teardown_sandbox

it "a file with a planted annotations file beside it opens nothing"
setup_markdown_sandbox
echo '# Plan' > "$DOCS/plan.md"
echo '[]' > "$DOCS/plan.md.annotations.json"
run_hook "$DOCS/plan.md"
assert_nothing_opened && pass
teardown_sandbox

it "a rewrite of the same file replaces its own review tab"
setup_markdown_sandbox
review_tab w1:t4 review:plan "$DOCS"
run_hook "$DOCS/plan.md"
assert_contains "$(herdr_calls)" "--no-focus" "herdr calls" &&
  assert_contains "$(herdr_calls)" "tab close w1:t4" "herdr calls" &&
  assert_renamed_to review:plan &&
  pass
teardown_sandbox

it "a different file opens its own tab and leaves the review being read alone"
setup_markdown_sandbox
review_tab w1:t4 review:notes "$DOCS" true
run_hook "$DOCS/plan.md"
assert_contains "$(herdr_calls)" "--workspace w1 --no-focus --cwd" "herdr calls" &&
  assert_nothing_closed &&
  assert_renamed_to review:plan &&
  pass
teardown_sandbox

it "a file of the same name in another folder gets its own tab"
setup_markdown_sandbox
review_tab w1:t4 review:plan "$SANDBOX/repo"
run_hook "$DOCS/plan.md"
assert_nothing_closed && assert_renamed_to review:plan && pass
teardown_sandbox

it "a rewrite of the file the person is reading reopens it in front of them"
setup_markdown_sandbox
review_tab w1:t4 review:plan "$DOCS" true
run_hook "$DOCS/plan.md"
assert_contains "$(herdr_calls)" "--workspace w1 --focus --cwd" "herdr calls" &&
  assert_contains "$(herdr_calls)" "tab close w1:t4" "herdr calls" &&
  pass
teardown_sandbox

it "a file written through a symlinked folder still finds its review tab"
setup_markdown_sandbox
ln -s "$DOCS" "$SANDBOX/docs-link"
review_tab w1:t4 review:plan "$(cd "$DOCS" && pwd -P)"
run_hook "$SANDBOX/docs-link/plan.md"
assert_contains "$(herdr_calls)" "tab close w1:t4" "herdr calls" && pass
teardown_sandbox

it "a review opens in the file's resolved folder, so a write by either path finds it"
setup_markdown_sandbox
ln -s "$DOCS" "$SANDBOX/docs-link"
run_hook "$SANDBOX/docs-link/plan.md"
assert_contains "$(herdr_calls)" "--cwd $(cd "$DOCS" && pwd -P) --env" "herdr calls" && pass
teardown_sandbox

it "only a tab holding this file's review is replaced"
setup_markdown_sandbox
review_tab w1:t4 review:plan "$SANDBOX/repo"
review_tab w1:t5 review:notes "$DOCS"
run_hook "$DOCS/plan.md"
assert_nothing_closed && pass
teardown_sandbox

it "every earlier review of the same file goes"
setup_markdown_sandbox
review_tab w1:t4 review:plan "$DOCS"
review_tab w1:t5 review:plan "$DOCS"
run_hook "$DOCS/plan.md"
assert_contains "$(herdr_calls)" "tab close w1:t4" "herdr calls" &&
  assert_contains "$(herdr_calls)" "tab close w1:t5" "herdr calls" &&
  pass
teardown_sandbox

it "the new tab is named before the old one closes, ahead of herdr's automatic tab naming"
setup_markdown_sandbox
review_tab w1:t4 review:plan "$DOCS"
run_hook "$DOCS/plan.md"
assert_equals "$(grep -E '^tab (rename|close)' "$MOCK_HERDR_LOG" | cut -d' ' -f2 | tr '\n' ' ')" "rename close " "order of tab calls" && pass
teardown_sandbox

it "when the review cannot open, the open review tab stays"
setup_markdown_sandbox
review_tab w1:t4 review:plan "$DOCS"
MOCK_PLUGIN_FAIL=1 run_hook "$DOCS/plan.md"
assert_nothing_closed &&
  assert_not_contains "$(herdr_calls)" "tab rename" "herdr calls" &&
  pass
teardown_sandbox

it "outside herdr nothing opens"
setup_markdown_sandbox
printf '{"tool_input":{"file_path":"%s"}}' "$DOCS/plan.md" |
  HERDR_WORKSPACE_ID=w1 HERDR_PANE_ID=w1:p1 env -u HERDR_ENV bash "$HOOK" ||
  fail "hook exited non-zero"
assert_nothing_opened && pass
teardown_sandbox
