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

run_entrypoint() {
    options=$1
    config_dir=$2
    ENV_FILE="${TEMP_DIR}/env-$3"
    ARGS_FILE="${TEMP_DIR}/args-$3"
    BONDS_OPTIONS_PATH="$options" \
    BONDS_CONFIG_DIR="$config_dir" \
    BONDS_EXECUTABLE="$FAKE_BONDS" \
    BONDS_TEST_ENV_FILE="$ENV_FILE" \
    BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" --fixture >"$LOG_FILE" 2>&1
}

expect_failure() {
    label=$1
    options=$2
    message=$3
    if BONDS_OPTIONS_PATH="$options" \
        BONDS_CONFIG_DIR="$CONFIG_DIR" \
        BONDS_EXECUTABLE="$FAKE_BONDS" \
        BONDS_TEST_ENV_FILE="$ENV_FILE" \
        BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
            sh "$ENTRYPOINT" --fixture >"$LOG_FILE" 2>&1; then
        fail "$label was accepted"
    fi
    grep -Fq "$message" "$LOG_FILE" ||
        fail "$label did not report the expected error"
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
assert_env "DB_DRIVER=postgres"
assert_env "DB_DSN=host='postgres.local' port='5432' user='bonds' password='pg-secret-\$pass word' dbname='bonds' sslmode='verify-full'"
assert_env "APP_ENV=production"
assert_env "DEBUG=true"
assert_env "APP_URL=https://bonds.example.test:8080"
assert_env "STORAGE_UPLOAD_DIR=${CONFIG_DIR}/uploads"
assert_env "STORAGE_MAX_SIZE_MB=256"
assert_env "BLEVE_INDEX_PATH=${CONFIG_DIR}/bonds.bleve"
assert_env "BACKUP_DIR=${CONFIG_DIR}/backups"
assert_env "BACKUP_CRON=0 15 2 * * *"
assert_env "BACKUP_RETENTION=14"
[ "$(cat "$ARGS_FILE")" = "--fixture" ] || fail "Arguments were not forwarded"

SECRETS_FILE="${CONFIG_DIR}/.secrets"
[ -f "$SECRETS_FILE" ] || fail "Secrets file was not created"
secrets_mode=$(stat -c '%a' "$SECRETS_FILE" 2>/dev/null || stat -f '%Lp' "$SECRETS_FILE")
[ "$secrets_mode" = "600" ] ||
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
if grep -Fq 'pg-secret' "$LOG_FILE"; then
    fail "Database password leaked to logs"
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
assert_env "BACKUP_CRON=0 0 3 * * *"

LEGACY_CRON_OPTIONS="${TEMP_DIR}/legacy-cron-options.json"
jq '.backup_cron = "15 2 * * *"' "$OPTIONS" >"$LEGACY_CRON_OPTIONS"
ENV_FILE="${TEMP_DIR}/env-legacy-cron"
ARGS_FILE="${TEMP_DIR}/args-legacy-cron"
BONDS_OPTIONS_PATH="$LEGACY_CRON_OPTIONS" \
BONDS_CONFIG_DIR="$CONFIG_DIR" \
BONDS_EXECUTABLE="$FAKE_BONDS" \
BONDS_TEST_ENV_FILE="$ENV_FILE" \
BONDS_TEST_ARGS_FILE="$ARGS_FILE" \
    sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1

assert_env "BACKUP_CRON=0 15 2 * * *"

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

# SQLite remains the storage mode when selected explicitly.
SQLITE_OPTIONS="${TEMP_DIR}/sqlite-options.json"
jq '.database = "sqlite" | .postgres_host = "" | .postgres_password = ""' \
    "$OPTIONS" >"$SQLITE_OPTIONS"
SQLITE_CONFIG_DIR="${TEMP_DIR}/sqlite-config"
run_entrypoint "$SQLITE_OPTIONS" "$SQLITE_CONFIG_DIR" sqlite
assert_env "DB_DRIVER=sqlite"
assert_env "DB_DSN=${SQLITE_CONFIG_DIR}/bonds.db"

# An absent database option falls back to SQLite.
DEFAULT_DATABASE="${TEMP_DIR}/default-database.json"
jq 'del(.database)' "$OPTIONS" >"$DEFAULT_DATABASE"
DEFAULT_CONFIG_DIR="${TEMP_DIR}/default-config"
run_entrypoint "$DEFAULT_DATABASE" "$DEFAULT_CONFIG_DIR" default
assert_env "DB_DRIVER=sqlite"
assert_env "DB_DSN=${DEFAULT_CONFIG_DIR}/bonds.db"

# PostgreSQL DSN quoting protects spaces, quotes, and backslashes.
ESCAPED_PASSWORD="${TEMP_DIR}/escaped-password.json"
jq --arg password "quote'\\slash" \
    '.postgres_password = $password' "$OPTIONS" >"$ESCAPED_PASSWORD"
run_entrypoint "$ESCAPED_PASSWORD" "$CONFIG_DIR" escaped
assert_env "DB_DSN=host='postgres.local' port='5432' user='bonds' password='quote\\'\\\\slash' dbname='bonds' sslmode='verify-full'"

# An empty password is omitted so PGPASSFILE and peer authentication still work.
EMPTY_PASSWORD="${TEMP_DIR}/empty-password.json"
jq '.postgres_password = "" | .postgres_sslmode = "disable"' \
    "$OPTIONS" >"$EMPTY_PASSWORD"
run_entrypoint "$EMPTY_PASSWORD" "$CONFIG_DIR" empty-password
assert_env "DB_DSN=host='postgres.local' port='5432' user='bonds' dbname='bonds' sslmode='disable'"

# PostgreSQL mode warns about a SQLite database left behind in /config.
STALE_CONFIG_DIR="${TEMP_DIR}/stale-config"
mkdir -p "$STALE_CONFIG_DIR"
: >"${STALE_CONFIG_DIR}/bonds.db"
run_entrypoint "$OPTIONS" "$STALE_CONFIG_DIR" stale
grep -Fq "${STALE_CONFIG_DIR}/bonds.db stays unused" "$LOG_FILE" ||
    fail "Unused SQLite database did not raise a warning"

# Invalid options are rejected with an option-specific message.
INVALID_DATABASE="${TEMP_DIR}/invalid-database.json"
jq '.database = "mysql"' "$OPTIONS" >"$INVALID_DATABASE"
expect_failure "Unknown database backend" "$INVALID_DATABASE" \
    "Option 'database' must be sqlite or postgres"

INVALID_SSLMODE="${TEMP_DIR}/invalid-sslmode.json"
jq '.postgres_sslmode = "verify-ca"' "$OPTIONS" >"$INVALID_SSLMODE"
expect_failure "Unknown PostgreSQL TLS mode" "$INVALID_SSLMODE" \
    "Option 'postgres_sslmode' must be disable, require or verify-full"

MISSING_HOST="${TEMP_DIR}/missing-host.json"
jq '.postgres_host = ""' "$OPTIONS" >"$MISSING_HOST"
expect_failure "Empty PostgreSQL host" "$MISSING_HOST" \
    "Option 'postgres_host' is required when database is postgres"

MISSING_DB="${TEMP_DIR}/missing-db.json"
jq '.postgres_db = ""' "$OPTIONS" >"$MISSING_DB"
expect_failure "Empty PostgreSQL database" "$MISSING_DB" \
    "Option 'postgres_db' is required when database is postgres"

CONTROL_USER="${TEMP_DIR}/control-user.json"
jq '.postgres_user = "bond\u0009s"' "$OPTIONS" >"$CONTROL_USER"
expect_failure "Control character in PostgreSQL user" "$CONTROL_USER" \
    "Option 'postgres_user' must be a string without control characters"

CONTROL_APP_URL="${TEMP_DIR}/control-app-url.json"
jq '.app_url = "http://bonds.example.test:8080\u000d"' \
    "$OPTIONS" >"$CONTROL_APP_URL"
expect_failure "Control character in application URL" "$CONTROL_APP_URL" \
    "Option 'app_url' must be a non-empty string"

BAD_PORT="${TEMP_DIR}/bad-port.json"
jq '.postgres_port = 70000' "$OPTIONS" >"$BAD_PORT"
expect_failure "Out-of-range PostgreSQL port" "$BAD_PORT" \
    "Option 'postgres_port' must be an integer between 1 and 65535"

INVALID_OPTIONS="${TEMP_DIR}/invalid-options.json"
jq '.storage_max_size_mb = 0' "$OPTIONS" >"$INVALID_OPTIONS"
expect_failure "Invalid numeric value" "$INVALID_OPTIONS" \
    "Option 'storage_max_size_mb' must be a positive integer"

INVALID_CRON="${TEMP_DIR}/invalid-cron.json"
jq '.backup_cron = "0 15 * *"' "$OPTIONS" >"$INVALID_CRON"
expect_failure "Invalid backup cron" "$INVALID_CRON" \
    "Option 'backup_cron' must contain exactly 5 or 6 fields"

MALFORMED_OPTIONS="${TEMP_DIR}/malformed-options.json"
printf '%s' '{"database": ' >"$MALFORMED_OPTIONS"
expect_failure "Malformed options file" "$MALFORMED_OPTIONS" \
    "Invalid options file: expected a JSON object"

printf '%s\n' "Bonds adapter tests passed"
