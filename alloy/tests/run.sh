#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
FAKE_ALLOY="${SCRIPT_DIR}/fixtures/fake-alloy"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}

chmod 0755 "$FAKE_ALLOY"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"
DATA_DIR="${TEMP_DIR}/config"
CONFIG="${DATA_DIR}/config.alloy"

run_entrypoint() {
    ALLOY_OPTIONS_PATH="$1" \
    ALLOY_DATA_DIR="$DATA_DIR" \
    ALLOY_BIN="$FAKE_ALLOY" \
    ALLOY_TEST_ARGS_FILE="$ARGS_FILE" \
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

refute_config() {
    if grep -Fq -- "$1" "$CONFIG"; then
        fail "Unexpected config line: $1"
    fi
}

# The pin itself lives in the Dockerfile and is bumped by Renovate.
grep -Eq 'ARG UPSTREAM_VERSION="v[0-9][0-9.]*"' "$ADDON_DIR/Dockerfile" ||
    fail "Upstream version is not pinned"
# shellcheck disable=SC2016  # the literal Dockerfile expression is under test
grep -Fq \
    'FROM docker.io/grafana/alloy:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}' \
    "$ADDON_DIR/Dockerfile" ||
    fail "Upstream image is not immutably pinned"

# Traefik and extra files are rendered and Alloy starts with the config.
run_entrypoint "$OPTIONS"
assert_config 'url = "http://ad52851a-loki:3100/loki/api/v1/push"'
assert_config '"__path__" = "/share/traefik/logs/access.jsonl", "job" = "traefik", "log_type" = "access"'
assert_config '"__path__" = "/share/traefik/logs/traefik.log", "job" = "traefik", "log_type" = "app"'
assert_config '"__path__" = "/share/example/app.log", "job" = "example", "log_type" = "file"'
assert_config 'level  = "info"'
grep -Fqx -- "$CONFIG" "$ARGS_FILE" || fail "Alloy was not started with the rendered config"
grep -Fqx -- "--storage.path=${DATA_DIR}/data" "$ARGS_FILE" || fail "Storage path is missing"

# Traefik can be switched off while extra files stay.
only_extra="${TEMP_DIR}/only-extra.json"
jq '.traefik_logs = false' "$OPTIONS" >"$only_extra"
run_entrypoint "$only_extra"
refute_config "/share/traefik/logs"
assert_config '/share/example/app.log'

expect_rejected "no log source" '.traefik_logs = false | .extra_files = []'
expect_rejected "quote in url" '.loki_url = "http://loki:3100\"/push"'
expect_rejected "non http url" '.loki_url = "file:///etc/passwd"'
expect_rejected "path outside share" '.extra_files[0].path = "/etc/shadow"'
expect_rejected "path traversal" '.extra_files[0].path = "/share/../etc/shadow"'
expect_rejected "quote in path" '.extra_files[0].path = "/share/a\"b"'
expect_rejected "bad job name" '.extra_files[0].job = "bad job"'
expect_rejected "newline in job" '.extra_files[0].job = "app\n"'
expect_rejected "newline in path" '.extra_files[0].path = "/share/a\n"'
expect_rejected "newline in url" '.loki_url = "http://loki:3100\n"'
expect_rejected "unknown log level" '.log_level = "trace"'
expect_rejected "non boolean traefik_logs" '.traefik_logs = "yes"'

printf '%s\n' "alloy adapter tests passed"
