# The upstream LinuxServer.io ddclient image is abandoned (last build sits on
# Alpine 3.12 with many fixed CVEs) and ddclient publishes no official image, so
# this add-on installs the maintained Alpine community ddclient package on a
# current, digest-pinned Alpine base. UPSTREAM_VERSION tracks the ddclient
# application version; UPSTREAM_DIGEST pins the Alpine base image.
# renovate: datasource=docker depName=alpine versioning=docker
ARG UPSTREAM_VERSION="3.11.2"
ARG UPSTREAM_DIGEST="sha256:48b0309ca019d89d40f670aa1bc06e426dc0931948452e8491e3d65087abc07d"
FROM alpine:3.21@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant ddclient addon" \
    org.opencontainers.image.description="Home Assistant adapter for ddclient" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="GPL-2.0-or-later"

# apk upgrade pulls the latest patched base packages within the pinned Alpine
# branch. ddclient is pinned to an exact package version; jq parses the add-on
# options and the perl modules cover TLS and common provider protocols.
RUN apk upgrade --no-cache \
    && apk add --no-cache \
        ddclient=3.11.2-r0 \
        ca-certificates \
        jq \
        perl-io-socket-ssl \
        perl-json

COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/addon-entrypoint

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD []

# ddclient runs one-shot per cycle, so health tracks the supervising entrypoint.
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pgrep -f addon-entrypoint >/dev/null 2>&1 || exit 1
