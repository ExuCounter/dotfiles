#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

ROOT="$HOME/Desktop/projects/own/build"

ws_create "build" "$ROOT"
ws_run   'vi notes.txt'

tab_add  "sql"    "$ROOT" 'vi sql.sql'
tab_add  "elixir" "$ROOT" 'vi elixir.ex'

ws_finalize
