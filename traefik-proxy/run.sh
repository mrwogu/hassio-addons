#!/bin/sh
set -eu

OPTIONS_PATH=${TRAEFIK_OPTIONS_PATH:-/data/options.json}
SHARE_DIR=${TRAEFIK_SHARE_DIR:-/share/traefik}
DATA_DIR=${TRAEFIK_DATA_DIR:-/config/traefik}
STATIC_CONFIG=${TRAEFIK_STATIC_CONFIG:-/etc/traefik/traefik.yml}
LOGROTATE_CONFIG=${TRAEFIK_LOGROTATE_CONFIG:-/etc/logrotate.d/traefik}
LOGROTATE_STATE=${TRAEFIK_LOGROTATE_STATE:-${DATA_DIR}/logrotate.status}
TRAEFIK_BIN=${TRAEFIK_BIN:-/usr/local/bin/traefik}
LOGROTATE_BIN=${TRAEFIK_LOGROTATE_BIN:-/usr/sbin/logrotate}
WATCHER_BIN=${TRAEFIK_WATCHER_BIN:-/usr/local/bin/dynamic-watcher.py}
STATIC_RENDERER=${TRAEFIK_STATIC_RENDERER:-/usr/local/bin/static-config.py}
RUNTIME_STATIC_CONFIG=${TRAEFIK_RUNTIME_STATIC_CONFIG:-${DATA_DIR}/static.yml}
ROTATE_INTERVAL=${TRAEFIK_ROTATE_INTERVAL:-300}
PREFLIGHT_WAIT=${TRAEFIK_PREFLIGHT_WAIT:-10}

DYNAMIC_DIR="${SHARE_DIR}/dynamic"
ACTIVE_DYNAMIC_DIR="${DATA_DIR}/dynamic-active"
LOG_DIR="${SHARE_DIR}/logs"
ACCESS_LOG="${LOG_DIR}/access.jsonl"
APP_LOG="${LOG_DIR}/traefik.log"
ACME_FILE="${DATA_DIR}/acme.json"
LOG_PIPE=${TRAEFIK_LOG_PIPE:-/tmp/traefik-stdout.pipe}
SECRET_DIR=${TRAEFIK_SECRET_DIR:-/run/secrets/traefik}
CF_TOKEN_SECRET="${SECRET_DIR}/cloudflare_api_token"

log() {
    printf '%s\n' "[traefik-proxy] $*" >&2
}

fail() {
    log "Error: $*"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "Required command is unavailable: $1"
}

write_secret() {
    target=$1
    value=$2
    temporary=$(mktemp "${target}.tmp.XXXXXX") ||
        fail "Could not create temporary secret file"
    if ! (
        umask 077
        printf '%s' "$value" >"$temporary"
        chmod 0600 "$temporary"
        mv -f "$temporary" "$target"
    ); then
        rm -f "$temporary"
        fail "Could not install secret file"
    fi
}

validate_options() {
    jq -e '
        def clean:
            type == "string"
            and length <= 1024
            and (explode | all(. >= 32 and . != 127));
        def optional_clean:
            ((. // "") | type == "string")
            and ((. // "") | length <= 1024)
            and ((. // "") | explode | all(. >= 32 and . != 127));
        type == "object"
        and ((.log_level // "info") |
            type == "string" and IN("error", "warn", "info", "debug"))
        and ((.access_log_format // "json") |
            type == "string" and IN("json", "common"))
        and ((.trusted_proxy_ips // []) |
            type == "array"
            and all(.[]; type == "string"
                and length > 0
                and length <= 128
                and test("^[0-9A-Fa-f:.\/]+$")))
        and ((.acme // {}) |
            type == "object"
            and ((.enabled // false) | type == "boolean")
            and (.email | optional_clean)
            and (.cloudflare_api_token | optional_clean)
            and (.cloudflare_api_token_file | optional_clean))
        and ((.log_level // "info") | clean)
    ' "$OPTIONS_PATH" >/dev/null 2>&1 ||
        fail "Invalid options: check logging, trusted proxy, and ACME settings"
}

read_option() {
    jq -r "$1" "$OPTIONS_PATH"
}

prepare_storage() {
    umask 077
    mkdir -p "$DYNAMIC_DIR" "$LOG_DIR" "$DATA_DIR" "$SECRET_DIR"
    chmod 0750 "$SHARE_DIR" "$DYNAMIC_DIR" "$LOG_DIR"
    chmod 0700 "$DATA_DIR" "$SECRET_DIR"
    touch "$ACCESS_LOG" "$APP_LOG"
    chmod 0640 "$ACCESS_LOG" "$APP_LOG"
}

prepare_acme() {
    ACME_ENABLED=$(read_option '.acme.enabled // false')
    ACME_EMAIL=$(read_option '.acme.email // ""')
    ACME_TOKEN=$(read_option '.acme.cloudflare_api_token // ""')
    ACME_TOKEN_FILE=$(read_option '.acme.cloudflare_api_token_file // ""')

    if [ "$ACME_ENABLED" != "true" ]; then
        rm -f "$CF_TOKEN_SECRET"
        unset CF_DNS_API_TOKEN CF_DNS_API_TOKEN_FILE
        return
    fi

    [ -n "$ACME_EMAIL" ] || fail "ACME email is required when ACME is enabled"
    if [ -n "$ACME_TOKEN" ] && [ -n "$ACME_TOKEN_FILE" ]; then
        fail "Configure one Cloudflare token source, not two"
    fi
    if [ -n "$ACME_TOKEN_FILE" ]; then
        ACME_TOKEN_PATH=$(python3 - "$ACME_TOKEN_FILE" <<'PY'
from pathlib import Path
import os
import sys

candidate = Path(sys.argv[1]).resolve(strict=True)
roots = (
    Path(os.environ.get("TRAEFIK_CONFIG_ROOT", "/config")).resolve(),
    Path(os.environ.get("TRAEFIK_SHARE_DIR", "/share/traefik")).resolve(),
)
if not any(candidate == root or root in candidate.parents for root in roots):
    raise SystemExit(1)
print(candidate)
PY
        ) || fail "Cloudflare token file must resolve under /config or /share/traefik"
        [ -r "$ACME_TOKEN_PATH" ] ||
            fail "Configured Cloudflare token file is not readable"
        ACME_TOKEN=$(python3 - "$ACME_TOKEN_PATH" <<'PY'
from pathlib import Path
import sys

value = Path(sys.argv[1]).read_bytes()
if not value or any(byte < 32 or byte == 127 for byte in value):
    raise SystemExit(1)
sys.stdout.buffer.write(value)
PY
        ) || fail "Cloudflare token file contains control characters or is empty"
    fi
    [ -n "$ACME_TOKEN" ] ||
        fail "Cloudflare DNS API token is required when ACME is enabled"
    case "$ACME_TOKEN" in
        *[![:print:]]*) fail "Cloudflare token contains control characters" ;;
    esac

    if [ ! -e "$ACME_FILE" ]; then
        : >"$ACME_FILE"
    fi
    [ -f "$ACME_FILE" ] || fail "ACME storage path is not a regular file"
    chmod 0600 "$ACME_FILE"
    write_secret "$CF_TOKEN_SECRET" "$ACME_TOKEN"
    unset CF_DNS_API_TOKEN
    CF_DNS_API_TOKEN_FILE="$CF_TOKEN_SECRET"
    export CF_DNS_API_TOKEN_FILE
}

prepare_runtime_options() {
    LOG_LEVEL=$(read_option '.log_level // "info"')
    ACCESS_LOG_FORMAT=$(read_option '.access_log_format // "json"')
    TRUSTED_PROXY_IPS=$(jq -r '(.trusted_proxy_ips // []) | join(",")' "$OPTIONS_PATH")
}

render_static_config() {
    WEB_ADDRESS=$1
    WEBSECURE_ADDRESS=$2
    HEALTH_ADDRESS=$3
    python3 "$STATIC_RENDERER" \
        --source "$STATIC_CONFIG" \
        --output "$RUNTIME_STATIC_CONFIG" \
        --web-address "$WEB_ADDRESS" \
        --websecure-address "$WEBSECURE_ADDRESS" \
        --health-address "$HEALTH_ADDRESS" \
        --dynamic-directory "$ACTIVE_DYNAMIC_DIR" \
        --access-log-path "$ACCESS_LOG" \
        --log-level "$LOG_LEVEL" \
        --access-log-format "$ACCESS_LOG_FORMAT" \
        --trusted-proxy-ips "$TRUSTED_PROXY_IPS" \
        --acme-enabled "$ACME_ENABLED" \
        --acme-email "$ACME_EMAIL" \
        --acme-storage "$ACME_FILE"
}

start_log_forwarder() {
    rm -f "$LOG_PIPE"
    mkfifo "$LOG_PIPE"
    chmod 0600 "$LOG_PIPE"
    tee -a "$APP_LOG" <"$LOG_PIPE" >&2 &
    log_forwarder_pid=$!
}

stop_log_forwarder() {
    if [ -n "${log_forwarder_pid:-}" ]; then
        kill "$log_forwarder_pid" 2>/dev/null || true
        wait "$log_forwarder_pid" 2>/dev/null || true
        log_forwarder_pid=
    fi
    rm -f "$LOG_PIPE"
}

run_traefik() {
    exec "$TRAEFIK_BIN" "--configFile=${RUNTIME_STATIC_CONFIG}" >"$LOG_PIPE" 2>&1
}

preflight() {
    log "Validating Traefik static configuration"
    render_static_config \
        "127.0.0.1:0" \
        "127.0.0.1:0" \
        "127.0.0.1:0"
    start_log_forwarder
    "$TRAEFIK_BIN" "--configFile=${RUNTIME_STATIC_CONFIG}" >"$LOG_PIPE" 2>&1 &
    preflight_pid=$!
    sleep "$PREFLIGHT_WAIT"
    if kill -0 "$preflight_pid" 2>/dev/null; then
        kill -TERM "$preflight_pid" 2>/dev/null || true
        wait "$preflight_pid" 2>/dev/null || true
        preflight_status=0
    elif wait "$preflight_pid"; then
        preflight_status=0
    else
        preflight_status=$?
    fi
    stop_log_forwarder
    [ "$preflight_status" -eq 0 ] ||
        fail "Traefik configuration validation failed; inspect ${APP_LOG}"
}

rotate_loop() {
    while :; do
        sleep "$ROTATE_INTERVAL"
        "$LOGROTATE_BIN" -s "$LOGROTATE_STATE" "$LOGROTATE_CONFIG" ||
            log "Warning: log rotation failed"
    done
}

# shellcheck disable=SC2317,SC2329
forward_signal() {
    if [ -n "${child_pid:-}" ]; then
        kill -TERM "$child_pid" 2>/dev/null || true
    fi
}

# shellcheck disable=SC2317,SC2329
stop_children() {
    for pid in "${child_pid:-}" "${rotation_pid:-}" "${watcher_pid:-}"; do
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

# shellcheck disable=SC2317,SC2329
on_exit() {
    exit_status=$?
    trap - EXIT
    stop_children
    stop_log_forwarder
    wait "${child_pid:-}" "${rotation_pid:-}" "${watcher_pid:-}" 2>/dev/null || true
    exit "$exit_status"
}

require_command jq
require_command "$TRAEFIK_BIN"
require_command "$LOGROTATE_BIN"
require_command mkfifo
require_command tee
require_command python3
[ -x "$WATCHER_BIN" ] || fail "Dynamic configuration watcher is not executable"
[ -x "$STATIC_RENDERER" ] || fail "Static configuration renderer is not executable"
[ -r "$OPTIONS_PATH" ] || fail "Options file is not readable"
[ -r "$STATIC_CONFIG" ] || fail "Static configuration is not readable"

trap on_exit EXIT
validate_options
prepare_storage
prepare_runtime_options
prepare_acme

python3 "$WATCHER_BIN" \
    --source "$DYNAMIC_DIR" \
    --active "$ACTIVE_DYNAMIC_DIR" \
    --log "$APP_LOG" \
    --once
python3 "$WATCHER_BIN" \
    --source "$DYNAMIC_DIR" \
    --active "$ACTIVE_DYNAMIC_DIR" \
    --log "$APP_LOG" &
watcher_pid=$!

preflight

render_static_config ":80" ":443" "127.0.0.1:8082"
log "Starting Traefik; dynamic configuration directory is ${DYNAMIC_DIR}"
rotate_loop &
rotation_pid=$!
trap forward_signal INT TERM HUP

start_log_forwarder
run_traefik &
child_pid=$!
if wait "$child_pid"; then
    exit_status=0
else
    exit_status=$?
fi

kill "$rotation_pid" 2>/dev/null || true
wait "$rotation_pid" 2>/dev/null || true
kill "$watcher_pid" 2>/dev/null || true
wait "$watcher_pid" 2>/dev/null || true
stop_log_forwarder
trap - INT TERM HUP
exit "$exit_status"
