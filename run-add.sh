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
    sha256sum "$file" > "$file.sha256"
    size=$(stat -c %s "$file")
    find "$WORK/backups" -maxdepth 1 -type f -name "${DB}_*.dump" -mtime +6 -print -delete >> "$LOG"
    log INFO "custom_archive=$file size=$size sha256=$(cut -d' ' -f1 "$file.sha256")"
}

log INFO "START db=$DB"
run_task
log INFO "END result=OK"
exit 0
