# renovate: datasource=docker depName=ghostfolio/ghostfolio versioning=semver
ARG UPSTREAM_VERSION="3.93.0"
ARG UPSTREAM_DIGEST="sha256:e5724d034def0e308c0089d3622711f2f643254870227e383f71f0b368f33489"
FROM ghostfolio/ghostfolio:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Ghostfolio addon" \
    org.opencontainers.image.description="Home Assistant adapter for Ghostfolio" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options. Supervisor writes /data/options.json owned by
# root with mode 0600, so the wrapper runs as root and gosu drops to the
# upstream node user for the application. tini stays PID 1 because Node does
# not handle SIGTERM as PID 1; upstream Compose uses init: true for the same
# reason. No Linux capabilities are granted.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq gosu tini \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

# The upstream launcher applies Prisma migrations, seeds the database, and
# then execs the API server.
ENTRYPOINT ["tini", "--", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=5 \
    CMD curl -fs --max-time 5 http://127.0.0.1:3333/api/v1/health || exit 1
