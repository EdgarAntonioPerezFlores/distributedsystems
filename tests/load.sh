#!/bin/bash
# Run on the partner's Linux / WSL computer. Each run gets its own directory.
set -euo pipefail
base=${1:?Uso: bash tests/load.sh http://IP_VM [concurrencia] [segundos] [ruta]}
c=${2:-20}; duration=${3:-60}; path=${4:-/api/products/cheapest}
[[ "$base" =~ ^https?:// ]] || exit 2
[[ "$c" =~ ^[0-9]+$ && "$duration" =~ ^[0-9]+$ ]] || exit 2
out="results/ab-$(date -u +%Y%m%dT%H%M%SZ)-c$c"
mkdir -p "$out"
printf '%s\n' "start=$(date -u +%FT%TZ) url=${base%/}$path concurrency=$c seconds=$duration" > "$out/run.txt"
curl -f --max-time 10 "${base%/}/api/health" > "$out/health.json"
# -l avoids classifying legitimate variable response sizes as failures.
# Non-2xx responses are counted separately by ab: do not ignore them.
ab -r -l -s 10 -n 100000000 -t "$duration" -c "$c" -e "$out/percentiles.csv" -g "$out/times.tsv" "${base%/}$path" 2>&1 | tee "$out/ab.txt"
echo "end=$(date -u +%FT%TZ)" >> "$out/run.txt"
echo "Evidencia: $out"
