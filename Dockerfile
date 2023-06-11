FROM ghcr.io/ekline-io/ekline-cli:4.4.0
RUN apk add jq --no-cache

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]