#!/usr/bin/env sh

validateVaultResponse () {
  local action="$1"
  local responsePayload="$2"

  if echo "${responsePayload}" | grep "errors" > /dev/null; then
    local message=$(echo "${responsePayload}" | jq -r '.[] | join (",")')
    echo "ERROR: unable to retrieve ${action}, error message: ${message}" >&2
    return 1
  else
    return 0
  fi
}

retrieveSecret () {
  local vault_token=$1
  local key=$2

  response="$(VAULT_TOKEN=${vault_token} vault read -format=json ${key} 2>&1)"
  if [[ $? -gt 0 ]]; then
    echo "ERROR: unable to retrieve secret (${key}), error message: ${response}" >&2
    return 1
  else
    if echo "${response}" | grep "Invalid path for a versioned K/V secrets engine" > /dev/null; then
      response="$(VAULT_TOKEN=${vault_token} vault kv get -format=json ${key} 2>&1)"
      if [[ $? -gt 0 ]]; then
        echo "ERROR: unable to retrieve secret (${key}), error message: ${response}" >&2
        return 1
      fi
    fi
    if validateVaultResponse "secret (${key})" "${response}"; then
      echo ${response}
      return 0
    else
      return 1
    fi
  fi
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
  local value=$(echo ${vault_response} | jq -r "if .data.metadata then .data.data.${field_name} else .data.${field_name} end")
  echo "export ${output_key}=\"${value}\"" >> ${VARIABLES_FILE}
}

#########################################################################

echo "Running kube-vault-auth-init"

[[ -z ${VAULT_ADDR} ]] && echo "VAULT_ADDR is required" && exit 1
[[ -z ${VARIABLES_FILE} ]] && VARIABLES_FILE='/env/variables'

#########################################################################

# Allow VAULT_TOKEN or KUBE_SA_TOKEN to be injected so that it can be
# tested without being deployed to Kubernetes
if [[ -z $VAULT_TOKEN ]]; then
    if [[ -z $KUBE_SA_TOKEN ]]; then
        if [[ ! -f "/var/run/secrets/kubernetes.io/serviceaccount/token" ]]; then
          printf "No authentications variables; either VAULT_TOKEN or KUBE_SA_TOKEN variables must be set or the "
          printf "kubernetes service account token file is available.\n"
          exit 1
        fi
        KUBE_SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
    fi

    [[ -z ${KUBERNETES_AUTH_PATH} ]] && KUBERNETES_AUTH_PATH="kubernetes"
    [[ -z ${KUBERNETES_ROLE} ]] && KUBERNETES_ROLE="${VAULT_LOGIN_ROLE}"
    [[ -z ${KUBERNETES_ROLE} ]] && echo "KUBERNETES_ROLE or VAULT_LOGIN_ROLE is required" && exit 1
    [[ -z ${APPROLE_ROLE} ]] && APPROLE_ROLE="${VAULT_LOGIN_ROLE}"
    [[ -z ${APPROLE_ROLE} ]] && echo "APPROLE_ROLE or VAULT_LOGIN_ROLEis required" && exit 1

    echo "Getting auth token from Vault server: ${VAULT_ADDR}"

    # Login to Vault and so I can get an approle token
    VAULT_LOGIN_TOKEN=$(curl -sS --request POST \
      ${VAULT_ADDR}/v1/auth/${KUBERNETES_AUTH_PATH}/login \
      -H "Content-Type: application/json" \
      -d '{"role":"'"${KUBERNETES_ROLE}"'","jwt":"'"${KUBE_SA_TOKEN}"'"}' | \
      jq -r 'if .errors then . else .auth.client_token end')
    validateVaultResponse 'vault login token' "${VAULT_LOGIN_TOKEN}" || exit 1

    VAULT_ROLE_ID=$(curl -sS --header "X-Vault-Token: ${VAULT_LOGIN_TOKEN}" \
      ${VAULT_ADDR}/v1/auth/approle/role/${APPROLE_ROLE}/role-id | \
      jq -r 'if .errors then . else .data.role_id end')
    validateVaultResponse 'role id' "${VAULT_ROLE_ID}" || exit 1

    VAULT_SECRET_ID=$(curl -sS --header "X-Vault-Token: ${VAULT_LOGIN_TOKEN}" \
      --request POST \
      ${VAULT_ADDR}/v1/auth/approle/role/${APPROLE_ROLE}/secret-id | \
      jq -r 'if .errors then . else .data.secret_id end')
    validateVaultResponse 'secret id' "${VAULT_SECRET_ID}" || exit 1

    VAULT_TOKEN=$(curl -sS --request POST \
      --data '{"role_id":"'"$VAULT_ROLE_ID"'","secret_id":"'"$VAULT_SECRET_ID"'"}' \
      ${VAULT_ADDR}/v1/auth/approle/login | \
      jq -r 'if .errors then . else .auth.client_token end')
    validateVaultResponse 'approle id' "${VAULT_TOKEN}" || exit 1
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
  if ! grep "export ${output_key}=" ${VARIABLES_FILE} > /dev/null; then
    vault_key=$(echo ${env_value} |awk -F "?" '{print $1}')

    vault_response=$(retrieveSecret ${VAULT_TOKEN} ${vault_key})
    if [[ $? -gt 0 ]]; then
      exit 1
    fi
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
