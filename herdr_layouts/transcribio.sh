#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

ROOT="$HOME/Desktop/projects/prosapient/transcribio"
BE="$HOME/Desktop/projects/prosapient/transcribio/backend"
FE="$HOME/Desktop/projects/prosapient/transcribio/frontend"

ws_create "transcribio" "$ROOT"
ws_run   'docker-compose up -d db redis backend'
ws_split right "$ROOT" 'sleep 5 && docker-compose run --rm backend python /app/src/manage.py rundramatiq'
ws_split down  "$ROOT" 'sleep 5 && docker-compose run --rm --service-ports backend python src/manage.py runserver 0.0.0.0:8000'
ws_split down  "$ROOT" 'cd frontend && pnpm start'

tab_add  "backend"  "$BE" 'vi'
ws_mark_focus_tab
tab_add  "frontend" "$FE" 'vi'
ws_mark_focus_tab

ws_finalize
