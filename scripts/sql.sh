#!/bin/bash
# SQL goes through stdin. Credentials remain inside the container.
set -euo pipefail
cd "$(dirname "$0")/.."
node=${1:-galera2}
case "$node" in galera1|galera2|galera3) ;; *) echo 'Nodo inválido'; exit 2;; esac
exec docker compose exec -T "$node" bash -ec 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -h127.0.0.1 -uroot store'
