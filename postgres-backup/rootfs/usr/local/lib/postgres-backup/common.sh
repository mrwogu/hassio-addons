# shellcheck shell=sh
# shellcheck disable=SC2034  # the variables are read by the sourcing scripts

# Shared by addon-entrypoint and pg-backup. Supervisor rewrites options.json
# when options are saved, even while the add-on runs, so the backup hook
# validates it again instead of trusting what the entrypoint saw.

OPTIONS_PATH=${PG_BACKUP_OPTIONS_PATH:-/data/options.json}
# /config is the addon_config folder. Supervisor puts it into the add-on
# backup next to /data, and users can reach it over Samba.
DUMP_DIR=${PG_BACKUP_DUMP_DIR:-/config/dumps}

# Dumps hold the password hashes of every role.
umask 077

log() {
    printf '%s\n' "[postgres-backup] $*" >&2
}

fail() {
    log "Error: $*"
    exit 1
}

load_options() {
    [ -r "$OPTIONS_PATH" ] || fail "Options file is not readable: $OPTIONS_PATH"
    command -v jq >/dev/null 2>&1 || fail "jq is required"

    if ! jq -e '(.password // "") != ""' "$OPTIONS_PATH" >/dev/null 2>&1; then
        fail "Set the password option to the Postgres superuser password"
    fi
    if ! jq -e '
        def control_free: (explode | map(select(. < 32 or . == 127)) | length) == 0;
        def clean: type == "string" and control_free;
        type == "object"
        and (.host | clean and length > 0)
        and (.port | type == "number" and floor == . and . >= 1 and . <= 65535)
        and (.username | clean and length > 0)
        and (.password | clean)
        and (.keep | type == "number" and floor == . and . >= 1)
        and ((.restore // "") | clean and (contains("/") | not))
    ' "$OPTIONS_PATH" >/dev/null 2>&1; then
        fail "Invalid options: check host, port, username, password, keep, or restore"
    fi

    host=$(jq -r '.host' "$OPTIONS_PATH")
    port=$(jq -r '.port' "$OPTIONS_PATH")
    username=$(jq -r '.username' "$OPTIONS_PATH")
    keep=$(jq -r '.keep' "$OPTIONS_PATH")
    restore=$(jq -r '.restore // ""' "$OPTIONS_PATH")
    # libpq reads the password from the environment, so it never shows up
    # in the process list or in the log.
    PGPASSWORD=$(jq -r '.password' "$OPTIONS_PATH")
    export PGPASSWORD
}
