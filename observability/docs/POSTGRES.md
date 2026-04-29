# Локальный PostgreSQL в Minikube

Этот контур поднимает PostgreSQL для локальной разработки в Minikube. Конфигурация предназначена только для dev-среды: пароль хранится в локальном Kubernetes Secret и берется из `observability/.env.local`.

Локальный JDBC endpoint:

```text
jdbc:postgresql://pg.grandlabs.dev:5432/grandlabs_dev
```

## Что создается

- Namespace `postgres`
- Secret `postgres-auth` с именем базы, пользователем, паролем и схемой
- ConfigMap с init-скриптом для создания схемы приложения
- StatefulSet `postgres` с PVC на `1Gi`
- Services `postgres` и `postgres-headless`

## Требования

```bash
brew install minikube kubectl postgresql@18
```

Проверьте инструменты:

```bash
minikube version
kubectl version --client
psql --version
```

## Переменные окружения

Создайте локальный env-файл, если его еще нет:

```bash
[ -f observability/.env.local ] || cp observability/.env.example observability/.env.local
```

Значения по умолчанию:

```bash
export POSTGRES_HOST=pg.grandlabs.dev
export POSTGRES_PORT=5432
export POSTGRES_DB=grandlabs_dev
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=change-me-local-postgres-password
export POSTGRES_SCHEMA=buggy
```

Не коммитьте `observability/.env.local`: в нем находятся локальные секреты. Если меняете значения базы, сделайте это до первой инициализации. Init-скрипты официального образа PostgreSQL выполняются только при создании пустого data directory.

## Установка

Из корня репозитория:

```bash
make -C observability -f Makefile.deploy-postgres.mk dev-up
```

Команда:

- запускает Minikube через Docker driver
- добавляет `pg.grandlabs.dev -> 127.0.0.1` в `/etc/hosts`
- создает namespace и secret
- применяет ConfigMap, Service и StatefulSet
- ждет готовности pod `postgres-0`

`postgres-hosts` использует `sudo` для обновления `/etc/hosts`, поэтому macOS может запросить пароль.

Проверка ресурсов:

```bash
make -C observability -f Makefile.deploy-postgres.mk postgres-status
```

## Доступ с хоста

Для подключения приложения, запущенного на вашей машине, откройте port-forward в отдельном терминале и держите его запущенным:

```bash
make -C observability -f Makefile.deploy-postgres.mk postgres-forward
```

JDBC URL:

```bash
make -C observability -f Makefile.deploy-postgres.mk postgres-url
```

Подключение через `psql` с хоста:

```bash
PGPASSWORD=<POSTGRES_PASSWORD> psql -h pg.grandlabs.dev -p 5432 -U postgres -d grandlabs_dev
```

Подключение внутри pod:

```bash
make -C observability -f Makefile.deploy-postgres.mk postgres-connect
```

## Запуск buggy-service

В одном терминале держите port-forward:

```bash
make -C observability -f Makefile.deploy-postgres.mk postgres-forward
```

В другом терминале запустите сервис:

```bash
source observability/.env.local
cd buggy-service
./gradlew bootRun
```

Профиль `dev` использует:

```text
jdbc:postgresql://pg.grandlabs.dev:5432/grandlabs_dev
```

Для запуска приложения внутри Kubernetes используйте service DNS:

```bash
export POSTGRES_HOST=postgres.postgres.svc.cluster.local
export POSTGRES_PORT=5432
```

## Интеграция с Vault

`observability/vault/init-dev.sh` читает те же `POSTGRES_*` переменные из `observability/.env.local` и записывает их в `secret/buggy-service/dev` как `spring.datasource.*`.

После изменения Postgres-переменных перезапустите dev-init Vault:

```bash
make -C observability -f Makefile.deploy-vault.mk vault-init-dev
```

## Удаление

Удалить Kubernetes-ресурсы без удаления PVC:

```bash
make -C observability -f Makefile.deploy-postgres.mk postgres-uninstall
```

PVC с данными остается в namespace `postgres`. Чтобы полностью пересоздать базу, удалите PVC вручную:

```bash
kubectl -n postgres delete pvc postgres-data-postgres-0
```

После удаления PVC следующая установка создаст пустую базу и заново выполнит init-скрипт.

## Troubleshooting

Если `postgres-0` не готов:

```bash
kubectl -n postgres describe pod postgres-0
kubectl -n postgres logs postgres-0
```

Если `pg.grandlabs.dev` не резолвится в `127.0.0.1`, обновите hosts:

```bash
make -C observability -f Makefile.deploy-postgres.mk postgres-hosts
dscacheutil -q host -a name pg.grandlabs.dev
```

Если `psql` не подключается с хоста, проверьте, что port-forward все еще запущен и порт `5432` не занят другим локальным Postgres. Для другого локального порта:

```bash
POSTGRES_LOCAL_PORT=15432 make -C observability -f Makefile.deploy-postgres.mk postgres-forward
```
