ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PARENT_DIR := $(abspath $(ROOT_DIR)/..)

POSTGRES_NS := dev
NAMESPACE_FILE := $(PARENT_DIR)/namespace.yaml

.PHONY: \
	minikube-up \
	switch-to-dev-ns \
	postgres-secret \
	postgres-install \
	postgres-forward \
	postgres-status \
	postgres-uninstall

minikube-up:
	minikube start --driver=docker

switch-to-dev-ns:
	kubectl config set-context --current --namespace dev

postgres-namespace:
	kubectl create namespace $(POSTGRES_NS) --dry-run=client -o yaml | kubectl apply -f -

postgres-secret: postgres-namespace
	. $(PARENT_DIR)/.env.local && \
	kubectl create secret generic postgres-secret \
		-n $(POSTGRES_NS) \
		--from-literal=postgres-password=$$POSTGRES_ADMIN_PASSWORD \
		--from-literal=password=$$POSTGRES_APP_PASSWORD \
		--dry-run=client -o yaml | kubectl apply -f -

postgres-install: postgres-secret
	helm upgrade --install postgres \
      oci://registry-1.docker.io/bitnamicharts/postgresql \
      -n $(POSTGRES_NS) \
      -f $(ROOT_DIR)/values-dev.yaml

postgres-forward:
	kubectl port-forward -n $(POSTGRES_NS) svc/postgres-postgresql 5432:5432

postgres-status:
	kubectl get pods,pvc,svc -n $(POSTGRES_NS)

postgres-uninstall:
	helm uninstall postgres -n $(POSTGRES_NS)
