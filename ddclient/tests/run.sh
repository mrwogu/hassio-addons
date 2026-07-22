#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
OPTIONS="${SCRIPT_DIR}/fixtures/options.json"
FAKE_DDCLIENT="${SCRIPT_DIR}/fixtures/fake-ddclient"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}

file_mode() {
    # GNU stat first (Linux CI); fall back to BSD stat (macOS).
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

chmod 0755 "$FAKE_DDCLIENT"
CONFIG_DIR="${TEMP_DIR}/config"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"
CONF_FILE="${CONFIG_DIR}/ddclient.conf"
CACHE_FILE="${CONFIG_DIR}/ddclient.cache"

run_entrypoint() {
    ADDON_OPTIONS_PATH="$1" \
    ADDON_CONFIG_DIR="$CONFIG_DIR" \
    ADDON_DDCLIENT_BIN="$FAKE_DDCLIENT" \
    ADDON_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" >"$LOG_FILE" 2>&1
}

# Valid options are written verbatim to ddclient.conf and ddclient is invoked
# in the foreground against the generated configuration and cache.
run_entrypoint "$OPTIONS"

[ -f "$CONF_FILE" ] || fail "ddclient.conf was not created"
jq -r '.config' "$OPTIONS" >"${TEMP_DIR}/expected.conf"
cmp -s "$CONF_FILE" "${TEMP_DIR}/expected.conf" ||
    fail "ddclient.conf content does not match the config option"
[ "$(file_mode "$CONF_FILE")" = "600" ] ||
    fail "ddclient.conf is not owner-only (0600)"
expected_args="-foreground -file ${CONF_FILE} -cache ${CACHE_FILE}"
[ "$(cat "$ARGS_FILE")" = "$expected_args" ] ||
    fail "ddclient was not invoked in the foreground against the config and cache"

# The provider credential is never written to the log.
if grep -Fq "cloudflare-secret-token" "$LOG_FILE"; then
    fail "Provider credential leaked into the log"
fi

# A second run keeps the configuration in sync with the options.
UPDATED="${TEMP_DIR}/updated.json"
jq '.config = "daemon=600\nprotocol=duckdns\nuse=web\npassword=duck-token\nexample\n"' \
    "$OPTIONS" >"$UPDATED"
run_entrypoint "$UPDATED"
jq -r '.config' "$UPDATED" >"${TEMP_DIR}/expected-updated.conf"
cmp -s "$CONF_FILE" "${TEMP_DIR}/expected-updated.conf" ||
    fail "ddclient.conf was not refreshed from updated options"
if grep -Fq "duck-token" "$LOG_FILE"; then
    fail "Updated credential leaked into the log"
fi

# An empty configuration is rejected.
EMPTY="${TEMP_DIR}/empty.json"
jq '.config = ""' "$OPTIONS" >"$EMPTY"
if run_entrypoint "$EMPTY"; then
    fail "Empty configuration was accepted"
fi
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Empty configuration did not report the expected error"

# A control character in the configuration is rejected.
CONTROL="${TEMP_DIR}/control.json"
jq '.config = "daemon=300\u0000protocol=duckdns"' "$OPTIONS" >"$CONTROL"
if run_entrypoint "$CONTROL"; then
    fail "Control character in configuration was accepted"
fi

printf '%s\n' "ddclient adapter tests passed"
