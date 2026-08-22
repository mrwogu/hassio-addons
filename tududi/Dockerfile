# renovate: datasource=docker depName=chrisvel/tududi versioning=semver
ARG UPSTREAM_VERSION="1.4.1"
ARG UPSTREAM_DIGEST="sha256:864d1a9f9cba650fba5d12da9693d9711b4199a58c3bb0eba20be7952f707d97"
FROM chrisvel/tududi:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Tududi addon" \
    org.opencontainers.image.description="Home Assistant adapter for Tududi" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options; the upstream Alpine image runs its own
# permission setup and privilege drop after the adapter prepares /config.
RUN apk add --no-cache jq

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# The upstream launcher keeps dumb-init as PID 1 and forwards signals to
# Tududi after preparing the database and running migrations.
ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
    CMD wget -q --spider --timeout=5 http://127.0.0.1:3002/api/health || exit 1
