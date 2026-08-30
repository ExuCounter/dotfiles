#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

OWN="$HOME/Desktop/projects/own"
SQL="$HOME/Desktop/projects/own/learning_sql"

ws_create "learning" "$OWN"
ws_run   'vi'

tab_add  "sql"     "$SQL" 'vi'
tab_add  "project" "$OWN" 'ls'
ws_mark_focus_tab

ws_finalize
