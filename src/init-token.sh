#!/usr/bin/env sh

set -eo pipefail

validateVaultResponse () {
  if echo ${2} | grep "errors"; then
    echo "ERROR: unable to retrieve ${1}: ${2}" >&2
  fi
}

retrieveSecret () {
  local vault_token=$1
  local key=$2

  local response=$(curl -sS \
    --header "X-Vault-Token: ${vault_token}" \
    ${VAULT_ADDR}/v1/${key} | \
    jq -r '.')
  validateVaultResponse "secret (${key})" "${response}"
  echo ${response}
}

appendToCommaSeparatedList () {
  local item=$1
  local list=$2

  if [[ ${item} ]]; then
    if [[ ${list} ]]; then
      list="${list},${item}"
    else
      list="${item}"
    fi
  fi
  echo ${list}
}

function extractFieldName () {
  local key=$1

  field_name=$(echo ${key} |awk -F "?" '{print $2}')
  [[ -z ${field_name} ]] &&  field_name=value
  echo ${field_name}
}

function storeSecret () {
  local key=$1
  local vault_response=$2

  local field_name=$(extractFieldName $(printenv ${key}))

  local output_key=$(echo ${key} | sed 's/^SECRET_//g')
  local value=$(echo ${vault_response} | jq -r ".data.${field_name}")

  echo "export ${output_key}=\"${value}\"" >> ${VARIABLES_FILE}
}

#########################################################################

[[ -z ${VARIABLES_FILE} ]] && VARIABLES_FILE='/env/variables'

#########################################################################

# Allow VAULT_TOKEN or KUBE_SA_TOKEN to be injected so that it can be
# tested without being deployed to Kubernetes
if [[ -z $VAULT_TOKEN ]]; then
    if [[ -z $KUBE_SA_TOKEN ]]; then
      KUBE_SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
    fi

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

    VAULT_TOKEN=$(curl -sS --request POST \
      --data '{"role_id":"'"$VAULT_ROLE_ID"'","secret_id":"'"$VAULT_SECRET_ID"'"}' \
      ${VAULT_ADDR}/v1/auth/approle/login | \
      jq -r 'if .errors then . else .auth.client_token end')
    validateVaultResponse 'approle id' "${VAULT_TOKEN}"
fi

echo "export VAULT_TOKEN=${VAULT_TOKEN}" > ${VARIABLES_FILE}

#########################################################################

echo "Getting secrets from Vault"

# Get all environment variables prefixed with SECRET_ and retrieve the secret from vault based on the value
secret_keys=$(printenv | grep '^SECRET_' | awk -F "=" '{print $1}')

for secret_key in ${secret_keys}
do
  env_value=$(printenv ${secret_key})
  output_key=$(echo ${secret_key} | sed 's/^SECRET_//g')

  # If the variable is already in the variables file then ignore it
  if ! grep ${output_key} ${VARIABLES_FILE} > /dev/null; then
    vault_key=$(echo ${env_value} |awk -F "?" '{print $1}')

    vault_response=$(retrieveSecret ${VAULT_TOKEN} ${vault_key})

    matching_secret_keys=$(printenv | grep -e "=${vault_key}" | awk -F "=" '{print $1}')
    for matching_secret_key in ${matching_secret_keys}
    do
      storeSecret "${matching_secret_key}" "${vault_response}"
    done
    lease_id=$(echo ${vault_response} | jq -r '.lease_id')
    lease_ids=$(appendToCommaSeparatedList ${lease_ids} ${lease_id})
  fi
done

echo "export LEASE_IDS=${lease_ids}" >> ${VARIABLES_FILE}

echo "Finished."