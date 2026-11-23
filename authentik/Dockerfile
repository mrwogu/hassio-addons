# renovate: datasource=docker depName=ghcr.io/goauthentik/server versioning=loose
ARG UPSTREAM_VERSION="2026.8.6"
ARG UPSTREAM_DIGEST="sha256:da89d8338a3b1889800eb033fd61f8d43f7aa9a1c5a042cb5e03d891b1f0c56c"
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
