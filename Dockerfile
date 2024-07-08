FROM ghcr.io/ekline-io/ekline-cli:7.4.2

RUN apk add --no-cache npm util-linux --update

RUN mkdir /code

WORKDIR /code

COPY . /code

RUN npm install --prefix /code

ENTRYPOINT ["/code/entrypoint.sh"]
