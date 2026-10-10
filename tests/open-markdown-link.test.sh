# open-markdown-link.sh is what kitty runs when a Markdown file link is
# Cmd-clicked: it opens the file in a Plannotator review tab in the main
# workspace, with notes going to the agent whose pane printed the link. Each
# case runs it with a mock herdr and reads back what it asked herdr to do.

SCRIPT="$REPO_ROOT/kitty/open-markdown-link.sh"

# Mock herdr: `pane list`, `pane read`, `workspace list` and `tab list` answer
# from files in the sandbox, `plugin pane open` returns a pane in tab w1:t9 (or
# fails when MOCK_PLUGIN_FAIL=1). `open` is mocked too. Every call is logged.
setup_link_sandbox() {
  setup_sandbox
  export MOCK_TABS="$SANDBOX/tabs.json" MOCK_PANES="$SANDBOX/panes.json" MOCK_WORKSPACES="$SANDBOX/workspaces.json" MOCK_SCREENS="$SANDBOX/screens"
  echo '[]' > "$MOCK_TABS"
  echo '[]' > "$MOCK_PANES"
  echo '[]' > "$MOCK_WORKSPACES"
  mkdir -p "$MOCK_SCREENS"
  unset MOCK_PLUGIN_FAIL
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
case "$1 $2" in
  "pane list") printf '{"result":{"panes":%s}}\n' "$(cat "$MOCK_PANES")" ;;
  "pane read") cat "$MOCK_SCREENS/${3//:/_}" 2>/dev/null ;;
  "workspace list") printf '{"result":{"workspaces":%s}}\n' "$(cat "$MOCK_WORKSPACES")" ;;
  "tab list") printf '{"result":{"tabs":%s}}\n' "$(cat "$MOCK_TABS")" ;;
  "plugin pane")
    [ "${MOCK_PLUGIN_FAIL:-0}" = 1 ] && exit 1
    echo '{"result":{"plugin_pane":{"pane":{"pane_id":"w1:p9","tab_id":"w1:t9"}}}}' ;;
esac
exit 0
MOCK
  printf '#!/usr/bin/env bash\nprintf "open %%s\\n" "$*" >> "$MOCK_HERDR_LOG"\n' > "$MOCK_BIN/open"
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/open"
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
opened_call() { grep '^plugin pane open' "$MOCK_HERDR_LOG" || true; }

it "sends notes to the agent whose pane printed the link, not the focused one"
setup_link_sandbox
agent_pane w1:p1 w1 true "nothing here"
agent_pane w1:p2 w1 false "read file://$DOC please"
run_link "$DOC"
out="$(opened_call)"
assert_contains "$out" "PLANNOTATOR_TUI_DELIVER_TO=w1:p2" "the open call" \
  && assert_contains "$out" "PLANNOTATOR_TUI_FILE=$DOC" "the open call" \
  && assert_contains "$out" "--focus" "the open call" \
  && assert_contains "$(calls)" "tab rename w1:t9 review:spec" "herdr calls" \
  && pass
teardown_sandbox

it "falls back to the focused agent when no pane shows the link"
setup_link_sandbox
agent_pane w1:p1 w1 false "nothing"
agent_pane w1:p2 w1 true "nothing either"
run_link "$DOC"
assert_contains "$(opened_call)" "PLANNOTATOR_TUI_DELIVER_TO=w1:p2" "the open call" && pass
teardown_sandbox

it "opens the review in the main workspace for a file in a worktree, labelled by branch"
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
assert_contains "$(opened_call)" "--workspace wm" "the open call" \
  && assert_contains "$(calls)" "tab rename w1:t9 review:x/plan" "herdr calls" \
  && pass
teardown_sandbox

it "opens with the plain opener when the file holds an escape sequence"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
printf '# hi \033[31mred\n' > "$DOC"
run_link "$DOC"
assert_equals "$(opened_call)" "" "plugin open calls" && assert_contains "$(calls)" "open -- $DOC" "calls" && pass
teardown_sandbox

it "opens with the plain opener when the review pane fails to open"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
MOCK_PLUGIN_FAIL=1 run_link "$DOC"
assert_contains "$(calls)" "open -- $DOC" "calls" && pass
teardown_sandbox

it "opens with the plain opener when the file holds a carriage return"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
printf '# hi\rrun it\r\n' > "$DOC"
run_link "$DOC"
assert_equals "$(opened_call)" "" "plugin open calls" && assert_contains "$(calls)" "open -- $DOC" "calls" && pass
teardown_sandbox

it "opens with the plain opener when the file has an annotations sidecar"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
echo '[]' > "$DOC.annotations.json"
run_link "$DOC"
assert_equals "$(opened_call)" "" "plugin open calls" && assert_contains "$(calls)" "open -- $DOC" "calls" && pass
teardown_sandbox

it "ignores a pane that shows only a longer path ending in the same name"
setup_link_sandbox
agent_pane w1:p1 w1 true "nothing"
agent_pane w1:p2 w1 false "see file:///other$DOC"
run_link "$DOC"
assert_contains "$(opened_call)" "PLANNOTATOR_TUI_DELIVER_TO=w1:p1" "the open call" && pass
teardown_sandbox

it "closes the file's earlier review tab and keeps other files' tabs"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
echo "[{\"tab_id\":\"w1:t5\",\"label\":\"review:spec\"},{\"tab_id\":\"w1:t6\",\"label\":\"review:spec\"}]" > "$MOCK_TABS"
echo "[{\"pane_id\":\"w1:p5\",\"tab_id\":\"w1:t5\",\"label\":\"Annotate\",\"cwd\":\"$(dirname "$DOC")\",\"workspace_id\":\"w1\"},{\"pane_id\":\"w1:p6\",\"tab_id\":\"w1:t6\",\"label\":\"Annotate\",\"cwd\":\"/elsewhere\",\"workspace_id\":\"w1\"}]" > "$MOCK_PANES.tabs"
jq -s 'add' "$MOCK_PANES" "$MOCK_PANES.tabs" > "$MOCK_PANES.all" && mv "$MOCK_PANES.all" "$MOCK_PANES"
run_link "$DOC"
assert_contains "$(calls)" "tab close w1:t5" "herdr calls" \
  && assert_not_contains "$(calls)" "tab close w1:t6" "herdr calls" \
  && pass
teardown_sandbox

it "reads only each pane's visible screen, so a full-screen agent is not scrolled through its history"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
agent_pane w1:p2 w1 false "nothing"
run_link "$DOC"
reads="$(grep '^pane read' "$MOCK_HERDR_LOG")"
assert_contains "$reads" "--source visible" "pane reads" \
  && assert_not_contains "$reads" "recent" "pane reads" \
  && assert_not_contains "$reads" "--lines" "pane reads" \
  && pass
teardown_sandbox

it "brings the new review tab to the front, since opening it with --focus leaves the viewer where it was"
setup_link_sandbox
agent_pane w1:p1 w1 true "file://$DOC"
run_link "$DOC"
assert_contains "$(calls)" "tab focus w1:t9" "herdr calls" && pass
teardown_sandbox
