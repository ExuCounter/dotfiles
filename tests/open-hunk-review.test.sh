# open-hunk-review.sh is what kitty runs when a `hunk-review://<base>..<branch>`
# link is Cmd-clicked: it opens `hunk diff <base> <branch>` in a tab of the main
# workspace, started in the main checkout. Each case runs it with a mock herdr
# and reads back what it asked herdr to do.

SCRIPT="$REPO_ROOT/kitty/open-hunk-review.sh"

# Mock herdr: `pane list`, `pane read`, `workspace list` and `tab list` answer
# from files in the sandbox; `tab create` returns a tab w1:t9 with pane w1:p9.
# Every call is logged.
setup_review_sandbox() {
  setup_sandbox
  export MOCK_TABS="$SANDBOX/tabs.json" MOCK_PANES="$SANDBOX/panes.json" MOCK_WORKSPACES="$SANDBOX/workspaces.json" MOCK_SCREENS="$SANDBOX/screens"
  echo '[]' > "$MOCK_TABS"
  echo '[]' > "$MOCK_PANES"
  mkdir -p "$MOCK_SCREENS"
  REPO="$SANDBOX/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q -b master
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$REPO" branch feat/mac-m5
  git -C "$REPO" branch feat/hunk-x
  REPO="$(git -C "$REPO" rev-parse --show-toplevel)"
  cat > "$MOCK_WORKSPACES" <<JSON
[{"workspace_id":"w1","worktree":{"is_linked_worktree":false,"repo_root":"$REPO"}},
 {"workspace_id":"w2","worktree":{"is_linked_worktree":true,"repo_root":"$REPO"}}]
JSON
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
case "$1 $2" in
  "pane list") printf '{"result":{"panes":%s}}\n' "$(cat "$MOCK_PANES")" ;;
  "pane read") cat "$MOCK_SCREENS/${3//:/_}" 2>/dev/null ;;
  "workspace list") printf '{"result":{"workspaces":%s}}\n' "$(cat "$MOCK_WORKSPACES")" ;;
  "tab list") printf '{"result":{"tabs":%s}}\n' "$(cat "$MOCK_TABS")" ;;
  "tab create") echo '{"result":{"tab":{"tab_id":"w1:t9"},"root_pane":{"pane_id":"w1:p9","tab_id":"w1:t9"}}}' ;;
esac
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr"
  LINK="hunk-review://feat/mac-m5..feat/hunk-x"
}

# An agent pane $1 in workspace $2, focused or not ($3), showing $4.
agent_pane() {
  jq -c --arg id "$1" --arg w "$2" --argjson f "$3" '. + [{pane_id: $id, workspace_id: $w, agent: "claude", focused: $f}]' \
    "$MOCK_PANES" > "$MOCK_PANES.new" && mv "$MOCK_PANES.new" "$MOCK_PANES"
  printf '%s\n' "$4" > "$MOCK_SCREENS/${1//:/_}"
}

run_link() { PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" "$1" || fail "script exited non-zero"; }
calls() { cat "$MOCK_HERDR_LOG"; }

it "runs hunk diff <base> <branch> in a new tab of the main checkout, and brings the tab to the front"
setup_review_sandbox
agent_pane w1:p1 w1 true "review: $LINK"
run_link "$LINK"
assert_contains "$(calls)" "tab create --workspace w1 --label hunk:feat/hunk-x --cwd $REPO --no-focus" "herdr calls" \
  && assert_contains "$(calls)" "pane run w1:p9 hunk diff feat/mac-m5 feat/hunk-x" "herdr calls" \
  && assert_contains "$(calls)" "tab focus w1:t9" "herdr calls" \
  && pass
teardown_sandbox

it "opens the tab in the main workspace when the pane that printed the link is in a worktree's"
setup_review_sandbox
agent_pane w1:p1 w1 true "nothing"
agent_pane w2:p2 w2 false "review: $LINK"
run_link "$LINK"
assert_contains "$(calls)" "tab create --workspace w1 " "herdr calls" && pass
teardown_sandbox

it "does nothing for a link whose refs are not plain names"
setup_review_sandbox
agent_pane w1:p1 w1 true "x"
run_link 'hunk-review://master..feat/x;touch$IFS/tmp/pwned'
run_link 'hunk-review://master..-x'
run_link 'hunk-review://master'
run_link 'hunk-review://..feat/x'
assert_not_contains "$(calls)" "tab create" "herdr calls" && pass
teardown_sandbox

it "does nothing when herdr has no agent pane to say which repo this is"
setup_review_sandbox
run_link "$LINK"
assert_not_contains "$(calls)" "tab create" "herdr calls" && pass
teardown_sandbox

it "closes the branch's earlier review tab only after the new one is up, and keeps other tabs"
setup_review_sandbox
agent_pane w1:p1 w1 true "review: $LINK"
echo '[{"tab_id":"w1:t5","label":"hunk:feat/hunk-x"},{"tab_id":"w1:t6","label":"hunk:other"}]' > "$MOCK_TABS"
run_link "$LINK"
assert_contains "$(calls)" "tab close w1:t5" "herdr calls" \
  && assert_not_contains "$(calls)" "tab close w1:t6" "herdr calls" \
  && assert_contains "$(calls | sed -n '/tab create/,$p')" "tab close w1:t5" "calls after tab create" \
  && pass
teardown_sandbox

it "is wired for kitty: executable, linked by install, its scheme a clickable prefix and an open action"
assert_equals "$([ -x "$SCRIPT" ] && echo yes || echo no)" "yes" "open-hunk-review.sh executable" \
  && assert_contains "$(cat "$REPO_ROOT/install.conf.yaml")" "~/.config/kitty/open-hunk-review.sh: kitty/open-hunk-review.sh" "install.conf.yaml" \
  && assert_contains "$(grep '^url_prefixes' "$REPO_ROOT/kitty.conf")" " hunk-review" "kitty.conf url_prefixes" \
  && assert_contains "$(cat "$REPO_ROOT/kitty/open-actions.conf")" "protocol hunk-review
action launch --type=background ~/.config/kitty/open-hunk-review.sh \${URL}" "open-actions.conf" \
  && pass

it "does nothing for a ref the repo does not have, so a file name is never compared as if it were a ref"
setup_review_sandbox
agent_pane w1:p1 w1 true "x"
echo a > "$REPO/README.md"; echo b > "$REPO/package.json"
run_link "hunk-review://README.md..package.json"
run_link "hunk-review://master..feat/nope"
assert_not_contains "$(calls)" "tab create" "herdr calls" && pass
teardown_sandbox

it "keeps the branch's earlier review tab when the new tab did not get its command"
setup_review_sandbox
agent_pane w1:p1 w1 true "review: $LINK"
echo '[{"tab_id":"w1:t5","label":"hunk:feat/hunk-x"}]' > "$MOCK_TABS"
sed -i.bak 's|^case "\$1 \$2" in|[ "$1 $2" = "pane run" ] \&\& exit 1\ncase "$1 $2" in|' "$MOCK_BIN/herdr"
run_link "$LINK"
assert_not_contains "$(calls)" "tab close w1:t5" "herdr calls" && pass
teardown_sandbox

it "gives branches that differ only by a feat/ or fix/ prefix their own tabs"
setup_review_sandbox
git -C "$REPO" branch fix/hunk-x
agent_pane w1:p1 w1 true "review: hunk-review://master..fix/hunk-x"
echo '[{"tab_id":"w1:t5","label":"hunk:feat/hunk-x"}]' > "$MOCK_TABS"
run_link "hunk-review://master..fix/hunk-x"
assert_contains "$(calls)" "--label hunk:fix/hunk-x" "herdr calls" \
  && assert_not_contains "$(calls)" "tab close w1:t5" "herdr calls" && pass
teardown_sandbox
