#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
FAKE_UPSTREAM="${SCRIPT_DIR}/fixtures/fake-upstream"
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
    grep -Fqx -- "$1" "$ENV_FILE" || fail "Missing environment value: $1"
}

chmod 0755 "$FAKE_UPSTREAM"
ENV_FILE="${TEMP_DIR}/env"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"

run_entrypoint() {
    FLARESOLVERR_OPTIONS_PATH="$1" \
    FLARESOLVERR_TEST_ENV_FILE="$ENV_FILE" \
    FLARESOLVERR_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" "$FAKE_UPSTREAM" --fixture >"$LOG_FILE" 2>&1
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

# The pin itself lives in the Dockerfile and is bumped by Renovate.
grep -Eq 'ARG UPSTREAM_VERSION="[0-9][0-9.]*"' "$ADDON_DIR/Dockerfile" ||
    fail "Upstream version is not pinned"
# shellcheck disable=SC2016  # the literal Dockerfile expression is under test
grep -Fq \
    'FROM ghcr.io/flaresolverr/flaresolverr:v${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Upstream image is not immutably pinned"

# Options reach FlareSolverr, secrets stay out of the log.
run_entrypoint "$OPTIONS"
assert_env "HOST=0.0.0.0"
assert_env "PORT=8191"
assert_env "LOG_LEVEL=debug"
assert_env "LOG_HTML=true"
assert_env "DISABLE_MEDIA=true"
assert_env "PROXY_URL=http://proxy.example.com:3128"
assert_env "PROXY_PASSWORD=dummy-proxy-password"
grep -Fq "PROXY_PASSWORD" "$LOG_FILE" ||
    fail "Custom environment variable name was not logged"
if grep -Fq "dummy-proxy-password" "$LOG_FILE"; then
    fail "Secret value leaked into the log"
fi
[ "$(cat "$ARGS_FILE")" = "--fixture" ] || fail "Arguments were not forwarded"

# Defaults.
DEFAULT_OPTIONS="${TEMP_DIR}/default.json"
jq '.log_level = "info" | .log_html = false | .disable_media = false |
    .env_vars = []' "$OPTIONS" >"$DEFAULT_OPTIONS"
run_entrypoint "$DEFAULT_OPTIONS"
assert_env "LOG_LEVEL=info"
assert_env "LOG_HTML=false"
assert_env "DISABLE_MEDIA=false"

# Invalid options fail before upstream starts.
expect_rejected "Unknown log level" '.log_level = "trace"'
expect_rejected "String boolean" '.log_html = "true"'
expect_rejected "Missing disable_media" 'del(.disable_media)'
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Invalid options did not report expected error"

# Managed, protected, malformed, and control-character variables fail.
expect_rejected "Managed environment override" \
    '.env_vars = [{"name": "PORT", "value": "9"}]'
expect_rejected "Protected environment override" \
    '.env_vars = [{"name": "PATH", "value": "/tmp"}]'
expect_rejected "Library preload" \
    '.env_vars = [{"name": "LD_PRELOAD", "value": "/tmp/x.so"}]'
expect_rejected "Python path override" \
    '.env_vars = [{"name": "PYTHONPATH", "value": "/tmp"}]'
expect_rejected "Malformed environment variable name" \
    '.env_vars = [{"name": "bad-name", "value": "x"}]'
expect_rejected "Control character in custom value" \
    '.env_vars = [{"name": "PROXY_URL", "value": "a\u0009b"}]'

printf '%s\n' "flaresolverr adapter tests passed"
