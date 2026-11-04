ARG TOOLS_VERSION="3.22.7"
ARG TOOLS_DIGEST="sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f"
# renovate: datasource=docker depName=docker.io/grafana/loki versioning=semver
ARG UPSTREAM_VERSION="3.7.9"
ARG UPSTREAM_DIGEST="sha256:0db216b630ae1f348a1584c67f3cead8b4c1fc839169a39501db664744158e28"

# The upstream image has no jq (and no shell). A pinned Alpine stage supplies a
# static busybox and jq with its musl loader under /opt/addon. jq runs through
# the bundled loader, so the upstream userland is left untouched.
FROM docker.io/library/alpine:${TOOLS_VERSION}@${TOOLS_DIGEST} AS tools
RUN set -eu; \
    apk add --no-cache busybox-static jq; \
    root=/out/opt/addon; \
    mkdir -p "$root/bin" "$root/lib" "$root/libexec"; \
    cp /bin/busybox.static "$root/bin/busybox"; \
    for applet in sh cat grep mkdir chmod mktemp dirname rm mv wget; do ln -s busybox "$root/bin/$applet"; done; \
    cp /usr/bin/jq "$root/libexec/jq"; \
    cp -a /usr/lib/libjq.so.1* /usr/lib/libonig.so.5* /lib/ld-musl-*.so.1 /lib/libc.musl-*.so.1 "$root/lib/"; \
    loader=$(basename /lib/ld-musl-*.so.1); \
    printf '#!/opt/addon/bin/sh\nexec /opt/addon/lib/%s --library-path /opt/addon/lib /opt/addon/libexec/jq "$@"\n' "$loader" > "$root/bin/jq"; \
    chmod 0755 "$root/bin/jq"; \
    ln -s "$root" /opt/addon; \
    /opt/addon/bin/jq --version

FROM docker.io/grafana/loki:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Loki addon" \
    org.opencontainers.image.description="Home Assistant adapter for Loki" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="AGPL-3.0"

USER root

ENV PATH="/opt/addon/bin:${PATH}"

COPY --from=tools /out/opt/addon /opt/addon
COPY --chmod=0755 rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

# The wrapper translates add-on options into an upstream config file and
# finishes with exec, so signals reach the upstream process.
ENTRYPOINT ["/opt/addon/bin/sh", "/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
    CMD ["/opt/addon/bin/wget", "-q", "-O", "/dev/null", "http://127.0.0.1:3100/ready"]
