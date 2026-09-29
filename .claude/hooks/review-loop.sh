#!/usr/bin/env bash
# This repo's review loop: a Claude Code Stop hook that will not let a turn
# end on `[worktree-status: done]` until the checks pass and the diff has been
# read back against the repo's own specs and decisions (ADR-0042).
#
# The repo owns this file. `whiska init` writes it once if it is missing, then
# leaves it alone for ever — including on `whiska update`, so an edited CHECK
# is never clobbered. Whiska never reads what is in here.
#
# ---------------------------------------------------------------------------
# Edit these three. They are the whole configuration.

# What "green" means in this repo. Any shell command; non-zero is a failure.
CHECK='true'

# Seconds one run of CHECK gets before it is killed. A Stop hook that hangs
# hangs the pane, so this is a ceiling, not a suggestion.
TIMEOUT=600

# The one review pass, asked for once per turn once the checks are green.
# Fixed words on purpose: there is no judgment in the hook (ADR-0042).
REVIEW='Checks pass. One review pass before you finish.

Read your own diff on this branch back — `git diff $(git merge-base HEAD main)` —
against specs/ and docs/adr/. Fix anything that contradicts a recorded decision
or the spec, and say in one line what you found, or that you found nothing.

Then finish the turn as you meant to, marker line included.'
# ---------------------------------------------------------------------------

set -uo pipefail

payload="$(cat)"

# The message can be anything at all, so there is no honest way to pull it out
# of the JSON without jq. Fail open, loudly, the way the whiska shim does when
# its binary is missing: a hook that cannot read its input must not wedge the
# session.
if ! command -v jq >/dev/null 2>&1; then
  echo "review-loop: jq not found - letting the stop through" >&2
  exit 0
fi

read_field() { printf '%s' "$payload" | jq -r "$1" 2>/dev/null; }

if ! message="$(read_field '.last_assistant_message // ""')"; then
  echo "review-loop: unreadable Stop payload - letting the stop through" >&2
  exit 0
fi
active="$(read_field '.stop_hook_active // false')"
session="$(read_field '.session_id // "unknown"' | tr -c 'A-Za-z0-9_.-' '_')"

# Only a turn claiming to be finished is this hook's business. A
# needs-decision turn is waiting on the person, and an unmarked one is already
# something the owl reports (ADR-0009) — blocking either would talk over them.
# The marker is the last line, so that is what is matched, not a substring
# somewhere in the middle of a paragraph about markers.
last_line="$(printf '%s\n' "$message" | sed -e 's/[[:space:]]*$//' -e '/^$/d' | tail -1)"
if [ "$last_line" != "[worktree-status: done]" ]; then
  exit 0
fi

# Two facts survive between the stops of one turn: how many times in a row the
# checks have failed, and whether the review pass has been asked for. Keyed by
# session so two panes never read each other's.
state_dir="${TMPDIR:-/tmp}/review-loop"
mkdir -p "$state_dir" 2>/dev/null
state="$state_dir/$session"

# stop_hook_active is false on exactly the first Stop of a turn, which is
# where both reset.
if [ "$active" != "true" ]; then
  printf '0\nno\n' > "$state"
fi
fails="$(sed -n 1p "$state" 2>/dev/null)"
reviewed="$(sed -n 2p "$state" 2>/dev/null)"
[ -n "$fails" ] || fails=0
[ -n "$reviewed" ] || reviewed=no

block() {
  jq -n --arg reason "$1" '{decision: "block", reason: $reason}'
  exit 0
}

# Run CHECK with a watchdog rather than `timeout`, which is not on a stock
# macOS. stdin is already spent, and a check must never read from the pane.
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

bash -c "$CHECK" > "$output_file" 2>&1 < /dev/null &
check_pid=$!
( sleep "$TIMEOUT"; kill -TERM "$check_pid" ) >/dev/null 2>&1 &
watchdog_pid=$!
wait "$check_pid"
status=$?
kill -TERM "$watchdog_pid" >/dev/null 2>&1
wait "$watchdog_pid" 2>/dev/null

if [ "$status" -ne 0 ]; then
  fails=$((fails + 1))
  printf '%s\n%s\n' "$fails" "$reviewed" > "$state"

  # Bounded, the same shape ADR-0011 gives a failing push: two blocks in a row
  # and then the stop goes through, so a check that can never pass reaches the
  # person through the doorstep instead of looping until someone notices.
  if [ "$fails" -gt 2 ]; then
    echo "review-loop: checks failed $fails times in a row - letting the stop through" >&2
    exit 0
  fi

  if [ "$status" -ge 128 ]; then
    detail="It timed out after ${TIMEOUT}s and was killed."
  else
    detail="It exited $status."
  fi

  block "The checks are not green, so this turn is not done.

$detail Command: $CHECK

$(tail -n 200 "$output_file")

Fix it and finish again. After $((3 - fails)) more failing attempt(s) this stop
goes through anyway and the failure reaches the person instead."
fi

# Green. One guaranteed review pass per turn, then out of the way.
printf '0\nyes\n' > "$state"
if [ "$reviewed" != "yes" ]; then
  block "$REVIEW"
fi
exit 0
