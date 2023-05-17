FROM ghcr.io/ekline-io/ekline-cli:4.4.0

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]