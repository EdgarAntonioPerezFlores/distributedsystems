#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose version >/dev/null
test -s .env && test -s secrets/mongo-keyfile
if docker volume inspect distributed-ha-lab_galera1-data >/dev/null 2>&1; then
 echo 'Hay un volumen Galera existente. Usa docs/OPERACION.md; no se hace bootstrap automático.' >&2
 exit 1
fi
mkdir -p results
docker compose config --quiet
docker compose pull --ignore-buildable
docker compose build
GALERA_BOOTSTRAP=yes docker compose up -d galera1
GALERA_BOOTSTRAP=yes docker compose up -d galera2 galera3
ready=0
for ((i=0;i<120;i++)); do
 size=$(docker compose exec -T galera2 bash -ec 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -h127.0.0.1 -uroot -N -B -e "SHOW GLOBAL STATUS LIKE '\''wsrep_cluster_size'\''"' 2>/dev/null | awk '{print $2}') || true
 if [ "$size" = 3 ]; then ready=1; break; fi
 sleep 5
done
if [ "$ready" != 1 ]; then echo 'Galera no alcanzó tamaño 3. Revisa logs; no borres volúmenes.' >&2; exit 1; fi
# Remove automatic bootstrap while two healthy members retain the Primary component.
docker compose up -d --no-deps --force-recreate galera1
docker compose up -d --build
for ((i=0;i<90;i++)); do
 if curl -fsS --max-time 5 http://localhost/api/health/deep; then
  echo; echo 'Arranque completo. Ejecuta bash scripts/verify.sh'; exit 0
 fi
 sleep 5
done
echo 'No terminó el arranque. Revisa docker compose ps -a y logs.' >&2
exit 1
