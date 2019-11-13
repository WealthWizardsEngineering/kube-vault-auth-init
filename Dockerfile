FROM vault

WORKDIR /usr/src

RUN apk add --no-cache bash curl jq
RUN mkdir /env

COPY src/* /usr/src/
RUN chmod u+x /usr/src/*.sh

CMD /usr/src/init-token.sh
