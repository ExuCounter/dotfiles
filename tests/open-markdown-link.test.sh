# open-markdown-link.sh is what kitty runs when a Markdown file link is
# Cmd-clicked: it opens the file in a revdiff review tab in the main workspace,
# with notes going to the agent whose pane printed the link. Each case runs it
# with a mock herdr and reads back what it asked herdr to do.

SCRIPT="$REPO_ROOT/kitty/open-markdown-link.sh"

# Mock herdr: `pane list`, `pane read`, `workspace list` and `tab list` answer
# from files in the sandbox, `tab create` returns tab w1:t9 with root pane
# w1:p9 (or fails when MOCK_TAB_FAIL=1). `open` and `revdiff` are mocked too.
# Every call is logged.
setup_link_sandbox() {
  setup_sandbox
  export MOCK_TABS="$SANDBOX/tabs.json" MOCK_PANES="$SANDBOX/panes.json" MOCK_WORKSPACES="$SANDBOX/workspaces.json" MOCK_SCREENS="$SANDBOX/screens"
  echo '[]' > "$MOCK_TABS"
  echo '[]' > "$MOCK_PANES"
  echo '[]' > "$MOCK_WORKSPACES"
  mkdir -p "$MOCK_SCREENS"
  unset MOCK_TAB_FAIL
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
case "$1 $2" in
  "pane list") printf '{"result":{"panes":%s}}\n' "$(cat "$MOCK_PANES")" ;;
  "pane read") cat "$MOCK_SCREENS/${3//:/_}" 2>/dev/null ;;
  "workspace list") printf '{"result":{"workspaces":%s}}\n' "$(cat "$MOCK_WORKSPACES")" ;;
  "tab list") printf '{"result":{"tabs":%s}}\n' "$(cat "$MOCK_TABS")" ;;
  "tab create")
    [ "${MOCK_TAB_FAIL:-0}" = 1 ] && exit 1
    echo '{"result":{"tab":{"tab_id":"w1:t9"},"root_pane":{"pane_id":"w1:p9","tab_id":"w1:t9"}}}' ;;
esac
exit 0
MOCK
  printf '#!/usr/bin/env bash\nprintf "open %%s\\n" "$*" >> "$MOCK_HERDR_LOG"\n' > "$MOCK_BIN/open"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/revdiff"
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/open" "$MOCK_BIN/revdiff"
  DOC="$SANDBOX/repo/spec.md"
  mkdir -p "$SANDBOX/repo"
  echo '# a spec' > "$DOC"
}

# An agent pane $1 in workspace $2, focused or not ($3), showing $4.
agent_pane() {
  jq -c --arg id "$1" --arg w "$2" --argjson f "$3" '. + [{pane_id: $id, workspace_id: $w, agent: "claude", focused: $f}]' \
    "$MOCK_PANES" > "$MOCK_PANES.new" && mv "$MOCK_PANES.new" "$MOCK_PANES"
  printf '%s\n' "$4" > "$MOCK_SCREENS/${1//:/_}"
}

run_link() { PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "$1" || fail "script exited non-zero"; }
calls() { cat "$MOCK_HERDR_LOG"; }
created_call() { grep '^tab create' "$MOCK_HERDR_LOG" || true; }
run_call() { grep '^pane run' "$MOCK_HERDR_LOG" || true; }
review="$HOME/.config/revdiff/review.sh"

it "runs the review in a new tab that closes with it, sending notes to the agent whose pane printed the link, not the focused one"
setup_link_sandbox
agent_pane w1:p1 w1 true "nothing here"
agent_pane w1:p2 w1 false "read file://$DOC please"
run_link "$DOC"
assert_contains "$(created_call)" "--workspace w1 --label review:spec" "the tab create call" \
  && assert_equals "$(run_call)" "pane run w1:p9 '$HOME/.config/revdiff/review.sh' '$DOC' 'w1:p2'; exit" "the pane run call" \
  && assert_contains "$(calls)" "tab focus w1:t9" "herdr calls" \
  && pass
teardown_sandbox

it "falls back to the focused agent when no pane shows the link"
setup_link_sandbox
agent_pane w1:p1 w1 false "nothing"
agent_pane w1:p2 w1 true "nothing either"
run_link "$DOC"
assert_contains "$(run_call)" "'$DOC' 'w1:p2'" "the pane run call" && pass
teardown_sandbox

it "quotes the file's path on the command line it types into the tab"
setup_link_sandbox
mkdir -p "$SANDBOX/my docs"
DOC="$SANDBOX/my docs/it's \$(touch pwned).md"
echo '# odd' > "$DOC"
agent_pane w1:p1 w1 true "nothing"
run_link "$DOC"
line="$(run_call)"
words="$(cd "$SANDBOX" && bash -c "printf '%s\n' ${line#pane run w1:p9 }" 2>&1)"
assert_no_file "$SANDBOX/pwned" \
  && assert_equals "$words" "$HOME/.config/revdiff/review.sh
$DOC
w1:p1" "the words the tab's shell reads" \
  && pass
teardown_sandbox

it "opens the review in the main workspace and checkout for a file in a worktree, labelled by branch"
setup_link_sandbox
MAIN="$SANDBOX/main"
mkdir -p "$MAIN"
git -C "$MAIN" init -q -b master
git -C "$MAIN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$MAIN" worktree add -q "$MAIN/worktrees/feat/x" -b feat/x
MAIN="$(git -C "$MAIN" rev-parse --show-toplevel)"
WT="$(git -C "$MAIN/worktrees/feat/x" rev-parse --show-toplevel)"
cat > "$MOCK_WORKSPACES" <<JSON
[{"workspace_id":"w1","worktree":{"is_linked_worktree":true,"repo_root":"$MAIN"}},
 {"workspace_id":"wm","worktree":{"is_linked_worktree":false,"repo_root":"$MAIN"}}]
JSON
echo '# plan' > "$WT/plan.md"
agent_pane w1:p1 w1 true "file://$WT/plan.md"
run_link "$WT/plan.md"
assert_contains "$(created_call)" "--workspace wm --label review:x/plan --cwd $MAIN" "the tab create call" && pass
teardown_sandbox

it "opens with the plain opener when the file holds an escape sequence"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
printf '# hi \033[31mred\n' > "$DOC"
run_link "$DOC"
assert_equals "$(created_call)" "" "tab create calls" && assert_contains "$(calls)" "open -- $DOC" "calls" && pass
teardown_sandbox

it "opens with the plain opener when the file holds a carriage return"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
printf '# hi\rrun it\r\n' > "$DOC"
run_link "$DOC"
assert_equals "$(created_call)" "" "tab create calls" && assert_contains "$(calls)" "open -- $DOC" "calls" && pass
teardown_sandbox

it "types a path with glob characters so the tab's shell reads it literally"
setup_link_sandbox
DOC="$SANDBOX/repo/spec#.md"
echo '# odd' > "$DOC"
echo '# other' > "$SANDBOX/repo/spe.md"
agent_pane w1:p1 w1 true "nothing"
run_link "$DOC"
line="$(run_call)"
words="$(cd "$SANDBOX/repo" && zsh -c "setopt extendedglob; printf '%s\n' ${line#pane run w1:p9 }" 2>&1)"
assert_contains "$words" "$DOC" "the words the tab's shell reads" && pass
teardown_sandbox

it "opens with the plain opener when the file's path holds a newline, which would submit the typed command early"
setup_link_sandbox
DOC="$SANDBOX/repo/a
b.md"
echo '# odd' > "$DOC"
agent_pane w1:p1 w1 true "nothing"
run_link "$DOC"
assert_equals "$(run_call)" "" "pane run calls" && assert_contains "$(calls)" "open -- $SANDBOX/repo/a" "calls" && pass
teardown_sandbox

it "opens with the plain opener when the review tab fails to open"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
MOCK_TAB_FAIL=1 run_link "$DOC"
assert_contains "$(calls)" "open -- $DOC" "calls" && assert_equals "$(run_call)" "" "pane run calls" && pass
teardown_sandbox

it "ignores a pane that shows only a longer path ending in the same name"
setup_link_sandbox
agent_pane w1:p1 w1 true "nothing"
agent_pane w1:p2 w1 false "see file:///other$DOC"
run_link "$DOC"
assert_contains "$(run_call)" "'$DOC' 'w1:p1'" "the pane run call" && pass
teardown_sandbox

it "closes the earlier review tab with the same label once the new one is up, and keeps other tabs"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
echo '[{"tab_id":"w1:t5","label":"review:spec"},{"tab_id":"w1:t6","label":"review:plan"}]' > "$MOCK_TABS"
run_link "$DOC"
assert_contains "$(calls)" "tab close w1:t5" "herdr calls" \
  && assert_not_contains "$(calls)" "tab close w1:t6" "herdr calls" \
  && assert_equals "$(grep -n 'tab close\|pane run' "$MOCK_HERDR_LOG" | head -1 | cut -d' ' -f2)" "run" "first of pane run and tab close" \
  && pass
teardown_sandbox

it "reads only each pane's visible screen, so a full-screen agent is not scrolled through its history"
setup_link_sandbox
agent_pane w1:p1 w1 true "nothing"
agent_pane w1:p2 w1 false "nothing either"
run_link "$DOC"
assert_equals "$(grep '^pane read' "$MOCK_HERDR_LOG")" "pane read w1:p1 --source visible
pane read w1:p2 --source visible" "pane reads" && pass
teardown_sandbox
