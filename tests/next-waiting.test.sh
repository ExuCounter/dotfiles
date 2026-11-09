# Ctrl+W focuses the next agent blocked on the person, in workspace order,
# counted from the focused pane. herdr is stubbed: it serves AGENTS, WORKSPACES
# and CURRENT, and logs every call.

NEXT="$REPO_ROOT/herdr_layouts/next_waiting.sh"

setup_next_sandbox() {
  setup_sandbox
  export AGENTS="$SANDBOX/agents.json" WORKSPACES="$SANDBOX/workspaces.json" CURRENT="w2:p1"
  # herdr lists w9 before w3, but w3 comes first in the sidebar.
  cat > "$AGENTS" <<'JSON'
{"result":{"agents":[
  {"pane_id":"w1:p1","workspace_id":"w1","agent_status":"blocked"},
  {"pane_id":"w2:p1","workspace_id":"w2","agent_status":"idle"},
  {"pane_id":"w9:p1","workspace_id":"w9","agent_status":"blocked"},
  {"pane_id":"w3:p1","workspace_id":"w3","agent_status":"blocked"},
  {"pane_id":"w3:p2","workspace_id":"w3","agent_status":"working"}
]}}
JSON
  cat > "$WORKSPACES" <<'JSON'
{"result":{"workspaces":[
  {"workspace_id":"w1","number":1},
  {"workspace_id":"w2","number":2},
  {"workspace_id":"w3","number":3},
  {"workspace_id":"w4","number":4},
  {"workspace_id":"w9","number":9}
]}}
JSON
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
case "$*" in
  "agent list") cat "$AGENTS" ;;
  "workspace list") cat "$WORKSPACES" ;;
  "pane current") ws=${CURRENT%%:*}; printf '{"result":{"pane":{"pane_id":"%s","workspace_id":"%s"}}}\n' "$CURRENT" "$ws" ;;
esac
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr"
}

focused() { grep '^agent focus ' "$MOCK_HERDR_LOG" | sed 's/^agent focus //'; }

it "focuses the next blocked agent after the focused pane, in workspace order"
setup_next_sandbox
bash "$NEXT"
assert_equals "$(focused)" "w3:p1" "focused pane" && pass
teardown_sandbox

it "moves on from a blocked agent that is already focused"
setup_next_sandbox
CURRENT=w3:p1 bash "$NEXT"
assert_equals "$(focused)" "w9:p1" "focused pane" && pass
teardown_sandbox

it "wraps around to the first blocked agent"
setup_next_sandbox
CURRENT=w9:p1 bash "$NEXT"
assert_equals "$(focused)" "w1:p1" "focused pane" && pass
teardown_sandbox

it "counts from the focused pane's workspace when that pane runs no agent"
setup_next_sandbox
CURRENT=w4:p7 bash "$NEXT"
assert_equals "$(focused)" "w9:p1" "focused pane" && pass
teardown_sandbox

it "does nothing when no agent is blocked"
setup_next_sandbox
sed -i '' 's/"blocked"/"idle"/g' "$AGENTS"
bash "$NEXT"
assert_equals "$?" "0" "exit code" && assert_equals "$(focused)" "" "focused pane" && pass
teardown_sandbox

it "asks herdr alone, never whiska"
assert_not_contains "$(grep -v '^#' "$NEXT")" "whiska" "next_waiting.sh" && pass
