FROM ghcr.io/ekline-io/ekline-cli:3.0.2

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]