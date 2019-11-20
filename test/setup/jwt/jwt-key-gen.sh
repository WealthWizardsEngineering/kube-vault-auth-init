#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ssh-keygen -t rsa -b 4096 -m PEM -P "" -f ${DIR}/certificates/jwtRS256.key
openssl rsa -in ${DIR}/certificates/jwtRS256.key -pubout -outform PEM -out ${DIR}/certificates/jwtRS256.key.pub
