#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
FAKE_INIT="${SCRIPT_DIR}/fixtures/fake-init"
FAKE_SU_EXEC="${SCRIPT_DIR}/fixtures/fake-su-exec"
TEMP_DIR=$(mktemp -d)
TEST_USER=$(id -un)
TEST_GROUP=$(id -gn)
SU_EXEC="$FAKE_SU_EXEC"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}

assert_env() {
    expected=$1
    grep -Fqx "$expected" "$ENV_FILE" ||
        fail "Missing environment value: $expected"
}

refute_env_key() {
    key=$1
    if grep -Eq "^${key}=" "$ENV_FILE"; then
        fail "Unexpected environment key: $key"
    fi
}

env_value() {
    key=$1
    sed -n "s/^${key}=//p" "$ENV_FILE"
}

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

chmod 0755 "$FAKE_INIT"
chmod 0755 "$FAKE_SU_EXEC"
CONFIG_DIR="${TEMP_DIR}/config"
ENV_FILE="${TEMP_DIR}/env"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"

run_entrypoint() {
    config_dir=${2:-$CONFIG_DIR}
    N8N_OPTIONS_PATH="$1" \
    N8N_CONFIG_DIR="$config_dir" \
    ADDON_INIT="$FAKE_INIT" \
    N8N_RUN_AS_USER="$TEST_USER" \
    N8N_RUN_AS_GROUP="$TEST_GROUP" \
    N8N_SU_EXEC="$SU_EXEC" \
    N8N_TEST_ENV_FILE="$ENV_FILE" \
    N8N_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" --fixture >"$LOG_FILE" 2>&1
}

# shellcheck disable=SC2016  # the literal Dockerfile expression is under test
grep -Fq 'FROM ghcr.io/n8n-io/runners:${RUNNERS_VERSION}@${RUNNERS_DIGEST} AS task-runners' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Runner image is not immutably pinned"
grep -Fq 'COPY --from=task-runners /opt/runners/task-runner-python' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Python task-runner package is not included"

# External PostgreSQL and Redis settings reach n8n without exposing secrets in
# the adapter log.
run_entrypoint "$OPTIONS"
assert_env "DB_TYPE=postgresdb"
assert_env "DB_POSTGRESDB_HOST=postgres.local"
assert_env "DB_POSTGRESDB_PORT=5432"
assert_env "DB_POSTGRESDB_DATABASE=n8n"
assert_env "DB_POSTGRESDB_USER=n8n"
# shellcheck disable=SC2016  # the literal $ is part of the password under test
assert_env 'DB_POSTGRESDB_PASSWORD=pg-secret-$pass word'
assert_env "DB_POSTGRESDB_SCHEMA=public"
assert_env "DB_POSTGRESDB_SSL_ENABLED=true"
assert_env "EXECUTIONS_MODE=queue"
assert_env "QUEUE_BULL_REDIS_HOST=redis.local"
assert_env "QUEUE_BULL_REDIS_PORT=6379"
assert_env "QUEUE_BULL_REDIS_DB=2"
assert_env "QUEUE_BULL_REDIS_USERNAME=n8n"
assert_env "QUEUE_BULL_REDIS_PASSWORD=redis-secret"
assert_env "QUEUE_BULL_REDIS_TLS=true"
assert_env "N8N_USER_FOLDER=${CONFIG_DIR}/n8n"
assert_env "N8N_LOG_LEVEL=debug"
assert_env "GENERIC_TIMEZONE=Europe/Warsaw"
assert_env "N8N_SECURE_COOKIE=true"
assert_env "N8N_EDITOR_BASE_URL=https://n8n.example.com"
assert_env "N8N_WEBHOOK_URL=https://n8n.example.com/"
refute_env_key "WEBHOOK_URL"
assert_env "N8N_PORT=5678"
assert_env "N8N_PROTOCOL=http"
assert_env "N8N_RUNNERS_MODE=internal"
assert_env "N8N_NATIVE_PYTHON_RUNNER=true"
assert_env "N8N_RUNNERS_TASK_TIMEOUT=300"
assert_env "N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES=2147483648"
assert_env "N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES=5000"
assert_env "N8N_UNVERIFIED_PACKAGES_ENABLED=true"
assert_env "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true"
assert_env "N8N_BLOCK_ENV_ACCESS_IN_NODE=true"
assert_env "N8N_DIAGNOSTICS_ENABLED=false"
assert_env "N8N_VERSION_NOTIFICATIONS_ENABLED=false"
grep -Eq '^N8N_ENCRYPTION_KEY=.' "$ENV_FILE" ||
    fail "Encryption key was not exported"
assert_env "N8N_CUSTOM_VALUE=custom-value"
grep -Fq "N8N_CUSTOM_VALUE" "$LOG_FILE" ||
    fail "Custom environment variable name was not logged"
[ "$(cat "$ARGS_FILE")" = "--fixture" ] || fail "Arguments were not forwarded"

# Persistent directories and generated key survive restarts.
[ -d "${CONFIG_DIR}/n8n" ] || fail "Missing n8n data directory"
SECRET_FILE="${CONFIG_DIR}/encryption_key"
[ -f "$SECRET_FILE" ] || fail "Encryption key file was not created"
[ "$(file_mode "$SECRET_FILE")" = "600" ] ||
    fail "Encryption key file is not owner-only (0600)"
first_key=$(env_value "N8N_ENCRYPTION_KEY")
run_entrypoint "$OPTIONS"
second_key=$(env_value "N8N_ENCRYPTION_KEY")
if [ -z "$first_key" ] || [ "$first_key" != "$second_key" ]; then
    fail "Generated encryption key was not stable across restarts"
fi
if grep -Fq "$first_key" "$LOG_FILE"; then
    fail "Encryption key leaked into the log"
fi
if grep -Fq 'pg-secret' "$LOG_FILE"; then
    fail "Database password leaked into the log"
fi

# SQLite regular mode does not require external database or Redis settings.
SQLITE_OPTIONS="${TEMP_DIR}/sqlite-options.json"
jq '.database = "sqlite" | .execution_mode = "regular" |
    .postgres_host = "" | .redis_host = "" | .encryption_key = "provided-key"' \
    "$OPTIONS" >"$SQLITE_OPTIONS"
SQLITE_CONFIG_DIR="${TEMP_DIR}/sqlite-config"
run_entrypoint "$SQLITE_OPTIONS" "$SQLITE_CONFIG_DIR"
assert_env "DB_TYPE=sqlite"
assert_env "EXECUTIONS_MODE=regular"
assert_env "N8N_ENCRYPTION_KEY=provided-key"
refute_env_key "DB_POSTGRESDB_HOST"
refute_env_key "QUEUE_BULL_REDIS_HOST"
[ ! -e "${SQLITE_CONFIG_DIR}/encryption_key" ] ||
    fail "Encryption key file created despite a provided key"

# Queue mode requires PostgreSQL so worker state is not stored in SQLite.
QUEUE_SQLITE="${TEMP_DIR}/queue-sqlite.json"
jq '.database = "sqlite" | .execution_mode = "queue"' \
    "$OPTIONS" >"$QUEUE_SQLITE"
if run_entrypoint "$QUEUE_SQLITE" "${TEMP_DIR}/queue-sqlite-config"; then
    fail "Queue mode with SQLite was accepted"
fi

# Required external service settings are rejected.
BAD_POSTGRES="${TEMP_DIR}/bad-postgres.json"
jq '.postgres_host = ""' "$OPTIONS" >"$BAD_POSTGRES"
if run_entrypoint "$BAD_POSTGRES"; then
    fail "Empty PostgreSQL host was accepted"
fi
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Empty PostgreSQL host did not report expected error"

BAD_REDIS="${TEMP_DIR}/bad-redis.json"
jq '.redis_host = ""' "$OPTIONS" >"$BAD_REDIS"
if run_entrypoint "$BAD_REDIS"; then
    fail "Empty Redis host was accepted"
fi

# Managed, protected, malformed, and control-character custom variables fail.
MANAGED_OVERRIDE="${TEMP_DIR}/managed-env.json"
jq '.env_vars = [{"name": "N8N_ENCRYPTION_KEY", "value": "nope"}]' \
    "$OPTIONS" >"$MANAGED_OVERRIDE"
if run_entrypoint "$MANAGED_OVERRIDE"; then
    fail "Managed environment override was accepted"
fi

PROTECTED_OVERRIDE="${TEMP_DIR}/protected-env.json"
jq '.env_vars = [{"name": "PATH", "value": "/tmp"}]' \
    "$OPTIONS" >"$PROTECTED_OVERRIDE"
if run_entrypoint "$PROTECTED_OVERRIDE"; then
    fail "Protected environment override was accepted"
fi

BAD_NAME="${TEMP_DIR}/bad-name.json"
jq '.env_vars = [{"name": "bad-name", "value": "x"}]' "$OPTIONS" >"$BAD_NAME"
if run_entrypoint "$BAD_NAME"; then
    fail "Malformed environment variable name was accepted"
fi

CONTROL_VALUE="${TEMP_DIR}/control-value.json"
jq '.env_vars = [{"name": "N8N_EXTRA", "value": "a\u0009b"}]' \
    "$OPTIONS" >"$CONTROL_VALUE"
if run_entrypoint "$CONTROL_VALUE"; then
    fail "Control character in custom value was accepted"
fi
grep -Fq "control characters" "$LOG_FILE" ||
    fail "Control character did not report expected error"

printf '%s\n' "n8n adapter tests passed"
