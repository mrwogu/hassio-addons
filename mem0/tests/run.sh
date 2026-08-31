#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}

run_entrypoint() {
    options=$1
    config_dir=$2
    label=$3
    ENV_FILE="${TEMP_DIR}/env-${label}"
    LOG_FILE="${TEMP_DIR}/log-${label}"
    MEM0_OPTIONS_PATH="$options" \
    MEM0_CONFIG_DIR="$config_dir" \
    MEM0_TEST_ENV_FILE="$ENV_FILE" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1
}

expect_failure() {
    label=$1
    options=$2
    message=$3
    if MEM0_OPTIONS_PATH="$options" \
        MEM0_CONFIG_DIR="${TEMP_DIR}/config-fail" \
        MEM0_TEST_ENV_FILE="${TEMP_DIR}/env-fail" \
            sh "$ENTRYPOINT" >"${TEMP_DIR}/log-fail" 2>&1; then
        fail "$label was accepted"
    fi
    grep -Fq "$message" "${TEMP_DIR}/log-fail" ||
        fail "$label did not report the expected error"
}

assert_env() {
    expected=$1
    grep -Fqx "$expected" "$ENV_FILE" ||
        fail "Missing environment value: $expected"
}

CONFIG_DIR="${TEMP_DIR}/config"
run_entrypoint "$OPTIONS" "$CONFIG_DIR" main

assert_env "OPENAI_API_KEY=sk-fixture-openai-key"
assert_env "ANTHROPIC_API_KEY=sk-ant-fixture"
assert_env "GOOGLE_API_KEY="
assert_env "ADMIN_API_KEY=m0sk-fixture-admin-key-0001"
assert_env "AUTH_DISABLED=false"
assert_env "POSTGRES_HOST=postgres.local"
assert_env "POSTGRES_PORT=5433"
assert_env "POSTGRES_DB=mem0"
assert_env "POSTGRES_USER=mem0"
assert_env "POSTGRES_PASSWORD=pg-secret-\$pass word"
assert_env "POSTGRES_COLLECTION_NAME=memories"
assert_env "APP_DB_NAME=mem0"
assert_env "MEM0_DEFAULT_LLM_MODEL=gpt-5-mini"
assert_env "MEM0_DEFAULT_EMBEDDER_MODEL=text-embedding-3-small"
assert_env "MEM0_TELEMETRY=false"
assert_env "REQUEST_LOG_RETENTION_DAYS=14"
assert_env "HISTORY_DB_PATH=${CONFIG_DIR}/history.db"

# Generated JWT secrets persist in the configuration directory.
SECRETS_FILE="${CONFIG_DIR}/.secrets"
[ -f "$SECRETS_FILE" ] || fail "Secrets file was not created"
secrets_mode=$(stat -c '%a' "$SECRETS_FILE" 2>/dev/null || stat -f '%Lp' "$SECRETS_FILE")
[ "$secrets_mode" = "600" ] ||
    fail "Secrets file mode is not 600"

JWT_SECRET=$(jq -r '.jwt_secret' "$SECRETS_FILE")
[ "${#JWT_SECRET}" -eq 64 ] || fail "Generated JWT secret has wrong length"
grep -Fqx "JWT_SECRET=$JWT_SECRET" "$ENV_FILE" ||
    fail "Generated JWT secret was not exported"
if grep -Fq "$JWT_SECRET" "${TEMP_DIR}/log-main"; then
    fail "Generated JWT secret leaked to logs"
fi
if grep -Fq "pg-secret" "${TEMP_DIR}/log-main"; then
    fail "Database password leaked to logs"
fi

# A stored secret survives runs without the option set.
run_entrypoint "$OPTIONS" "$CONFIG_DIR" second
assert_env "JWT_SECRET=$JWT_SECRET"

# A user-provided JWT secret takes precedence and is never logged.
CUSTOM_OPTIONS="${TEMP_DIR}/custom-options.json"
jq '.jwt_secret = "fixture-jwt-secret"' "$OPTIONS" >"$CUSTOM_OPTIONS"
CUSTOM_CONFIG_DIR="${TEMP_DIR}/config-custom"
run_entrypoint "$CUSTOM_OPTIONS" "$CUSTOM_CONFIG_DIR" custom
assert_env "JWT_SECRET=fixture-jwt-secret"
if grep -Fq "fixture-jwt-secret" "${TEMP_DIR}/log-custom"; then
    fail "User-provided secret leaked to logs"
fi
[ -f "${CUSTOM_CONFIG_DIR}/.secrets" ] &&
    fail "Secrets file was created despite a user-provided secret"

# Missing optional keys default to empty values.
OPTIONAL_OPTIONS="${TEMP_DIR}/optional-options.json"
jq 'del(.anthropic_api_key, .google_api_key, .admin_api_key)' \
    "$OPTIONS" >"$OPTIONAL_OPTIONS"
OPTIONAL_CONFIG_DIR="${TEMP_DIR}/config-optional"
run_entrypoint "$OPTIONAL_OPTIONS" "$OPTIONAL_CONFIG_DIR" optional
assert_env "ANTHROPIC_API_KEY="
assert_env "GOOGLE_API_KEY="
assert_env "ADMIN_API_KEY="

# Invalid options are rejected with option-specific messages.
MISSING_KEY="${TEMP_DIR}/missing-key.json"
jq '.openai_api_key = ""' "$OPTIONS" >"$MISSING_KEY"
expect_failure "Empty OpenAI API key" "$MISSING_KEY" \
    "Option 'openai_api_key' is required"

MISSING_HOST="${TEMP_DIR}/missing-host.json"
jq '.postgres_host = ""' "$OPTIONS" >"$MISSING_HOST"
expect_failure "Empty PostgreSQL host" "$MISSING_HOST" \
    "Option 'postgres_host' must be a non-empty string"

BAD_PORT="${TEMP_DIR}/bad-port.json"
jq '.postgres_port = 70000' "$OPTIONS" >"$BAD_PORT"
expect_failure "Out-of-range PostgreSQL port" "$BAD_PORT" \
    "Option 'postgres_port' must be an integer between 1 and 65535"

CONTROL_USER="${TEMP_DIR}/control-user.json"
jq '.postgres_user = "mem\u0009o"' "$OPTIONS" >"$CONTROL_USER"
expect_failure "Control character in PostgreSQL user" "$CONTROL_USER" \
    "Option 'postgres_user' must be a non-empty string"

CONTROL_ADMIN_KEY="${TEMP_DIR}/control-admin.json"
jq '.admin_api_key = "key\u001b[31m"' "$OPTIONS" >"$CONTROL_ADMIN_KEY"
expect_failure "Control character in admin API key" "$CONTROL_ADMIN_KEY" \
    "Option 'admin_api_key' must be a string without control characters"

MALFORMED_OPTIONS="${TEMP_DIR}/malformed-options.json"
printf '%s' '{"openai_api_key": ' >"$MALFORMED_OPTIONS"
expect_failure "Malformed options file" "$MALFORMED_OPTIONS" \
    "Invalid options file: expected a JSON object"

INVALID_RETENTION="${TEMP_DIR}/invalid-retention.json"
jq '.request_log_retention_days = 0' "$OPTIONS" >"$INVALID_RETENTION"
expect_failure "Invalid retention value" "$INVALID_RETENTION" \
    "Option 'request_log_retention_days' must be a positive integer"

printf '%s\n' "Mem0 adapter tests passed"
