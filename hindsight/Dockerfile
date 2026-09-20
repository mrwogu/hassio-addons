# renovate: datasource=docker depName=ghcr.io/vectorize-io/hindsight versioning=semver
ARG UPSTREAM_VERSION="0.10.0"
ARG UPSTREAM_DIGEST="sha256:3edcb6165cefdeaa6721dd0fce43cfd13b7a9c346ce0d2c5f4b4bf7bc3c8ac0b"
FROM ghcr.io/vectorize-io/hindsight:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Hindsight addon" \
    org.opencontainers.image.description="Home Assistant adapter for Hindsight" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# The adapter needs jq for option parsing; the upstream image ships without it.
# gosu drops to the upstream non-root user after the Supervisor-only option
# reads; Supervisor keeps /data root-only, so parsing must run as root.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD ["/app/start-all.sh"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl --silent --fail --max-time 3 http://127.0.0.1:${HINDSIGHT_API_PORT:-8888}/health || exit 1
