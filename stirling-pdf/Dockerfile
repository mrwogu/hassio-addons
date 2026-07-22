# renovate: datasource=docker depName=ghcr.io/stirling-tools/stirling-pdf versioning=semver
ARG UPSTREAM_VERSION="2.14.2"
ARG UPSTREAM_DIGEST="sha256:7ed4d9681d18e4fbc3aa6a63647c4b5c2bcc4b75841df7c05d7e3d2320f5c9a1"
FROM ghcr.io/stirling-tools/stirling-pdf:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Stirling-PDF addon" \
    org.opencontainers.image.description="Home Assistant adapter for Stirling-PDF" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options; the base image is Debian-based. The OpenSSL
# upgrade patches CVE-2026-45447 (fixed in the Ubuntu archive, not yet in the
# pinned base image).
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && apt-get install -y --only-upgrade libssl3t64 openssl \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# tini stays PID 1 to reap the LibreOffice, Tesseract, and Ghostscript
# children Stirling spawns; the wrapper prepares storage and env, then hands
# off to the upstream init script unchanged.
ENTRYPOINT ["tini", "--", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=5 \
    CMD curl -fs --max-time 10 http://127.0.0.1:8080/api/v1/info/status || exit 1
