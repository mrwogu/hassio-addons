# renovate: datasource=docker depName=qmcgaw/gluetun versioning=docker
ARG UPSTREAM_VERSION="v3.41.3"
ARG UPSTREAM_DIGEST="sha256:fa19cc76b2af13d57a8d3dc3066f2ada061b1c761b8aecf989b3877c0486e027"
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
