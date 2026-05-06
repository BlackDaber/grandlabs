#!/usr/bin/env bash
set -euo pipefail

# Local Vault connection. Requires: make vault-forward
export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"

ENV_NAME="${ENV_NAME:-dev}"

SERVICES=(
  "buggy-service"
)

command -v vault >/dev/null || {
  echo "ERROR: vault CLI is required" >&2
  exit 1
}

echo "Checking Vault..."
vault status >/dev/null

echo "Configuring KV secrets engine..."
vault secrets list -format=json | grep -q '"secret/"' \
  || vault secrets enable -path=secret kv-v2

# Enable AppRole auth for machine-to-machine login
echo "Configuring AppRole auth..."
vault auth list -format=json | grep -q '"approle/"' \
  || vault auth enable approle

#Configure basic environment for several services at scaling
for SERVICE in "${SERVICES[@]}"; do
  ROLE_NAME="${SERVICE}"
  POLICY_NAME="${SERVICE}-${ENV_NAME}"
  SECRET_PATH="secret/${SERVICE}/${ENV_NAME}"
  POLICY_PATH="secret/data/${SERVICE}/${ENV_NAME}"

  echo ""
  echo "Configuring ${SERVICE}..."

  # Demo secret. Replace values with real dev values when needed.
  vault kv put "${SECRET_PATH}" \
    app.name="${SERVICE}" \
    app.env="${ENV_NAME}" \
    app.message="hello from vault for ${SERVICE}" >/dev/null

  # Least-privilege policy: service can read only its own env secret.
  vault policy write "${POLICY_NAME}" - <<EOF
path "${POLICY_PATH}" {
  capabilities = ["read"]
}
EOF

  # AppRole for this service.
  vault write "auth/approle/role/${ROLE_NAME}" \
    token_policies="${POLICY_NAME}" \
    token_ttl="1h" \
    token_max_ttl="4h" >/dev/null

  ROLE_ID="$(vault read -field=role_id "auth/approle/role/${ROLE_NAME}/role-id")"
  SECRET_ID="$(vault write -f -field=secret_id "auth/approle/role/${ROLE_NAME}/secret-id")"

  cat <<EOF
${SERVICE}:
  SECRET_PATH=${SECRET_PATH}
  VAULT_ROLE_ID=${ROLE_ID}
  VAULT_SECRET_ID=${SECRET_ID}
EOF
done

echo ""
echo "Done."