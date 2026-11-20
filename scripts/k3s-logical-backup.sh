#!/usr/bin/env bash
# Set a maintenance window; these are separate logical snapshots.
set -euo pipefail
: "${KUBECONFIG:?}" "${MONGO_TOOLS_POD:?Pod in catalog with mongodump and tools-user URI in MONGO_BACKUP_URI}" "${SQL_TOOLS_POD:?Pod in catalog with mariadb-dump and mounted /auth/backup.cnf}"
kubectl get node catalog-0 >/dev/null
umask 077; out="backups/k3s-$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p backups; mkdir "$out"
kubectl -n catalog exec "$SQL_TOOLS_POD" -- mariadb-dump --defaults-extra-file=/auth/backup.cnf --single-transaction --skip-lock-tables catalog | gzip > "$out/catalog.sql.gz"
kubectl -n catalog exec "$MONGO_TOOLS_POD" -- sh -ec 'mongodump --uri="$MONGO_BACKUP_URI" --db=catalog --gzip --archive' > "$out/reviews.archive.gz"
kubectl -n catalog exec broker-server-0 -- rabbitmqctl -q export_definitions /tmp/catalog-definitions.json
kubectl -n catalog exec broker-server-0 -- cat /tmp/catalog-definitions.json > "$out/rabbit.json"
kubectl -n catalog exec broker-server-0 -- rm -f /tmp/catalog-definitions.json
gzip -t "$out/catalog.sql.gz" "$out/reviews.archive.gz"
python3 - "$out/rabbit.json" <<'PY'
import json,sys
assert 'queues' in json.load(open(sys.argv[1]))
PY
(cd "$out" && sha256sum catalog.sql.gz reviews.archive.gz rabbit.json > SHA256SUMS)
echo "Cifrar y copiar fuera de la VM: $out (contiene datos sensibles)."
