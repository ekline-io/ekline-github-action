############################
# STEP 1
############################
FROM golang:alpine AS builder

ENV REVIEWDOG_VERSION=v0.14.1

# Install build tools
RUN apk update && apk add --no-cache  wget zip tar

WORKDIR /

RUN wget -O - -q https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s ${REVIEWDOG_VERSION}

RUN wget https://github.com/errata-ai/vale/releases/download/v2.21.3/vale_2.21.3_Linux_64-bit.tar.gz && \
    tar -xvzf vale_2.21.3_Linux_64-bit.tar.gz

# Install Microsoft style file
#RUN wget https://github.com/errata-ai/Microsoft/releases/download/v0.8.1/Microsoft.zip && \
#    unzip Microsoft.zip
#
## Install Openly style file
#RUN wget https://github.com/testthedocs/Openly/releases/download/0.3.1/Openly.zip && \
#    unzip Openly.zip

############################
# STEP 2
############################
FROM alpine:3.17

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk update && apk add --no-cache git

# Copy our static executable.
COPY --from=builder /vale /usr/local/bin/vale
COPY --from=builder /bin/reviewdog /usr/local/bin/reviewdog
#COPY --from=builder /Microsoft /styles/Microsoft
#COPY --from=builder /Openly /styles/Openly

## Set the working directory to /app
#WORKDIR /app
#
## Copy the current directory contents into the container at /app
#COPY . /app

COPY files /files

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]


#ENTRYPOINT ["/usr/local/bin/vale", "src/content/", "--output=rdjsonl.tmpl"]




#FROM alpine:3.17
#
#ENV REVIEWDOG_VERSION=v0.14.1
#
#SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
#
## hadolint ignore=DL3006
#RUN apk --no-cache add git
#
#RUN wget -O - -q https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh| sh -s -- -b /usr/local/bin/ ${REVIEWDOG_VERSION}
#
## TODO: Install a linter and/or change docker image as you need.
#RUN wget -O - -q https://git.io/misspell | sh -s -- -b /usr/local/bin/
#
#COPY entrypoint.sh /entrypoint.sh
#
#ENTRYPOINT ["/entrypoint.sh"]
