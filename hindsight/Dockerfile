# renovate: datasource=docker depName=ghcr.io/vectorize-io/hindsight versioning=semver
ARG UPSTREAM_VERSION="0.9.2"
ARG UPSTREAM_DIGEST="sha256:84ab276b8f501546deb6ea9c64a57291718b4e16a59dd9e02a02fdd5adfe9028"
FROM ghcr.io/vectorize-io/hindsight:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Hindsight addon" \
    org.opencontainers.image.description="Home Assistant adapter for Hindsight" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# The adapter needs jq for option parsing; the upstream image ships without it.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*
USER hindsight

# The upstream image runs as a non-root user; use COPY --chmod instead of a
# RUN chmod, which would need elevated privileges the build does not have.
COPY --chmod=0755 rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD ["/app/start-all.sh"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl --silent --fail --max-time 3 http://127.0.0.1:${HINDSIGHT_API_PORT:-8888}/health || exit 1
