#!/usr/bin/env bash
# Plain bash test runner. No dependencies — every tests/*.test.sh is sourced
# with tests/lib.sh already loaded, runs against a throwaway HOME and a mock
# `herdr` on PATH, and reports a pass/fail tally.
#
# Usage:  ./tests/run.sh            run everything
#         ./tests/run.sh wake       run only tests/*wake*.test.sh
#
# Deliberately NOT wired into ./install — installing dotfiles shouldn't run a
# test suite.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
filter="${1:-}"

total_run=0
total_failed=0
failed_files=()

shopt -s nullglob
for f in "$REPO_ROOT"/tests/*.test.sh; do
  [ -n "$filter" ] && case "$(basename "$f")" in *"$filter"*) ;; *) continue ;; esac
  printf '\n\033[1m%s\033[0m\n' "$(basename "$f")"
  # Each file runs in its own subshell so a crash in one can't take out the rest.
  out="$(
    set +e
    # shellcheck source=/dev/null
    source "$REPO_ROOT/tests/lib.sh"
    # shellcheck source=/dev/null
    source "$f"
    echo "__TALLY__ $TESTS_RUN $TESTS_FAILED"
  )"
  tally="$(printf '%s\n' "$out" | grep '^__TALLY__ ' | tail -1)"
  printf '%s\n' "$out" | grep -v '^__TALLY__ '
  if [ -n "$tally" ]; then
    r=$(echo "$tally" | awk '{print $2}')
    fl=$(echo "$tally" | awk '{print $3}')
  else
    r=0; fl=1
    printf '  \033[31mFAIL\033[0m test file crashed before reporting\n'
  fi
  total_run=$((total_run + r))
  total_failed=$((total_failed + fl))
  [ "$fl" -gt 0 ] && failed_files+=("$(basename "$f")")
done

printf '\n'
if [ "$total_failed" -eq 0 ]; then
  printf '\033[32m%d passed\033[0m\n' "$total_run"
  exit 0
fi
printf '\033[31m%d failed\033[0m, %d run  (%s)\n' "$total_failed" "$total_run" "${failed_files[*]}"
exit 1
