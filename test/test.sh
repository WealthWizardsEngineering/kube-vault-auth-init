#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${DIR}/utils.sh

RESULT=0

echo "Waiting for test data to load..."
sleep 10

source ${DIR}/tests/testSimpleKvV1Secret.sh || RESULT=1
source ${DIR}/tests/testSimpleKvV2Secret.sh || RESULT=1
source ${DIR}/tests/testDynamicSecret.sh || RESULT=1

if [[ "$RESULT" -gt 0 ]]; then
    printf "\n************************\n"
    printf "FAIL: There were test failures, inspect the details above for details\n"
fi

exit ${RESULT}
