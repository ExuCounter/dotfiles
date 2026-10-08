# The prefix+space popup lists every project's main session from
# `whiska jump --list` and jumps to the one picked. fzf and whiska are stubbed:
# fzf records its input and arguments and picks the line named by PICK
# (1-based; 0 is esc, which real fzf exits 130 on), whiska serves LIST and logs
# the rest of its calls.

PICKER="$REPO_ROOT/fzf_whiska/bin/whiska_picker.sh"

setup_picker_sandbox() {
  setup_sandbox
  export SANDBOX WHISKA_LOG="$SANDBOX/whiska-calls.log"
  : > "$WHISKA_LOG"
  export LIST="$SANDBOX/list.tsv"
  printf '%s\n' \
    "early-bird	/p/early	2	3600	#1 needs a decision: first" \
    "late	/p/late	1	59	#4 finished" \
    "calm	/p/calm	0	-	quiet" \
    "gone	/p/gone	0	-	no main session" > "$LIST"

  cat > "$MOCK_BIN/whiska" <<'MOCK'
#!/usr/bin/env bash
if [ "$*" = "jump --list" ]; then
  [ -n "${WHISKA_LIST_FAILS:-}" ] && { echo "whiska: boom" >&2; exit 1; }
  cat "$LIST"; exit 0
fi
printf '%s\n' "$*" >> "$WHISKA_LOG"
exit "${WHISKA_JUMP_EXIT:-0}"
MOCK
  cat > "$MOCK_BIN/fzf" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$SANDBOX/fzf-args"
input=$(cat)
printf '%s\n' "$input" > "$SANDBOX/fzf-input"
[ "${PICK:-1}" -eq 0 ] && exit 130
printf '%s\n' "$input" | sed -n "${PICK:-1}p"
MOCK
  chmod +x "$MOCK_BIN/whiska" "$MOCK_BIN/fzf"
}

# The visible row: fields 3 and 4 of what fzf was given.
visible() { sed -n "${1}p" "$SANDBOX/fzf-input" | cut -f3-; }

it "formats each row: padded repo, then count and wait, or the plain summary"
setup_picker_sandbox
PICK=0 bash "$PICKER" </dev/null
assert_equals "$(visible 1)" "early-bird	2 waiting · 1h · #1 needs a decision: first" "first row" \
  && assert_equals "$(visible 2)" "late      	1 waiting · 59s · #4 finished" "second row" \
  && assert_equals "$(visible 3)" "calm      	quiet" "quiet row" \
  && assert_equals "$(visible 4)" "gone      	no main session" "unstarted row" && pass
teardown_sandbox

it "matches what is typed against the repo alone"
setup_picker_sandbox
PICK=0 bash "$PICKER" </dev/null
args=$(tr '\n' ' ' < "$SANDBOX/fzf-args")
assert_contains "$args" "--with-nth 3,4 --nth 1" "fzf args" && pass
teardown_sandbox

it "jumps by main checkout through whiska when herdr has no workspace on it"
setup_picker_sandbox
PICK=3 bash "$PICKER" </dev/null
assert_equals "$(cat "$WHISKA_LOG")" "jump /p/calm" "whiska calls" && pass
teardown_sandbox

it "focuses the main checkout's own herdr workspace, not a worktree's on the same path"
setup_picker_sandbox
cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
[ "$*" = "workspace list" ] && cat <<'JSON'
{"result":{"workspaces":[
  {"workspace_id":"w9","worktree":{"checkout_path":"/p/early","is_linked_worktree":true}},
  {"workspace_id":"w2","worktree":{"checkout_path":"/p/early","is_linked_worktree":false}}
]}}
JSON
exit 0
MOCK
PICK=1 bash "$PICKER" </dev/null
assert_contains "$(cat "$MOCK_HERDR_LOG")" "workspace focus w2" "herdr calls" \
  && assert_equals "$(cat "$WHISKA_LOG")" "" "whiska calls" && pass
teardown_sandbox

it "does nothing when the popup is closed without a pick"
setup_picker_sandbox
PICK=0 bash "$PICKER" </dev/null
assert_equals "$?" "0" "exit code" \
  && assert_equals "$(cat "$WHISKA_LOG")" "" "whiska calls" \
  && assert_not_contains "$(cat "$MOCK_HERDR_LOG")" "focus" "herdr calls" && pass
teardown_sandbox

it "says why when the picked project has no main session, and does not jump"
setup_picker_sandbox
out=$(PICK=4 bash "$PICKER" </dev/null)
assert_contains "$out" "gone has no main session" "popup output" \
  && assert_equals "$(cat "$WHISKA_LOG")" "" "whiska calls" && pass
teardown_sandbox

it "keeps whiska's reason on screen when the jump fails"
setup_picker_sandbox
out=$(PICK=3 WHISKA_JUMP_EXIT=1 bash "$PICKER" </dev/null 2>&1)
assert_contains "$out" "press any key" "popup output" && pass
teardown_sandbox

it "puts whiska's error in the header when the list cannot be read"
setup_picker_sandbox
PICK=0 WHISKA_LIST_FAILS=1 bash "$PICKER" </dev/null
assert_contains "$(cat "$SANDBOX/fzf-args")" "whiska jump --list failed: whiska: boom" "fzf header" && pass
teardown_sandbox

it "is bound to prefix+space and linked by install"
assert_contains "$(grep -A3 'key = "prefix+space"' "$REPO_ROOT/herdr.toml")" \
  "~/.config/fzf_whiska/bin/whiska_picker.sh" "herdr.toml" \
  && assert_contains "$(cat "$REPO_ROOT/install.conf.yaml")" "path: fzf_whiska/*" "install.conf.yaml" \
  && pass
