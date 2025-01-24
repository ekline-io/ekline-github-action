FROM ghcr.io/ekline-io/ekline-cli:7

RUN apk add --no-cache npm util-linux curl jq --update

COPY dist/reviewdog /usr/local/bin/reviewdog

RUN mkdir /code

WORKDIR /code

COPY . /code

RUN npm install --prefix /code

ENTRYPOINT ["/code/entrypoint.sh"]
