FROM ghcr.io/ekline-io/ekline-cli:6.0.6

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]