#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
FIXTURES="${SCRIPT_DIR}/fixtures"
FAKE_START_ALL="${FIXTURES}/fake-start-all.sh"
TEMP_DIR=$(mktemp -d)

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

assert_absent_env() {
    name=$1
    grep -Fq "^${name}=" "$ENV_FILE" &&
        fail "Unexpected environment variable: $name"
    return 0
}

run_entrypoint() {
    options=$1
    config_dir=$2
    ENV_FILE="${TEMP_DIR}/env-$3"
    LOG_FILE="${TEMP_DIR}/log-$3"
    HINDSIGHT_OPTIONS_PATH="$options" \
    HINDSIGHT_CONFIG_DIR="$config_dir" \
    HINDSIGHT_EXECUTABLE="$FAKE_START_ALL" \
    HINDSIGHT_TEST_ENV_FILE="$ENV_FILE" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1 ||
        fail "Entrypoint failed for $3: $(cat "$LOG_FILE")"
}

expect_failure() {
    options=$1
    label=$2
    LOG_FILE="${TEMP_DIR}/log-$label"
    if HINDSIGHT_OPTIONS_PATH="$options" \
        HINDSIGHT_CONFIG_DIR="${TEMP_DIR}/config-$label" \
        HINDSIGHT_EXECUTABLE="$FAKE_START_ALL" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1
    then
        fail "Entrypoint unexpectedly succeeded for $label"
    fi
    grep -q '\[hindsight-addon\]' "$LOG_FILE" ||
        fail "Missing addon log prefix for $label"
}

CONFIG_DEFAULT="${TEMP_DIR}/config-default"
run_entrypoint "$FIXTURES/options-default.json" "$CONFIG_DEFAULT" default
assert_env "HOME=$CONFIG_DEFAULT"
assert_env "HINDSIGHT_API_LLM_PROVIDER=openai"
assert_env "HINDSIGHT_API_LLM_API_KEY=****************"
assert_env "HINDSIGHT_API_LLM_MODEL="
assert_env "HINDSIGHT_API_LLM_BASE_URL="
assert_env "HINDSIGHT_API_DATABASE_URL="
assert_env "HINDSIGHT_API_TENANT_EXTENSION="
assert_absent_env "HINDSIGHT_API_TENANT_API_KEY"
assert_env "HINDSIGHT_API_WORKER_ID=hindsight-hassio"
assert_absent_env "HINDSIGHT_EXTRA_FLAG"

CONFIG_POSTGRES="${TEMP_DIR}/config-postgres"
run_entrypoint "$FIXTURES/options-postgres.json" "$CONFIG_POSTGRES" postgres
assert_env "HINDSIGHT_API_LLM_PROVIDER=ollama"
assert_env "HINDSIGHT_API_LLM_MODEL=llama3"
assert_env "HINDSIGHT_API_LLM_BASE_URL=http://192.168.1.50:11434/v1"
assert_env "HINDSIGHT_API_DATABASE_URL=postgresql://hindsight%40sa:****@db.example.com:6543/hindsight-db?sslmode=require"
assert_env "HINDSIGHT_API_TENANT_EXTENSION=hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension"
assert_env "HINDSIGHT_API_TENANT_API_KEY=****************"
assert_env "HINDSIGHT_API_WORKER_ID=worker-1"

CONFIG_ENVVARS="${TEMP_DIR}/config-envvars"
run_entrypoint "$FIXTURES/options-envvars.json" "$CONFIG_ENVVARS" envvars
assert_env "HINDSIGHT_EXTRA_FLAG=enabled"
assert_env "MY_CUSTOM_SETTING=custom-value"

expect_failure "$FIXTURES/options-bad-name.json" bad-name
expect_failure "$FIXTURES/options-managed-override.json" managed-override
expect_failure "$FIXTURES/options-protected-override.json" protected-override
expect_failure "$FIXTURES/options-control-char.json" control-char
expect_failure "$FIXTURES/options-control-env.json" control-env

# Without the fixture env file the entrypoint must exec the upstream script.
MARKER="${TEMP_DIR}/started"
CONFIG_EXEC="${TEMP_DIR}/config-exec"
HINDSIGHT_OPTIONS_PATH="$FIXTURES/options-default.json" \
HINDSIGHT_CONFIG_DIR="$CONFIG_EXEC" \
HINDSIGHT_EXECUTABLE="$FAKE_START_ALL" \
HINDSIGHT_FAKE_MARKER="$MARKER" \
    sh "$ENTRYPOINT" >/dev/null 2>&1 ||
    fail "Entrypoint failed to start upstream"
grep -q 'started' "$MARKER" || fail "Upstream startup script was not executed"

printf '%s\n' "All hindsight adapter tests passed."
