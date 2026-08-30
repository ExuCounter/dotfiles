#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

PANELS="$HOME/Desktop/projects/prosapient/survey-panels"
DATATOOL="$HOME/Desktop/projects/prosapient/survey-datatool"
FACADE="$HOME/Desktop/projects/prosapient/survey-facade"
BUILDER="$HOME/Desktop/projects/prosapient/survey-builder"
DATATOOL_FE="$HOME/Desktop/projects/prosapient/survey-datatool/frontend"
FACADE_FE="$HOME/Desktop/projects/prosapient/survey-facade/frontend"

ws_create "surveys" "$PANELS"

tab_add  "datatool-ps" "$DATATOOL" 'cd backend && docker-compose up'
ws_split down "$DATATOOL" 'cd backend && pipenv --python 3.14.0 && pipenv run gunicorn main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:4000'

tab_add  "facade-ps" "$FACADE" 'docker-compose up'
ws_split right "$FACADE" 'cd backend && pipenv --python 3.14.0 && pipenv run python src/manage.py runserver 0.0.0.0:8000'
ws_split down  "$FACADE" 'cd frontend && npm run dev'

tab_add  "builder-ps" "$BUILDER" 'docker-compose up'
ws_split right "$BUILDER" 'pipenv --python 3.14.0 && pipenv run gunicorn main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8001'
ws_split down  "$BUILDER" 'psql -d survey_builder -U postgres -h 0.0.0.0 -p 5433'

tab_add  "datatool" "$DATATOOL_FE" 'vi'
tab_add  "facade"   "$FACADE_FE"   'vi'
ws_mark_focus_tab

ws_finalize
