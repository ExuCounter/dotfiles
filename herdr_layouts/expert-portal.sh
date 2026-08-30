#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

BE="$HOME/Desktop/projects/prosapient/expert-portal"
FE="$HOME/Desktop/projects/prosapient/expert-portal/frontend"

ws_create "expert-portal" "$BE"
ws_run   'cd backend && source bin/activate && python src/manage.py runserver'
ws_split right "$BE" 'cd frontend && pnpm start'
ws_split down  "$BE" 'echo "Hello"'

tab_add  "frontend" "$FE" 'vi'
ws_mark_focus_tab

ws_finalize
