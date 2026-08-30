#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

ROOT="$HOME/Desktop/projects/poker"

ws_create "poker" "$ROOT"
ws_run   'iex -S mix phx.server'

tab_add  "backend" "$ROOT" "echo 'hi'"

ws_finalize
