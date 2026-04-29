#!/usr/bin/env bash
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-https://vault.grandlabs.com:443}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"
POSTGRES_HOST="${POSTGRES_HOST:-pg.grandlabs.dev}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-grandlabs_dev}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required. Set it in observability/.env.local}"
POSTGRES_SCHEMA="${POSTGRES_SCHEMA:-buggy}"

if vault secrets list -format=json | grep -q '"secret/"'; then
  echo "KV secrets engine already enabled at secret/"
else
  vault secrets enable -path=secret kv-v2
fi

if vault auth list -format=json | grep -q '"approle/"'; then
  echo "AppRole auth method already enabled at approle/"
else
  vault auth enable approle
fi

cat > /tmp/buggy-service-policy.hcl <<EOF
path "sys/internal/ui/mounts/secret" {
  capabilities = ["read"]
}

path "sys/internal/ui/mounts/secret/*" {
  capabilities = ["read"]
}

path "secret/data/buggy-service/dev" {
  capabilities = ["read"]
}
EOF

vault policy write buggy-service-dev /tmp/buggy-service-policy.hcl

vault write auth/approle/role/buggy-service-dev \
  token_policies="buggy-service-dev" \
  token_ttl=1h \
  token_max_ttl=4h

vault kv put secret/buggy-service/dev \
  spring.datasource.url="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}" \
  spring.datasource.username="${POSTGRES_USER}" \
  spring.datasource.password="${POSTGRES_PASSWORD}" \
  spring.datasource.hikari.schema="${POSTGRES_SCHEMA}" \
  DB_HOST="${POSTGRES_HOST}" \
  DB_PORT="${POSTGRES_PORT}" \
  DB_NAME="${POSTGRES_DB}" \
  DB_USER="${POSTGRES_USER}" \
  DB_PASS="${POSTGRES_PASSWORD}" \
  DB_SCHEMA="${POSTGRES_SCHEMA}"

echo ""
echo "ROLE_ID:"
vault read -field=role_id auth/approle/role/buggy-service-dev/role-id

echo ""
echo "SECRET_ID:"
vault write -f -field=secret_id auth/approle/role/buggy-service-dev/secret-id
