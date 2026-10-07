# renovate: datasource=docker depName=ghcr.io/dictionarry-hub/profilarr versioning=semver
ARG UPSTREAM_VERSION="2.2.0"
ARG UPSTREAM_DIGEST="sha256:ddcdd0f340043c2ec0a85ca74b9a6be9be42b1c0288c75fc36a26a43f695860b"
FROM ghcr.io/dictionarry-hub/profilarr:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Profilarr addon" \
    org.opencontainers.image.description="Home Assistant adapter for Profilarr" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="AGPL-3.0"

# jq parses the add-on options; the upstream Alpine image keeps its own
# PUID/PGID setup and privilege drop.
RUN apk add --no-cache jq

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

# tini stays PID 1 like upstream; the wrapper translates options and hands
# off to the upstream entrypoint, which owns /config and drops privileges.
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/addon-entrypoint"]
CMD []
