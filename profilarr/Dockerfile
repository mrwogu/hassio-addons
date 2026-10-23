# renovate: datasource=docker depName=ghcr.io/dictionarry-hub/profilarr versioning=semver
ARG UPSTREAM_VERSION="2.3.1"
ARG UPSTREAM_DIGEST="sha256:352e42dec74ecfd68d13bb198fbc6d9346e3a8c55003026e1814e59319a2176d"
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
