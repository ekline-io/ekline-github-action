FROM ghcr.io/ekline-io/ekline-cli:7.30.2

RUN apk add --no-cache npm util-linux curl jq --update

RUN mkdir /code

WORKDIR /code

COPY . /code

RUN npm install --prefix /code

ENTRYPOINT ["/code/entrypoint.sh"]
