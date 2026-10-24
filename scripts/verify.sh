#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose ps -a
curl -fsS http://localhost/api/health/deep
echo
for node in galera1 galera2 galera3; do
 echo "--- $node ---"
 docker compose exec -T "$node" bash -ec 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -h127.0.0.1 -uroot -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('\''wsrep_cluster_size'\'','\''wsrep_cluster_status'\'','\''wsrep_ready'\'','\''wsrep_local_state_comment'\'');"'
done
docker compose exec -T mongo1 bash -ec 'mongosh --quiet --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --eval "rs.status().members.map(m=>({name:m.name,state:m.stateStr,health:m.health}))"'
for node in sentinel1 sentinel2 sentinel3; do
 echo "--- $node ---"
 docker compose exec -T "$node" sh -ec 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -p 26379 SENTINEL get-master-addr-by-name cachemaster'
 docker compose exec -T "$node" sh -ec 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -p 26379 SENTINEL CKQUORUM cachemaster'
done
for ((i=0;i<9;i++)); do curl -fsS -D - http://localhost/api/products/cheapest -o /dev/null; done
