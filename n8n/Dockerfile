# renovate: datasource=docker depName=ghcr.io/n8n-io/n8n versioning=semver
ARG UPSTREAM_VERSION="2.32.7"
ARG UPSTREAM_DIGEST="sha256:882b126a8ddd0646e7d17ec47630e7704615e4647f3363471859fddc3f8946e2"
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
# signed Alpine package manager before installing the small adapter tools.
# renovate: datasource=repology depName=alpine_3_24/apk-tools-static versioning=loose
ARG APK_TOOLS_VERSION="3.0.7-r0"
ARG ALPINE_VERSION="v3.24"
RUN set -eux; \
    cd /tmp; \
    wget -nv "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/main/$(uname -m)/apk-tools-static-${APK_TOOLS_VERSION}.apk"; \
    tar -xzf "apk-tools-static-${APK_TOOLS_VERSION}.apk"; \
    ./sbin/apk.static add --no-cache apk-tools; \
    rm -rf /tmp/*

RUN apk add --no-cache jq openssl su-exec

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# The wrapper prepares persistent storage and environment, then hands off to
# the upstream launcher so its certificate handling and signal behavior remain.
ENTRYPOINT ["tini", "--", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD wget -q -O /dev/null --timeout=5 http://127.0.0.1:5678/healthz || exit 1
