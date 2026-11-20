#!/usr/bin/env bash
# Run on a LAN client with kubectl access to the team's real cluster.
set -euo pipefail
: "${BASE_URL:?https://catalog.lab.test}" "${KUBECONFIG:?}" "${CATALOG_NETRC:?Archivo netrc privado del usuario writer}"
test -r "$CATALOG_NETRC"
out="results/equipo-$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p results; mkdir "$out"
kubectl get nodes -l node-role.kubernetes.io/etcd -o json > "$out/servidores.json"
python3 - "$out/servidores.json" <<'PY'
import json,sys
nodes=json.load(open(sys.argv[1]))['items']
assert len(nodes)>=3,'Se requieren al menos tres servidores etcd'
for n in nodes:
 s=n['status'];assert any(x['type']=='Ready' and x['status']=='True' for x in s['conditions']),n['metadata']['name']
 print(n['metadata']['name'], n['metadata']['labels'].get('lab-pc','PC física no documentada'))
PY
kubectl -n catalog get pods,pvc,svc,ingress,hpa,pdb -o wide > "$out/topologia.txt"
flux get kustomizations -A > "$out/flux.txt"
git rev-parse HEAD > "$out/revision-cliente.txt"
kubectl -n catalog get deployments -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.template.spec.containers[*].image}{"\n"}{end}' > "$out/imagenes.txt"
curl -fsS "${BASE_URL%/}/api/health/deep" > "$out/salud-antes.json"
BASE_URL="$BASE_URL" CATALOG_NETRC="$CATALOG_NETRC" bash scripts/k3s-review-test.sh | tee "$out/resenas.txt"
# k3s-performance.sh produces a separate results/k3s-<UTC> with AB raw and CSV.
PLATFORM=k3s BASE_URL="$BASE_URL" bash scripts/k3s-performance.sh | tee "$out/carga.txt"
echo "Inventario y pruebas en $out. Revisar archivos antes de publicar."
