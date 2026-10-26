# renovate: datasource=docker depName=docker.io/library/alpine versioning=docker
ARG UPSTREAM_VERSION="3.24.3"
ARG UPSTREAM_DIGEST="sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a"
FROM docker.io/library/alpine:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Postgres Backup addon" \
    org.opencontainers.image.description="Hot SQL dumps of the Postgres 16 add-on for Home Assistant backups" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT AND PostgreSQL"

# Official postgres tags like 16.15-alpine do not fit the <x.y.z>-<revision>
# version rule, so the client tools come from Alpine instead. The package
# name keeps the major at 16 to match the Postgres 16 add-on.
RUN apk add --no-cache jq postgresql16-client

COPY rootfs/ /

RUN chmod 0755 /usr/local/bin/addon-entrypoint /usr/local/bin/pg-backup

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD []
