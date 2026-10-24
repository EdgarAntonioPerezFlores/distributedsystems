#!/bin/bash
# One reversible fault, with recovery on INT/TERM. Logs use UTC for correlation.
set -euo pipefail
cd "$(dirname "$0")/.."
action=${1:-stop}; service=${2:-web1}; duration=${3:-30}
case "$action" in stop|kill|pause) ;; *) echo 'Usa stop, kill o pause'; exit 2;; esac
case "$service" in web[123]|app[123]|galera[123]|mongo[123]|redis[123]|sentinel[123]|db-proxy[12]|presentation-lb-master|application-lb-master) ;; *) echo 'Servicio fuera de la lista de laboratorio'; exit 2;; esac
[[ "$duration" =~ ^[0-9]+$ ]] && ((duration>=1 && duration<=300)) || exit 2
mkdir -p results
log="results/fault-$(date -u +%Y%m%dT%H%M%SZ)-$service.log"
exec > >(tee -a "$log") 2>&1
recover() {
 trap - EXIT INT TERM
 date -u +%FT%TZ
 if [ "$action" = pause ]; then docker compose unpause "$service"; else docker compose start "$service"; fi
 case "$service" in
  *-lb-master) docker compose restart "${service/-lb-/-keepalived-}";;
  galera*) docker compose restart "galera-check${service#galera}";;
 esac
 echo "Recuperación solicitada: $service. Validar con scripts/verify.sh."
}
trap recover EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
date -u +%FT%TZ
echo "Inyectando $action en $service por $duration segundos"
docker compose "$action" "$service"
sleep "$duration"
