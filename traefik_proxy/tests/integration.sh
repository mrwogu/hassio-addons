#!/bin/sh
set -eu

IMAGE=${IMAGE:-local/traefik-proxy:3.7.10-amd64}
PODMAN_ARCH=${PODMAN_ARCH:-amd64}
TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
WORK_DIR=$(mktemp -d)
CONTAINER="traefik-proxy-integration-$$"
HTTP_PORT=${HTTP_PORT:-19080}
HTTPS_PORT=${HTTPS_PORT:-19443}

cleanup() {
    podman rm --force "$CONTAINER" >/dev/null 2>&1 || true
    if [ -n "${BACKEND_PID:-}" ]; then
        kill "$BACKEND_PID" 2>/dev/null || true
        wait "$BACKEND_PID" 2>/dev/null || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf '%s\n' "FAIL: $*" >&2
    if [ -f "${WORK_DIR:-}/share/traefik/logs/traefik.log" ]; then
        tail -n 40 "${WORK_DIR}/share/traefik/logs/traefik.log" >&2
        if [ -f "${WORK_DIR}/share/traefik/logs/access.jsonl" ]; then
            tail -n 20 "${WORK_DIR}/share/traefik/logs/access.jsonl" >&2
        fi
        find "${WORK_DIR}/share/traefik" -maxdepth 3 -type f -print >&2
        if [ -f "${WORK_DIR}/share/traefik/dynamic/routes.yml" ]; then
            cat "${WORK_DIR}/share/traefik/dynamic/routes.yml" >&2
        fi
        if [ -f "${WORK_DIR}/share/traefik/dynamic/hot.yml" ]; then
            cat "${WORK_DIR}/share/traefik/dynamic/hot.yml" >&2
        fi
        if [ -n "${CONTAINER:-}" ]; then
            podman exec "$CONTAINER" ls -la /share/traefik/dynamic >&2 || true
            podman exec "$CONTAINER" sed -n '1,80p' /etc/traefik/traefik.yml >&2 || true
            podman exec "$CONTAINER" ps >&2 || true
        fi
    fi
    exit 1
}

wait_for_file() {
    path=$1
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ -s "$path" ] && return 0
        sleep 1
    done
    fail "Timed out waiting for $path"
}

wait_for_route() {
    host=$1
    expected=$2
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        status=$(curl --silent --insecure --output /dev/null \
            --write-out '%{http_code}' \
            -H "Host: ${host}" "https://127.0.0.1:${HTTPS_PORT}/")
        if [ "$status" = "$expected" ]; then
            return 0
        fi
        sleep 1
    done
    fail "Route ${host} did not return ${expected}, got ${status}"
}

wait_for_health() {
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        if podman exec "$CONTAINER" /usr/local/bin/traefik healthcheck \
            --configFile=/etc/traefik/traefik.yml \
            --ping=true --ping.entrypoint=health >/dev/null 2>&1
        then
            return 0
        fi
        sleep 1
    done
    fail "Traefik healthcheck did not become ready"
}

mkdir -p "$WORK_DIR/data" "$WORK_DIR/config" "$WORK_DIR/share/traefik/dynamic" \
    "$WORK_DIR/bin"
cp "${TEST_DIR}/fixtures/options.json" "$WORK_DIR/data/options.json"
if [ "${ACME_TEST:-false}" = true ]; then
    printf '%s' 'fixture-acme-token' >"$WORK_DIR/config/cloudflare-token"
    jq '.acme = {
        enabled: true,
        email: "acme-test@example.invalid",
        cloudflare_api_token: "",
        cloudflare_api_token_file: "/config/cloudflare-token"
    }' "$WORK_DIR/data/options.json" >"$WORK_DIR/data/options.json.tmp"
    mv "$WORK_DIR/data/options.json.tmp" "$WORK_DIR/data/options.json"
fi

BACKEND_PORT_FILE="${WORK_DIR}/backend.port"
BACKEND_LOG="${WORK_DIR}/backend.log"
BACKEND_PORT_FILE="$BACKEND_PORT_FILE" BACKEND_LOG="$BACKEND_LOG" \
    python3 - <<'PY' &
import base64
import hashlib
import http.server
import os

port_file = os.environ["BACKEND_PORT_FILE"]
log_file = os.environ["BACKEND_LOG"]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with open(log_file, "a", encoding="utf-8") as output:
            output.write(f"{self.path}\n")
        if self.path.startswith("/ws") and self.headers.get("Upgrade", "").lower() == "websocket":
            key = self.headers.get("Sec-WebSocket-Key", "")
            accept = base64.b64encode(
                hashlib.sha1(
                    (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
                ).digest()
            ).decode()
            self.send_response(101, "Switching Protocols")
            self.send_header("Upgrade", "websocket")
            self.send_header("Connection", "Upgrade")
            self.send_header("Sec-WebSocket-Accept", accept)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"backend-ok\n")

    def log_message(self, *_args):
        return


server = http.server.ThreadingHTTPServer(("0.0.0.0", 0), Handler)
with open(port_file, "w", encoding="utf-8") as output:
    output.write(str(server.server_port))
server.serve_forever()
PY
BACKEND_PID=$!
wait_for_file "$BACKEND_PORT_FILE"
BACKEND_PORT=$(cat "$BACKEND_PORT_FILE")

cat >"${WORK_DIR}/share/traefik/dynamic/routes.yml" <<'EOF'
---
http:
  routers:
    plain:
      rule: "Host(`plain.localhost`)"
      entryPoints:
        - websecure
      service: backend
      tls: {}
    websocket:
      rule: "Host(`ws.localhost`) && PathPrefix(`/ws`)"
      entryPoints:
        - websecure
      service: backend
      tls: {}
  services:
    backend:
      loadBalancer:
        servers:
          - url: "http://host.containers.internal:__BACKEND_PORT__"
EOF
sed -i.bak "s/__BACKEND_PORT__/${BACKEND_PORT}/" \
    "${WORK_DIR}/share/traefik/dynamic/routes.yml"
rm -f "${WORK_DIR}/share/traefik/dynamic/routes.yml.bak"

podman run --detach --name "$CONTAINER" --arch "$PODMAN_ARCH" \
    --publish "${HTTP_PORT}:80" --publish "${HTTPS_PORT}:443" \
    --volume "$WORK_DIR/data:/data" --volume "$WORK_DIR/config:/config" \
    --volume "$WORK_DIR/share:/share" \
    "$IMAGE" >/dev/null

sleep 5
wait_for_health
if [ "${ACME_TEST:-false}" = true ]; then
    acme_file="$WORK_DIR/config/traefik/acme.json"
    [ -f "$acme_file" ] || fail "ACME storage file missing"
    acme_mode=$(stat -c '%a' "$acme_file" 2>/dev/null || stat -f '%Lp' "$acme_file")
    [ "$acme_mode" = 600 ] || fail "ACME storage mode is $acme_mode, expected 600"
    if grep -Fq 'fixture-acme-token' "$WORK_DIR/share/traefik/logs/traefik.log"; then
        fail "Cloudflare token leaked into application log"
    fi
fi

http_status=$(curl --silent --show-error --output /dev/null \
    --write-out '%{http_code}' "http://127.0.0.1:${HTTP_PORT}/")
[ "$http_status" = 301 ] || fail "HTTP redirect returned $http_status"

wait_for_route plain.localhost 200
body=$(curl --silent --insecure -H 'Host: plain.localhost' \
    "https://127.0.0.1:${HTTPS_PORT}/")
[ "$body" = "backend-ok" ] || fail "HTTP backend returned unexpected body"

websocket_status=$(curl --silent --insecure --output /dev/null \
    --write-out '%{http_code}' \
    --http1.1 \
    -H 'Host: ws.localhost' \
    -H 'Connection: Upgrade' \
    -H 'Upgrade: websocket' \
    -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: dGVzdC13ZWJzb2NrZXQ=' \
    "https://127.0.0.1:${HTTPS_PORT}/ws") || true
[ "$websocket_status" = 101 ] || fail "WebSocket upgrade returned $websocket_status"

log_file="$WORK_DIR/share/traefik/logs/access.jsonl"
wait_for_file "$log_file"
jq -e . "$log_file" >/dev/null
grep -Fq '"ClientHost"' "$log_file" || fail "ClientHost missing from access log"
grep -Fq '"RequestHost"' "$log_file" || fail "RequestHost missing from access log"
grep -Fq '"DownstreamStatus"' "$log_file" ||
    fail "DownstreamStatus missing from access log"
grep -Fq '"RetryAttempts"' "$log_file" ||
    fail "RetryAttempts missing from access log"

curl --silent --insecure --output /dev/null \
    -H 'Host: plain.localhost' \
    -H 'CF-Connecting-IP: 198.51.100.24' \
    -H 'X-Forwarded-For: 198.51.100.24' \
    -H 'X-Real-IP: 198.51.100.24' \
    "https://127.0.0.1:${HTTPS_PORT}/"
sleep 1
grep -Fq '"request_Cf-Connecting-Ip":"198.51.100.24"' "$log_file" ||
    fail "Cloudflare client-IP header was not retained"

curl --silent --insecure --output /dev/null \
    -H 'Host: plain.localhost' \
    -H 'Cookie: fixture-cookie-secret' \
    -H 'Authorization: Bearer fixture-access-token' \
    -H 'X-Api-Key: fixture-api-key' \
    "https://127.0.0.1:${HTTPS_PORT}/?access_token=fixture-query-token"
sleep 1
for secret in fixture-cookie-secret fixture-access-token fixture-api-key fixture-query-token; do
    if grep -Fq "$secret" "$log_file"; then
        fail "Protected value leaked into access log: $secret"
    fi
done

dashboard_status=$(curl --silent --insecure --output /dev/null \
    --write-out '%{http_code}' \
    -H 'Host: proxy-admin.localhost' \
    "https://127.0.0.1:${HTTPS_PORT}/dashboard/")
[ "$dashboard_status" = 404 ] || fail "Dashboard unexpectedly returned $dashboard_status"

cat >"${WORK_DIR}/hot.yml" <<'EOF'
---
http:
  routers:
    hot:
      rule: "Host(`hot.localhost`)"
      entryPoints:
        - websecure
      service: backend
      tls: {}
EOF
podman exec --interactive "$CONTAINER" /bin/sh \
    -c 'cat > /share/traefik/dynamic/hot.yml' <"${WORK_DIR}/hot.yml"
wait_for_route hot.localhost 200

cat >"${WORK_DIR}/broken.yml" <<'EOF'
http:
  routers:
    broken:
      rule: "Host(`broken.localhost`)"
      service: [
EOF
podman exec --interactive "$CONTAINER" /bin/sh \
    -c 'cat > /share/traefik/dynamic/broken.yml' <"${WORK_DIR}/broken.yml"
sleep 2
grep -Eiq 'error|invalid|configuration' "$WORK_DIR/share/traefik/logs/traefik.log" ||
    fail "Invalid dynamic configuration was not logged"
wait_for_route hot.localhost 200

podman exec "$CONTAINER" logrotate -f \
    -s /config/forced-logrotate.status /etc/logrotate.d/traefik
[ -f "$WORK_DIR/share/traefik/logs/access.jsonl" ] ||
    fail "Active access log missing after rotation"
[ -f "$WORK_DIR/share/traefik/logs/traefik.log" ] ||
    fail "Active application log missing after rotation"

podman restart "$CONTAINER" >/dev/null
wait_for_health
wait_for_route hot.localhost 200

printf '%s\n' "Traefik Proxy integration tests passed"
