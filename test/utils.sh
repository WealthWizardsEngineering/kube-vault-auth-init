#!/usr/bin/env bash

function getOutputValue()
{
    local VARIABLES_FILE="$1"
    local VARIABLE_NAME="$2"

    local temp=$(grep "^export ${VARIABLE_NAME}=" ${VARIABLES_FILE} | awk -F "=" '{print $2}')
    temp="${temp%\"}"
    printf "${temp#\"}"
}

function assertEquals()
{
    local MESSAGE="$1"
    local EXPECTED_STRING="$2"
    local ACTUAL_STRING="$3"

    if [[ "${EXPECTED_STRING}" = "${ACTUAL_STRING}" ]]; then
        return 0
    else
        printf "FAILED: ${MESSAGE}, expected: ${EXPECTED_STRING}, but was: ${ACTUAL_STRING}\n"
        return 1
    fi
}

function assertVaultToken()
{
    local VAULT_TOKEN_TO_TEST="$1"

    if OUTPUT="$(VAULT_TOKEN=${VAULT_TOKEN_TO_TEST} vault token lookup 2>&1)"; then
      return 0
    else
      printf "FAILED: token is not valid:\n${OUTPUT}\n"
      return 1
    fi
}
