#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
WORK="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$WORK/config.env"
mkdir -p "$WORK/out" "$WORK/backups" "$WORK/logs"
LOG="$WORK/logs/run.log"
STAMP="$(date +%Y%m%d_%H%M%S)"

log() { printf '%s [%s] %s\n' "$(date -Is)" "$1" "$2" >> "$LOG"; }
trap 'rc=$?; log ERROR "exit=$rc"; exit "$rc"' ERR
export PGPASSFILE="$AUTH"

db_query() {
    "$CLIENT" -X -w -h "$DB_HOST" -p "$DB_PORT" -U admin -d "$DB" -v ON_ERROR_STOP=1 -A -t -c "$1"
}

dump_db() {
    "$DUMP" -w -h "$DB_HOST" -p "$DB_PORT" -U admin -d "$DB" -Fc -f "$1"
}

run_task() {
    file="$WORK/backups/${DB}_${STAMP}.dump"
    dump_db "$file"
    test -s "$file"
    pg_restore --list "$file" > "$file.toc.txt"
    log INFO "custom_archive=$file"
}

log INFO "START db=$DB"
run_task
log INFO "END result=OK"
exit 0
