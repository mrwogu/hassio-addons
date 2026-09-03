# renovate: datasource=docker depName=ghcr.io/n8n-io/n8n versioning=semver
ARG UPSTREAM_VERSION="2.38.3"
ARG UPSTREAM_DIGEST="sha256:4b76b9c5a69dc1c0f26bedd21b4e281ac2c84bd88d33857487b9e63dd0a42e87"

# renovate: datasource=docker depName=ghcr.io/n8n-io/runners versioning=semver
ARG RUNNERS_VERSION="2.37.6"
ARG RUNNERS_DIGEST="sha256:74bf10f1b12943a787f155853c177c5af4b3ec24a810887a1772d252ced82654"
FROM ghcr.io/n8n-io/runners:${RUNNERS_VERSION}@${RUNNERS_DIGEST} AS task-runners

FROM ghcr.io/n8n-io/n8n:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant n8n addon" \
    org.opencontainers.image.description="Home Assistant adapter for n8n" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options. Home Assistant's Supervisor writes
# /data/options.json owned by root with mode 0600, so the wrapper must run as
# root to read it; no Linux capabilities are granted.
USER root

# The Docker Hardened Alpine base omits the package manager. Bootstrap the
# pinned Alpine package manager before installing the small adapter tools.
# renovate: datasource=repology depName=alpine_3_24/apk-tools-static versioning=loose
ARG APK_TOOLS_VERSION="3.0.8-r0"
ARG ALPINE_VERSION="v3.24"
ARG APK_TOOLS_SHA256_X86_64="c8e2c88c13ba12a12269b79a3543e1190ff8c0ab0beb32b58cadfd5881c619e3"
ARG APK_TOOLS_SHA256_AARCH64="7e86f8258f3a97ea1c279105950ebf6c9af960891eb499f731b7e5f0af26ff63"
RUN set -eux; \
    cd /tmp; \
    arch=$(uname -m); \
    case "$arch" in \
        x86_64) expected="$APK_TOOLS_SHA256_X86_64" ;; \
        aarch64) expected="$APK_TOOLS_SHA256_AARCH64" ;; \
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    package="apk-tools-static-${APK_TOOLS_VERSION}.apk"; \
    wget -nv "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/main/${arch}/${package}"; \
    printf '%s  %s\n' "$expected" "$package" | sha256sum -c -; \
    tar -xzf "$package"; \
    ./sbin/apk.static add --no-cache apk-tools; \
    rm -rf /tmp/*

RUN apk add --no-cache jq openssl python3 su-exec

# Internal Python runners need the package, virtual environment, and matching
# interpreter. The upstream n8n image contains none of these files.
COPY --from=task-runners /opt/runners/task-runner-python /usr/local/lib/node_modules/@n8n/task-runner-python
COPY --from=task-runners /usr/local/bin/python3.13 /usr/local/bin/python3.13
COPY --from=task-runners /usr/local/lib/libpython3.13.so* /usr/local/lib/
COPY --from=task-runners /usr/local/lib/python3.13 /usr/local/lib/python3.13

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# The wrapper prepares persistent storage and environment, then hands off to
# the upstream launcher so its certificate handling and signal behavior remain.
ENTRYPOINT ["tini", "--", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD wget -q -O /dev/null --timeout=5 http://127.0.0.1:5678/healthz || exit 1
