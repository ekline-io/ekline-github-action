############################
# STEP 1
############################
FROM golang:alpine AS builder

ENV REVIEWDOG_VERSION=v0.14.1

RUN apk update && apk add --no-cache  wget zip tar

WORKDIR /

RUN wget -O - -q https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s ${REVIEWDOG_VERSION}

RUN wget https://github.com/errata-ai/vale/releases/download/v2.21.3/vale_2.21.3_Linux_64-bit.tar.gz && \
    tar -xvzf vale_2.21.3_Linux_64-bit.tar.gz

############################
# STEP 2
############################
FROM alpine:3.17

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk update && apk add --no-cache git

COPY --from=builder /vale /usr/local/bin/vale
COPY --from=builder /bin/reviewdog /usr/local/bin/reviewdog

COPY files /files
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]