ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PARENT_DIR := $(abspath $(ROOT_DIR)/..)

VAULT_NS := dev
NAMESPACE_FILE := $(PARENT_DIR)/namespace.yaml

.PHONY: minikube-up switch-to-dev-ns vault-install vault-forward vault-init-dev

minikube-up:
	minikube start --driver=docker

switch-to-dev-ns:
	kubectl config set-context --current --namespace dev

vault-install:
	kubectl apply -f $(NAMESPACE_FILE)
	helm repo add hashicorp https://helm.releases.hashicorp.com || true
	helm repo update
	helm upgrade --install vault hashicorp/vault \
		-n $(VAULT_NS) \
		-f $(ROOT_DIR)/values-dev.yaml

vault-forward:
	kubectl -n $(VAULT_NS) port-forward svc/vault 8200:8200

vault-init-dev:
	chmod +x "$(ROOT_DIR)/init-dev.sh"
	"$(ROOT_DIR)/init-dev.sh"
