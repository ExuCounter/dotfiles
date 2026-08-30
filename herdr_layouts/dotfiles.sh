#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

ROOT="$HOME/Desktop/projects/dotfiles"

ws_create "dotfiles" "$ROOT"
ws_run   'vi'
ws_mark_focus_tab

ws_finalize
