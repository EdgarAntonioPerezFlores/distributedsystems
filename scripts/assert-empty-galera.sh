#!/bin/bash
# Read-only guard: never bootstrap over any existing database files.
set -euo pipefail
cd "$(dirname "$0")/.."
for node in 1 2 3; do
  running=$(docker ps -q --filter label=com.docker.compose.project=distributed-ha-lab --filter "label=com.docker.compose.service=galera$node")
  if [ -n "$running" ]; then echo "Detén galera$node antes de comprobar sus datos." >&2; exit 1; fi
  volume="distributed-ha-lab_galera${node}-data"
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    if ! docker run --rm --network none --mount "type=volume,src=$volume,dst=/check,readonly" alpine:3.21 sh -ec 'test -z "$(find /check -mindepth 1 ! -type d -print -quit)"'; then
      echo "No se puede confirmar que $volume carezca de datos. Se detiene sin borrarlo ni cambiar contraseñas." >&2
      exit 1
    fi
  fi
done
echo 'Comprobado: nodos detenidos y volúmenes sin archivos de datos.'
