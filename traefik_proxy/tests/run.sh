#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
FIXTURES="${SCRIPT_DIR}/fixtures"
FILTER_DIR="${ADDON_DIR}/docs/fail2ban/filter.d"
TMP_DIR=$(mktemp -d)

cleanup() {
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

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
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

for path in \
    "${ADDON_DIR}/config.yaml" \
    "${ADDON_DIR}/Dockerfile" \
    "${ADDON_DIR}/traefik.yml" \
    "${ADDON_DIR}/run.sh" \
    "${ADDON_DIR}/apparmor.txt"
do
    [ -s "$path" ] || fail "Required file is empty: $path"
done

sh -n "${ADDON_DIR}/run.sh"
sh -n "${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
python3 "${SCRIPT_DIR}/test_dynamic_watcher.py"
jq -e . "${FIXTURES}/options.json" >/dev/null
jq -e . "${FIXTURES}/access.jsonl" >/dev/null
jq -e . "${FIXTURES}/access.jsonl" >/dev/null

assert_contains 'arch:' "${ADDON_DIR}/config.yaml"
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

assert_contains "ACME_FILE=\"\${DATA_DIR}/acme.json\"" "${ADDON_DIR}/run.sh"
assert_contains "chmod 0600 \"\$ACME_FILE\"" "${ADDON_DIR}/run.sh"
assert_contains 'cloudflare_api_token' "${ADDON_DIR}/run.sh"
assert_contains 'CF_DNS_API_TOKEN' "${ADDON_DIR}/run.sh"
assert_contains 'profile ADDON_SLUG' "${ADDON_DIR}/apparmor.txt"
assert_not_contains 'capability' "${ADDON_DIR}/apparmor.txt"
pass "ACME permissions and minimal AppArmor declarations present"

printf '%s\n' "Traefik Proxy addon tests passed"
