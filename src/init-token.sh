#!/usr/bin/env sh

set -eo pipefail

validateVaultResponse () {
  if echo ${2} | grep "errors"; then
    echo "ERROR: unable to retrieve ${1}: ${2}"
    exit 1
  fi
}

# Allow KUBE_SA_TOKEN to be injected so that it can be tested without
# being deployed to Kubernetes
if [[ -z $KUBE_SA_TOKEN ]]; then
  KUBE_SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
fi

#########################################################################

echo "Getting auth token from Vault server: ${VAULT_ADDR}"

# Login to Vault and so I can get an approle token
VAULT_LOGIN_TOKEN=$(curl -sS --request POST \
  ${VAULT_ADDR}/v1/auth/${KUBERNETES_AUTH_PATH}/login \
  -H "Content-Type: application/json" \
  -d '{"role":"'"${VAULT_LOGIN_ROLE}"'","jwt":"'"${KUBE_SA_TOKEN}"'"}' | \
  jq -r 'if .errors then . else .auth.client_token end')
validateVaultResponse 'vault login token' "${VAULT_LOGIN_TOKEN}"

VAULT_ROLE_ID=$(curl -sS --header "X-Vault-Token: ${VAULT_LOGIN_TOKEN}" \
  ${VAULT_ADDR}/v1/auth/approle/role/${VAULT_LOGIN_ROLE}/role-id | \
  jq -r 'if .errors then . else .data.role_id end')
validateVaultResponse 'role id' "${VAULT_ROLE_ID}"

VAULT_SECRET_ID=$(curl -sS --header "X-Vault-Token: ${VAULT_LOGIN_TOKEN}" \
  --request POST \
  ${VAULT_ADDR}/v1/auth/approle/role/${VAULT_LOGIN_ROLE}/secret-id | \
  jq -r 'if .errors then . else .data.secret_id end')
validateVaultResponse 'secret id' "${VAULT_SECRET_ID}"

APPROLE_TOKEN=$(curl -sS --request POST \
  --data '{"role_id":"'"$VAULT_ROLE_ID"'","secret_id":"'"$VAULT_SECRET_ID"'"}' \
  ${VAULT_ADDR}/v1/auth/approle/login | \
  jq -r 'if .errors then . else .auth.client_token end')
validateVaultResponse 'approle id' "${APPROLE_TOKEN}"

echo "export VAULT_TOKEN=${APPROLE_TOKEN}" > /env/variables

#########################################################################

echo "Getting secrets from Vault"

# Get all environment variables prefixed with SECRET_ and retrieve the secret from vault based on the value
INJECTED_SECRET_KEYS=$(printenv | grep '^SECRET_' | awk -F "=" '{print $1}')

for key in ${INJECTED_SECRET_KEYS}
do
 value=$(printenv ${key})
 ACTUAL_KEY=$(echo ${key} | sed 's/^SECRET_//g')

 vault_secret_key=$(echo ${value} |awk -F "?" '{print $1}')
 vault_data_key=$(echo ${value} |awk -F "?" '{print $2}')
 [[ -z ${vault_data_key} ]] &&  vault_data_key=value

 LOOKUP_SECRET_RESPONSE=$(curl -sS \
    --header "X-Vault-Token: ${APPROLE_TOKEN}" \
    ${VAULT_ADDR}/v1/${vault_secret_key} | \
      jq -r 'if .errors then . else . end')
    validateVaultResponse "secret (${vault_secret_key})" "${LOOKUP_SECRET_RESPONSE}"

    LEASE_ID=$(echo ${LOOKUP_SECRET_RESPONSE} | jq -r '.lease_id')
    VALUE_OF_SECRET=$(echo ${LOOKUP_SECRET_RESPONSE} | jq -r ".data.${vault_data_key}")
    if [[ ${LEASE_ID} ]]; then
        if [[ ${LEASE_IDS} ]]; then
            LEASE_IDS="${LEASE_IDS},${LEASE_ID}"
        else
            LEASE_IDS="${LEASE_ID}"
        fi
    fi
    echo "export ${ACTUAL_KEY}=${VALUE_OF_SECRET}" >> /env/variables
done

echo "export LEASE_IDS=${LEASE_IDS}" >> /env/variables

echo "Finished."