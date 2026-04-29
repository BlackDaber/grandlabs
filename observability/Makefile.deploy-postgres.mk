ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
POSTGRES_NS ?= postgres
POSTGRES_PATH := $(ROOT_DIR)/postgres
ENV_FILE := $(ROOT_DIR)/.env.local
POSTGRES_HOST_IP := 127.0.0.1

-include $(ENV_FILE)

POSTGRES_HOST ?= pg.grandlabs.dev
POSTGRES_DB ?= grandlabs_dev
POSTGRES_USER ?= postgres
POSTGRES_SCHEMA ?= buggy
POSTGRES_LOCAL_PORT ?= 5432

.PHONY: minikube-up check-env check-postgres-env postgres-hosts postgres-namespace postgres-secret postgres-install postgres-wait postgres-status postgres-forward postgres-connect postgres-url postgres-uninstall dev-up

minikube-up:
	minikube start --driver=docker

check-env:
	@test -f $(ENV_FILE) || { echo "Missing $(ENV_FILE). Create it with: cp $(ROOT_DIR)/.env.example $(ENV_FILE)"; exit 1; }

check-postgres-env: check-env
	@test -n "$(POSTGRES_PASSWORD)" || { echo "Missing POSTGRES_PASSWORD in $(ENV_FILE)"; exit 1; }

postgres-hosts:
	@set -e; \
	TMP=$$(mktemp); \
	awk -v host="$(POSTGRES_HOST)" '$$0 !~ ("(^|[[:space:]])" host "([[:space:]]|$$)") { print }' /etc/hosts > "$$TMP"; \
	echo "$(POSTGRES_HOST_IP) $(POSTGRES_HOST)" >> "$$TMP"; \
	sudo tee /etc/hosts < "$$TMP" >/dev/null; \
	rm "$$TMP"; \
	echo "$(POSTGRES_HOST) -> $(POSTGRES_HOST_IP)"

postgres-namespace:
	kubectl apply -f $(POSTGRES_PATH)/namespace.yaml

postgres-secret: check-postgres-env postgres-namespace
	kubectl -n $(POSTGRES_NS) create secret generic postgres-auth \
		--from-literal=POSTGRES_DB='$(POSTGRES_DB)' \
		--from-literal=POSTGRES_USER='$(POSTGRES_USER)' \
		--from-literal=POSTGRES_PASSWORD='$(POSTGRES_PASSWORD)' \
		--from-literal=POSTGRES_SCHEMA='$(POSTGRES_SCHEMA)' \
		--dry-run=client -o yaml | kubectl apply -f -

postgres-install: postgres-secret
	kubectl apply -f $(POSTGRES_PATH)/configmap.yaml
	kubectl apply -f $(POSTGRES_PATH)/service.yaml
	kubectl apply -f $(POSTGRES_PATH)/statefulset.yaml

postgres-wait:
	kubectl -n $(POSTGRES_NS) rollout status statefulset/postgres --timeout=180s
	kubectl -n $(POSTGRES_NS) wait --for=condition=Ready pod -l app.kubernetes.io/name=postgres --timeout=180s

postgres-status:
	kubectl -n $(POSTGRES_NS) get pods,svc,pvc

postgres-forward:
	kubectl -n $(POSTGRES_NS) port-forward --address=$(POSTGRES_HOST_IP) svc/postgres $(POSTGRES_LOCAL_PORT):5432

postgres-connect:
	kubectl -n $(POSTGRES_NS) exec -it postgres-0 -- psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

postgres-url:
	@echo "jdbc:postgresql://$(POSTGRES_HOST):$(POSTGRES_LOCAL_PORT)/$(POSTGRES_DB)"

postgres-uninstall:
	kubectl delete -f $(POSTGRES_PATH)/statefulset.yaml --ignore-not-found
	kubectl delete -f $(POSTGRES_PATH)/service.yaml --ignore-not-found
	kubectl delete -f $(POSTGRES_PATH)/configmap.yaml --ignore-not-found
	kubectl -n $(POSTGRES_NS) delete secret postgres-auth --ignore-not-found

dev-up: minikube-up postgres-hosts postgres-install postgres-wait
	@echo ""
	@echo "Postgres installed."
	@echo "Run in a separate terminal and keep it open:"
	@echo "make -C observability -f Makefile.deploy-postgres.mk postgres-forward"
