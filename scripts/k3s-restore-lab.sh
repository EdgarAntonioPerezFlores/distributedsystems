#!/usr/bin/env bash
# Import ONLY into a fresh and deliberately isolated restore namespace.
set -euo pipefail
: "${KUBECONFIG:?}" "${RESTORE_NAMESPACE:?use catalog-restore-*}" "${BACKUP_DIR:?}" "${SQL_TOOLS_POD:?}" "${MONGO_TOOLS_POD:?}" "${BROKER_POD:?}"
[[ "$RESTORE_NAMESPACE" =~ ^catalog-restore-[a-z0-9-]+$ ]]
k=(kubectl -n "$RESTORE_NAMESPACE")
[[ "$(kubectl get namespace "$RESTORE_NAMESPACE" -o jsonpath='{.metadata.labels.catalog-restore}')" == "disposable" ]]
cd "$BACKUP_DIR"
sha256sum --check SHA256SUMS
# The operator provisions an EMPTY catalog database and a dedicated tools account in this namespace.
count=$("${k[@]}" exec "$SQL_TOOLS_POD" -- mariadb --defaults-extra-file=/auth/backup.cnf -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='catalog'")
[[ "$count" == 0 ]] || { echo 'La base de destino no está vacía'; exit 1; }
# Destination URIs must be scoped to the restore namespace; require the namespace in both targets.
"${k[@]}" exec "$MONGO_TOOLS_POD" -- sh -ec 'case "$MONGO_BACKUP_URI" in *."$1".svc*) ;; *) exit 1;; esac
  mongosh "$MONGO_BACKUP_URI" --quiet --eval "if(db.getSiblingDB(\"catalog\").getCollectionNames().length) quit(1)"' sh "$RESTORE_NAMESPACE"
"${k[@]}" exec "$SQL_TOOLS_POD" -- sh -ec 'grep -F ".$1.svc" /auth/backup.cnf >/dev/null' sh "$RESTORE_NAMESPACE"
gzip -dc catalog.sql.gz | "${k[@]}" exec -i "$SQL_TOOLS_POD" -- mariadb --defaults-extra-file=/auth/backup.cnf catalog
"${k[@]}" exec -i "$MONGO_TOOLS_POD" -- sh -ec 'mongorestore --uri="$MONGO_BACKUP_URI" --archive --gzip --nsInclude="catalog.*"' < reviews.archive.gz
"${k[@]}" exec -i "$BROKER_POD" -- sh -ec 'umask 077; f=$(mktemp); trap '\''rm -f "$f"'\'' EXIT; cat > "$f"; rabbitmqctl -q import_definitions "$f"' < rabbit.json
"${k[@]}" exec "$SQL_TOOLS_POD" -- mariadb --defaults-extra-file=/auth/backup.cnf -N -e 'SELECT COUNT(*) FROM catalog.products'
"${k[@]}" exec "$MONGO_TOOLS_POD" -- sh -ec 'mongosh "$MONGO_BACKUP_URI" --quiet --eval "db.getSiblingDB(\"catalog\").product_reviews.countDocuments({})"'
"${k[@]}" exec "$BROKER_POD" -- rabbitmqctl list_queues name type messages
