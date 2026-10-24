#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose config --quiet
for service in presentation-entry presentation-lb-master presentation-lb-backup application-lb-master application-lb-backup db-proxy1 db-proxy2; do
 docker compose exec -T "$service" haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
done
for service in web1 web2 web3; do docker compose exec -T "$service" nginx -t; done
bash scripts/verify.sh
python3 tests/functional.py http://localhost
