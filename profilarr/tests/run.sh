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

chmod 0755 "$FAKE_INIT"
ENV_FILE="${TEMP_DIR}/env"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"

run_entrypoint() {
    PROFILARR_OPTIONS_PATH="$1" \
    PROFILARR_INIT="$FAKE_INIT" \
    PROFILARR_TEST_ENV_FILE="$ENV_FILE" \
    PROFILARR_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" --fixture >"$LOG_FILE" 2>&1
}

expect_rejected() {
    description=$1
    filter=$2
    candidate="${TEMP_DIR}/rejected.json"
    jq "$filter" "$OPTIONS" >"$candidate"
    if run_entrypoint "$candidate"; then
        fail "$description was accepted"
    fi
}

# The version is intentionally not pinned to a literal here: Renovate bumps
# it on every upstream release and the pin itself lives in the Dockerfile.
grep -Eq 'ARG UPSTREAM_VERSION="[0-9][0-9.]*"' "$ADDON_DIR/Dockerfile" ||
    fail "Upstream version is not pinned"
# shellcheck disable=SC2016  # the literal Dockerfile expression is under test
grep -Fq \
    'FROM ghcr.io/dictionarry-hub/profilarr:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Upstream image is not immutably pinned"

# Structured settings reach Profilarr and secrets stay out of the log.
run_entrypoint "$OPTIONS"
assert_env "PORT=6868"
assert_env "HOST=0.0.0.0"
assert_env "APP_BASE_PATH=/config"
assert_env "AUTH=oidc"
assert_env "ORIGIN=https://profilarr.example.com"
assert_env "PROFILARR_API_KEY=dummy-api-key-0123456789abcdef0123"
assert_env "OIDC_DISCOVERY_URL=https://auth.example.com/.well-known/openid-configuration"
assert_env "OIDC_CLIENT_ID=profilarr"
assert_env "OIDC_CLIENT_SECRET=dummy-oidc-secret"
assert_env "PARSER_HOST=parser.example.com"
assert_env "PROFILARR_BULLETIN_URL=dummy-bulletin-url"
grep -Fq "PROFILARR_BULLETIN_URL" "$LOG_FILE" ||
    fail "Custom environment variable name was not logged"
for secret in dummy-api-key dummy-oidc-secret dummy-bulletin-url; do
    if grep -Fq "$secret" "$LOG_FILE"; then
        fail "Secret value leaked into the log: $secret"
    fi
done
[ "$(cat "$ARGS_FILE")" = "--fixture" ] || fail "Arguments were not forwarded"

# Default local auth needs no OIDC settings or API key.
DEFAULT_OPTIONS="${TEMP_DIR}/default.json"
jq '.auth = "on" | .origin = "" | .api_key = "" | .oidc_discovery_url = "" |
    .oidc_client_id = "" | .oidc_client_secret = "" | .env_vars = []' \
    "$OPTIONS" >"$DEFAULT_OPTIONS"
run_entrypoint "$DEFAULT_OPTIONS"
assert_env "AUTH=on"
assert_env "PROFILARR_API_KEY="

# Disabled auth starts but warns.
OFF_OPTIONS="${TEMP_DIR}/off.json"
jq '.auth = "off"' "$DEFAULT_OPTIONS" >"$OFF_OPTIONS"
run_entrypoint "$OFF_OPTIONS"
assert_env "AUTH=off"
grep -Fq "authentication is disabled" "$LOG_FILE" ||
    fail "Disabled auth did not warn"

# Invalid structured options fail before upstream starts.
expect_rejected "Unknown auth mode" '.auth = "local"'
expect_rejected "OIDC without origin" '.origin = ""'
expect_rejected "OIDC without client secret" '.oidc_client_secret = ""'
expect_rejected "Non-HTTP origin" '.origin = "javascript:alert(1)"'
expect_rejected "Short API key" '.api_key = "short-api-key"'
expect_rejected "API key with whitespace" \
    '.api_key = "dummy api key 0123456789abcdef0123"'
expect_rejected "Control character in OIDC client id" \
    '.oidc_client_id = "a\u0009b"'
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Invalid options did not report expected error"

# Managed, protected, malformed, and control-character custom variables fail.
expect_rejected "Managed environment override" \
    '.env_vars = [{"name": "APP_BASE_PATH", "value": "/tmp"}]'
expect_rejected "Protected environment override" \
    '.env_vars = [{"name": "PUID", "value": "0"}]'
expect_rejected "Upstream secret file indirection" \
    '.env_vars = [{"name": "OIDC_CLIENT_SECRET_FILE", "value": "/etc/shadow"}]'
expect_rejected "Deno runtime override" \
    '.env_vars = [{"name": "DENO_DIR", "value": "/tmp"}]'
expect_rejected "Malformed environment variable name" \
    '.env_vars = [{"name": "bad-name", "value": "x"}]'
expect_rejected "Control character in custom value" \
    '.env_vars = [{"name": "PARSER_HOST", "value": "a\u0009b"}]'

printf '%s\n' "Profilarr adapter tests passed"
