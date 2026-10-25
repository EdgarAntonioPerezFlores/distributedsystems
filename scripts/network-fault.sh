#!/bin/bash
# Linux VM only. Use a helper container in the target network namespace.
# Only remove netem if this invocation installed it successfully.
set -euo pipefail
cd "$(dirname "$0")/.."
service=${1:-app1}; mode=${2:-delay}; seconds=${3:-30}
case "$service" in app1|galera2) ;; *) echo 'Solo app1 o galera2' >&2; exit 2;; esac
case "$mode" in delay|loss|partition|bandwidth) ;; *) echo 'Modo de fallo invalido' >&2; exit 2;; esac
[[ "$seconds" =~ ^[0-9]+$ ]] && ((seconds >= 1 && seconds <= 120)) || { echo 'Duracion: 1 a 120 segundos' >&2; exit 2; }

docker build -t distributed-ha-nettools ha/nettools
target=$(docker compose ps -q "$service")
test -n "$target" || { echo "Contenedor no encontrado: $service" >&2; exit 1; }
args=(--rm --network "container:$target" --cap-add NET_ADMIN distributed-ha-nettools)

# Read the route first, then parse its interface on the host.
# Avoid interpolating awk inside double-quoted sh -c (old unterminated-quote bug).
route=$(docker run "${args[@]}" -c 'ip route get 172.28.0.254')
iface=$(printf '%s\n' "$route" | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')
if [[ ! "$iface" =~ ^[a-zA-Z0-9_.@:-]+$ ]]; then
    echo "No se pudo encontrar la interfaz de datos. Ruta: $route" >&2
    exit 1
fi

echo "Interfaz seleccionada: $iface ($service)"
before=$(docker run "${args[@]}" -c 'tc qdisc show dev "$1"' sh "$iface")
if grep -q 'netem' <<< "$before"; then
    echo "Ya existe netem en $iface; no modificaremos una regla preexistente." >&2
    exit 1
fi

applied=0
cleanup() {
    rc=$?
    trap - EXIT INT TERM
    if (( applied == 1 )); then
        echo "Retirando netem de $service/$iface ..."
        if docker run "${args[@]}" -c 'tc qdisc del dev "$1" root' sh "$iface"; then
            echo 'Regla temporal eliminada.'
        else
            echo "ATENCION: no se pudo retirar netem de $iface. Revisar con tc antes de otra prueba." >&2
            rc=1
        fi
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

case "$mode" in
 delay) spec=(delay 200ms 50ms);;
 loss) spec=(loss 5%);;
 partition) spec=(loss 100%);;
 bandwidth) spec=(rate 128kbit);;
esac

echo "UTC: $(date -u +%FT%TZ); servicio=$service, modo=$mode, duracion=${seconds}s"
docker run "${args[@]}" -c 'dev=$1; shift; tc qdisc add dev "$dev" root netem "$@"' sh "$iface" "${spec[@]}"
applied=1
echo 'Regla de prueba aplicada:'
docker run "${args[@]}" -c 'tc qdisc show dev "$1"' sh "$iface"
sleep "$seconds"
