FROM ghcr.io/ekline-io/ekline-cli:2.2.0

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]