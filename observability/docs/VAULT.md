# 🚀 Local Vault Setup (Minikube + Spring Boot)

⚠️ This setup uses Vault **dev mode** with a static root token.
**DO NOT use this configuration in production environments.**

This guide explains how to run HashiCorp Vault using Minikube, expose it through `vault.grandlabs.com:443`, and connect a Spring Boot application to it.

---

## 📦 Requirements

Install the following:

```bash
brew install minikube kubectl helm mkcert
brew tap hashicorp/tap
brew install hashicorp/tap/vault
```

Verify installation:

```bash
minikube version
kubectl version --client
helm version
mkcert -version
vault version
```

---

## ⚙️ Infrastructure Setup

Run all commands below from the repository root:

```bash
cd /Users/blackdaber/GitHub/grandlabs
```

---

### 0. Create local environment file

```bash
[ -f observability/.env.local ] || cp observability/.env.example observability/.env.local
```

For the local dev Vault configured in this repository, `VAULT_TOKEN=root` is expected.

---

### 1. Start Minikube and install Vault

```bash
make -C observability -f Makefile.deploy-vault.mk dev-up
```

This command:

* starts Minikube
* maps `vault.grandlabs.com` to `127.0.0.1` in `/etc/hosts`
* enables nginx ingress
* creates a trusted local TLS certificate with `mkcert`
* creates a Java PKCS12 truststore for Spring Boot
* creates the Kubernetes TLS secret `vault-grandlabs-com-tls`
* installs or upgrades Vault with Helm

---

### 2. Start the local tunnel

Minikube with the Docker driver on macOS does not expose the ingress IP directly to the host.
Run this in a separate terminal and keep it open:

```bash
cd /Users/blackdaber/GitHub/grandlabs
make -C observability -f Makefile.deploy-vault.mk vault-tunnel
```

The command may ask for your macOS password because it creates local network routes.

---

### 3. Open Vault through ingress

Vault will be available at:

```text
https://vault.grandlabs.com:443/ui/
```

If you installed Vault without `dev-up`, run these setup steps explicitly:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-hosts
make -C observability -f Makefile.deploy-vault.mk vault-tls
make -C observability -f Makefile.deploy-vault.mk vault-install
```

Verify the route:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-health
```

---

### 4. Initialize Vault (dev setup)

Run this only while `vault-tunnel` is still running in the separate terminal.

```bash
make -C observability -f Makefile.deploy-vault.mk vault-init-dev
```

The script will output:

```text
ROLE_ID: ...
SECRET_ID: ...
```

The init script is idempotent. If `secret/` or `approle/` already exists, it reuses them and updates the policy, role, and dev secret values.

---

### 5. Configure environment variables

Copy the printed `ROLE_ID` and `SECRET_ID` into `observability/.env.local`:

```bash
export VAULT_ROLE_ID=<printed-role-id>
export VAULT_SECRET_ID=<printed-secret-id>
```

---

## 🔑 What the init script does

* Enables KV secrets engine (`secret/`) if it does not exist
* Enables AppRole authentication if it does not exist
* Creates a policy
* Creates role `buggy-service-dev`
* Stores test secrets:

```text
secret/buggy-service/dev
```

---

## 🧪 Verification

```bash
# assuming environment variables are loaded from .env.local
vault kv get secret/buggy-service/dev
```

---

## ▶️ Running the application

```bash
source observability/.env.local
cd buggy-service
./gradlew bootRun
```

`mkcert` trusts the certificate for macOS and browsers, but Java uses its own truststore.
The `vault-tls` target creates `observability/.certs/mkcert-truststore.p12`, and the Spring profiles use it through:

```bash
export VAULT_SSL_TRUST_STORE=file:../observability/.certs/mkcert-truststore.p12
export VAULT_SSL_TRUST_STORE_PASSWORD=changeit
```

---


## ❗ Troubleshooting

### ❌ `vault: command not found`

```bash
brew install hashicorp/tap/vault
```

---

### ❌ `helm: command not found`

```bash
brew install helm
```

---

### ❌ `apiserver: Stopped`

```bash
minikube delete
minikube start --driver=docker --wait=all
```

---

### ❌ `failed calling webhook "validate.nginx.ingress.kubernetes.io"`

This means the nginx ingress admission webhook is installed but not ready yet.
Wait for ingress and rerun the Vault install:

```bash
make -C observability -f Makefile.deploy-vault.mk ingress-ready
make -C observability -f Makefile.deploy-vault.mk vault-install
```

---

### ❌ `conflict with "vault-k8s" ... vault-agent-injector-cfg`

This repository does not use Vault Agent Injector; Spring Boot connects to Vault directly.
The dev values disable the injector. If an old failed install left the webhook behind, remove it and rerun the install:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-clean-injector
make -C observability -f Makefile.deploy-vault.mk vault-install
```

---

### ❌ Browser shows `ERR_SSL_UNRECOGNIZED_NAME_ALERT`

The browser is not reaching the local Vault ingress with the expected TLS hostname.
Usually one of these is missing:

* `vault.grandlabs.com` is not mapped to `127.0.0.1` in `/etc/hosts`
* the local TLS secret `vault-grandlabs-com-tls` was not created
* Chrome still has an old DNS entry cached

Run:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-hosts
make -C observability -f Makefile.deploy-vault.mk vault-tls
make -C observability -f Makefile.deploy-vault.mk vault-install
```

Check:

```bash
minikube ip
dscacheutil -q host -a name vault.grandlabs.com
kubectl get secret -n vault vault-grandlabs-com-tls
kubectl get ingress -n vault
```

If macOS or Chrome still uses a stale DNS entry:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Then reopen the browser.

---

### ❌ Vault CLI fails with `dial tcp 192.168.49.2:443: i/o timeout`

Your machine is resolving `vault.grandlabs.com` to the Minikube Docker IP, but that IP is not reachable from macOS.
Use the local tunnel flow:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-hosts
make -C observability -f Makefile.deploy-vault.mk vault-tunnel
```

Keep `vault-tunnel` running, then in another terminal:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-health
make -C observability -f Makefile.deploy-vault.mk vault-init-dev
```

`vault-hosts` should make this command return `127.0.0.1`:

```bash
dscacheutil -q host -a name vault.grandlabs.com
```

---

### ❌ Spring Boot fails with `PKIX path building failed`

The browser may trust the `mkcert` certificate while the JVM does not.
Regenerate the Java truststore and run the app with the environment variables from `.env.local`:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-java-truststore
make -C observability -f Makefile.deploy-vault.mk vault-init-dev
source observability/.env.local
cd buggy-service
./gradlew bootRun
```

If you change `VAULT_SSL_TRUST_STORE_PASSWORD`, rerun `vault-java-truststore`.
The truststore password must match the value passed to Spring Boot.

Check that the truststore exists:

```bash
ls -l observability/.certs/mkcert-truststore.p12
```

If running from IntelliJ IDEA, add these environment variables to the Run Configuration:

```text
VAULT_SSL_TRUST_STORE=file:../observability/.certs/mkcert-truststore.p12
VAULT_SSL_TRUST_STORE_PASSWORD=changeit
```

The relative path assumes the working directory is `buggy-service`.

---

### ❌ Vault host is not reachable

Check:

```bash
kubectl get ingress -n vault
kubectl describe ingress -n vault vault
```

---

### ❌ Vault is not responding

```bash
curl https://vault.grandlabs.com:443/v1/sys/health
```

---

## 💡 Useful commands

```bash
kubectl get pods -n vault
kubectl get svc -n vault
helm list -n vault
minikube logs
```

---

## 🧠 Important Notes

* This is **Vault dev mode** (NOT production)
* All data is lost after `minikube delete`
* Root token `root` is used for local development only

---

## ✅ Result

After completing the setup:

* Vault is running in Minikube
* Available via `https://vault.grandlabs.com:443`
* AppRole authentication is configured
* Spring Boot application can read secrets from Vault

---

## 🚀 Possible Improvements

* Vault Agent Injector (for Kubernetes pods)
* Persistent storage (non-dev mode)
* Dynamic secrets (e.g. database credentials)

---
