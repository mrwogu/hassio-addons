#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
FAKE_INIT="${SCRIPT_DIR}/fixtures/fake-init"
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
CONFIG_DIR="${TEMP_DIR}/config"
ENV_FILE="${TEMP_DIR}/env"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"
mkdir -p "${CONFIG_DIR}.upstream-backups"
printf '%s\n' "bundled" >"${CONFIG_DIR}.upstream-backups/example.json.gz"

run_entrypoint() {
    config_dir=${2:-$CONFIG_DIR}
    upstream_backup_dir="${config_dir}.upstream-backups"
    TUDUDI_OPTIONS_PATH="$1" \
    TUDUDI_CONFIG_DIR="$config_dir" \
    TUDUDI_INIT="$FAKE_INIT" \
    TUDUDI_SKIP_CHOWN=true \
    TUDUDI_TEST_ENV_FILE="$ENV_FILE" \
    TUDUDI_TEST_ARGS_FILE="$ARGS_FILE" \
    TUDUDI_UPSTREAM_BACKUP_DIR="$upstream_backup_dir" \
        sh "$ENTRYPOINT" --fixture >"$LOG_FILE" 2>&1
}

grep -Fq 'ARG UPSTREAM_VERSION="1.4.0"' "$ADDON_DIR/Dockerfile" ||
    fail "Upstream version is not pinned"
# shellcheck disable=SC2016  # the literal Dockerfile expression is under test
grep -Fq \
    'FROM chrisvel/tududi:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Upstream image is not immutably pinned"

# Structured settings reach Tududi and custom variables do not expose values
# in the adapter log.
run_entrypoint "$OPTIONS"
assert_env "NODE_ENV=production"
assert_env "HOST=0.0.0.0"
assert_env "PORT=3002"
assert_env "DB_FILE=${CONFIG_DIR}/db/production.sqlite3"
assert_env "TUDUDI_USER_EMAIL=admin@example.com"
assert_env "TUDUDI_USER_PASSWORD=dummy-admin-password"
assert_env "TUDUDI_ALLOWED_ORIGINS=https://tududi.example.com"
assert_env "TUDUDI_UPLOAD_PATH=${CONFIG_DIR}/uploads"
assert_env "TUDUDI_TRUST_PROXY=true"
assert_env "COOKIE_SECURE=true"
assert_env "FILE_UPLOAD_LIMIT_MB=25"
assert_env "DISABLE_SCHEDULER=false"
assert_env "DISABLE_TELEGRAM=true"
assert_env "SWAGGER_ENABLED=false"
assert_env "FF_ENABLE_BACKUPS=true"
assert_env "FF_ENABLE_CALDAV=true"
assert_env "CALDAV_ENABLED=true"
assert_env "FF_ENABLE_MCP=false"
encryption_key=$(env_value "ENCRYPTION_KEY")
[ -n "$encryption_key" ] || fail "Generated CalDAV encryption key is empty"
assert_env "BASE_URL=https://tududi.example.com"
assert_env "OIDC_ENABLED=true"
assert_env "OIDC_CLIENT_SECRET=dummy-client-secret"
grep -Fq "OIDC_CLIENT_SECRET" "$LOG_FILE" ||
    fail "Custom environment variable name was not logged"
if grep -Fq "dummy-client-secret" "$LOG_FILE"; then
    fail "Custom environment variable value leaked into the log"
fi
[ "$(cat "$ARGS_FILE")" = "--fixture" ] || fail "Arguments were not forwarded"

# CalDAV's scheduler stays disabled unless the feature is explicitly enabled.
DISABLED_CALDAV_OPTIONS="${TEMP_DIR}/disabled-caldav-options.json"
jq '.enable_caldav = false' "$OPTIONS" >"$DISABLED_CALDAV_OPTIONS"
run_entrypoint "$DISABLED_CALDAV_OPTIONS" "${TEMP_DIR}/disabled-caldav-config"
assert_env "CALDAV_ENABLED=false"

# Database, uploads, backups, and generated secrets persist across restarts.
[ -d "${CONFIG_DIR}/db" ] || fail "Missing persistent database directory"
[ -d "${CONFIG_DIR}/uploads" ] || fail "Missing persistent upload directory"
[ -d "${CONFIG_DIR}/backups" ] || fail "Missing persistent backup directory"
[ -L "${CONFIG_DIR}.upstream-backups" ] ||
    fail "Missing upstream backup symlink"
[ "$(readlink "${CONFIG_DIR}.upstream-backups")" = "${CONFIG_DIR}/backups" ] ||
    fail "Upstream backup symlink points outside persistent storage"
[ "$(cat "${CONFIG_DIR}.upstream-backups.image/example.json.gz")" = "bundled" ] ||
    fail "Bundled backup directory was not preserved"
printf '%s\n' "stored" >"${CONFIG_DIR}/uploads/file.txt"
printf '%s\n' "backup" >"${CONFIG_DIR}/backups/export.json.gz"
SECRET_FILE="${CONFIG_DIR}/session_secret"
ENCRYPTION_FILE="${CONFIG_DIR}/caldav_encryption_key"
[ -f "$SECRET_FILE" ] || fail "Session secret file was not created"
[ "$(file_mode "$SECRET_FILE")" = "600" ] ||
    fail "Session secret file is not owner-only (0600)"
[ -f "$ENCRYPTION_FILE" ] || fail "CalDAV encryption key was not created"
[ "$(file_mode "$ENCRYPTION_FILE")" = "600" ] ||
    fail "CalDAV encryption key is not owner-only (0600)"
run_entrypoint "$OPTIONS"
first_secret=$(env_value "TUDUDI_SESSION_SECRET")
first_encryption_key=$(env_value "ENCRYPTION_KEY")
run_entrypoint "$OPTIONS"
second_secret=$(env_value "TUDUDI_SESSION_SECRET")
second_encryption_key=$(env_value "ENCRYPTION_KEY")
[ -n "$first_secret" ] || fail "Generated session secret is empty"
[ "$first_secret" = "$second_secret" ] ||
    fail "Generated session secret was not stable across restarts"
[ "$first_encryption_key" = "$second_encryption_key" ] ||
    fail "CalDAV encryption key was not stable across restarts"
[ "$(cat "${CONFIG_DIR}/uploads/file.txt")" = "stored" ] ||
    fail "Persisted upload data was not retained"
[ "$(cat "${CONFIG_DIR}/backups/export.json.gz")" = "backup" ] ||
    fail "Persisted Tududi backup was not retained"
if grep -Fq "$first_secret" "$LOG_FILE"; then
    fail "Session secret leaked into the log"
fi
if grep -Fq "$first_encryption_key" "$LOG_FILE"; then
    fail "CalDAV encryption key leaked into the log"
fi
if grep -Fq "dummy-admin-password" "$LOG_FILE"; then
    fail "User password leaked into the log"
fi

# Initial credentials are suppressed after the database contains a user.
sqlite3 "${CONFIG_DIR}/db/production.sqlite3" \
    'CREATE TABLE users (id INTEGER PRIMARY KEY);
     INSERT INTO users DEFAULT VALUES;'
run_entrypoint "$OPTIONS"
assert_env "TUDUDI_USER_EMAIL="
assert_env "TUDUDI_USER_PASSWORD="
grep -Fq "skipping credential bootstrap" "$LOG_FILE" ||
    fail "Existing user did not report skipped credential bootstrap"

# A supplied session secret is used without creating a generated secret.
PROVIDED_OPTIONS="${TEMP_DIR}/provided-options.json"
PROVIDED_CONFIG="${TEMP_DIR}/provided-config"
jq '.session_secret = "provided-session-secret-012345678901234567890123" |
    .user_email = "" | .user_password = "" | .base_url = ""' \
    "$OPTIONS" >"$PROVIDED_OPTIONS"
run_entrypoint "$PROVIDED_OPTIONS" "$PROVIDED_CONFIG"
assert_env "TUDUDI_SESSION_SECRET=provided-session-secret-012345678901234567890123"
[ ! -e "${PROVIDED_CONFIG}/session_secret" ] ||
    fail "Session secret file created despite a supplied secret"
refute_env_key "BASE_URL"

# Credentials and supplied secrets must satisfy upstream constraints.
MISSING_PASSWORD="${TEMP_DIR}/missing-password.json"
jq '.user_password = ""' "$OPTIONS" >"$MISSING_PASSWORD"
if run_entrypoint "$MISSING_PASSWORD"; then
    fail "Mismatched credentials were accepted"
fi
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Mismatched credentials did not report expected error"

INVALID_EMAIL="${TEMP_DIR}/invalid-email.json"
jq '.user_email = "not-an-email"' "$OPTIONS" >"$INVALID_EMAIL"
if run_entrypoint "$INVALID_EMAIL"; then
    fail "Invalid email was accepted"
fi

SHORT_PASSWORD="${TEMP_DIR}/short-password.json"
jq '.user_password = "short"' "$OPTIONS" >"$SHORT_PASSWORD"
if run_entrypoint "$SHORT_PASSWORD"; then
    fail "Short initial password was accepted"
fi

SHORT_SECRET="${TEMP_DIR}/short-secret.json"
jq '.session_secret = "short-session-secret"' "$OPTIONS" >"$SHORT_SECRET"
if run_entrypoint "$SHORT_SECRET"; then
    fail "Short session secret was accepted"
fi

# Managed, protected, malformed, and control-character custom variables fail.
MANAGED_OVERRIDE="${TEMP_DIR}/managed-env.json"
jq '.env_vars = [{"name": "DB_FILE", "value": "/tmp/db"}]' \
    "$OPTIONS" >"$MANAGED_OVERRIDE"
if run_entrypoint "$MANAGED_OVERRIDE"; then
    fail "Managed environment override was accepted"
fi

ENCRYPTION_OVERRIDE="${TEMP_DIR}/encryption-env.json"
jq '.env_vars = [{"name": "ENCRYPTION_KEY", "value": "override"}]' \
    "$OPTIONS" >"$ENCRYPTION_OVERRIDE"
if run_entrypoint "$ENCRYPTION_OVERRIDE"; then
    fail "Managed CalDAV encryption key override was accepted"
fi

PROTECTED_OVERRIDE="${TEMP_DIR}/protected-env.json"
jq '.env_vars = [{"name": "PATH", "value": "/tmp"}]' \
    "$OPTIONS" >"$PROTECTED_OVERRIDE"
if run_entrypoint "$PROTECTED_OVERRIDE"; then
    fail "Protected environment override was accepted"
fi

BAD_NAME="${TEMP_DIR}/bad-name.json"
jq '.env_vars = [{"name": "bad-name", "value": "x"}]' \
    "$OPTIONS" >"$BAD_NAME"
if run_entrypoint "$BAD_NAME"; then
    fail "Malformed environment variable name was accepted"
fi

CONTROL_VALUE="${TEMP_DIR}/control-value.json"
jq '.env_vars = [{"name": "OIDC_EXTRA", "value": "a\u0009b"}]' \
    "$OPTIONS" >"$CONTROL_VALUE"
if run_entrypoint "$CONTROL_VALUE"; then
    fail "Control character in custom value was accepted"
fi

printf '%s\n' "Tududi adapter tests passed"
