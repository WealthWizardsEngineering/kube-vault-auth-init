#!/usr/bin/env bash

#
# JWT Encoder Bash Script
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Static header fields.
header='{
	"typ": "JWT",
	"alg": "RS256",
	"kid": ""
}'

payload='{
  "iss": "kubernetes/serviceaccount",
  "kubernetes.io/serviceaccount/namespace": "default",
  "kubernetes.io/serviceaccount/secret.name": "test-service-token-tql7d",
  "kubernetes.io/serviceaccount/service-account.name": "test-service",
  "kubernetes.io/serviceaccount/service-account.uid": "05794f6c-f969-11e9-b92a-060e5ccada16",
  "sub": "system:serviceaccount:default:test-service"
}'

base64_encode()
{
	declare input=${1:-$(</dev/stdin)}
	# Use `tr` to URL encode the output from base64.
	printf '%s' "${input}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

json() {
	declare input=${1:-$(</dev/stdin)}
	printf '%s' "${input}" | jq -c .
}

sign()
{
	declare input=${1:-$(</dev/stdin)}
	printf '%s' "${input}" | openssl dgst -sha256 -sign ${DIR}/certificates/jwtRS256.key
}

header_base64=$(echo "${header}" | json | base64_encode)
payload_base64=$(echo "${payload}" | json | base64_encode)

header_payload=$(echo "${header_base64}.${payload_base64}")

signature=$(echo "${header_payload}" | sign | base64_encode)

echo "${header_payload}.${signature}"
