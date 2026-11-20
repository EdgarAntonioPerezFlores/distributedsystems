#!/usr/bin/env bash
# Run from the same client for each platform. Results are never overwritten.
set -euo pipefail
: "${BASE_URL:?e.g. https://catalog.lab.test}" "${PLATFORM:?compose or k3s}"
[[ "$PLATFORM" == compose || "$PLATFORM" == k3s ]]
out="results/$PLATFORM-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p results; mkdir "$out"; url="${BASE_URL%/}/api/products/cheapest"
curl -fsS --retry 3 "$url" > "$out/warmup.json"
python3 - "$out/warmup.json" <<'PY'
import sys,json
v=json.load(open(sys.argv[1])); assert isinstance(v,list) and len(v)>0 and 'sku' in v[0]
PY
git rev-parse HEAD > "$out/revision.txt"
if [[ "$PLATFORM" == k3s ]]; then
  kubectl get nodes -o wide > "$out/nodes.txt"
  kubectl get pods -A -o wide > "$out/pods.txt"
  (while true; do date -u; kubectl top nodes || true; kubectl top pods -n catalog || true; sleep 10; done) > "$out/resources.txt" 2>&1 &
  sampler=$!; trap 'kill "$sampler" 2>/dev/null || true' EXIT
fi
ab -V > "$out/ab-version.txt"
ab -k -c 20 -t 600 -n 1000000 "$url" | tee "$out/ab.txt"
curl -fsS "${BASE_URL%/}/api/health/deep" > "$out/after.json"
python3 - "$out" <<'PY'
import re,sys,pathlib
p=pathlib.Path(sys.argv[1]);s=(p/'ab.txt').read_text()
def field(pattern):
 m=re.search(pattern,s,re.M);return m.group(1) if m else None
row=[field(p) for p in [r'^Time taken for tests:\s+([\d.]+)',r'^Complete requests:\s+(\d+)',r'^Failed requests:\s+(\d+)',r'^Non-2xx responses:\s+(\d+)',r'^Requests per second:\s+([\d.]+)',r'^\s*95%\s+(\d+)',r'^\s*99%\s+(\d+)']]
row[3]=row[3] or '0'
if any(v is None for v in row):sys.exit('Informe AB incompleto')
(p/'summary.csv').write_text('seconds,complete,failed,non2xx,rps,p95_ms,p99_ms\n'+','.join(row)+'\n')
print((p/'summary.csv').read_text())
sys.exit(0 if float(row[0])>=595 and int(row[2])==int(row[3])==0 and int(row[5])<200 else 1)
PY
