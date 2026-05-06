# Local Vault In Minikube

This setup runs HashiCorp Vault in local dev mode inside Minikube. It is intended only for local development.

Vault dev mode uses a static root token and in-memory storage. Do not use this configuration for shared, staging, or production environments.

## Requirements

Check the tools:

```bash
minikube version
kubectl version --client
helm version
vault version
```

## What Gets Created

- Kubernetes namespace `dev`
- Vault Helm release `vault`
- Vault server in dev mode with root token `root`
- ClusterIP services `vault` and `vault-ui`
- KV v2 secrets engine at `secret/`
- AppRole auth method at `approle/`
- AppRole and policy for `buggy-service`

Vault ingress and local TLS are not used. Access from the host goes through `kubectl port-forward`.

## Install Vault

Run commands from the repository root.

```bash
make -C infra/vault -f Makefile.deploy-vault.mk minikube-up
make -C infra/vault -f Makefile.deploy-vault.mk vault-install
```

The install command installs the HashiCorp Vault chart with [infra/vault/values-dev.yaml](../vault/values-dev.yaml).

## Open Local Access

Keep this running in a separate terminal:

```bash
make -C infra/vault -f Makefile.deploy-vault.mk vault-forward
```

Vault is then available on the host at:

```text
http://127.0.0.1:8200
http://127.0.0.1:8200/ui/
```

For the UI, use token:

```text
root
```

## Initialize Dev Secrets And AppRole

Run this while `vault-forward` is still running:

```bash
make -C infra/vault -f Makefile.deploy-vault.mk vault-init-dev
```

The script configures Vault and prints credentials for the service:

```text
buggy-service:
  SECRET_PATH=secret/buggy-service/dev
  VAULT_ROLE_ID=<role-id>
  VAULT_SECRET_ID=<secret-id>
```

Use the printed values when running `buggy-service`:

```bash
export VAULT_ROLE_ID=<role-id>
export VAULT_SECRET_ID=<secret-id>
```

`infra/vault/init-dev.sh` is idempotent. It reuses existing `secret/` and `approle/`, updates the service policy and role, and generates a fresh `SECRET_ID` on each run.

## What The Init Script Writes

For each service listed in `SERVICES`, currently `buggy-service`, the script writes a demo secret:

```text
secret/buggy-service/dev
```

Current keys:

```text
app.name
app.env
app.message
```

If the application expects datasource credentials from Vault, add them explicitly:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

vault kv patch secret/buggy-service/dev \
  spring.datasource.username=blackdaber \
  spring.datasource.password=<POSTGRES_APP_PASSWORD>
```

## Verify

```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

vault status
vault kv get secret/buggy-service/dev
```

Check Kubernetes resources:

```bash
kubectl get pods,svc -n dev
helm list -n dev
```

## Running Buggy Service

Keep Vault port-forward running, then run the service with the printed AppRole credentials:

```bash
export VAULT_ROLE_ID=<role-id>
export VAULT_SECRET_ID=<secret-id>

cd buggy-service
./gradlew bootRun
```

The dev Spring profile connects to Vault at `http://127.0.0.1:8200` and reads `secret/buggy-service/dev`.

## Troubleshooting

### `vault: command not found`

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault
```

### Vault CLI Cannot Connect

Make sure the port-forward is still running:

```bash
make -C infra/vault -f Makefile.deploy-vault.mk vault-forward
```

Then verify:

```bash
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault status
```

### Pod Is Not Ready

```bash
kubectl -n dev describe pod vault-0
kubectl -n dev logs vault-0
```

### Recreate Local Vault

Vault dev mode does not persist data. To recreate it, uninstall the release or delete Minikube:

```bash
helm uninstall vault -n dev
make -C infra/vault -f Makefile.deploy-vault.mk vault-install
```

or:

```bash
minikube delete
```

## Notes

- Namespace is `dev`.
- Vault address from the host is `http://127.0.0.1:8200`.
- Root token is `root`.
- Ingress, `vault.grandlabs.com`, `mkcert`, and Java truststore setup are not part of the current local flow.
