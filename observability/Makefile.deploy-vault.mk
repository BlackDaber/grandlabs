ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
VAULT_NS := vault
VAULT_PATH := $(ROOT_DIR)/vault
ENV_FILE := $(ROOT_DIR)/.env.local
INGRESS_NS := ingress-nginx
VAULT_HOST := vault.grandlabs.com
VAULT_HOST_IP := 127.0.0.1
TLS_SECRET := vault-grandlabs-com-tls
TLS_DIR := $(ROOT_DIR)/.certs
JAVA_TRUST_STORE := $(TLS_DIR)/mkcert-truststore.p12
JAVA_TRUST_STORE_PASSWORD := changeit

.PHONY: minikube-up vault-hosts vault-tunnel ingress-enable ingress-ready vault-java-truststore vault-tls vault-clean-injector vault-install vault-forward vault-health check-env vault-init-dev vault-status dev-up

minikube-up:
	minikube start --driver=docker

vault-hosts:
	@set -e; \
	TMP=$$(mktemp); \
	awk -v host="$(VAULT_HOST)" '$$0 !~ ("(^|[[:space:]])" host "([[:space:]]|$$)") { print }' /etc/hosts > "$$TMP"; \
	echo "$(VAULT_HOST_IP) $(VAULT_HOST)" >> "$$TMP"; \
	sudo tee /etc/hosts < "$$TMP" >/dev/null; \
	rm "$$TMP"; \
	echo "$(VAULT_HOST) -> $(VAULT_HOST_IP)"

vault-tunnel:
	minikube tunnel --bind-address=$(VAULT_HOST_IP)

ingress-enable:
	minikube addons enable ingress

ingress-ready: ingress-enable
	kubectl wait -n $(INGRESS_NS) --for=condition=Available deployment/ingress-nginx-controller --timeout=180s
	kubectl wait -n $(INGRESS_NS) --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=180s

vault-java-truststore:
	@command -v mkcert >/dev/null || { echo "Missing mkcert. Install it with: brew install mkcert"; exit 1; }
	@command -v keytool >/dev/null || { echo "Missing keytool. Use a JDK, not only a JRE."; exit 1; }
	@set -a; [ ! -f "$(ENV_FILE)" ] || . "$(ENV_FILE)"; set +a; \
	TRUST_STORE_URI="$${VAULT_SSL_TRUST_STORE:-file:$(JAVA_TRUST_STORE)}"; \
	TRUST_STORE_PATH="$${TRUST_STORE_URI#file:}"; \
	TRUST_STORE_PASSWORD="$${VAULT_SSL_TRUST_STORE_PASSWORD:-$(JAVA_TRUST_STORE_PASSWORD)}"; \
	mkdir -p "$$(dirname "$$TRUST_STORE_PATH")"; \
	mkcert -install; \
	rm -f "$$TRUST_STORE_PATH"; \
	keytool -importcert -noprompt \
		-alias mkcert-root-ca \
		-file "$$(mkcert -CAROOT)/rootCA.pem" \
		-keystore "$$TRUST_STORE_PATH" \
		-storetype PKCS12 \
		-storepass "$$TRUST_STORE_PASSWORD"; \
	echo "Java truststore created: $$TRUST_STORE_PATH"

vault-tls: vault-java-truststore
	kubectl apply -f $(VAULT_PATH)/namespace.yaml
	mkcert -cert-file "$(TLS_DIR)/$(VAULT_HOST).pem" -key-file "$(TLS_DIR)/$(VAULT_HOST)-key.pem" "$(VAULT_HOST)"
	kubectl -n $(VAULT_NS) create secret tls $(TLS_SECRET) \
		--cert="$(TLS_DIR)/$(VAULT_HOST).pem" \
		--key="$(TLS_DIR)/$(VAULT_HOST)-key.pem" \
		--dry-run=client -o yaml | kubectl apply -f -

vault-clean-injector:
	kubectl delete mutatingwebhookconfiguration vault-agent-injector-cfg --ignore-not-found

vault-install: ingress-ready vault-tls
	kubectl apply -f $(VAULT_PATH)/namespace.yaml
	helm repo add hashicorp https://helm.releases.hashicorp.com || true
	helm repo update
	helm upgrade --install vault hashicorp/vault \
		-n $(VAULT_NS) \
		-f $(VAULT_PATH)/values-dev.yaml

vault-forward:
	kubectl port-forward -n $(VAULT_NS) svc/vault 8200:8200

vault-health:
	curl -vk https://$(VAULT_HOST):443/v1/sys/health

check-env:
	@test -f $(ENV_FILE) || { echo "Missing $(ENV_FILE). Create it with: cp $(ROOT_DIR)/.env.example $(ENV_FILE)"; exit 1; }

vault-init-dev: check-env
	chmod +x "$(VAULT_PATH)/init-dev.sh"
	set -a; . "$(ENV_FILE)"; set +a; "$(VAULT_PATH)/init-dev.sh"

vault-status: check-env
	set -a; . "$(ENV_FILE)"; set +a; vault status

dev-up: minikube-up vault-hosts vault-install
	@echo ""
	@echo "Vault installed."
	@echo "Vault should be exposed via ingress at https://vault.grandlabs.com:443"
	@echo ""
	@echo "Run in a separate terminal and keep it open:"
	@echo "make -C observability -f Makefile.deploy-vault.mk vault-tunnel"
	@echo ""
	@echo "Then run:"
	@echo "make -C observability -f Makefile.deploy-vault.mk vault-init-dev"
