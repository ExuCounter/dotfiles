#!/usr/bin/env bash
# Durable wake-queue for herdr worktree watchers, modeled on firstmate's
# bin/fm-wake-lib.sh: a plain tab-separated append-only file, a shared lock so
# concurrent watchers never corrupt it or race on the same terminal, and a
# retry so a busy main pane doesn't silently lose a notification.
set -u

QUEUE_FILE="${HERDR_WAKE_QUEUE:-$HOME/.herdr/worktree-wake-queue}"
LOCK_DIR="${HERDR_WAKE_LOCK:-/tmp/herdr-worktree-wake.lock}"
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

# Fields: epoch\tbranch\tpane_id\tmain_pane_id\tkind\tdetail
queue_append() {
  local branch=$1 pane_id=$2 main_pane_id=$3 kind=$4 detail=$5
  lock_acquire
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$branch" "$pane_id" "$main_pane_id" "$kind" "$detail" >> "$QUEUE_FILE"
  lock_release
}

queue_clear_branch() {
  local branch=$1
  lock_acquire
  if [ -f "$QUEUE_FILE" ]; then
    awk -F'\t' -v b="$branch" '$2 != b' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" 2>/dev/null
    mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
  fi
  lock_release
}

# Most recent queued line for a branch (a branch can be queued more than once
# if earlier delivery attempts failed; only the latest status matters).
queue_latest_for_branch() {
  local branch=$1
  awk -F'\t' -v b="$branch" '$2 == b { line = $0 } END { if (line) print line }' "$QUEUE_FILE" 2>/dev/null
}

deliver_branch() {
  local branch=$1
  local entry pane_id main_pane_id kind detail
  entry=$(queue_latest_for_branch "$branch")
  [ -n "$entry" ] || return 0
  IFS=$'\t' read -r _ _ pane_id main_pane_id kind detail <<< "$entry"

  local title
  case "$kind" in
    needs-decision) title="Worktree needs a decision" ;;
    done)           title="Worktree finished" ;;
    exited)         title="Worktree session exited" ;;
    stopped)        title="Worktree stopped" ;;
    stale)          title="Worktree may be wedged" ;;
    *)              title="Worktree update" ;;
  esac

  local tries=0 delivered=1
  while [ "$tries" -lt 20 ]; do
    if herdr agent prompt "$main_pane_id" "[auto] worktree $branch (pane $pane_id): $detail" >/dev/null 2>&1; then
      delivered=0
      break
    fi
    tries=$((tries + 1))
    sleep 3
  done

  if [ "$delivered" -eq 0 ]; then
    herdr notification show "$title" --body "$branch" --sound request >/dev/null 2>&1
    queue_clear_branch "$branch"
  else
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

# Called from the global Stop hook (claude/hooks/herdr-worktree-notify.sh) on
# every completed turn in a worktree session. Reads the assistant's last
# message from stdin, checks for a [worktree-status: ...] marker, and queues +
# delivers if found. A turn with no marker (ordinary mid-task work) is a
# silent no-op — this fires on every turn, not just final ones.
#
# This replaced an earlier design where spawn-worktree/send-to-worktree each
# launched a one-shot background poller and had to remember to relaunch one
# after every reply. That was model-driven and fragile: a coordinating
# session that forgot the relaunch step silently broke all future rounds for
# that worktree. A hook is harness-enforced instead — it fires on every turn
# regardless of what any model remembers to do.
notify_cmd() {
  local branch=$1 pane_id=$2 main_pane_id=$3
  local message marker kind detail
  message=$(cat)
  marker=$(printf '%s' "$message" | grep -oE '\[worktree-status:.*$' | tail -1)
  [ -n "$marker" ] || return 0

  case "$marker" in
    *needs-decision*) kind="needs-decision"; detail="$marker" ;;
    *done*)           kind="done"; detail="finished" ;;
    *)                return 0 ;;  # malformed marker, nothing we recognize
  esac

  queue_append "$branch" "$pane_id" "$main_pane_id" "$kind" "$detail"
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
  while IFS=$'\t' read -r epoch branch pane_id main_pane_id kind detail; do
    ts=$(date -r "$epoch" "+%H:%M:%S" 2>/dev/null || echo "$epoch")
    echo "  $branch (pane $pane_id): [$kind] $detail — queued $ts"
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
