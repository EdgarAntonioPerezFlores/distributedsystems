#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="results/evidence-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out"
docker compose ps -a > "$out/containers.txt"
docker compose logs --since 30m --timestamps --no-color > "$out/logs.txt" 2>&1
docker stats --no-stream $(docker compose ps -q) > "$out/resources.txt"
bash scripts/verify.sh > "$out/health.txt" 2>&1 || true
docker compose exec -T nagios cat /opt/nagios/var/nagios.log > "$out/nagios.log" 2>/dev/null || true
docker compose exec -T nagios cat /opt/nagios/var/status.dat > "$out/nagios-status.dat" 2>/dev/null || true
echo "$out (revisar antes de publicar; no incluye .env ni docker inspect)"
