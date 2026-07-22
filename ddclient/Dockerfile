# renovate: datasource=docker depName=ghcr.io/linuxserver/ddclient versioning=loose
ARG UPSTREAM_VERSION="v3.9.1-ls69"
ARG UPSTREAM_DIGEST="sha256:c33de1e3bcdb6105429468f00c36d0da0f8d3fc1ef9cc4dce44913c631f6e732"
FROM ghcr.io/linuxserver/ddclient:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant ddclient addon" \
    org.opencontainers.image.description="Home Assistant adapter for ddclient" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="GPL-2.0-or-later"

# jq parses the add-on options. The base image is Alpine-based; its s6-overlay
# init starts as root and reads the root-owned /data/options.json before it
# drops to the service user.
RUN apk add --no-cache jq

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# The wrapper writes /config/ddclient.conf from the add-on options, then hands
# off to the upstream s6-overlay init (/init) so it keeps PID 1 and starts the
# ddclient daemon unchanged.
ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pidof ddclient >/dev/null 2>&1 || exit 1
