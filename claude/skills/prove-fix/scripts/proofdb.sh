#!/usr/bin/env bash
# The current branch's proof database, for an app that reads DATABASE_NAME, whatever the environment names.
#   proofdb.sh name [<branch>]    prints proof_<slug>
#   proofdb.sh drop               drops it, closing its connections
#   proofdb.sh psql [<arg>...]    psql connected to it
#   proofdb.sh run <command>...   runs the command with DATABASE_NAME set to it
# Connects with the app's DATABASE_* settings and their defaults.
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

name() {
  local slug
  slug="$("$SCRIPTS/slug.sh" "$@")" || exit $?
  printf 'proof_%s\n' "$slug"
}

connect() {
  export PGHOST="${DATABASE_SOCKET_DIR:-${DATABASE_HOST:-${DB_HOST:-localhost}}}"
  export PGPORT="${DATABASE_PORT:-${DB_PORT:-5432}}"
  export PGUSER="${DATABASE_USERNAME:-${DB_USERNAME:-${DB_USER:-postgres}}}"
  export PGPASSWORD="${DATABASE_PASSWORD:-${DB_PASSWORD:-${DB_PASS:-postgres}}}"
}

command="${1:-}"
[ $# -gt 0 ] && shift
case "$command" in
  name) name "$@" ;;
  drop)
    database="$(name)"
    connect
    PGOPTIONS="--client-min-messages=warning" psql -d postgres -v ON_ERROR_STOP=1 -qc "DROP DATABASE IF EXISTS \"$database\" WITH (FORCE)"
    ;;
  psql)
    database="$(name)"
    connect
    exec psql -d "$database" "$@"
    ;;
  run)
    [ $# -gt 0 ] || { echo "proofdb.sh: run needs a command" >&2; exit 64; }
    database="$(name)"
    DATABASE_NAME="$database" exec "$@"
    ;;
  *) echo "usage: proofdb.sh name [<branch>] | drop | psql [<arg>...] | run <command>..." >&2; exit 64 ;;
esac
