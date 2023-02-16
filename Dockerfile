FROM ghcr.io/ekline-io/ekline-cli:latest

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]