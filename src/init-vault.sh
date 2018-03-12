#!/usr/bin/env sh

#!/bin/bash
set -eo pipefail

validateVaultResponse () {
  if echo ${2} | grep "errors"; then
    echo "ERROR: unable to retrieve ${1}: ${2}"
    exit 1
  fi
}

# Allow me to pass a KUBE_SA_TOKEN so I can test this without having to run it on Kube
if [[ -z $KUBE_SA_TOKEN ]]; then
  KUBE_SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
fi

#########################################################################

echo "Getting token from Vault server: ${VAULT_ADDR}"

# Login to Vault and so I can get an approle token
VAULT_LOGIN_TOKEN=$(curl -sS --request POST \
  ${VAULT_ADDR}/v1/auth/${KUBERNETES_AUTH_PATH}/login \
  -H "Content-Type: application/json" \
  -d '{"role":"'"${VAULT_LOGIN_ROLE}"'","jwt":"'"${KUBE_SA_TOKEN}"'"}' | \
  jq -r 'if .errors then . else .auth.client_token end')

validateVaultResponse 'vault login token' "${VAULT_LOGIN_TOKEN}"

ROLE_ID=$(curl -sS --header "X-Vault-Token: ${VAULT_LOGIN_TOKEN}" \
  ${VAULT_ADDR}/v1/auth/approle/role/${VAULT_LOGIN_ROLE}/role-id | \
  jq -r 'if .errors then . else .data.role_id end')

validateVaultResponse 'role id' "${ROLE_ID}"

SECRET_ID=$(curl -sS --header "X-Vault-Token: ${VAULT_LOGIN_TOKEN}" \
  --request POST \
  ${VAULT_ADDR}/v1/auth/approle/role/${VAULT_LOGIN_ROLE}/secret-id | \
  jq -r 'if .errors then . else .data.secret_id end')

validateVaultResponse 'secret id' "${SECRET_ID}"

APPROLE_TOKEN=$(curl -sS --request POST \
  --data '{"role_id":"'"$ROLE_ID"'","secret_id":"'"$SECRET_ID"'"}' \
  ${VAULT_ADDR}/v1/auth/approle/login | \
  jq -r 'if .errors then . else .auth.client_token end')

validateVaultResponse 'approle id' "${APPROLE_TOKEN}"

echo ${APPROLE_TOKEN}
echo "VAULT_TOKEN=${APPROLE_TOKEN}" > /env/variables