# renovate: datasource=docker depName=ghcr.io/naiba/bonds versioning=semver
ARG UPSTREAM_VERSION="0.29.0"
ARG UPSTREAM_DIGEST="sha256:0b431e275cfd96f3f9fc3e8b071f30e1391ce71cc28b2e46333411ee6be5623e"
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
