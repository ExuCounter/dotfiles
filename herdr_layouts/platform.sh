#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

ROOT="$HOME/Desktop/projects/prosapient/platform"

ws_create "platform" "$ROOT"
ws_run   'OBAN_DISABLED=1 iex -S mix phx.server'
ws_split right "$ROOT" 'cd frontend && pnpm start'

tab_add  "backend" "$ROOT" 'uname'
ws_mark_focus_tab

ws_finalize
