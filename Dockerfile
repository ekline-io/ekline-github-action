FROM ghcr.io/ekline-io/ekline-cli:6.1.0

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]