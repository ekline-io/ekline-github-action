FROM ghcr.io/ekline-io/ekline-cli:2.1.2

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]