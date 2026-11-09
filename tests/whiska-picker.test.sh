# The prefix+space popup lists every Claude agent from `herdr agent list`, the
# blocked ones first, and focuses the one picked. herdr and fzf are stubbed: herdr
# serves AGENTS and WORKSPACES and logs every call; fzf records its input and
# arguments and picks the line named by PICK (1-based; 0 is esc, which real fzf
# exits 130 on).

PICKER="$REPO_ROOT/fzf_whiska/bin/whiska_picker.sh"

setup_picker_sandbox() {
  setup_sandbox
  export SANDBOX AGENTS="$SANDBOX/agents.json" WORKSPACES="$SANDBOX/workspaces.json"
  cat > "$AGENTS" <<'JSON'
{"result":{"agents":[
  {"pane_id":"w1:p1","workspace_id":"w1","agent":"claude","agent_status":"working"},
  {"pane_id":"w2:p1","workspace_id":"w2","agent":"claude","agent_status":"idle"},
  {"pane_id":"w2:p2","workspace_id":"w2","agent":null,"agent_status":"unknown"},
  {"pane_id":"w3:p1","workspace_id":"w3","agent":"claude","agent_status":"blocked"},
  {"pane_id":"w4:p1","workspace_id":"w4","agent":"claude","agent_status":"done"},
  {"pane_id":"w5:p1","workspace_id":"w5","agent":"codex","agent_status":"blocked"}
]}}
JSON
  cat > "$WORKSPACES" <<'JSON'
{"result":{"workspaces":[
  {"workspace_id":"w1","number":1,"label":"platform","tokens":{"whiska":"✓ shipped"}},
  {"workspace_id":"w2","number":2,"label":"dotfiles","tokens":null},
  {"workspace_id":"w3","number":3,"label":"fix/long-branch","tokens":{"whiska":"❓ which tracker?"}},
  {"workspace_id":"w4","number":4,"label":"anki","tokens":{}},
  {"workspace_id":"w5","number":5,"label":"other","tokens":null}
]}}
JSON
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
case "$*" in
  "agent list") [ -n "${HERDR_LIST_FAILS:-}" ] && { echo "herdr: no server" >&2; exit 1; }; cat "$AGENTS" ;;
  "workspace list") cat "$WORKSPACES" ;;
  "agent read "*) echo "screen of ${3}" ;;
esac
exit 0
MOCK
  cat > "$MOCK_BIN/fzf" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$SANDBOX/fzf-args"
input=$(cat)
printf '%s\n' "$input" > "$SANDBOX/fzf-input"
[ "${PICK:-1}" -eq 0 ] && exit 130
printf '%s\n' "$input" | sed -n "${PICK:-1}p"
MOCK
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/fzf"
}

# The visible row: every field after the hidden pane id.
visible() { sed -n "${1}p" "$SANDBOX/fzf-input" | cut -f2-; }

it "lists Claude agents blocked first, then done, idle, working, with label and token"
setup_picker_sandbox
PICK=0 bash "$PICKER" </dev/null
assert_equals "$(grep -c . "$SANDBOX/fzf-input")" "4" "row count" \
  && assert_equals "$(visible 1)" "fix/long-branch	blocked	❓ which tracker?" "blocked row" \
  && assert_equals "$(visible 2)" "anki           	done	" "done row" \
  && assert_equals "$(visible 3)" "dotfiles       	idle	" "idle row" \
  && assert_equals "$(visible 4)" "platform       	working	✓ shipped" "working row" && pass
teardown_sandbox

it "keeps workspace order within one status"
setup_picker_sandbox
sed -i '' 's/"working"/"idle"/' "$AGENTS"
PICK=0 bash "$PICKER" </dev/null
assert_equals "$(sed -n 3,4p "$SANDBOX/fzf-input" | cut -f1 | tr '\n' ' ')" "w1:p1 w2:p1 " "idle rows" && pass
teardown_sandbox

it "previews the agent's screen and matches typing against the label"
setup_picker_sandbox
PICK=0 bash "$PICKER" </dev/null
args=$(tr '\n' ' ' < "$SANDBOX/fzf-args")
assert_contains "$args" "--with-nth 2.. --nth 1" "fzf args" \
  && assert_contains "$args" "herdr agent read {1}" "fzf preview" && pass
teardown_sandbox

it "focuses the picked agent's pane"
setup_picker_sandbox
PICK=1 bash "$PICKER" </dev/null
assert_contains "$(cat "$MOCK_HERDR_LOG")" "agent focus w3:p1" "herdr calls" && pass
teardown_sandbox

it "does nothing when the popup is closed without a pick"
setup_picker_sandbox
PICK=0 bash "$PICKER" </dev/null
assert_equals "$?" "0" "exit code" \
  && assert_not_contains "$(cat "$MOCK_HERDR_LOG")" "focus" "herdr calls" && pass
teardown_sandbox

it "puts herdr's error in the header when the agents cannot be listed"
setup_picker_sandbox
PICK=0 HERDR_LIST_FAILS=1 bash "$PICKER" </dev/null
assert_contains "$(cat "$SANDBOX/fzf-args")" "herdr agent list failed: herdr: no server" "fzf header" && pass
teardown_sandbox

it "calls no whiska and no owl socket"
assert_equals "$(grep -cE '(^|[;|&(]|then|else) *whiska ' "$PICKER")" "0" "whiska calls in picker" \
  && assert_not_contains "$(cat "$PICKER")" "owl.sock" "picker" && pass

it "is bound to prefix+space and linked by install"
assert_contains "$(grep -A3 'key = "prefix+space"' "$REPO_ROOT/herdr.toml")" \
  "~/.config/fzf_whiska/bin/whiska_picker.sh" "herdr.toml" \
  && assert_contains "$(cat "$REPO_ROOT/install.conf.yaml")" "fzf_whiska/bin/whiska_picker.sh" "install.conf.yaml" \
  && pass
