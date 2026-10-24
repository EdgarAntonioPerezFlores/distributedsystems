#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node=${1:-galera2}
case "$node" in galera1|galera2|galera3) ;; *) exit 2;; esac
umask 077
mkdir -p backups
out="backups/catalog-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
docker compose exec -T "$node" bash -ec 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb-dump -h127.0.0.1 -uroot --single-transaction --routines --events --triggers store' | gzip > "$out"
gzip -t "$out"
sha256sum "$out" > "$out.sha256"
echo "$out"
