#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

ROOT="$HOME/Desktop/projects/own/blog"

ws_create "blog" "$ROOT"
ws_run   'iex -S mix phx.server'
ws_split down "$ROOT" 'echo "Hello, World!"'

tab_add  "backend" "$ROOT" 'vi'

ws_finalize
