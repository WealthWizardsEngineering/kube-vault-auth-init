#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Waiting for test services to start..."
sleep 5

${DIR}/setup-mock.sh

${DIR}/vault/setup.sh
