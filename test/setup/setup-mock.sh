#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

curl -v -X PUT "http://mock:1080/mockserver/clear" -d "@${DIR}/kubernetes/clear-token-review.json"

curl -v -X PUT "http://mock:1080/mockserver/expectation" -d "@${DIR}/kubernetes/token-review-body.json"
