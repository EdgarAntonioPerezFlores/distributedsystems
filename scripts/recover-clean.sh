#!/bin/bash
# Only for an orderly complete shutdown. Never forces safe_to_bootstrap.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -n "$(docker compose ps --status running -q galera1 galera2 galera3)" ]; then
 echo 'Hay nodos en ejecución: primero diagnostica el componente Primary. No se hará bootstrap.' >&2; exit 1
fi
chosen=''
for node in galera1 galera2 galera3; do
 state=$(docker compose run --rm --no-deps --entrypoint bash "$node" -ec 'cat /bitnami/mariadb/data/grastate.dat')
 printf '%s\n%s\n' "$node" "$state"
 if grep -Eq '^safe_to_bootstrap:[[:space:]]*1' <<< "$state"; then
  [ -z "$chosen" ] || { echo 'Más de un candidato; revisión manual requerida'; exit 1; }
  grep -Eq '^seqno:[[:space:]]*[0-9]+' <<< "$state" || { echo 'seqno desconocido; se requiere recuperación manual'; exit 1; }
  chosen=$node
 fi
done
test -n "$chosen" || { echo 'Ningún nodo seguro. Seguir docs/OPERACION.md; no forzar flags.'; exit 1; }
tmp=$(mktemp .recovery.XXXXXX.yml)
trap 'rm -f "$tmp"' EXIT
printf 'services:\n  %s:\n    environment:\n      MARIADB_GALERA_CLUSTER_BOOTSTRAP: "yes"\n' "$chosen" > "$tmp"
docker compose -f docker-compose.yml -f "$tmp" up -d --no-deps "$chosen"
docker compose -f docker-compose.yml -f "$tmp" up -d --no-deps galera1 galera2 galera3
ready=0
for ((i=0;i<120;i++)); do
 size=$(docker compose exec -T "$chosen" bash -ec 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -h127.0.0.1 -uroot -N -B -e "SHOW GLOBAL STATUS LIKE '\''wsrep_cluster_size'\''"' 2>/dev/null | awk '{print $2}') || true
 if [ "$size" = 3 ]; then ready=1; break; fi
 sleep 5
done
[ "$ready" = 1 ] || { echo 'No hay 3 miembros. No continuar, revisar logs.'; exit 1; }
docker compose up -d --no-deps --force-recreate "$chosen"
docker compose up -d
docker compose up -d --no-deps --force-recreate "galera-check${chosen#galera}"
echo 'Recuperación solicitada. Espera salud y ejecuta scripts/verify.sh.'
