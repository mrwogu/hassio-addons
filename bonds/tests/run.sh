#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
FAKE_BONDS="${SCRIPT_DIR}/fixtures/fake-bonds"
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

chmod 0755 "$FAKE_BONDS"
CONFIG_DIR="${TEMP_DIR}/config"
ENV_FILE="${TEMP_DIR}/env"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"

BONDS_OPTIONS_PATH="$OPTIONS" \
BONDS_CONFIG_DIR="$CONFIG_DIR" \
BONDS_EXECUTABLE="$FAKE_BONDS" \
BONDS_TEST_ENV_FILE="$ENV_FILE" \
BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
    sh "$ENTRYPOINT" --fixture >"$LOG_FILE" 2>&1

assert_env "SERVER_PORT=8080"
assert_env "SERVER_HOST=0.0.0.0"
assert_env "DB_DRIVER=sqlite"
assert_env "DB_DSN=${CONFIG_DIR}/bonds.db"
assert_env "APP_ENV=production"
assert_env "DEBUG=true"
assert_env "APP_URL=https://bonds.example.test:8080"
assert_env "STORAGE_UPLOAD_DIR=${CONFIG_DIR}/uploads"
assert_env "STORAGE_MAX_SIZE_MB=256"
assert_env "BLEVE_INDEX_PATH=${CONFIG_DIR}/bonds.bleve"
assert_env "BACKUP_DIR=${CONFIG_DIR}/backups"
assert_env "BACKUP_CRON=15 2 * * *"
assert_env "BACKUP_RETENTION=14"
[ "$(cat "$ARGS_FILE")" = "--fixture" ] || fail "Arguments were not forwarded"

SECRETS_FILE="${CONFIG_DIR}/.secrets"
[ -f "$SECRETS_FILE" ] || fail "Secrets file was not created"
[ "$(stat -f '%Lp' "$SECRETS_FILE" 2>/dev/null || stat -c '%a' "$SECRETS_FILE")" = "600" ] ||
    fail "Secrets file mode is not 600"

JWT_SECRET=$(jq -r '.jwt_secret' "$SECRETS_FILE")
SETTINGS_KEY=$(jq -r '.settings_encryption_key' "$SECRETS_FILE")
[ "${#JWT_SECRET}" -eq 64 ] || fail "Generated JWT secret has wrong length"
[ "${#SETTINGS_KEY}" -eq 64 ] || fail "Generated settings key has wrong length"
grep -Fqx "JWT_SECRET=$JWT_SECRET" "$ENV_FILE" ||
    fail "Generated JWT secret was not exported"
grep -Fqx "SETTINGS_ENC_KEY=$SETTINGS_KEY" "$ENV_FILE" ||
    fail "Generated settings key was not exported"
if grep -Fq "$JWT_SECRET" "$LOG_FILE" ||
    grep -Fq "$SETTINGS_KEY" "$LOG_FILE"; then
    fail "Generated secret leaked to logs"
fi

ENV_FILE="${TEMP_DIR}/env-second"
ARGS_FILE="${TEMP_DIR}/args-second"
BONDS_OPTIONS_PATH="$OPTIONS" \
BONDS_CONFIG_DIR="$CONFIG_DIR" \
BONDS_EXECUTABLE="$FAKE_BONDS" \
BONDS_TEST_ENV_FILE="$ENV_FILE" \
BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
    sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1

grep -Fqx "JWT_SECRET=$JWT_SECRET" "$ENV_FILE" ||
    fail "Generated JWT secret did not persist"
grep -Fqx "SETTINGS_ENC_KEY=$SETTINGS_KEY" "$ENV_FILE" ||
    fail "Generated settings key did not persist"

OPTIONAL_OPTIONS="${TEMP_DIR}/optional-options.json"
jq 'del(.jwt_secret, .settings_encryption_key, .backup_cron)' \
    "$OPTIONS" >"$OPTIONAL_OPTIONS"
ENV_FILE="${TEMP_DIR}/env-optional"
ARGS_FILE="${TEMP_DIR}/args-optional"
BONDS_OPTIONS_PATH="$OPTIONAL_OPTIONS" \
BONDS_CONFIG_DIR="$CONFIG_DIR" \
BONDS_EXECUTABLE="$FAKE_BONDS" \
BONDS_TEST_ENV_FILE="$ENV_FILE" \
BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
    sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1

assert_env "JWT_SECRET=$JWT_SECRET"
assert_env "SETTINGS_ENC_KEY=$SETTINGS_KEY"
assert_env "BACKUP_CRON=0 3 * * *"

CUSTOM_OPTIONS="${TEMP_DIR}/custom-options.json"
CUSTOM_JWT="fixture-jwt-secret"
CUSTOM_SETTINGS="fixture-settings-key"
jq \
    --arg jwt "$CUSTOM_JWT" \
    --arg settings "$CUSTOM_SETTINGS" \
    '.jwt_secret = $jwt | .settings_encryption_key = $settings | .debug = false' \
    "$OPTIONS" >"$CUSTOM_OPTIONS"

ENV_FILE="${TEMP_DIR}/env-custom"
ARGS_FILE="${TEMP_DIR}/args-custom"
BONDS_OPTIONS_PATH="$CUSTOM_OPTIONS" \
BONDS_CONFIG_DIR="$CONFIG_DIR" \
BONDS_EXECUTABLE="$FAKE_BONDS" \
BONDS_TEST_ENV_FILE="$ENV_FILE" \
BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
    sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1

assert_env "APP_ENV=production"
assert_env "DEBUG=false"
grep -Fqx "JWT_SECRET=$CUSTOM_JWT" "$ENV_FILE" ||
    fail "User JWT secret was not exported"
grep -Fqx "SETTINGS_ENC_KEY=$CUSTOM_SETTINGS" "$ENV_FILE" ||
    fail "User settings key was not exported"
if grep -Fq "$CUSTOM_JWT" "$LOG_FILE" ||
    grep -Fq "$CUSTOM_SETTINGS" "$LOG_FILE"; then
    fail "User-provided secret leaked to logs"
fi

INVALID_OPTIONS="${TEMP_DIR}/invalid-options.json"
jq '.storage_max_size_mb = 0' "$OPTIONS" >"$INVALID_OPTIONS"
if BONDS_OPTIONS_PATH="$INVALID_OPTIONS" \
    BONDS_CONFIG_DIR="$CONFIG_DIR" \
    BONDS_EXECUTABLE="$FAKE_BONDS" \
    BONDS_TEST_ENV_FILE="$ENV_FILE" \
    BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1; then
    fail "Invalid numeric value was accepted"
fi
grep -Fq "Invalid options structure or numeric value" "$LOG_FILE" ||
    fail "Invalid numeric value did not report expected error"

printf '%s\n' "Bonds adapter tests passed"
