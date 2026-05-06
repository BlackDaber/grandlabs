# Local PostgreSQL In Minikube

This setup runs PostgreSQL in Minikube for local development. PostgreSQL is installed with the Bitnami Helm chart and exposed to the host through `kubectl port-forward`.
The current infrastructure uses the shared Kubernetes namespace `dev`.

## Requirements

```bash
brew install minikube kubectl postgresql@18
```

Check the tools:

```bash
minikube version
kubectl version --client
helm version
psql --version
```

## What Gets Created

- Kubernetes namespace `dev`
- Secret `postgres-secret`
- Helm release `postgres`
- Bitnami PostgreSQL service `postgres-postgresql`
- Persistent volume claim for PostgreSQL data

The chart values are in [infra/postgres/values-dev.yaml](infra/postgres/values-dev.yaml).

## Local Environment

Create `infra/.env.local` if it does not exist:

```bash
touch infra/.env.local
```

Add local passwords:

```bash
export POSTGRES_ADMIN_PASSWORD=change-me-local-admin-password
export POSTGRES_APP_PASSWORD=change-me-local-app-password
```

`infra/.env.local` is local-only and must not be committed.

Current chart defaults:

```text
database: grandlabs_dev
app user: blackdaber
host from local machine: 127.0.0.1
port from local machine: 5432
```

## Install PostgreSQL

Run commands from the repository root.

```bash
make -C infra/postgres -f Makefile.deploy-postgres.mk minikube-up
make -C infra/postgres -f Makefile.deploy-postgres.mk postgres-install
```

The install flow:

- creates namespace `dev`
- reads passwords from `infra/.env.local`
- creates or updates `postgres-secret`
- installs or upgrades the Bitnami PostgreSQL Helm release

Check resources:

```bash
make -C infra/postgres -f Makefile.deploy-postgres.mk postgres-status
```

## Open Local Access

Keep this running in a separate terminal:

```bash
make -C infra/postgres -f Makefile.deploy-postgres.mk postgres-forward
```

The database is then reachable from the host at:

```text
127.0.0.1:5432
```

Local JDBC URL:

```text
jdbc:postgresql://127.0.0.1:5432/grandlabs_dev
```

## Running Buggy Service

Keep PostgreSQL port-forward running:

```bash
make -C infra/postgres -f Makefile.deploy-postgres.mk postgres-forward
```

The dev Spring profile uses:

```text
jdbc:postgresql://${POSTGRES_HOST:127.0.0.1}:${POSTGRES_PORT:5432}/${POSTGRES_DB:grandlabs_dev}
```

So for local host execution, the default host and port are enough.

Datasource username and password are expected from Vault in the current application config. See [VAULT.md](/infra/docs/VAULT.md) for AppRole setup and Vault secret updates.

## Kubernetes DNS

For workloads running inside the same `dev` namespace, use:

```text
postgres-postgresql:5432
```

For workloads running from another namespace, use:

```text
postgres-postgresql.dev.svc.cluster.local:5432
```

## Uninstall

Remove the Helm release:

```bash
make -C infra/postgres -f Makefile.deploy-postgres.mk postgres-uninstall
```

PVCs can remain after uninstall depending on chart and cluster state. Check them:

```bash
kubectl get pvc -n dev
```

To fully reset local PostgreSQL data, delete the PVC manually:

```bash
kubectl -n dev delete pvc -l app.kubernetes.io/instance=postgres
```

The next install will create a fresh database.

## Troubleshooting

### `infra/.env.local` Is Missing Or Password Variables Are Empty

`postgres-secret` is created from:

```text
POSTGRES_ADMIN_PASSWORD
POSTGRES_APP_PASSWORD
```

Make sure both are exported in `infra/.env.local`.

### PostgreSQL Pod Is Not Ready

```bash
kubectl -n dev get pods
kubectl -n dev describe pod -l app.kubernetes.io/instance=postgres
kubectl -n dev logs -l app.kubernetes.io/instance=postgres
```

### psql Cannot Connect From Host

Make sure port-forward is still running:

```bash
make -C infra/postgres -f Makefile.deploy-postgres.mk postgres-forward
```

Check whether local port `5432` is already used by another PostgreSQL instance:

```bash
lsof -i :5432
```

### Secret Changes Do Not Affect Existing Database Passwords

Changing `infra/.env.local` updates the Kubernetes secret, but an already initialized PostgreSQL data directory may keep old credentials. For a clean local reset, uninstall PostgreSQL and delete the PVC.
