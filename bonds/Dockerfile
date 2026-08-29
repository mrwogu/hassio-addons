# renovate: datasource=docker depName=ghcr.io/naiba/bonds versioning=semver
ARG UPSTREAM_VERSION="0.22.11"
ARG UPSTREAM_DIGEST="sha256:ba252ab80dc49350f30442e2d5a2f23ef6d6e17befdf16ad1b80983c70a85d30"
FROM ghcr.io/naiba/bonds:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Bonds addon" \
    org.opencontainers.image.description="Home Assistant adapter for Bonds" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="BUSL-1.1"

RUN apk add --no-cache jq

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget --quiet --timeout=3 --output-document=/dev/null http://127.0.0.1:8080/ || exit 1
