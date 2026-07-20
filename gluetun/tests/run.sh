#!/bin/sh
set -eu

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ADDON_DIR=$(CDPATH='' cd -- "${TEST_DIR}/.." && pwd)
ENTRYPOINT="${ADDON_DIR}/rootfs/usr/local/bin/addon-entrypoint"
MOCK="${TEST_DIR}/mock-gluetun-entrypoint"
FIXTURES="${TEST_DIR}/fixtures"
WORK_DIR=$(mktemp -d)
SECRETS_DIR="${WORK_DIR}/secrets"
ENV_OUTPUT="${WORK_DIR}/env"
ARGS_OUTPUT="${WORK_DIR}/args"
LOG_OUTPUT="${WORK_DIR}/log"

trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    exit 1
}

pass() {
    printf '%s\n' "PASS: $*"
}

run_success() {
    fixture=$1
    rm -f "$ENV_OUTPUT" "$ARGS_OUTPUT" "$LOG_OUTPUT"
    ADDON_OPTIONS_PATH="${FIXTURES}/${fixture}" \
    ADDON_SECRETS_DIR="$SECRETS_DIR" \
    GLUETUN_ENTRYPOINT="$MOCK" \
    TEST_ENV_OUTPUT="$ENV_OUTPUT" \
    TEST_ARGS_OUTPUT="$ARGS_OUTPUT" \
        "$ENTRYPOINT" healthcheck >"${WORK_DIR}/stdout" 2>"$LOG_OUTPUT" ||
        fail "Fixture unexpectedly failed: $fixture"
}

run_failure() {
    fixture=$1
    rm -f "$ENV_OUTPUT" "$ARGS_OUTPUT" "$LOG_OUTPUT"
    if ADDON_OPTIONS_PATH="${FIXTURES}/${fixture}" \
        ADDON_SECRETS_DIR="$SECRETS_DIR" \
        GLUETUN_ENTRYPOINT="$MOCK" \
        TEST_ENV_OUTPUT="$ENV_OUTPUT" \
        TEST_ARGS_OUTPUT="$ARGS_OUTPUT" \
            "$ENTRYPOINT" >"${WORK_DIR}/stdout" 2>"$LOG_OUTPUT"
    then
        fail "Fixture unexpectedly succeeded: $fixture"
    fi
}

assert_env() {
    name=$1
    expected=$2
    actual=$(grep -F "${name}=" "$ENV_OUTPUT" | head -n 1 | cut -d= -f2- || true)
    [ "$actual" = "$expected" ] ||
        fail "$name expected '$expected', got '$actual'"
}

assert_env_absent() {
    name=$1
    if grep -q "^${name}=" "$ENV_OUTPUT"; then
        fail "$name should be absent"
    fi
}

assert_file() {
    path=$1
    expected=$2
    [ -f "$path" ] || fail "Missing secret file: $path"
    actual=$(cat "$path")
    [ "$actual" = "$expected" ] || fail "Wrong secret file content: $path"
    mode=$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path")
    [ "$mode" = "600" ] || fail "Secret file mode is $mode: $path"
}

assert_log_excludes() {
    value=$1
    if grep -Fq "$value" "$LOG_OUTPUT"; then
        fail "Log contains secret value"
    fi
}

chmod 0755 "$ENTRYPOINT" "$MOCK"

run_success openvpn.json
assert_env VPN_SERVICE_PROVIDER protonvpn
assert_env VPN_TYPE openvpn
assert_env OPENVPN_ENDPOINT_IP 198.51.100.10
assert_env SERVER_COUNTRIES Poland,Germany
assert_env FIREWALL_OUTBOUND_SUBNETS 192.168.1.0/24,10.0.0.0/8
assert_env DNS_UPSTREAM_RESOLVER_TYPE DoT
assert_env HTTPPROXY_LISTENING_ADDRESS :8888
assert_env SOCKS5_LISTENING_ADDRESS :1080
assert_env SHADOWSOCKS_LISTENING_ADDRESS :8388
assert_env HEALTH_TARGET_ADDRESSES vpn-check.invalid:443
assert_env OPENVPN_USER_SECRETFILE "${SECRETS_DIR}/openvpn_user"
assert_env OPENVPN_PASSWORD_SECRETFILE "${SECRETS_DIR}/openvpn_password"
assert_env HTTPPROXY_PASSWORD_SECRETFILE "${SECRETS_DIR}/httpproxy_password"
assert_env SHADOWSOCKS_PASSWORD_SECRETFILE "${SECRETS_DIR}/shadowsocks_password"
assert_file "${SECRETS_DIR}/openvpn_user" fixture-openvpn-user
assert_file "${SECRETS_DIR}/openvpn_password" fixture-openvpn-password
assert_file "${SECRETS_DIR}/httpproxy_password" fixture-http-password
assert_file "${SECRETS_DIR}/shadowsocks_password" fixture-shadowsocks-password
[ "$(cat "$ARGS_OUTPUT")" = "healthcheck" ] || fail "Arguments were not preserved"
grep -Fq "HEALTH_TARGET_ADDRESSES" "$LOG_OUTPUT" ||
    fail "Custom environment variable name was not logged"
for value in \
    fixture-openvpn-user fixture-openvpn-password \
    fixture-http-user fixture-http-password \
    fixture-socks-user fixture-socks-password \
    fixture-shadowsocks-password vpn-check.invalid:443
do
    assert_log_excludes "$value"
done
if find "$SECRETS_DIR" -type f -name '*.tmp.*' | grep -q .; then
    fail "Atomic secret temporary file remains"
fi
pass "OpenVPN options, proxies, secrets, and redacted logs"

run_success wireguard.json
assert_env VPN_TYPE wireguard
assert_env WIREGUARD_PRIVATE_KEY_SECRETFILE "${SECRETS_DIR}/wireguard_private_key"
assert_env WIREGUARD_PRESHARED_KEY_SECRETFILE "${SECRETS_DIR}/wireguard_preshared_key"
assert_env WIREGUARD_ADDRESSES_SECRETFILE "${SECRETS_DIR}/wireguard_addresses"
assert_env WIREGUARD_ENDPOINT_PORT 51820
assert_env WIREGUARD_MTU 1420
assert_file "${SECRETS_DIR}/wireguard_private_key" fixture-wireguard-private
assert_file "${SECRETS_DIR}/wireguard_preshared_key" fixture-wireguard-preshared
assert_file "${SECRETS_DIR}/wireguard_addresses" 10.64.1.2/32
assert_log_excludes fixture-wireguard-private
assert_log_excludes fixture-wireguard-preshared
pass "WireGuard mapping and secret files"

run_success amneziawg.json
assert_env VPN_TYPE amneziawg
assert_env AMNEZIAWG_PRIVATE_KEY_SECRETFILE "${SECRETS_DIR}/amneziawg_private_key"
assert_env AMNEZIAWG_PRESHARED_KEY_SECRETFILE "${SECRETS_DIR}/amneziawg_preshared_key"
assert_env AMNEZIAWG_ADDRESSES_SECRETFILE "${SECRETS_DIR}/amneziawg_addresses"
assert_env AMNEZIAWG_JC 4
assert_env AMNEZIAWG_JMIN 40
assert_env AMNEZIAWG_H4 4
assert_file "${SECRETS_DIR}/amneziawg_private_key" fixture-amnezia-private
assert_file "${SECRETS_DIR}/amneziawg_preshared_key" fixture-amnezia-preshared
assert_log_excludes fixture-amnezia-private
assert_log_excludes fixture-amnezia-preshared
pass "AmneziaWG mapping and secret files"

run_success null-optionals.json
assert_env VPN_SERVICE_PROVIDER custom
assert_env VPN_TYPE openvpn
assert_env_absent OPENVPN_USER_SECRETFILE
assert_env_absent LOG_LEVEL
if grep -Eq '^[A-Z][A-Z0-9_]*=null$' "$ENV_OUTPUT"; then
    fail "Null optional value became string null"
fi
for path in \
    "${SECRETS_DIR}/openvpn_user" \
    "${SECRETS_DIR}/wireguard_private_key" \
    "${SECRETS_DIR}/amneziawg_private_key"
do
    [ ! -e "$path" ] || fail "Stale secret was not removed: $path"
done
pass "Null optionals omitted and stale secrets removed"

run_failure invalid-env-name.json
grep -Fq "bad-name" "$LOG_OUTPUT" || fail "Invalid name error missing"
assert_log_excludes fixture-invalid-value
pass "Invalid custom environment name rejected"

run_failure control-env-value.json
grep -Fq "control characters" "$LOG_OUTPUT" ||
    fail "Control character error missing"
pass "Custom environment control characters rejected"

run_failure managed-env-override.json
grep -Fq "VPN_TYPE" "$LOG_OUTPUT" || fail "Managed override error missing"
assert_log_excludes fixture-managed-override
pass "Managed environment override rejected"

run_failure protected-env-override.json
grep -Fq "LD_PRELOAD" "$LOG_OUTPUT" || fail "Protected override error missing"
assert_log_excludes fixture-protected-override
pass "Protected environment override rejected"

expected_entrypoint_tail=$(printf 'exec "$%s" "$%s"' GLUETUN_BIN @)
tail -n 1 "$ENTRYPOINT" | grep -Fq "$expected_entrypoint_tail" ||
    fail "Entrypoint does not exec Gluetun"
grep -Fq 'HEALTHCHECK --interval=5s' "${ADDON_DIR}/Dockerfile" ||
    fail "Native Gluetun healthcheck missing"
grep -Fq 'sha256:1a5bf4b4820a879cdf8d93d7ef0d2d963af56670c9ebff8981860b6804ebc8ab' \
    "${ADDON_DIR}/Dockerfile" || fail "Base image digest is not pinned"
grep -Fq 'ln -s /config /gluetun' "${ADDON_DIR}/Dockerfile" ||
    fail "Persistent Gluetun storage link missing"
broad_access_pattern='full_access|host_network|unconfined'
if grep -Eq "$broad_access_pattern" \
    "${ADDON_DIR}/config.yaml" "${ADDON_DIR}/apparmor.txt"
then
    fail "Forbidden broad access setting present"
fi
grep -Fq 'profile ADDON_SLUG' "${ADDON_DIR}/apparmor.txt" ||
    fail "AppArmor profile placeholder missing"
pass "Runtime exec, image pin, persistence, and confinement declarations"

printf '%s\n' "All Gluetun addon tests passed"
