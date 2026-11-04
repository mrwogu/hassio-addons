#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
FAKE_LOKI="${SCRIPT_DIR}/fixtures/fake-loki"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}

chmod 0755 "$FAKE_LOKI"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"
DATA_DIR="${TEMP_DIR}/config"
CONFIG="${DATA_DIR}/loki.yaml"

run_entrypoint() {
    LOKI_OPTIONS_PATH="$1" \
    LOKI_DATA_DIR="$DATA_DIR" \
    LOKI_BIN="$FAKE_LOKI" \
    LOKI_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1
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

assert_config() {
    grep -Fq -- "$1" "$CONFIG" || fail "Missing config line: $1"
}

# The pin itself lives in the Dockerfile and is bumped by Renovate.
grep -Eq 'ARG UPSTREAM_VERSION="[0-9][0-9.]*"' "$ADDON_DIR/Dockerfile" ||
    fail "Upstream version is not pinned"
# shellcheck disable=SC2016  # the literal Dockerfile expression is under test
grep -Fq \
    'FROM docker.io/grafana/loki:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Upstream image is not immutably pinned"

# Defaults render a 30 day retention and hand the config to Loki.
run_entrypoint "$OPTIONS"
assert_config "retention_period: 720h"
assert_config "retention_enabled: true"
assert_config "log_level: info"
assert_config "path_prefix: ${DATA_DIR}/data"
grep -Fqx -- "-config.file=${CONFIG}" "$ARGS_FILE" ||
    fail "Loki was not started with the rendered config"
[ -d "${DATA_DIR}/data" ] || fail "Data directory was not created"

# Custom values are applied on the next start.
custom="${TEMP_DIR}/custom.json"
jq '.retention_days = 7 | .log_level = "warn"' "$OPTIONS" >"$custom"
run_entrypoint "$custom"
assert_config "retention_period: 168h"
assert_config "log_level: warn"

expect_rejected "zero retention" '.retention_days = 0'
expect_rejected "huge retention" '.retention_days = 4000'
expect_rejected "fractional retention" '.retention_days = 1.5'
expect_rejected "string retention" '.retention_days = "30"'
expect_rejected "unknown log level" '.log_level = "trace"'
expect_rejected "missing log level" 'del(.log_level)'

printf '%s\n' "loki adapter tests passed"
