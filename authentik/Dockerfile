# renovate: datasource=docker depName=ghcr.io/goauthentik/server versioning=loose
ARG UPSTREAM_VERSION="2026.8.1"
ARG UPSTREAM_DIGEST="sha256:9d605ed569ff9f39146be39da93714b2acf19072acc4ab0f0e2f2d81be88cdce"
FROM ghcr.io/goauthentik/server:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant authentik addon" \
    org.opencontainers.image.description="Home Assistant adapter for authentik" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options. Home Assistant's Supervisor writes
# /data/options.json owned by root with mode 0600, so the wrapper must run as
# root to read it; the Supervisor sandboxes the container and no Linux
# capabilities are granted.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# dumb-init stays PID 1 (as in the upstream image) to reap the server and
# worker children the allinone process spawns; the wrapper validates options
# and prepares persistent storage, then hands off to the upstream launcher.
ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=5 \
    CMD curl -fs --max-time 10 http://127.0.0.1:9000/-/health/live/ || exit 1
