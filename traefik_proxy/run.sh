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
ROTATE_INTERVAL=${TRAEFIK_ROTATE_INTERVAL:-5}
PREFLIGHT_WAIT=${TRAEFIK_PREFLIGHT_WAIT:-1}

DYNAMIC_DIR="${SHARE_DIR}/dynamic"
ACTIVE_DYNAMIC_DIR="${DATA_DIR}/dynamic-active"
LOG_DIR="${SHARE_DIR}/logs"
ACCESS_LOG="${LOG_DIR}/access.jsonl"
APP_LOG="${LOG_DIR}/traefik.log"
ACME_FILE="${DATA_DIR}/acme.json"
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
        return
    fi

    [ -n "$ACME_EMAIL" ] || fail "ACME email is required when ACME is enabled"
    if [ -n "$ACME_TOKEN" ] && [ -n "$ACME_TOKEN_FILE" ]; then
        fail "Configure one Cloudflare token source, not two"
    fi
    if [ -n "$ACME_TOKEN_FILE" ]; then
        case "$ACME_TOKEN_FILE" in
            /config/* | /share/traefik/*) ;;
            *) fail "Cloudflare token file must be under /config or /share/traefik" ;;
        esac
        [ -r "$ACME_TOKEN_FILE" ] ||
            fail "Configured Cloudflare token file is not readable"
        ACME_TOKEN=$(cat "$ACME_TOKEN_FILE") ||
            fail "Could not read Cloudflare token file"
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
    CF_DNS_API_TOKEN=$(cat "$CF_TOKEN_SECRET")
    export CF_DNS_API_TOKEN
}

prepare_runtime_options() {
    LOG_LEVEL=$(read_option '.log_level // "info"')
    ACCESS_LOG_FORMAT=$(read_option '.access_log_format // "json"')
    TRUSTED_PROXY_IPS=$(jq -r '(.trusted_proxy_ips // []) | join(",")' "$OPTIONS_PATH")
}

run_traefik() {
    if [ -n "$TRUSTED_PROXY_IPS" ]; then
        exec "$TRAEFIK_BIN" \
            "--configFile=${STATIC_CONFIG}" \
            "--log.level=${LOG_LEVEL}" \
            "--accesslog.format=${ACCESS_LOG_FORMAT}" \
            "--providers.file.directory=${ACTIVE_DYNAMIC_DIR}" \
            "--providers.file.watch=true" \
            "--entryPoints.web.forwardedHeaders.trustedIPs=${TRUSTED_PROXY_IPS}" \
            "--entryPoints.websecure.forwardedHeaders.trustedIPs=${TRUSTED_PROXY_IPS}" \
            "$@"
    else
        exec "$TRAEFIK_BIN" \
            "--configFile=${STATIC_CONFIG}" \
            "--log.level=${LOG_LEVEL}" \
            "--accesslog.format=${ACCESS_LOG_FORMAT}" \
            "--providers.file.directory=${ACTIVE_DYNAMIC_DIR}" \
            "--providers.file.watch=true" \
            "$@"
    fi
}

run_with_acme() {
    if [ "$ACME_ENABLED" = "true" ]; then
        run_traefik \
            "--certificatesResolvers.letsencrypt.acme.email=${ACME_EMAIL}" \
            "--certificatesResolvers.letsencrypt.acme.storage=${ACME_FILE}" \
            "--certificatesResolvers.letsencrypt.acme.dnsChallenge.provider=cloudflare" \
            "$@"
    else
        run_traefik "$@"
    fi
}

preflight() {
    log "Validating Traefik static configuration"
    run_with_acme \
        "--entrypoints.web.address=127.0.0.1:0" \
        "--entrypoints.websecure.address=127.0.0.1:0" \
        "--entrypoints.health.address=127.0.0.1:0" &
    preflight_pid=$!
    sleep "$PREFLIGHT_WAIT"
    if kill -0 "$preflight_pid" 2>/dev/null; then
        kill -TERM "$preflight_pid" 2>/dev/null || true
        wait "$preflight_pid" 2>/dev/null || true
        return 0
    fi
    if wait "$preflight_pid"; then
        return 0
    fi
    fail "Traefik configuration validation failed; inspect ${APP_LOG}"
}

rotate_loop() {
    while :; do
        sleep "$ROTATE_INTERVAL"
        "$LOGROTATE_BIN" -s "$LOGROTATE_STATE" "$LOGROTATE_CONFIG" ||
            log "Warning: log rotation failed"
    done
}

# shellcheck disable=SC2329
forward_signal() {
    if [ -n "${child_pid:-}" ]; then
        kill -TERM "$child_pid" 2>/dev/null || true
    fi
}

# shellcheck disable=SC2329
stop_children() {
    for pid in "${child_pid:-}" "${rotation_pid:-}" "${watcher_pid:-}"; do
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

# shellcheck disable=SC2329
on_exit() {
    exit_status=$?
    trap - EXIT
    stop_children
    wait "${child_pid:-}" "${rotation_pid:-}" "${watcher_pid:-}" 2>/dev/null || true
    exit "$exit_status"
}

require_command jq
require_command "$TRAEFIK_BIN"
require_command "$LOGROTATE_BIN"
require_command python3
[ -x "$WATCHER_BIN" ] || fail "Dynamic configuration watcher is not executable"
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

log "Starting Traefik; dynamic configuration directory is ${DYNAMIC_DIR}"
rotate_loop &
rotation_pid=$!
trap forward_signal INT TERM HUP

run_with_acme &
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
trap - INT TERM HUP
exit "$exit_status"
