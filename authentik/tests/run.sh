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
    # GNU stat first (Linux CI); fall back to BSD stat (macOS). The BSD form
    # does not fail cleanly on GNU, so it must not come first.
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

chmod 0755 "$FAKE_INIT"
CONFIG_DIR="${TEMP_DIR}/config"
ENV_FILE="${TEMP_DIR}/env"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"

run_entrypoint() {
    ADDON_OPTIONS_PATH="$1" \
    ADDON_CONFIG_DIR="$CONFIG_DIR" \
    ADDON_INIT="$FAKE_INIT" \
    ADDON_TEST_ENV_FILE="$ENV_FILE" \
    ADDON_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1
}

# Valid options are translated to upstream environment variables.
run_entrypoint "$OPTIONS"

assert_env "AUTHENTIK_POSTGRESQL__HOST=postgres.local"
assert_env "AUTHENTIK_POSTGRESQL__PORT=5432"
assert_env "AUTHENTIK_POSTGRESQL__NAME=authentik"
assert_env "AUTHENTIK_POSTGRESQL__USER=authentik"
# shellcheck disable=SC2016  # the literal $ is part of the password under test
assert_env 'AUTHENTIK_POSTGRESQL__PASSWORD=pg-secret-$pass word'
assert_env "AUTHENTIK_REDIS__HOST=redis.local"
assert_env "AUTHENTIK_REDIS__PORT=6379"
assert_env "AUTHENTIK_REDIS__DB=2"
assert_env "AUTHENTIK_REDIS__PASSWORD=redis-secret"
assert_env "AUTHENTIK_LOG_LEVEL=warning"
assert_env "AUTHENTIK_ERROR_REPORTING__ENABLED=false"
assert_env "AUTHENTIK_STORAGE__FILE__PATH=${CONFIG_DIR}/data"
assert_env "AUTHENTIK_CERT_DISCOVERY_DIR=${CONFIG_DIR}/certs"
assert_env "AUTHENTIK_EMAIL__TEMPLATE_DIR=${CONFIG_DIR}/templates"
# Managed variables are forced regardless of user input.
assert_env "AUTHENTIK_DISABLE_UPDATE_CHECK=true"
assert_env "AUTHENTIK_DISABLE_STARTUP_ANALYTICS=true"
grep -Eq '^AUTHENTIK_SECRET_KEY=.' "$ENV_FILE" || fail "Secret key was not exported"
# Custom advanced variables are exported and their names logged.
assert_env "AUTHENTIK_EMAIL__HOST=smtp.local"
grep -Fq "AUTHENTIK_EMAIL__HOST" "$LOG_FILE" ||
    fail "Custom environment variable name was not logged"
# The single process runs server and worker together.
[ "$(cat "$ARGS_FILE")" = "allinone" ] || fail "allinone was not requested"

# Persistent directories are created under /config.
for dir in data certs templates; do
    [ -d "${CONFIG_DIR}/${dir}" ] || fail "Missing persistent directory: $dir"
done

# The generated secret key is persisted privately and reused across restarts.
SECRET_FILE="${CONFIG_DIR}/secret_key"
[ -f "$SECRET_FILE" ] || fail "Secret key file was not created"
[ "$(file_mode "$SECRET_FILE")" = "600" ] ||
    fail "Secret key file is not owner-only (0600)"
first_secret=$(env_value "AUTHENTIK_SECRET_KEY")
run_entrypoint "$OPTIONS"
second_secret=$(env_value "AUTHENTIK_SECRET_KEY")
if [ -z "$first_secret" ] || [ "$first_secret" != "$second_secret" ]; then
    fail "Generated secret key was not stable across restarts"
fi

# Secrets are never written to the log.
if grep -Fq "$first_secret" "$LOG_FILE"; then
    fail "Secret key leaked into the log"
fi
if grep -Fq 'pg-secret' "$LOG_FILE"; then
    fail "Database password leaked into the log"
fi

# A provided secret key is used verbatim and no key file is generated.
PROVIDED="${TEMP_DIR}/provided.json"
PROVIDED_CONFIG="${TEMP_DIR}/provided-config"
jq '.secret_key = "provided-signing-key-123"' "$OPTIONS" >"$PROVIDED"
ADDON_OPTIONS_PATH="$PROVIDED" \
ADDON_CONFIG_DIR="$PROVIDED_CONFIG" \
ADDON_INIT="$FAKE_INIT" \
ADDON_TEST_ENV_FILE="$ENV_FILE" \
ADDON_TEST_ARGS_FILE="$ARGS_FILE" \
    sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1
assert_env "AUTHENTIK_SECRET_KEY=provided-signing-key-123"
[ ! -e "${PROVIDED_CONFIG}/secret_key" ] ||
    fail "Secret key file created despite a provided key"

# The optional Redis password is omitted when blank.
NO_REDIS_PW="${TEMP_DIR}/no-redis-pw.json"
jq '.redis_password = ""' "$OPTIONS" >"$NO_REDIS_PW"
run_entrypoint "$NO_REDIS_PW"
refute_env_key "AUTHENTIK_REDIS__PASSWORD"
assert_env "AUTHENTIK_REDIS__HOST=redis.local"

# A missing required value is rejected.
EMPTY_HOST="${TEMP_DIR}/empty-host.json"
jq '.postgres_host = ""' "$OPTIONS" >"$EMPTY_HOST"
if run_entrypoint "$EMPTY_HOST"; then
    fail "Empty PostgreSQL host was accepted"
fi
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Empty host did not report the expected error"

# A control character in a user string is rejected.
CONTROL="${TEMP_DIR}/control.json"
jq '.postgres_user = "auth\u0009entik"' "$OPTIONS" >"$CONTROL"
if run_entrypoint "$CONTROL"; then
    fail "Control character in database user was accepted"
fi

# An out-of-range Redis database is rejected.
BAD_DB="${TEMP_DIR}/bad-db.json"
jq '.redis_db = 99' "$OPTIONS" >"$BAD_DB"
if run_entrypoint "$BAD_DB"; then
    fail "Out-of-range Redis database was accepted"
fi

# A custom variable that overrides a managed one is rejected.
MANAGED_OVERRIDE="${TEMP_DIR}/managed-env.json"
jq '.env_vars = [{"name": "AUTHENTIK_SECRET_KEY", "value": "nope"}]' \
    "$OPTIONS" >"$MANAGED_OVERRIDE"
if run_entrypoint "$MANAGED_OVERRIDE"; then
    fail "Managed environment override was accepted"
fi
grep -Fq "AUTHENTIK_SECRET_KEY" "$LOG_FILE" ||
    fail "Managed override did not report the offending name"

# A custom variable that overrides a protected one is rejected.
PROTECTED_OVERRIDE="${TEMP_DIR}/protected-env.json"
jq '.env_vars = [{"name": "PATH", "value": "/tmp"}]' \
    "$OPTIONS" >"$PROTECTED_OVERRIDE"
if run_entrypoint "$PROTECTED_OVERRIDE"; then
    fail "Protected environment override was accepted"
fi

# A malformed custom variable name is rejected.
BAD_NAME="${TEMP_DIR}/bad-name.json"
jq '.env_vars = [{"name": "bad-name", "value": "x"}]' "$OPTIONS" >"$BAD_NAME"
if run_entrypoint "$BAD_NAME"; then
    fail "Malformed custom environment name was accepted"
fi

# A control character in a custom value is rejected.
CONTROL_VALUE="${TEMP_DIR}/control-value.json"
jq '.env_vars = [{"name": "AUTHENTIK_EXTRA", "value": "a\u0009b"}]' \
    "$OPTIONS" >"$CONTROL_VALUE"
if run_entrypoint "$CONTROL_VALUE"; then
    fail "Control character in custom value was accepted"
fi
grep -Fq "control characters" "$LOG_FILE" ||
    fail "Control character value did not report the expected error"

printf '%s\n' "authentik adapter tests passed"
