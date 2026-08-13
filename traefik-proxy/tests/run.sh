#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
FIXTURES="${SCRIPT_DIR}/fixtures"
FILTER_DIR="${ADDON_DIR}/docs/fail2ban/filter.d"
TMP_DIR=$(mktemp -d)

cleanup() {
    if [ -n "${RUN_PID:-}" ]; then
        kill -TERM "$RUN_PID" 2>/dev/null || true
        wait "$RUN_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}

pass() {
    printf '%s\n' "PASS: $*"
}

assert_contains() {
    value=$1
    path=$2
    grep -Fq "$value" "$path" || fail "Missing '$value' in $path"
}

assert_not_contains() {
    value=$1
    path=$2
    if grep -Fq "$value" "$path"; then
        fail "Unexpected '$value' in $path"
    fi
}

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

FAKE_TRAEFIK="${TMP_DIR}/traefik"
FAKE_LOGROTATE="${TMP_DIR}/logrotate"
DATA_DIR="${TMP_DIR}/config"
SHARE_DIR="${TMP_DIR}/share/traefik"
SECRET_DIR="${TMP_DIR}/secrets"
CONFIG_ROOT="${TMP_DIR}/config-root"
ARGS_FILE="${TMP_DIR}/traefik.args"
ENV_FILE="${TMP_DIR}/traefik.env"
CONFIG_DUMPS="${TMP_DIR}/configs"
RUN_LOG="${TMP_DIR}/run.log"
WATCHER_BIN="${TMP_DIR}/dynamic-watcher.py"
STATIC_RENDERER="${TMP_DIR}/static-config.py"
mkdir -p "$CONFIG_DUMPS"
: >"$ARGS_FILE"
: >"$ENV_FILE"
cp "${ADDON_DIR}/dynamic-watcher.py" "$WATCHER_BIN"
cp "${ADDON_DIR}/static-config.py" "$STATIC_RENDERER"

cat >"$FAKE_TRAEFIK" <<'EOF'
#!/bin/sh
set -eu

args_file=$TRAEFIK_TEST_ARGS_FILE
env_file=$TRAEFIK_TEST_ENV_FILE
config_dir=$TRAEFIK_TEST_CONFIG_DIR
count=$(grep -c '^--- invocation$' "$args_file" 2>/dev/null || true)
count=$((count + 1))
{
    printf '%s\n' '--- invocation'
    for argument do
        printf '%s\n' "$argument"
    done
} >>"$args_file"
config_path=
for argument do
    case "$argument" in
        --configFile=*) config_path=${argument#--configFile=} ;;
    esac
done
cp "$config_path" "${config_dir}/config-${count}.yml"
{
    printf 'CF_DNS_API_TOKEN_FILE=%s\n' "${CF_DNS_API_TOKEN_FILE:-}"
    printf 'CF_DNS_API_TOKEN=%s\n' "${CF_DNS_API_TOKEN:-}"
} >>"$env_file"
trap 'exit 0' INT TERM
while :; do
    sleep 0.1
done
EOF

cat >"$FAKE_LOGROTATE" <<'EOF'
#!/bin/sh
printf '%s\n' rotated >>"${TRAEFIK_TEST_LOGROTATE_FILE}"
EOF
chmod 0755 "$FAKE_TRAEFIK" "$FAKE_LOGROTATE"
chmod 0755 "$WATCHER_BIN" "$STATIC_RENDERER"

run_adapter() {
    options=$1
    rm -rf "$DATA_DIR" "$SHARE_DIR" "$SECRET_DIR" "$CONFIG_ROOT"
    rm -rf "$CONFIG_DUMPS"
    mkdir -p "$CONFIG_DUMPS" "$SECRET_DIR"
    if [ -n "${ACME_SOURCE_VALUE:-}" ]; then
        mkdir -p "$(dirname "$ACME_TOKEN_FILE")"
        printf '%s' "$ACME_SOURCE_VALUE" >"$ACME_TOKEN_FILE"
    fi
    : >"$ARGS_FILE"
    : >"$ENV_FILE"
    TRAEFIK_OPTIONS_PATH="$options" \
    TRAEFIK_SHARE_DIR="$SHARE_DIR" \
    TRAEFIK_DATA_DIR="$DATA_DIR" \
    TRAEFIK_STATIC_CONFIG="${ADDON_DIR}/traefik.yml" \
    TRAEFIK_RUNTIME_STATIC_CONFIG="${DATA_DIR}/static.yml" \
    TRAEFIK_LOGROTATE_CONFIG="${TMP_DIR}/logrotate.conf" \
    TRAEFIK_BIN="$FAKE_TRAEFIK" \
    TRAEFIK_LOGROTATE_BIN="$FAKE_LOGROTATE" \
    TRAEFIK_WATCHER_BIN="$WATCHER_BIN" \
    TRAEFIK_STATIC_RENDERER="$STATIC_RENDERER" \
    TRAEFIK_PREFLIGHT_WAIT=0.1 \
    TRAEFIK_SECRET_DIR="$SECRET_DIR" \
    TRAEFIK_CONFIG_ROOT="$CONFIG_ROOT" \
    TRAEFIK_TEST_ARGS_FILE="$ARGS_FILE" \
    TRAEFIK_TEST_ENV_FILE="$ENV_FILE" \
    TRAEFIK_TEST_CONFIG_DIR="$CONFIG_DUMPS" \
    TRAEFIK_TEST_LOGROTATE_FILE="${TMP_DIR}/logrotate.calls" \
        sh "${ADDON_DIR}/run.sh" >"$RUN_LOG" 2>&1 &
    RUN_PID=$!
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        if ! kill -0 "$RUN_PID" 2>/dev/null; then
            cat "$RUN_LOG" >&2
            wait "$RUN_PID" 2>/dev/null ||
                fail "Adapter exited before Traefik started: $options"
            fail "Adapter exited before Traefik started: $options"
        fi
        if find "$CONFIG_DUMPS" -name 'config-*.yml' -exec \
            grep -l 'address: :80' {} + 2>/dev/null | grep -q .
        then
            return 0
        fi
        sleep 0.1
    done
    cat "$RUN_LOG" >&2
    cat "$ARGS_FILE" >&2
    fail "Adapter did not start Traefik: $options"
}

stop_adapter() {
    kill -TERM "$RUN_PID" 2>/dev/null || true
    if wait "$RUN_PID"; then
        :
    else
        status=$?
        [ "$status" -eq 143 ] || fail "Adapter exit status was $status"
    fi
    RUN_PID=
}

run_failure() {
    options=$1
    if TRAEFIK_OPTIONS_PATH="$options" \
        TRAEFIK_SHARE_DIR="$SHARE_DIR" \
        TRAEFIK_DATA_DIR="$DATA_DIR" \
        TRAEFIK_STATIC_CONFIG="${ADDON_DIR}/traefik.yml" \
        TRAEFIK_RUNTIME_STATIC_CONFIG="${DATA_DIR}/static.yml" \
        TRAEFIK_BIN="$FAKE_TRAEFIK" \
        TRAEFIK_LOGROTATE_BIN="$FAKE_LOGROTATE" \
        TRAEFIK_WATCHER_BIN="$WATCHER_BIN" \
        TRAEFIK_STATIC_RENDERER="$STATIC_RENDERER" \
        TRAEFIK_PREFLIGHT_WAIT=0.1 \
        TRAEFIK_SECRET_DIR="$SECRET_DIR" \
        TRAEFIK_CONFIG_ROOT="$CONFIG_ROOT" \
        TRAEFIK_TEST_ARGS_FILE="$ARGS_FILE" \
        TRAEFIK_TEST_ENV_FILE="$ENV_FILE" \
        TRAEFIK_TEST_CONFIG_DIR="$CONFIG_DUMPS" \
        TRAEFIK_TEST_LOGROTATE_FILE="${TMP_DIR}/logrotate.calls" \
            sh "${ADDON_DIR}/run.sh" >"$RUN_LOG" 2>&1
    then
        fail "Invalid options were accepted: $options"
    fi
}

for path in \
    "${ADDON_DIR}/config.yaml" \
    "${ADDON_DIR}/Dockerfile" \
    "${ADDON_DIR}/traefik.yml" \
    "${ADDON_DIR}/static-config.py" \
    "${ADDON_DIR}/run.sh" \
    "${ADDON_DIR}/apparmor.txt"
do
    [ -s "$path" ] || fail "Required file is empty: $path"
done

sh -n "${ADDON_DIR}/run.sh"
sh -n "${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
python3 "${SCRIPT_DIR}/test_dynamic_watcher.py"
python3 -m py_compile "${ADDON_DIR}/dynamic-watcher.py" "${ADDON_DIR}/static-config.py"
jq -e . "${FIXTURES}/options.json" >/dev/null
jq -e . "${FIXTURES}/access.jsonl" >/dev/null

assert_contains 'arch:' "${ADDON_DIR}/config.yaml"
assert_contains 'slug: traefik-proxy' "${ADDON_DIR}/config.yaml"
assert_contains '  - aarch64' "${ADDON_DIR}/config.yaml"
assert_contains '  - amd64' "${ADDON_DIR}/config.yaml"
assert_contains 'init: false' "${ADDON_DIR}/config.yaml"
assert_contains 'type: share' "${ADDON_DIR}/config.yaml"
assert_contains '80/tcp: 80' "${ADDON_DIR}/config.yaml"
assert_contains '443/tcp: 443' "${ADDON_DIR}/config.yaml"
assert_not_contains '81/tcp' "${ADDON_DIR}/config.yaml"
assert_not_contains 'host_network: true' "${ADDON_DIR}/config.yaml"
assert_not_contains 'privileged:' "${ADDON_DIR}/config.yaml"
assert_not_contains 'docker_api' "${ADDON_DIR}/config.yaml"

assert_contains 'ARG UPSTREAM_DIGEST="sha256:' "${ADDON_DIR}/Dockerfile"
assert_contains "FROM docker.io/library/traefik:\${UPSTREAM_VERSION}@\${UPSTREAM_DIGEST}" \
    "${ADDON_DIR}/Dockerfile"
assert_contains 'providers:' "${ADDON_DIR}/traefik.yml"
assert_contains 'directory: /config/traefik/dynamic-active' "${ADDON_DIR}/traefik.yml"
assert_contains 'watch: true' "${ADDON_DIR}/traefik.yml"
assert_contains 'bufferingSize: 0' "${ADDON_DIR}/traefik.yml"
assert_contains 'defaultMode: drop' "${ADDON_DIR}/traefik.yml"
assert_contains 'insecure: false' "${ADDON_DIR}/traefik.yml"
assert_not_contains 'docker:' "${ADDON_DIR}/traefik.yml"
grep -Eq '^[[:space:]]*capability net_bind_service,$' "${ADDON_DIR}/apparmor.txt" ||
    fail "AppArmor net_bind_service capability missing"
assert_contains '/bin/busybox ix' "${ADDON_DIR}/apparmor.txt"

for filter in traefik-auth.conf traefik-404.conf traefik-scan.conf; do
    filter_path="${FILTER_DIR}/${filter}"
    regex=$(sed -n 's/^failregex = //p' "$filter_path" | head -n 1)
    [ -n "$regex" ] || fail "Missing failregex: $filter"
    host_regex='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
    host_regex="${host_regex}(\\.${host_regex}){3}"
    regex=$(printf '%s' "$regex" | sed "s/<HOST>/${host_regex}/g")
    grep -Eq "$regex" "${FIXTURES}/access.jsonl" ||
        fail "Filter does not match fixture: $filter"
done
pass "Traefik JSON access fixtures match <HOST> filters"

for secret in Cookie Authorization X-Api-Key access_token password api_key; do
    assert_not_contains "\"${secret}\"" "${FIXTURES}/access.jsonl"
done
pass "Fixtures contain no protected secret fields"

run_adapter "${FIXTURES}/options.json"
static_config=$(find "$CONFIG_DUMPS" -name 'config-*.yml' -print | sort | tail -n 1)
[ -f "$static_config" ] || fail "Effective static configuration was not rendered"
assert_contains 'level: debug' "$static_config"
assert_contains 'format: json' "$static_config"
assert_contains 'address: :80' "$static_config"
assert_contains 'address: :443' "$static_config"
assert_contains '172.30.33.0/24' "$static_config"
assert_contains 'directory: '"${DATA_DIR}"'/dynamic-active' "$static_config"
[ "$(grep -v '^--- invocation$' "$ARGS_FILE" | grep -c '^--configFile=')" -ge 1 ] ||
    fail "Adapter did not pass configFile to Traefik"
[ "$(grep -v '^--- invocation$' "$ARGS_FILE" | grep -v '^--configFile=' |
    grep -c . || true)" -eq 0 ] ||
    fail "Adapter passed static CLI flags alongside configFile"
stop_adapter
pass "Adapter renders effective static options and forwards only configFile"

run_failure "${FIXTURES}/invalid-options.json"
assert_contains "Invalid options" "$RUN_LOG"
pass "Adapter rejects invalid options"

ACME_OPTIONS="${TMP_DIR}/acme-options.json"
ACME_TOKEN_FILE="${CONFIG_ROOT}/cloudflare-token"
ACME_SOURCE_VALUE=fixture-acme-token
jq --arg token_file "$ACME_TOKEN_FILE" \
    '.acme = {
        enabled: true,
        email: "acme-test@example.invalid",
        cloudflare_api_token: "",
        cloudflare_api_token_file: $token_file
    }' "${FIXTURES}/options.json" >"$ACME_OPTIONS"
run_adapter "$ACME_OPTIONS"
acme_config=$(find "$CONFIG_DUMPS" -name 'config-*.yml' -print | sort | tail -n 1)
assert_contains 'certificatesResolvers:' "$acme_config"
assert_contains 'storage: '"${DATA_DIR}"'/acme.json' "$acme_config"
assert_contains "CF_DNS_API_TOKEN_FILE=${SECRET_DIR}/cloudflare_api_token" "$ENV_FILE"
assert_not_contains 'CF_DNS_API_TOKEN=fixture-acme-token' "$ENV_FILE"
[ "$(file_mode "${SECRET_DIR}/cloudflare_api_token")" = "600" ] ||
    fail "Cloudflare runtime secret is not 0600"
stop_adapter
unset ACME_SOURCE_VALUE
pass "ACME token uses 0600 file path without exported token value"

CONFLICT_OPTIONS="${TMP_DIR}/conflict-options.json"
jq --arg token_file "$ACME_TOKEN_FILE" \
    '.acme.enabled = true |
     .acme.email = "acme-test@example.invalid" |
     .acme.cloudflare_api_token = "fixture-direct-token" |
     .acme.cloudflare_api_token_file = $token_file' \
    "${FIXTURES}/options.json" >"$CONFLICT_OPTIONS"
run_failure "$CONFLICT_OPTIONS"
assert_contains "one Cloudflare token source" "$RUN_LOG"
pass "Adapter rejects conflicting Cloudflare token sources"

NO_EMAIL_OPTIONS="${TMP_DIR}/no-email-options.json"
jq --arg token_file "$ACME_TOKEN_FILE" \
    '.acme.enabled = true |
     .acme.email = "" |
     .acme.cloudflare_api_token_file = $token_file' \
    "${FIXTURES}/options.json" >"$NO_EMAIL_OPTIONS"
run_failure "$NO_EMAIL_OPTIONS"
assert_contains "ACME email is required" "$RUN_LOG"
pass "Adapter rejects ACME without an email address"

OUTSIDE_TOKEN="${TMP_DIR}/outside-token"
printf '%s' 'fixture-outside-token' >"$OUTSIDE_TOKEN"
OUTSIDE_OPTIONS="${TMP_DIR}/outside-options.json"
jq --arg token_file "$OUTSIDE_TOKEN" \
    '.acme.enabled = true |
     .acme.email = "acme-test@example.invalid" |
     .acme.cloudflare_api_token_file = $token_file' \
    "${FIXTURES}/options.json" >"$OUTSIDE_OPTIONS"
run_failure "$OUTSIDE_OPTIONS"
assert_contains "must resolve under" "$RUN_LOG"
pass "Adapter rejects Cloudflare token paths outside allowlist"

run_adapter "${FIXTURES}/options.json"
[ ! -e "${SECRET_DIR}/cloudflare_api_token" ] ||
    fail "Cloudflare runtime secret was not removed when ACME was disabled"
stop_adapter
pass "Adapter removes stale ACME runtime secret"

LOG_DIR="${TMP_DIR}/logs"
mkdir -p "$LOG_DIR"
cp "${FIXTURES}/access.jsonl" "${LOG_DIR}/access.jsonl"
cp "${FIXTURES}/access.jsonl" "${LOG_DIR}/traefik.log"
if command -v logrotate >/dev/null 2>&1; then
    cat >"${TMP_DIR}/logrotate.conf" <<EOF
${LOG_DIR}/access.jsonl ${LOG_DIR}/traefik.log {
  size 1
  rotate 14
  compress
  missingok
  notifempty
  copytruncate
}
EOF
    logrotate -s "${TMP_DIR}/logrotate.status" -f "${TMP_DIR}/logrotate.conf"
    [ -f "${LOG_DIR}/access.jsonl" ] || fail "Access log missing after rotation"
    [ -f "${LOG_DIR}/traefik.log" ] || fail "Application log missing after rotation"
    [ "$(find "$LOG_DIR" -type f | wc -l | tr -d ' ')" -le 30 ] ||
        fail "Log rotation created unbounded files"
    pass "Log rotation preserves active files and bounded history"
else
    pass "logrotate unavailable, rotation covered by container smoke test"
fi

printf '%s\n' "Traefik Proxy addon tests passed"
