#!/usr/bin/env bash
# Shared helpers for herdr layout scripts (teamocil replacement).
#
# Usage:
#   source "$(dirname "$0")/lib.sh"
#   ws_create "myproject" "~/path/to/root"
#   ws_run   "iex -S mix phx.server"
#   ws_split right "~/path/to/root" "pnpm start"
#   tab_add  "editor" "~/path/to/root" "vi"
#   ws_mark_focus_tab   # optional: focus this tab at the end
#   ws_finalize

set -euo pipefail

_WS_ID=""
_TAB_ID=""
_PANE_ID=""
_FOCUS_TAB_ID=""

_jq() { jq -r "$1"; }

ws_create() {
  local label="$1" cwd="${2:-$HOME}"
  local resp
  resp=$(herdr workspace create --label "$label" --cwd "$cwd" --focus)
  _WS_ID=$(printf '%s' "$resp" | _jq '.result.workspace.workspace_id')
  _TAB_ID=$(printf '%s' "$resp" | _jq '.result.tab.tab_id')
  _PANE_ID=$(printf '%s' "$resp" | _jq '.result.root_pane.pane_id')
  _FOCUS_TAB_ID="$_TAB_ID"
}

ws_run() {
  local cmd="$1"
  [ -z "$cmd" ] && return 0
  herdr pane run "$_PANE_ID" "$cmd" >/dev/null
}

# ws_split <right|down> <cwd> [command]
ws_split() {
  local direction="$1" cwd="$2" cmd="${3:-}"
  local resp
  resp=$(herdr pane split --pane "$_PANE_ID" \
    --direction "$direction" --cwd "$cwd" --no-focus)
  _PANE_ID=$(printf '%s' "$resp" | _jq '.result.pane.pane_id')
  ws_run "$cmd"
}

# tab_add <label> <cwd> [command]
tab_add() {
  local label="$1" cwd="$2" cmd="${3:-}"
  local resp
  resp=$(herdr tab create --workspace "$_WS_ID" \
    --label "$label" --cwd "$cwd" --no-focus)
  _TAB_ID=$(printf '%s' "$resp" | _jq '.result.tab.tab_id')
  _PANE_ID=$(printf '%s' "$resp" | _jq '.result.root_pane.pane_id')
  ws_run "$cmd"
}

# Mark the current tab as the one to focus at the end (teamocil `focus: true`).
ws_mark_focus_tab() { _FOCUS_TAB_ID="$_TAB_ID"; }

ws_finalize() {
  [ -n "$_FOCUS_TAB_ID" ] || return 0
  herdr tab focus "$_FOCUS_TAB_ID" >/dev/null 2>&1 || true
}
