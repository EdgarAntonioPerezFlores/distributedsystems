#!/usr/bin/env bash
set -eu
: "${BASE_URL:?}"
id=$(python3 -c 'import uuid; print(uuid.uuid4())')
url="${BASE_URL%/}/api/products/ST-001/reviews"
for _ in 1 2; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -H "Idempotency-Key: $id" -d "{\"reviewer\":\"lab\",\"rating\":5,\"comment\":\"$id\"}" "$url")
  test "$code" = 202
done
for _ in $(seq 1 30); do
 count=$(curl -fsS "$url" | python3 -c 'import json,sys;print(sum(x["comment"]==sys.argv[1] for x in json.load(sys.stdin)["reviews"]))' "$id")
 [[ "$count" == 1 ]] && { echo "202 dos veces; una reseña visible ($id)"; exit 0; }
 sleep 1
done
exit 1
