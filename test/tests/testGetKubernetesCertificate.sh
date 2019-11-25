#!/usr/bin/env bash

printf "\n************************\n"
printf "Running test: Test that it's possible to retrieve the kubernetes certificate\n"

################################################

# set up standard inputs required for running within the test framework
echo 'path "auth/kubernetes/config" { capabilities = [ "read" ] }' | VAULT_TOKEN=${SETUP_VAULT_TOKEN} vault policy write my-policy - > /dev/null
export VAULT_TOKEN=$(VAULT_TOKEN=${SETUP_VAULT_TOKEN} vault token create -policy=my-policy -period=1m -field=token)
export VARIABLES_FILE=$(mktemp -d)/variables

################################################

# set up inputs for this test
export SECRET_MY_SECRET=auth/kubernetes/config?kubernetes_ca_cert

/usr/src/init-token.sh  2>&1 >&1 | sed 's/^/>> /'
RESULT="${PIPESTATUS[0]}"
[ "${RESULT}" -gt "0" ] && printf "ERROR: Script returned a non-zero exit code\n"

################################################

# assert output
assertVaultToken "$(getOutputValue ${VARIABLES_FILE} VAULT_TOKEN)" || RESULT=1
assertNotEmpty "MY_SECRET should be set" "$(getOutputValue ${VARIABLES_FILE} MY_SECRET)" || RESULT=1
assertEmpty "LEASE_IDS should not be set" "$(getOutputValue ${VARIABLES_FILE} LEASE_IDS)" || RESULT=1

################################################

# clean up
VAULT_TOKEN=${SETUP_VAULT_TOKEN} vault policy delete my-policy > /dev/null
VAULT_TOKEN=${SETUP_VAULT_TOKEN} vault token revoke "$(getOutputValue ${VARIABLES_FILE} VAULT_TOKEN)" > /dev/null

cleanEnv

[[ "${RESULT}" -eq 0 ]] && printf "Test passed\n"
return ${RESULT}
