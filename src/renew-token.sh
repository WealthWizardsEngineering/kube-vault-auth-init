#!/usr/bin/env sh

set -eo pipefail

source /env/variables

validateVaultResponse () {
  if echo ${2} | grep "errors"; then
    echo "ERROR: unable to retrieve ${1}: ${2}"
    exit 1
  fi
}

TOKEN_LOOKUP_RESPONSE=$(curl -sS \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  ${VAULT_ADDR}/v1/auth/token/lookup-self | \
  jq -r 'if .errors then . else . end')
validateVaultResponse 'token lookup' "${TOKEN_LOOKUP_RESPONSE}"

CREATION_TTL=$(echo ${TOKEN_LOOKUP_RESPONSE} | jq -r '.data.creation_ttl')
RENEWAL_TTL=$(expr ${CREATION_TTL} / 2)
CURRENT_TTL=$(echo ${TOKEN_LOOKUP_RESPONSE} | jq -r '.data.ttl')

# Only renew if the current ttl is below half the original ttl
if [ $CURRENT_TTL -lt $RENEWAL_TTL ]; then
    echo "Renewing token from Vault server: ${VAULT_ADDR}"

    TOKEN_RENEW=$(curl -sS --request POST \
      --header "X-Vault-Token: ${VAULT_TOKEN}" \
      ${VAULT_ADDR}/v1/auth/token/renew-self | \
      jq -r 'if .errors then . else .auth.client_token end')
    validateVaultResponse 'renew token' "${TOKEN_RENEW}"

    echo "Token renewed"
fi

