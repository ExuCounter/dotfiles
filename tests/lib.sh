# Shared helpers for tests/*.test.sh. Sourced by the runner, never run directly.
# Each test file gets a throwaway HOME, a throwaway PATH entry holding a mock
# `herdr`, and its own queue/relay directories, so tests never touch the real
# ~/.herdr or the real herdr server.

set -u

TESTS_RUN=0
TESTS_FAILED=0
FAILED_NAMES=()

_current_test=""

# --- assertions -------------------------------------------------------------

fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_NAMES+=("$_current_test")
  printf '  \033[31mFAIL\033[0m %s\n' "$_current_test"
  printf '       %s\n' "$*"
}

pass() {
  printf '  \033[32mok\033[0m   %s\n' "$_current_test"
}

it() {
  _current_test="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  _test_failed=0
}

assert_contains() {
  local haystack=$1 needle=$2 what=${3:-output}
  case "$haystack" in
    *"$needle"*) return 0 ;;
    *) fail "expected $what to contain: $needle
       actual: $haystack"; return 1 ;;
  esac
}

assert_not_contains() {
  local haystack=$1 needle=$2 what=${3:-output}
  case "$haystack" in
    *"$needle"*) fail "expected $what NOT to contain: $needle
       actual: $haystack"; return 1 ;;
    *) return 0 ;;
  esac
}

assert_equals() {
  local actual=$1 expected=$2 what=${3:-value}
  if [ "$actual" != "$expected" ]; then
    fail "expected $what to be: $expected
       actual: $actual"
    return 1
  fi
}

assert_file_exists() {
  [ -f "$1" ] || { fail "expected file to exist: $1"; return 1; }
}

assert_no_file() {
  [ ! -e "$1" ] || { fail "expected no file at: $1"; return 1; }
}

# --- sandbox ----------------------------------------------------------------

# Fresh sandbox per test: temp HOME and a mock herdr that logs every invocation
# and can be told to fail a fixed number of times.
setup_sandbox() {
  SANDBOX="$(mktemp -d)"
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME/.herdr"
  MOCK_BIN="$SANDBOX/bin"
  mkdir -p "$MOCK_BIN"
  export MOCK_HERDR_LOG="$SANDBOX/herdr-calls.log"
  : > "$MOCK_HERDR_LOG"
  export MOCK_HERDR_FAIL_FILE="$SANDBOX/herdr-fail-count"

  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
# Mock herdr: log the full argv (one invocation per line, NUL-free) and
# optionally fail the first N `agent prompt` calls.
printf '%s\n' "$*" >> "$MOCK_HERDR_LOG"
if [ "${1:-}" = "agent" ] && [ "${2:-}" = "prompt" ] && [ -s "${MOCK_HERDR_FAIL_FILE:-/nonexistent}" ]; then
  n=$(cat "$MOCK_HERDR_FAIL_FILE")
  if [ "$n" -gt 0 ] 2>/dev/null; then
    echo $((n - 1)) > "$MOCK_HERDR_FAIL_FILE"
    exit 1
  fi
fi
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr"
  export PATH="$MOCK_BIN:$PATH"
}

teardown_sandbox() {
  [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}

# Make the next N `herdr agent prompt` calls fail.
herdr_fail_next() { echo "$1" > "$MOCK_HERDR_FAIL_FILE"; }

# Every `herdr agent prompt` invocation, one per line.
herdr_prompt_calls() { grep '^agent prompt ' "$MOCK_HERDR_LOG" 2>/dev/null || true; }
herdr_prompt_count() { herdr_prompt_calls | grep -c . || true; }

