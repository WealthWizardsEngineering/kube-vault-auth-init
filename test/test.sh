#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${DIR}/utils.sh

TEST_SUITE_RESULT=0

echo "Waiting for test data to load..."
sleep 10

source ${DIR}/tests/testSimpleKvV1Secret.sh || TEST_SUITE_RESULT=1
source ${DIR}/tests/testSimpleKvV2Secret.sh || TEST_SUITE_RESULT=1
source ${DIR}/tests/testDynamicSecret.sh || TEST_SUITE_RESULT=1
source ${DIR}/tests/testErrorReturnedWhenNoTokenOrSAProvided.sh || TEST_SUITE_RESULT=1
source ${DIR}/tests/testErrorReturnedWhenMandatoryVariablesNotProvided.sh || TEST_SUITE_RESULT=1
source ${DIR}/tests/testErrorReturnedWhenVaultAuthenticationFails.sh || TEST_SUITE_RESULT=1
source ${DIR}/tests/testErrorReturnedWhenPermissionDeniedGettingSecret.sh || TEST_SUITE_RESULT=1

if [[ "TEST_SUITE_RESULT" -gt 0 ]]; then
    printf "\n************************\n"
    printf "FAIL: There were test failures, inspect the details above for details\n"
fi

exit ${TEST_SUITE_RESULT}
