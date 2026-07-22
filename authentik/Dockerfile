# renovate: datasource=docker depName=ghcr.io/goauthentik/server versioning=loose
ARG UPSTREAM_VERSION="2026.5.5"
ARG UPSTREAM_DIGEST="sha256:50a833c48a714709f15d4f8846ec6b81a41d0d6a6bd2975087dfed3000d0d72e"
FROM ghcr.io/goauthentik/server:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant authentik addon" \
    org.opencontainers.image.description="Home Assistant adapter for authentik" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options; the base image is Debian-based and ships as a
# non-root user, so switch to root only for the package and copy steps.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

USER 1000

# dumb-init stays PID 1 (as in the upstream image) to reap the server and
# worker children the allinone process spawns; the wrapper validates options
# and prepares persistent storage, then hands off to the upstream launcher.
ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=5 \
    CMD curl -fs --max-time 10 http://127.0.0.1:9000/-/health/live/ || exit 1
