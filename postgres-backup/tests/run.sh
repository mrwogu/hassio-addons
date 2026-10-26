#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
BIN_DIR="${ADDON_DIR}/rootfs/usr/local/bin"
LIB="${ADDON_DIR}/rootfs/usr/local/lib/postgres-backup/common.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"
OPTIONS="${FIXTURES}/options.json"
PASSWORD="dummy-postgres-password"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    if [ -f "${LOG_FILE:-}" ]; then
        sed 's/^/  log: /' "$LOG_FILE" >&2
    fi
    exit 1
}

chmod 0755 "$FIXTURES/pg_dumpall" "$FIXTURES/pg_isready" "$FIXTURES/psql" \
    "$FIXTURES/sleep"
DUMP_DIR="${TEMP_DIR}/dumps"
RECORD_DIR="${TEMP_DIR}/records"
LOG_FILE="${TEMP_DIR}/log"

# Runs one of the add-on scripts with fake Postgres tools first on PATH.
# Extra NAME=value arguments go to the environment of that run.
run_script() {
    script=$1
    options=$2
    shift 2
    rm -rf "$RECORD_DIR"
    mkdir -p "$RECORD_DIR"
    : >"$LOG_FILE"
    env PATH="${FIXTURES}:${PATH}" \
        PG_BACKUP_OPTIONS_PATH="$options" \
        PG_BACKUP_DUMP_DIR="$DUMP_DIR" \
        PG_BACKUP_LIB="$LIB" \
        PG_BACKUP_LOG="$LOG_FILE" \
        PG_BACKUP_TEST_DIR="$RECORD_DIR" \
        "$@" sh "${BIN_DIR}/${script}" >>"$LOG_FILE" 2>&1
}

with_options() {
    candidate=$(mktemp "${TEMP_DIR}/options.XXXXXX")
    jq "$1" "$OPTIONS" >"$candidate"
    printf '%s\n' "$candidate"
}

make_dump() {
    printf '%s\n' "$2" | gzip -c >"${DUMP_DIR}/$1"
}

count_dumps() {
    find "$DUMP_DIR" -name 'pg_dumpall-*.sql.gz' | wc -l | tr -d ' '
}

assert_log() {
    grep -Fq "$1" "$LOG_FILE" || fail "Log does not contain: $1"
}

assert_no_password() {
    for file in "$LOG_FILE" "$RECORD_DIR"/*.args; do
        if [ -f "$file" ] && grep -Fq "$PASSWORD" "$file"; then
            fail "Password leaked into ${file##*/}"
        fi
    done
}

# The version is intentionally not pinned to a literal here: Renovate bumps
# it on every upstream release and the pin itself lives in the Dockerfile.
grep -Eq 'ARG UPSTREAM_VERSION="[0-9][0-9.]*"' "$ADDON_DIR/Dockerfile" ||
    fail "Upstream version is not pinned"
# shellcheck disable=SC2016  # the literal Dockerfile expression is under test
grep -Fq \
    'FROM docker.io/library/alpine:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Upstream image is not immutably pinned"

# A dump lands under its final name, gzip-compressed, with no temp file left.
run_script pg-backup "$OPTIONS" || fail "pg-backup failed"
dump=$(find "$DUMP_DIR" -name 'pg_dumpall-*.sql.gz')
printf '%s\n' "${dump##*/}" |
    grep -Eqx 'pg_dumpall-[0-9]{8}-[0-9]{6}\.sql\.gz' ||
    fail "Unexpected dump name: $dump"
expected_body=$(printf '%s\n' '-- fake pg_dumpall output' 'CREATE ROLE fixture;' \
    '-- PostgreSQL database cluster dump complete')
[ "$(gunzip -c "$dump")" = "$expected_body" ] || fail "Dump content differs"
[ -z "$(find "$DUMP_DIR" -name '.*')" ] || fail "Temporary file left behind"
[ "$(cat "$RECORD_DIR/pg_dumpall.args")" = \
    "--clean --if-exists -w -h db.example.test -p 5433 -U backup-user" ] ||
    fail "Unexpected pg_dumpall arguments"
# The password reaches libpq only through PGPASSWORD.
[ "$(cat "$RECORD_DIR/pg_dumpall.password")" = "$PASSWORD" ] ||
    fail "pg_dumpall did not get PGPASSWORD"
assert_no_password
assert_log "Wrote ${dump##*/}"

# keep removes the oldest dumps and their restore markers.
rm -rf "$DUMP_DIR"
mkdir -p "$DUMP_DIR"
make_dump pg_dumpall-20200101-000000.sql.gz old1
make_dump pg_dumpall-20200102-000000.sql.gz old2
make_dump pg_dumpall-20200103-000000.sql.gz old3
: >"${DUMP_DIR}/pg_dumpall-20200101-000000.sql.gz.restored"
run_script pg-backup "$(with_options '.keep = 2')" || fail "pg-backup failed"
[ "$(count_dumps)" = 2 ] || fail "keep=2 left $(count_dumps) dumps"
[ ! -e "${DUMP_DIR}/pg_dumpall-20200101-000000.sql.gz" ] ||
    fail "Oldest dump was not removed"
[ ! -e "${DUMP_DIR}/pg_dumpall-20200102-000000.sql.gz" ] ||
    fail "Second oldest dump was not removed"
[ -e "${DUMP_DIR}/pg_dumpall-20200103-000000.sql.gz" ] ||
    fail "Newer dump was removed"
[ ! -e "${DUMP_DIR}/pg_dumpall-20200101-000000.sql.gz.restored" ] ||
    fail "Marker of a removed dump was left behind"

# A failing pg_dumpall fails the hook and leaves no partial dump.
rm -rf "$DUMP_DIR"
mkdir -p "$DUMP_DIR"
if run_script pg-backup "$OPTIONS" PG_BACKUP_TEST_DUMP_FAIL=1; then
    fail "Failed pg_dumpall was reported as success"
fi
[ -z "$(find "$DUMP_DIR" -type f)" ] || fail "Failed dump left a file"
assert_log "pg_dumpall failed"

# Backups are refused while a restore is configured.
if run_script pg-backup "$(with_options '.restore = "latest"')"; then
    fail "pg-backup ran while restore was set"
fi
[ ! -e "$RECORD_DIR/pg_dumpall.args" ] || fail "pg_dumpall ran while restore was set"
assert_log "restore option is still set"

# Normal start waits for the backup hook.
run_script addon-entrypoint "$OPTIONS" || fail "Entrypoint failed"
assert_log "accepting connections"
[ "$(cat "$RECORD_DIR/sleep.args")" = "infinity" ] || fail "Entrypoint did not idle"
[ ! -e "$RECORD_DIR/psql.args" ] || fail "psql ran without restore"

# An unreachable server is only a warning at start.
run_script addon-entrypoint "$OPTIONS" PG_BACKUP_TEST_READY=2 ||
    fail "Entrypoint failed for an unreachable server"
assert_log "Warning: Postgres at db.example.test:5433 is not ready"

# Invalid options stop the add-on before anything runs.
for filter in \
    '.port = 0' \
    '.port = "abc"' \
    '.password = ""' \
    '.host = "db\u000aexample"' \
    '.username = "a\u0009b"' \
    '.keep = 0' \
    '.restore = "../pg_dumpall-20200101-000000.sql.gz"' \
    '.restore = "a\u0009b"'; do
    if run_script addon-entrypoint "$(with_options "$filter")"; then
        fail "Accepted invalid options: $filter"
    fi
    [ ! -e "$RECORD_DIR/pg_isready.args" ] || fail "Tools ran with: $filter"
done
run_script addon-entrypoint "$(with_options '.password = ""')" || true
assert_log "Set the password option"

# restore=latest loads the newest dump by name, then writes a marker.
rm -rf "$DUMP_DIR"
mkdir -p "$DUMP_DIR"
make_dump pg_dumpall-20200101-000000.sql.gz "SELECT 'older';"
make_dump pg_dumpall-20200102-000000.sql.gz "SELECT 'newer';"
LATEST=$(with_options '.restore = "latest"')
run_script addon-entrypoint "$LATEST" || fail "Restore of latest failed"
[ "$(cat "$RECORD_DIR/psql.stdin")" = "SELECT 'newer';" ] ||
    fail "restore=latest did not pick the newest dump"
[ "$(cat "$RECORD_DIR/psql.bytes")" = 16 ] || fail "Unexpected restore size"
[ "$(cat "$RECORD_DIR/psql.args")" = \
    "-X -q -w -h db.example.test -p 5433 -U backup-user -d postgres" ] ||
    fail "Unexpected psql arguments"
[ "$(cat "$RECORD_DIR/psql.password")" = "$PASSWORD" ] ||
    fail "psql did not get PGPASSWORD"
assert_no_password
[ -s "${DUMP_DIR}/pg_dumpall-20200102-000000.sql.gz.restored" ] ||
    fail "Restore marker was not written"
assert_log "set the restore option back to empty"
[ "$(cat "$RECORD_DIR/sleep.args")" = "infinity" ] ||
    fail "Entrypoint did not idle after restore"

# The marker stops the same dump from being loaded again on restart.
run_script addon-entrypoint "$LATEST" || fail "Second start failed"
[ ! -e "$RECORD_DIR/psql.args" ] || fail "Restored dump was loaded again"
assert_log "already restored, skipping"

# An exact file name works and expected psql errors are counted, not hidden.
run_script addon-entrypoint \
    "$(with_options '.restore = "pg_dumpall-20200101-000000.sql.gz"')" \
    PG_BACKUP_TEST_PSQL_ERRORS=2 || fail "Restore by name failed"
[ "$(cat "$RECORD_DIR/psql.stdin")" = "SELECT 'older';" ] ||
    fail "Restore by name loaded the wrong dump"
[ -e "${DUMP_DIR}/pg_dumpall-20200101-000000.sql.gz.restored" ] ||
    fail "Restore by name wrote no marker"
assert_log "finished with 2 psql errors"
assert_log '[psql] psql:<stdin>:1: ERROR:  role "postgres" already exists'

# A failing psql stops the add-on and leaves no marker.
make_dump pg_dumpall-20200103-000000.sql.gz "SELECT 'third';"
if run_script addon-entrypoint "$LATEST" PG_BACKUP_TEST_PSQL_FAIL=1; then
    fail "Failed psql was reported as success"
fi
[ ! -e "${DUMP_DIR}/pg_dumpall-20200103-000000.sql.gz.restored" ] ||
    fail "Failed restore wrote a marker"
assert_log "psql exited with status 2"

# A server that never gets ready is a failed restore, psql never runs.
if run_script addon-entrypoint "$LATEST" PG_BACKUP_TEST_READY=2; then
    fail "Restore without a ready server was reported as success"
fi
[ ! -e "$RECORD_DIR/psql.args" ] || fail "psql ran without a ready server"
[ "$(grep -c '^5$' "$RECORD_DIR/sleep.args")" = 60 ] ||
    fail "Restore did not wait about five minutes"
assert_log "not ready after 300s"

# A damaged or missing dump is rejected before the database is touched.
printf '%s\n' "not gzip" >"${DUMP_DIR}/pg_dumpall-20200104-000000.sql.gz"
if run_script addon-entrypoint "$LATEST"; then
    fail "Damaged dump was restored"
fi
[ ! -e "$RECORD_DIR/psql.args" ] || fail "psql ran for a damaged dump"
if run_script addon-entrypoint "$(with_options '.restore = "missing.sql.gz"')"; then
    fail "Missing dump was accepted"
fi
assert_log "Dump to restore not found"

printf '%s\n' "Postgres Backup adapter tests passed"
