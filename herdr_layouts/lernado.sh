#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

ROOT="$HOME/Desktop/projects/own/lernado"
BE="$HOME/Desktop/projects/own/lernado/backend"
FE="$HOME/Desktop/projects/own/lernado/frontend"

ws_create "lernado" "$ROOT"
ws_run   'cd backend && iex -S mix phx.server'
ws_split right "$ROOT" 'cd frontend && npm run dev'
ws_split down  "$ROOT" 'echo "Hello, World!"'
ws_split down  "$ROOT" 'echo "Hello, World!"'

tab_add  "backend"  "$BE" 'vi'
tab_add  "frontend" "$FE" 'vi'

ws_finalize
