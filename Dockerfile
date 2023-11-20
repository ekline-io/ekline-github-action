FROM ghcr.io/ekline-io/ekline-cli:5.1.3

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]