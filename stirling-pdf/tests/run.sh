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

chmod 0755 "$FAKE_INIT"
CONFIG_DIR="${TEMP_DIR}/config"
LINK_ROOT="${TEMP_DIR}/root"
ENV_FILE="${TEMP_DIR}/env"
ARGS_FILE="${TEMP_DIR}/args"
LOG_FILE="${TEMP_DIR}/log"
mkdir -p "$LINK_ROOT/usr/share"

run_entrypoint() {
    STIRLING_OPTIONS_PATH="$1" \
    STIRLING_CONFIG_DIR="$CONFIG_DIR" \
    STIRLING_LINK_ROOT="$LINK_ROOT" \
    STIRLING_INIT="$FAKE_INIT" \
    STIRLING_TEST_ENV_FILE="$ENV_FILE" \
    STIRLING_TEST_ARGS_FILE="$ARGS_FILE" \
        sh "$ENTRYPOINT" --fixture >"$LOG_FILE" 2>&1
}

# Valid options are translated to upstream environment variables.
run_entrypoint "$OPTIONS"

assert_env "SYSTEM_DEFAULTLOCALE=pl-PL"
assert_env "DOCKER_ENABLE_SECURITY=false"
assert_env "METRICS_ENABLED=true"
assert_env "UI_APPNAME=Stirling PDF"
assert_env "UI_APPNAVBARNAME=Stirling PDF"
assert_env "UI_HOMEDESCRIPTION=Twoje lokalne centrum obsługi PDF"
# Managed variables are forced regardless of user input.
assert_env "SYSTEM_SHOWUPDATE=false"
assert_env "SYSTEM_ENABLEANALYTICS=false"
# The adapter never sets a server context path.
refute_env_key "SYSTEM_ROOTURIPATH"
[ "$(cat "$ARGS_FILE")" = "--fixture" ] || fail "Arguments were not forwarded"

# Every upstream state path is redirected into /config.
for pair in \
    "configs:configs" \
    "customFiles:customFiles" \
    "pipeline:pipeline" \
    "storage:storage" \
    "usr/share/tessdata:tessdata"; do
    link="${LINK_ROOT}/${pair%%:*}"
    target="${CONFIG_DIR}/${pair##*:}"
    [ -L "$link" ] || fail "Missing state symlink: $link"
    [ "$(readlink "$link")" = "$target" ] ||
        fail "State symlink $link does not point to $target"
    [ -d "$target" ] || fail "Missing state directory: $target"
done

# State written through a link persists and the link survives a restart.
printf 'stored\n' >"${LINK_ROOT}/configs/settings.yml"
run_entrypoint "$OPTIONS"
[ -L "${LINK_ROOT}/configs" ] || fail "State symlink lost on restart"
[ "$(cat "${CONFIG_DIR}/configs/settings.yml")" = "stored" ] ||
    fail "Persisted state was not retained"

# Optional description is omitted when blank.
OPTIONAL_OPTIONS="${TEMP_DIR}/optional-options.json"
jq 'del(.home_description)' "$OPTIONS" >"$OPTIONAL_OPTIONS"
run_entrypoint "$OPTIONAL_OPTIONS"
refute_env_key "UI_HOMEDESCRIPTION"
assert_env "SYSTEM_DEFAULTLOCALE=pl-PL"

# A control character in a user string is rejected.
INVALID_OPTIONS="${TEMP_DIR}/invalid-options.json"
jq '.app_name = "Bad\u001bName"' "$OPTIONS" >"$INVALID_OPTIONS"
if run_entrypoint "$INVALID_OPTIONS"; then
    fail "Control character in app name was accepted"
fi
grep -Fq "Invalid options" "$LOG_FILE" ||
    fail "Invalid app name did not report expected error"

# A malformed locale is rejected.
BAD_LOCALE="${TEMP_DIR}/bad-locale.json"
jq '.default_locale = "not a locale"' "$OPTIONS" >"$BAD_LOCALE"
if run_entrypoint "$BAD_LOCALE"; then
    fail "Malformed locale was accepted"
fi

printf '%s\n' "Stirling-PDF adapter tests passed"
