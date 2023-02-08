FROM puneetar/ekline-github-action-docker:v3.0

COPY files /files
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]