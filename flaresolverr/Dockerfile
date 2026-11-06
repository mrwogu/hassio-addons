# renovate: datasource=docker depName=ghcr.io/flaresolverr/flaresolverr versioning=semver
ARG UPSTREAM_VERSION="3.5.2"
ARG UPSTREAM_DIGEST="sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767"
FROM ghcr.io/flaresolverr/flaresolverr:v${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant FlareSolverr addon" \
    org.opencontainers.image.description="Home Assistant adapter for FlareSolverr" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

# jq parses the add-on options. The upstream image runs as an unprivileged
# user, so switch to root only for the install.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*
USER flaresolverr

COPY --chmod=0755 rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

# dumb-init stays PID 1 like upstream; the wrapper validates options and
# finishes with exec, so signals reach the upstream process.
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/addon-entrypoint"]
CMD ["/usr/local/bin/python", "-u", "/app/flaresolverr.py"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD ["/usr/local/bin/python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8191/health', timeout=5)"]
