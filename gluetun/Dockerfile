# renovate: datasource=docker depName=qmcgaw/gluetun versioning=docker
ARG UPSTREAM_VERSION="v3.41.1"
ARG UPSTREAM_DIGEST="sha256:1a5bf4b4820a879cdf8d93d7ef0d2d963af56670c9ebff8981860b6804ebc8ab"
FROM qmcgaw/gluetun:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Gluetun addon" \
    org.opencontainers.image.description="Home Assistant adapter for Gluetun" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

RUN apk upgrade --no-cache \
    && apk add --no-cache jq \
    && rm -rf /gluetun \
    && ln -s /config /gluetun

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]

HEALTHCHECK --interval=5s --timeout=5s --start-period=10s --retries=3 \
    CMD /gluetun-entrypoint healthcheck
