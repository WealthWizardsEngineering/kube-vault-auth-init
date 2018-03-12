FROM alpine

WORKDIR /usr/src

RUN apk add --no-cache curl jq
RUN mkdir /env

COPY src/* /usr/src/
RUN chmod u+x /usr/src/*.sh

CMD /usr/src/init-token.sh