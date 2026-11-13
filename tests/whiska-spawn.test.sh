# `whiska spawn` from a terminal of the Herdr app starts a mouse as a space there;
# anything else goes to the Elixir whiska. herdr-app, hc and the Elixir whiska are
# stubbed and log their argv; the repo is a throwaway git repo Claude trusts.

WHISKA="$REPO_ROOT/bin/whiska"

setup_spawn_sandbox() {
  setup_sandbox
  # git answers with the real path; /var is /private/var on macOS.
  SANDBOX=$(cd "$SANDBOX" && pwd -P)
  export HC_TERMINAL_ID=t1
  export WHISKA_SRC="$SANDBOX/whiska-src"
  mkdir -p "$WHISKA_SRC/priv"
  printf 'You are a mouse.\n' > "$WHISKA_SRC/priv/brief.md"

  REPO="$SANDBOX/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' "$SANDBOX" > "$HOME/.claude.json"

  export CALLS="$SANDBOX/calls.log"
  : > "$CALLS"
  cat > "$MOCK_BIN/herdr-app" <<'MOCK'
#!/usr/bin/env bash
for a in "$@"; do printf 'herdr-app %s\n' "$a" >> "$CALLS"; done
[ -n "${HERDR_APP_FAIL:-}" ] && { echo "no window" >&2; exit 1; }
echo '{"space":"sp1","tab":"tb1","terminal":"t42"}'
MOCK
  cat > "$MOCK_BIN/hc" <<'MOCK'
#!/usr/bin/env bash
printf 'hc %s\n' "$*" >> "$CALLS"
MOCK
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/whiska" <<'MOCK'
#!/usr/bin/env bash
printf 'elixir %s\n' "$*" >> "$CALLS"
MOCK
  chmod +x "$MOCK_BIN/herdr-app" "$MOCK_BIN/hc" "$HOME/.local/bin/whiska"
}

spawn() { (cd "$REPO" && "$WHISKA" spawn "$@" 2>&1); }

# The JSON object space.new was given, one field per call.
space_new() { grep '^herdr-app {' "$CALLS" | sed 's/^herdr-app //' | python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }

it "forwards anything but spawn to the Elixir whiska"
setup_spawn_sandbox
"$WHISKA" doctor --fix
assert_equals "$(cat "$CALLS")" "elixir doctor --fix" "calls" && pass
teardown_sandbox

it "forwards spawn outside the Herdr app"
setup_spawn_sandbox
unset HC_TERMINAL_ID
"$WHISKA" spawn fix/x "task"
assert_equals "$(cat "$CALLS")" "elixir spawn fix/x task" "calls" && pass
teardown_sandbox

it "makes the worktree off the checkout's branch and hides worktrees/"
setup_spawn_sandbox
out=$(spawn fix/login "fix it")
assert_contains "$out" "Spawned fix/login in worktrees/fix/login" &&
  assert_equals "$(git -C "$REPO/worktrees/fix/login" symbolic-ref --short HEAD)" "fix/login" "worktree branch" &&
  assert_equals "$(git -C "$REPO" merge-base main fix/login)" "$(git -C "$REPO" rev-parse main)" "fork point" &&
  assert_contains "$(cat "$REPO/.git/info/exclude")" "/worktrees/" "exclude" && pass
teardown_sandbox

it "opens a space with Claude, the brief and the task, keeping quotes and newlines"
setup_spawn_sandbox
spawn fix/login 'say "hi"
then stop' -- --model sonnet >/dev/null
brief="$HOME/.whiska/brief.md"
assert_equals "$(cat "$brief")" "You are a mouse." "brief" &&
  assert_equals "$(space_new "['name']")" "fix/login" "name" &&
  assert_equals "$(space_new "['folder']")" "$REPO/worktrees/fix/login" "folder" &&
  assert_equals "$(space_new "['argv']")" "['claude', '--name', 'fix/login', '--dangerously-skip-permissions', '--disallowedTools', 'AskUserQuestion', '--append-system-prompt-file', '$brief', '--model', 'sonnet']" "argv" &&
  assert_equals "$(space_new "['task']")" 'Your branch fix/login was cut from main.

Your task:

say "hi"
then stop' "task" && pass
teardown_sandbox

it "labels the mouse's terminal"
setup_spawn_sandbox
spawn fix/login "fix it" >/dev/null
assert_contains "$(cat "$CALLS")" "hc label t42 whiska.branch=fix/login whiska.base=main whiska.main=$REPO" && pass
teardown_sandbox

it "spawns off the main checkout from inside a worktree"
setup_spawn_sandbox
spawn feat/a "a" >/dev/null
: > "$CALLS"
(cd "$REPO/worktrees/feat/a" && "$WHISKA" spawn feat/b "b" >/dev/null 2>&1)
assert_equals "$(space_new "['folder']")" "$REPO/worktrees/feat/b" "folder" &&
  assert_contains "$(space_new "['task']")" "cut from main." "task" && pass
teardown_sandbox

it "refuses a branch name herdr would not take"
setup_spawn_sandbox
out=$(spawn Fix/Login "x")
assert_contains "$out" "is not a branch name spawn takes" &&
  assert_no_file "$REPO/worktrees" && assert_equals "$(cat "$CALLS")" "" "calls" && pass
teardown_sandbox

it "refuses a branch name longer than 32 characters"
setup_spawn_sandbox
out=$(spawn "feat/$(printf 'a%.0s' {1..30})" "x")
assert_contains "$out" "longer than the 32 characters" && pass
teardown_sandbox

it "refuses a branch that already exists"
setup_spawn_sandbox
git -C "$REPO" branch fix/old
out=$(spawn fix/old "x")
assert_contains "$out" "fix/old already exists" && pass
teardown_sandbox

it "refuses an empty task and a control character"
setup_spawn_sandbox
out=$(spawn fix/a "  ")
out2=$(spawn fix/a "$(printf 'a\033b')")
assert_contains "$out" "the task is empty" &&
  assert_contains "$out2" "control character" && assert_no_file "$REPO/worktrees" && pass
teardown_sandbox

it "refuses a repo Claude has not trusted"
setup_spawn_sandbox
echo '{"projects":{}}' > "$HOME/.claude.json"
out=$(spawn fix/a "x")
assert_contains "$out" "Claude has not been trusted in $REPO" && pass
teardown_sandbox

it "refuses usage without a task"
setup_spawn_sandbox
out=$(spawn fix/a)
assert_contains "$out" "expected whiska spawn <branch> <task> [-- <claude args>]." && pass
teardown_sandbox

it "clones ignored deps when the lock file matches, skips them when it differs"
setup_spawn_sandbox
printf 'deps\n_build\n' > "$REPO/.gitignore"
touch "$REPO/mix.exs"; echo lock1 > "$REPO/mix.lock"
git -C "$REPO" add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m mix
mkdir -p "$REPO/deps/jason" "$REPO/_build"; touch "$REPO/deps/jason/mix.exs"
out=$(spawn feat/a "a")
echo lock2 > "$REPO/mix.lock"
out2=$(spawn feat/b "b")
assert_file_exists "$REPO/worktrees/feat/a/deps/jason/mix.exs" &&
  assert_contains "$out" "cloned deps, _build" &&
  assert_no_file "$REPO/worktrees/feat/b/deps" &&
  assert_contains "$out2" "deps, _build not cloned: mix.lock differs from the main checkout's" && pass
teardown_sandbox

it "names the worktree when the app does not start the mouse"
setup_spawn_sandbox
out=$(HERDR_APP_FAIL=1 spawn fix/a "x"; echo "exit=$?")
assert_contains "$out" "fix/a's worktree is at $REPO/worktrees/fix/a, but its mouse did not start" &&
  assert_contains "$out" "no window" && assert_contains "$out" "git worktree remove" &&
  assert_contains "$out" "exit=1" && pass
teardown_sandbox
