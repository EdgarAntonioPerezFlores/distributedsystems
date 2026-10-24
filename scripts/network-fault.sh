#!/bin/bash
# Linux VM only. Shares one container network namespace; removes netem on exit.
set -euo pipefail
cd "$(dirname "$0")/.."
service=${1:-app1}; mode=${2:-delay}; seconds=${3:-30}
case "$service" in app1|galera2) ;; *) echo 'Solo app1 o galera2'; exit 2;; esac
case "$mode" in delay|loss|partition|bandwidth) ;; *) exit 2;; esac
[[ "$seconds" =~ ^[0-9]+$ ]] && ((seconds>=1 && seconds<=120)) || exit 2
docker build -t distributed-ha-nettools ha/nettools
target=$(docker compose ps -q "$service")
test -n "$target"
args=(--rm --network "container:$target" --cap-add NET_ADMIN distributed-ha-nettools)
iface=$(docker run "${args[@]}" -c "ip route get 172.28.0.254 | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\") print \$(i+1)}")
test -n "$iface"
clean() { trap - EXIT INT TERM; docker run "${args[@]}" -c 'tc qdisc del dev "$1" root' sh "$iface" || true; }
trap clean EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
case "$mode" in
 delay) spec=(delay 200ms 50ms);;
 loss) spec=(loss 5%);;
 partition) spec=(loss 100%);;
 bandwidth) spec=(rate 128kbit);;
esac
date -u +%FT%TZ
docker run "${args[@]}" -c 'dev=$1; shift; tc qdisc add dev "$dev" root netem "$@"' sh "$iface" "${spec[@]}"
sleep "$seconds"
