# claude/hooks/herdr-status.sh: Claude Code's hooks report the session's state
# to the Herdr app as OSC 7501 on the claude process's pty, and the agents-ids
# labels through `hc label`. Mock `ps` serves a process table, mock `hc` serves
# `hc get --json` from a file and logs `hc label`; the pty is a plain file.

HOOK="$REPO_ROOT/claude/hooks/herdr-status.sh"

# The terminal t9 runs claude as pid 500 on ttys900; its agent.session is s1.
hs_setup() {
  setup_sandbox
  export HERDR_STATUS_DEV_DIR="$SANDBOX/dev"
  mkdir -p "$HERDR_STATUS_DEV_DIR"
  export MOCK_PS_TABLE="$SANDBOX/ps-table" MOCK_HC_GET="$SANDBOX/hc-get.json" MOCK_HC_LOG="$SANDBOX/hc.log"
  : > "$MOCK_HC_LOG"
  # Any pid outside the table is the hook's own shell, a child of pid 500.
  printf '500 1 ttys900 /Users/x/.local/bin/claude\n' > "$MOCK_PS_TABLE"
  hc_get 500 s1 working
  export HC_TERMINAL_ID=t9

  cat > "$MOCK_BIN/ps" <<'MOCK'
#!/usr/bin/env bash
pid="${@: -1}"
row="$(awk -v p="$pid" '$1 == p { $1 = ""; sub(/^ /, ""); print }' "$MOCK_PS_TABLE")"
[ -n "$row" ] && echo "$row" || echo "500 ?? /bin/sh"
MOCK
  cat > "$MOCK_BIN/hc" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  get) cat "$MOCK_HC_GET" ;;
  label) shift; printf '%s\n' "$*" >> "$MOCK_HC_LOG" ;;
esac
MOCK
  chmod +x "$MOCK_BIN/ps" "$MOCK_BIN/hc"
}

# hc_get <foreground pid> <agent.session> <status>
hc_get() {
  printf '{"address":"t9","status":{"state":"%s"},"foreground":{"pid":%s},"labels":{"agent.session":"%s"}}' "$3" "$1" "$2" > "$MOCK_HC_GET"
}

hook() { printf '%s' "$1" | bash "$HOOK"; }
pty() { cat "$HERDR_STATUS_DEV_DIR/ttys900" 2>/dev/null; }
labels() { cat "$MOCK_HC_LOG"; }
b64() { printf '%s' "$1" | base64 | tr -d '\n'; }
osc() { printf '\033]7501;%s\033\\' "$1"; }

it "writes nothing outside an hc terminal"
hs_setup
unset HC_TERMINAL_ID
hook '{"hook_event_name":"SessionStart","session_id":"s1","source":"startup"}'
assert_equals "$(pty)" "" "pty" && assert_equals "$(labels)" "" "labels" && pass
teardown_sandbox

it "SessionStart labels the terminal's session and reports idle"
hs_setup
hc_get 500 "" null
hook '{"hook_event_name":"SessionStart","session_id":"s2","source":"startup"}'
assert_equals "$(pty)" "$(osc "state=idle:app=claude-code")" "pty" &&
  assert_contains "$(labels)" "t9 agent.session=s2 agent.app=claude agent.doing= agent.doing.since= agent.next= agent.needs=" "labels" && pass
teardown_sandbox

it "a claude that is not the terminal's foreground program writes nothing (nested in a Bash tool)"
hs_setup
printf '500 600 ?? claude\n600 700 ?? /bin/zsh\n700 1 ttys900 claude\n' > "$MOCK_PS_TABLE"
hc_get 700 s1 working
hook '{"hook_event_name":"SessionStart","session_id":"s3","source":"startup"}'
assert_equals "$(pty)" "" "pty" && assert_equals "$(labels)" "" "labels" && pass
teardown_sandbox

it "a session that is not the terminal's agent.session writes nothing"
hs_setup
hook '{"hook_event_name":"UserPromptSubmit","session_id":"other","prompt":"hi"}'
assert_equals "$(pty)" "" "pty" && assert_equals "$(labels)" "" "labels" && pass
teardown_sandbox

it "UserPromptSubmit reports working with the prompt's first plain line"
hs_setup
hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","prompt":"\n## Fix **the** login\nmore"}'
assert_equals "$(pty)" "$(osc "state=working:app=claude-code:msg=$(b64 "Fix the login")")" "pty" &&
  assert_contains "$(labels)" "t9 agent.doing=Fix the login agent.doing.since=" "labels" &&
  assert_contains "$(labels)" "agent.next= agent.needs=" "labels" && pass
teardown_sandbox

it "PreToolUse reports what the tool does"
hs_setup
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/a/b/foo.sh"}}'
assert_equals "$(pty)" "$(osc "state=working:app=claude-code:msg=$(b64 "editing foo.sh")")" "pty" &&
  assert_contains "$(labels)" "t9 agent.doing=editing foo.sh agent.doing.since=" "labels" && pass
teardown_sandbox

it "PreToolUse words Bash, Grep, Skill and MCP tools as Whiska's progress hook does"
hs_setup
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"ls","description":"List files"}}'
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Bash","tool_input":{"command":"git status\necho x"}}'
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Grep","tool_input":{"pattern":"foo"}}'
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Skill","tool_input":{"skill":"tdd"}}'
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"mcp__GitLab__get_mr","tool_input":{}}'
out="$(labels)"
assert_contains "$out" "agent.doing=List files " &&
  assert_contains "$out" "agent.doing=running git status " &&
  assert_contains "$out" "agent.doing=searching for foo " &&
  assert_contains "$out" "agent.doing=/tdd " &&
  assert_contains "$out" "agent.doing=get_mr " && pass
teardown_sandbox

it "PreToolUse after the turn ended leaves the turn's state alone"
hs_setup
hc_get 500 s1 done
hook '{"hook_event_name":"PreToolUse","session_id":"s1","tool_name":"Read","tool_input":{"file_path":"/a/x"}}'
assert_equals "$(pty)" "" "pty" && assert_equals "$(labels)" "" "labels" && pass
teardown_sandbox

it "Stop on a question reports blocked:question and asks for you"
hs_setup
hook '{"hook_event_name":"Stop","session_id":"s1","last_assistant_message":"Done the thing.\n\n**Shall I go on?**"}'
assert_equals "$(pty)" "$(osc "state=blocked:kind=question:app=claude-code:msg=$(b64 "❓ Shall I go on?")")" "pty" &&
  assert_contains "$(labels)" "t9 agent.doing= agent.doing.since= agent.next=❓ Shall I go on? agent.needs=you" "labels" && pass
teardown_sandbox

it "Stop otherwise reports done with the reply's first plain line"
hs_setup
hook '{"hook_event_name":"Stop","session_id":"s1","last_assistant_message":"# All `tests` pass\n\nDetails."}'
assert_equals "$(pty)" "$(osc "state=done:app=claude-code:msg=$(b64 "All tests pass")")" "pty" &&
  assert_contains "$(labels)" "agent.next=All tests pass agent.needs=" "labels" && pass
teardown_sandbox

it "a long line is cut to forty characters"
hs_setup
hook '{"hook_event_name":"Stop","session_id":"s1","last_assistant_message":"aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeee"}'
assert_contains "$(labels)" "agent.next=aaaaaaaaaabbbbbbbbbbccccccccccddddddddd… " "labels" && pass
teardown_sandbox

it "a permission prompt reports blocked:permission and asks for you"
hs_setup
hook '{"hook_event_name":"Notification","session_id":"s1","notification_type":"permission_prompt","message":"Claude needs your permission to use Bash"}'
assert_equals "$(pty)" "$(osc "state=blocked:kind=permission:app=claude-code:msg=$(b64 "Claude needs your permission to use Bash")")" "pty" &&
  assert_contains "$(labels)" "agent.needs=you" "labels" && pass
teardown_sandbox

it "SessionEnd clears the report and the turn's labels, keeping the session for Resume"
hs_setup
hook '{"hook_event_name":"SessionEnd","session_id":"s1","reason":"prompt_input_exit"}'
assert_equals "$(pty)" "$(osc "state=clear")" "pty" &&
  assert_equals "$(labels)" "t9 agent.doing= agent.doing.since= agent.next= agent.needs=" "labels" && pass
teardown_sandbox

it "bad input never fails the hook"
hs_setup
printf 'not json' | bash "$HOOK"
assert_equals "$?" "0" "exit code" && pass
teardown_sandbox
