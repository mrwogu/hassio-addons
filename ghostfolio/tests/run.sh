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
    ADDON_CONFIG_DIR="${2:-$CONFIG_DIR}" \
    ADDON_INIT="$FAKE_INIT" \
    ADDON_USER="" \
    ADDON_TEST_ENV_FILE="$ENV_FILE" \
    ADDON_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1
}

expect_failure() {
    options=$1
    label=$2
    if run_entrypoint "$options"; then
        fail "$label was accepted"
    fi
    grep -Fq "[ghostfolio-addon] Error:" "$LOG_FILE" ||
        fail "$label did not report an adapter error"
}

# Valid options are translated to upstream environment variables.
run_entrypoint "$OPTIONS" || fail "Valid options were rejected: $(cat "$LOG_FILE")"

# The password is percent-encoded so it cannot break the connection URL.
assert_env "DATABASE_URL=postgresql://ghostfolio:pg-secret-%24pass%20word%40%2F%3A@postgres.local:5432/ghostfolio?connect_timeout=300&sslmode=prefer"
assert_env "REDIS_HOST=redis.local"
assert_env "REDIS_PORT=6379"
assert_env "REDIS_DB=2"
assert_env "REDIS_PASSWORD=redis-secret"
assert_env "REDIS_TLS=false"
assert_env "HOST=0.0.0.0"
assert_env "PORT=3333"
# The trailing slash is dropped so upstream callback URLs stay clean.
assert_env "ROOT_URL=https://ghostfolio.example.com"
assert_env 'LOG_LEVELS=["error","warn","log"]'
assert_env "ENABLE_FEATURE_AUTH_TOKEN=true"
assert_env "ENABLE_FEATURE_SECURITY_HEADERS=false"
assert_env "ENABLE_FEATURE_MCP=false"
assert_env "ENABLE_FEATURE_AUTH_OIDC=false"
refute_env_key "API_KEY_COINGECKO_DEMO"
refute_env_key "API_KEY_COINGECKO_PRO"
refute_env_key "OIDC_ISSUER"
refute_env_key "OIDC_CLIENT_ID"
refute_env_key "OIDC_CLIENT_SECRET"
grep -Eq '^ACCESS_TOKEN_SALT=[0-9a-f]{64}$' "$ENV_FILE" ||
    fail "Access token salt was not exported"
grep -Eq '^JWT_SECRET_KEY=[0-9a-f]{64}$' "$ENV_FILE" ||
    fail "JWT secret key was not exported"
# Custom advanced variables are exported and their names logged.
assert_env "REQUEST_TIMEOUT=5000"
grep -Fq "REQUEST_TIMEOUT" "$LOG_FILE" ||
    fail "Custom environment variable name was not logged"
[ "$(cat "$ARGS_FILE")" = "" ] || fail "Unexpected launcher arguments"

# Generated secrets are persisted privately and reused across restarts.
for key in access_token_salt jwt_secret_key; do
    [ -f "${CONFIG_DIR}/${key}" ] || fail "Secret file was not created: $key"
    [ "$(file_mode "${CONFIG_DIR}/${key}")" = "600" ] ||
        fail "Secret file is not owner-only (0600): $key"
done
first_salt=$(env_value "ACCESS_TOKEN_SALT")
first_jwt=$(env_value "JWT_SECRET_KEY")
[ "$first_salt" != "$first_jwt" ] || fail "Generated secrets are identical"
run_entrypoint "$OPTIONS" || fail "Restart was rejected"
[ "$first_salt" = "$(env_value "ACCESS_TOKEN_SALT")" ] ||
    fail "Access token salt was not stable across restarts"
[ "$first_jwt" = "$(env_value "JWT_SECRET_KEY")" ] ||
    fail "JWT secret key was not stable across restarts"

# Secrets are never written to the log.
for secret in "$first_salt" "$first_jwt" pg-secret redis-secret; do
    if grep -Fq "$secret" "$LOG_FILE"; then
        fail "Secret leaked into the log"
    fi
done

# Provided secrets are used verbatim and no secret files are generated.
PROVIDED="${TEMP_DIR}/provided.json"
PROVIDED_CONFIG="${TEMP_DIR}/provided-config"
jq '.access_token_salt = "provided-salt" | .jwt_secret_key = "provided-jwt"' \
    "$OPTIONS" >"$PROVIDED"
run_entrypoint "$PROVIDED" "$PROVIDED_CONFIG" || fail "Provided secrets were rejected"
assert_env "ACCESS_TOKEN_SALT=provided-salt"
assert_env "JWT_SECRET_KEY=provided-jwt"
[ ! -e "${PROVIDED_CONFIG}/access_token_salt" ] ||
    fail "Salt file created despite a provided salt"
[ ! -e "${PROVIDED_CONFIG}/jwt_secret_key" ] ||
    fail "JWT file created despite a provided key"

# Optional features, API keys, OIDC, IPv6 hosts, and log levels map through.
FEATURES="${TEMP_DIR}/features.json"
jq '.postgres_host = "fd00::10"
    | .postgres_sslmode = "require"
    | .redis_tls = true
    | .redis_password = ""
    | .root_url = ""
    | .log_level = "verbose"
    | .enable_auth_token = false
    | .enable_security_headers = true
    | .enable_mcp = true
    | .api_key_coingecko_demo = "cg-demo"
    | .api_key_coingecko_pro = "cg-pro"
    | .oidc_enabled = true
    | .oidc_issuer = "https://auth.example.com/application/o/ghostfolio/"
    | .oidc_client_id = "ghostfolio"
    | .oidc_client_secret = "oidc-secret"' "$OPTIONS" >"$FEATURES"
run_entrypoint "$FEATURES" || fail "Feature options were rejected: $(cat "$LOG_FILE")"
assert_env "DATABASE_URL=postgresql://ghostfolio:pg-secret-%24pass%20word%40%2F%3A@[fd00::10]:5432/ghostfolio?connect_timeout=300&sslmode=require"
assert_env "REDIS_TLS=true"
assert_env "REDIS_PASSWORD="
refute_env_key "ROOT_URL"
assert_env 'LOG_LEVELS=["error","warn","log","debug","verbose"]'
assert_env "ENABLE_FEATURE_AUTH_TOKEN=false"
assert_env "ENABLE_FEATURE_SECURITY_HEADERS=true"
assert_env "ENABLE_FEATURE_MCP=true"
assert_env "API_KEY_COINGECKO_DEMO=cg-demo"
assert_env "API_KEY_COINGECKO_PRO=cg-pro"
assert_env "ENABLE_FEATURE_AUTH_OIDC=true"
assert_env "OIDC_ISSUER=https://auth.example.com/application/o/ghostfolio/"
assert_env "OIDC_CLIENT_ID=ghostfolio"
assert_env "OIDC_CLIENT_SECRET=oidc-secret"
if grep -Fq "oidc-secret" "$LOG_FILE"; then
    fail "OIDC client secret leaked into the log"
fi

# OIDC without its required settings is rejected.
OIDC_MISSING="${TEMP_DIR}/oidc-missing.json"
jq '.oidc_enabled = true | .oidc_issuer = "https://auth.example.com"' \
    "$OPTIONS" >"$OIDC_MISSING"
expect_failure "$OIDC_MISSING" "OIDC without client settings"
grep -Fq "OIDC needs" "$LOG_FILE" ||
    fail "Missing OIDC settings did not report the expected error"

# Missing required values are rejected.
EMPTY_HOST="${TEMP_DIR}/empty-host.json"
jq '.postgres_host = ""' "$OPTIONS" >"$EMPTY_HOST"
expect_failure "$EMPTY_HOST" "Empty PostgreSQL host"
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Empty host did not report the expected error"

EMPTY_REDIS="${TEMP_DIR}/empty-redis.json"
jq '.redis_host = ""' "$OPTIONS" >"$EMPTY_REDIS"
expect_failure "$EMPTY_REDIS" "Empty Redis host"

EMPTY_PASSWORD="${TEMP_DIR}/empty-password.json"
jq '.postgres_password = ""' "$OPTIONS" >"$EMPTY_PASSWORD"
expect_failure "$EMPTY_PASSWORD" "Empty PostgreSQL password"

# A host that could inject URL parts is rejected.
URL_HOST="${TEMP_DIR}/url-host.json"
jq '.postgres_host = "evil.local/other?x=1"' "$OPTIONS" >"$URL_HOST"
expect_failure "$URL_HOST" "PostgreSQL host with URL parts"

# A control character in a user string is rejected.
CONTROL="${TEMP_DIR}/control.json"
jq '.postgres_user = "ghost\u0009folio"' "$OPTIONS" >"$CONTROL"
expect_failure "$CONTROL" "Control character in database user"

# Out-of-range ports and Redis databases are rejected.
BAD_PORT="${TEMP_DIR}/bad-port.json"
jq '.postgres_port = 70000' "$OPTIONS" >"$BAD_PORT"
expect_failure "$BAD_PORT" "Out-of-range PostgreSQL port"

BAD_REDIS_DB="${TEMP_DIR}/bad-redis-db.json"
jq '.redis_db = 16' "$OPTIONS" >"$BAD_REDIS_DB"
expect_failure "$BAD_REDIS_DB" "Out-of-range Redis database"

# A root URL without an HTTP scheme is rejected.
BAD_ROOT_URL="${TEMP_DIR}/bad-root-url.json"
jq '.root_url = "javascript:alert(1)"' "$OPTIONS" >"$BAD_ROOT_URL"
expect_failure "$BAD_ROOT_URL" "Root URL without an HTTP scheme"

# An unknown log level is rejected.
BAD_LOG_LEVEL="${TEMP_DIR}/bad-log-level.json"
jq '.log_level = "trace"' "$OPTIONS" >"$BAD_LOG_LEVEL"
expect_failure "$BAD_LOG_LEVEL" "Unknown log level"

# A custom variable that overrides a managed one is rejected.
MANAGED_OVERRIDE="${TEMP_DIR}/managed-env.json"
jq '.env_vars = [{"name": "JWT_SECRET_KEY", "value": "nope"}]' \
    "$OPTIONS" >"$MANAGED_OVERRIDE"
expect_failure "$MANAGED_OVERRIDE" "Managed environment override"
grep -Fq "JWT_SECRET_KEY" "$LOG_FILE" ||
    fail "Managed override did not report the offending name"

# A custom variable that overrides a protected one is rejected.
PROTECTED_OVERRIDE="${TEMP_DIR}/protected-env.json"
jq '.env_vars = [{"name": "NODE_OPTIONS", "value": "--require=/tmp/x.js"}]' \
    "$OPTIONS" >"$PROTECTED_OVERRIDE"
expect_failure "$PROTECTED_OVERRIDE" "Protected environment override"

# A malformed custom variable name is rejected.
BAD_NAME="${TEMP_DIR}/bad-name.json"
jq '.env_vars = [{"name": "bad-name", "value": "x"}]' "$OPTIONS" >"$BAD_NAME"
expect_failure "$BAD_NAME" "Malformed custom environment name"

# A control character in a custom value is rejected.
CONTROL_VALUE="${TEMP_DIR}/control-value.json"
jq '.env_vars = [{"name": "GHOSTFOLIO_EXTRA", "value": "a\u0009b"}]' \
    "$OPTIONS" >"$CONTROL_VALUE"
expect_failure "$CONTROL_VALUE" "Control character in custom value"
grep -Fq "control characters" "$LOG_FILE" ||
    fail "Control character value did not report the expected error"

printf '%s\n' "Ghostfolio adapter tests passed"
