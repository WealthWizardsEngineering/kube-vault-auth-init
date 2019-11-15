#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Required policies

vault policy write my-app-role-login-policy ${DIR}/policies/approle-login-policy.txt
vault policy write my-app-role-policy ${DIR}/policies/approle-policy.txt

# Kubernetes authentication
vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host=http://mock:1080 kubernetes_ca_cert="@${DIR}/../jwt/certificates/jwtRS256.key"

vault write auth/kubernetes/role/my-app-role \
    bound_service_account_names=test-service \
    bound_service_account_namespaces=default \
    policies=my-app-role-login-policy \
    ttl=300 \
    max_ttl=300 \
    num_uses=3

# Approle authentication

vault auth enable approle
vault write auth/approle/role/my-app-role \
    secret_id_ttl=5m \
    secret_id_num_uses=3 \
    period=24h \
    bind_secret_id="true" \
    policies="my-app-role-policy"

# Database backend

vault secrets enable database

vault write database/config/my-mongodb-database \
    plugin_name=mongodb-database-plugin \
    allowed_roles="my-role" \
    connection_url="mongodb://@mongo/admin"
