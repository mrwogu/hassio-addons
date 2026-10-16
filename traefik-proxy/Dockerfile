# renovate: datasource=docker depName=docker.io/library/traefik versioning=docker
ARG UPSTREAM_VERSION="v3.7.15"
ARG UPSTREAM_DIGEST="sha256:0f6150202bc1fed72a7bd2107460eaa510e5b8a905f3fdb5b84f2c8619c33368"
FROM docker.io/library/traefik:${UPSTREAM_VERSION}@${UPSTREAM_DIGEST}

LABEL \
    org.opencontainers.image.title="Home Assistant Traefik Proxy app" \
    org.opencontainers.image.description="Home Assistant adapter for Traefik Proxy" \
    org.opencontainers.image.source="https://github.com/mrwogu/hassio-addons" \
    org.opencontainers.image.licenses="MIT"

USER root

RUN apk add --no-cache jq logrotate python3 py3-yaml

COPY traefik.yml /etc/traefik/traefik.yml
COPY logrotate/traefik /etc/logrotate.d/traefik
COPY static-config.py /usr/local/bin/static-config.py
COPY dynamic-watcher.py /usr/local/bin/dynamic-watcher.py
COPY run.sh /usr/local/bin/run.sh
COPY rootfs/usr/local/bin/addon-entrypoint /usr/local/bin/addon-entrypoint

RUN chmod 0755 /usr/local/bin/static-config.py \
    /usr/local/bin/dynamic-watcher.py /usr/local/bin/run.sh \
    /usr/local/bin/addon-entrypoint \
    && chmod 0644 /etc/traefik/traefik.yml /etc/logrotate.d/traefik

ENTRYPOINT ["/usr/local/bin/addon-entrypoint"]
CMD []

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=5 \
    CMD ["/usr/local/bin/traefik", "healthcheck", "--configFile=/config/traefik/static.yml", "--ping=true", "--ping.entrypoint=health"]
