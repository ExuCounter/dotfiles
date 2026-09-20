#!/usr/bin/env bash
# Durable wake-queue for herdr worktree watchers, modeled on firstmate's
# bin/fm-wake-lib.sh: a plain tab-separated append-only file, a shared lock so
# concurrent watchers never corrupt it or race on the same terminal, and a
# retry so a busy main pane doesn't silently lose a notification.
#
# The queue carries a POINTER, not a summary. A worktree turn's full assistant
# message is written to a relay file under $HERDR_WAKE_RELAY_DIR and the
# delivered notification names that path, because the main session cannot read
# the content back any other way: Claude Code runs on the terminal's alternate
# screen, and herdr's own docs are explicit that rows leaving the alternate
# screen never enter host scrollback, so no `pane read --lines N` can recover
# them. Pushing the text at notify time is the only thing that works.
set -u

QUEUE_FILE="${HERDR_WAKE_QUEUE:-$HOME/.herdr/worktree-wake-queue}"
LOCK_DIR="${HERDR_WAKE_LOCK:-/tmp/herdr-worktree-wake.lock}"
RELAY_DIR="${HERDR_WAKE_RELAY_DIR:-$HOME/.herdr/worktree-relay}"
RELAY_KEEP_DAYS="${HERDR_WAKE_RELAY_KEEP_DAYS:-7}"
RETRIES="${HERDR_WAKE_RETRIES:-20}"
RETRY_SLEEP="${HERDR_WAKE_RETRY_SLEEP:-3}"
mkdir -p "$(dirname "$QUEUE_FILE")"

log() { echo "herdr-worktree-wake: $*" >&2; }

lock_acquire() {
  local dir=${1:-$LOCK_DIR} tries=0 age
  while ! mkdir "$dir" 2>/dev/null; do
    if [ -d "$dir" ]; then
      age=$(( $(date +%s) - $(stat -f %m "$dir" 2>/dev/null || echo 0) ))
      [ "$age" -gt 30 ] && rmdir "$dir" 2>/dev/null
    fi
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
      log "lock timed out after 10s, proceeding without it"
      return 0
    fi
    sleep 0.1
  done
}

lock_release() {
  local dir=${1:-$LOCK_DIR}
  rmdir "$dir" 2>/dev/null
}

# --- relay files ------------------------------------------------------------

slugify() { printf '%s' "$1" | tr '/' '-' | sed 's|[^A-Za-z0-9._-]|-|g'; }

# Write the turn's complete message somewhere the main session can just `cat`.
# Returns the path on stdout.
relay_write() {
  local branch=$1 kind=$2 message=$3
  local dir file
  dir="$RELAY_DIR/$(slugify "$branch")"
  mkdir -p "$dir" || return 1
  file="$dir/$(date +%s)-$kind-$$-${RANDOM}.md"
  printf '%s\n' "$message" > "$file" || return 1
  printf '%s' "$file"
}

# Bounded by age, not count: these are a few KB each, and a week is well past
# any window where an old decision point is still worth reading.
relay_prune() {
  [ -d "$RELAY_DIR" ] || return 0
  find "$RELAY_DIR" -type f -name '*.md' -mtime "+$RELAY_KEEP_DAYS" -delete 2>/dev/null
  find "$RELAY_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null
  return 0
}

# --- queue ------------------------------------------------------------------

# Fields: epoch\tbranch\tpane_id\tmain_pane_id\tkind\tdetail\trelay_file
# detail is a one-line marker; tabs and newlines are stripped so a line always
# round-trips through the tab-separated format.
oneline() { printf '%s' "$1" | tr '\t\n' '  ' | sed 's/  */ /g; s/^ //; s/ $//'; }

queue_append() {
  local branch=$1 pane_id=$2 main_pane_id=$3 kind=$4 detail=$5 relay=$6
  lock_acquire
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "$branch" "$pane_id" "$main_pane_id" "$kind" "$(oneline "$detail")" "$relay" \
    >> "$QUEUE_FILE"
  lock_release
}

# All queued lines for a branch, oldest first. Every entry points at its own
# relay file, so none of them is redundant with any other — an older entry is
# not superseded by a newer one, it's a decision point you haven't seen yet.
queue_entries_for_branch() {
  local branch=$1
  awk -F'\t' -v b="$branch" '$2 == b' "$QUEUE_FILE" 2>/dev/null
}

# Drop exactly one line (the first exact match), leaving everything else —
# including other entries for the same branch — untouched.
queue_remove_line() {
  local line=$1
  lock_acquire
  if [ -f "$QUEUE_FILE" ]; then
    awk -v target="$line" '
      !done_removal && $0 == target { done_removal = 1; next }
      { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" 2>/dev/null && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
  fi
  lock_release
}

# --- delivery ---------------------------------------------------------------

# One self-contained line. Multi-line text is deliberately avoided: `herdr
# agent prompt` submits its argument into a TUI prompt box, where an embedded
# newline would submit early and split the notification in half.
compose_text() {
  local branch=$1 pane_id=$2 detail=$3 relay=$4
  local text="[auto] worktree $branch (pane $pane_id): $detail"
  if [ -n "$relay" ] && [ -f "$relay" ]; then
    text="$text | full message: $relay — read that file for the complete content; the worktree pane's scrollback cannot be read back (Claude runs on the terminal's alternate screen)"
  fi
  text="$text | reply with: herdr agent prompt $pane_id \"<your answer>\""
  printf '%s' "$text"
}

deliver_one() {
  local main_pane_id=$1 text=$2 tries=0
  while [ "$tries" -lt "$RETRIES" ]; do
    if herdr agent prompt "$main_pane_id" "$text" >/dev/null 2>&1; then
      return 0
    fi
    tries=$((tries + 1))
    [ "$tries" -lt "$RETRIES" ] && sleep "$RETRY_SLEEP"
  done
  return 1
}

title_for_kind() {
  case "$1" in
    needs-decision) echo "Worktree needs a decision" ;;
    done)           echo "Worktree finished" ;;
    exited)         echo "Worktree session exited" ;;
    stopped)        echo "Worktree stopped" ;;
    stale)          echo "Worktree may be wedged" ;;
    *)              echo "Worktree update" ;;
  esac
}

deliver_branch() {
  local branch=$1
  local entries entry pane_id main_pane_id kind detail relay text
  local delivered_any=0 stalled=0 last_kind=""
  entries=$(queue_entries_for_branch "$branch")
  [ -n "$entries" ] || return 0

  # Oldest first, and stop at the first failure so ordering is preserved on the
  # next attempt rather than delivering a later round before an earlier one.
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    [ "$stalled" -eq 1 ] && break
    IFS=$'\t' read -r _ _ pane_id main_pane_id kind detail relay <<< "$entry"
    text="$(compose_text "$branch" "$pane_id" "$detail" "${relay:-}")"
    if deliver_one "$main_pane_id" "$text"; then
      queue_remove_line "$entry"
      delivered_any=1
      last_kind="$kind"
    else
      stalled=1
    fi
  done <<< "$entries"

  if [ "$delivered_any" -eq 1 ]; then
    herdr notification show "$(title_for_kind "$last_kind")" --body "$branch" --sound request >/dev/null 2>&1
  fi
  if [ "$stalled" -eq 1 ]; then
    log "could not deliver notification for $branch after retries; left queued for a later attempt"
  fi
}

flush_all() {
  [ -s "$QUEUE_FILE" ] || return 0
  local branches
  branches=$(awk -F'\t' '{print $2}' "$QUEUE_FILE" 2>/dev/null | sort -u)
  while IFS= read -r b; do
    [ -n "$b" ] && deliver_branch "$b"
  done <<< "$branches"
}

# --- commands ---------------------------------------------------------------

# Called from the global Stop hook (claude/hooks/herdr-worktree-notify.sh) on
# every completed turn in a worktree session. Reads the assistant's complete
# last message from stdin; if it carries a [worktree-status: ...] marker, the
# WHOLE message is persisted to a relay file and the queue entry points at it.
# A turn with no marker (ordinary mid-task work) is a silent no-op.
#
# Persisting the whole message is the point. An earlier version kept only the
# marker line, which meant a grilling round that ended "5 questions ready, see
# above" reached the main session as exactly that — with "above" referring to a
# pane whose scrollback is unreadable. The main session then had to ask the
# worktree to repeat itself, question by question.
#
# This also replaced an even earlier design where spawn-worktree /
# send-to-worktree each launched a one-shot background poller and had to
# remember to relaunch one after every reply. That was model-driven and
# fragile. A hook is harness-enforced instead — it fires on every turn
# regardless of what any model remembers to do.
notify_cmd() {
  local branch=$1 pane_id=$2 main_pane_id=$3
  local message marker kind relay
  message=$(cat)
  marker=$(printf '%s' "$message" | grep -oE '\[worktree-status:.*$' | tail -1)
  [ -n "$marker" ] || return 0

  case "$marker" in
    *needs-decision*) kind="needs-decision" ;;
    *done*)           kind="done" ;;
    *)                return 0 ;;  # malformed marker, nothing we recognize
  esac

  relay_prune
  relay="$(relay_write "$branch" "$kind" "$message")" || relay=""

  queue_append "$branch" "$pane_id" "$main_pane_id" "$kind" "$marker" "$relay"
  flush_all
}

# A new session starting is exactly the moment a previously-unreachable main
# pane (agent_not_found while you'd quit Claude, or it was mid-restart)
# becomes reachable again. Retry anything still stuck in the queue now,
# instead of waiting for some future turn to eventually flush it.
resume_cmd() {
  flush_all
  [ -s "$QUEUE_FILE" ] && echo "Some notifications are still stuck; run 'status' for detail." || echo "Nothing was stuck."
}

status_cmd() {
  # Pure read, no delivery attempt — a status check must be instant, even if
  # the main pane is currently unreachable and would otherwise retry for a
  # while. Delivery only happens from `notify` (on a worktree turn) or
  # `resume` (on session start).
  if [ ! -s "$QUEUE_FILE" ]; then
    echo "No pending worktree notifications."
    return 0
  fi
  echo "Pending worktree notifications (delivery failed, will retry on the next turn or session start):"
  while IFS=$'\t' read -r epoch branch pane_id main_pane_id kind detail relay; do
    ts=$(date -r "$epoch" "+%H:%M:%S" 2>/dev/null || echo "$epoch")
    echo "  $branch (pane $pane_id): [$kind] $detail — queued $ts"
    [ -n "${relay:-}" ] && echo "      full message: $relay"
  done < "$QUEUE_FILE"
}

cmd=${1:-}
shift || true
case "$cmd" in
  notify) notify_cmd "$@" ;;
  status) status_cmd "$@" ;;
  resume) resume_cmd "$@" ;;
  *)
    echo "usage: herdr-worktree-wake.sh notify <branch> <pane-id> <main-pane-id>   (message on stdin)" >&2
    echo "       herdr-worktree-wake.sh status" >&2
    echo "       herdr-worktree-wake.sh resume" >&2
    exit 2
    ;;
esac
