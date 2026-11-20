#!/usr/bin/env bash
# Non-destructive consistency check; use after backup restore or loss of one node.
set -eu
: "${BASE_URL:?}" "${KUBECONFIG:?}"
kubectl -n catalog get mariadb,maxscale,mongodbcommunity,rabbitmqcluster
kubectl -n catalog get endpoints,pvc -o wide
kubectl -n catalog rollout status deploy/api --timeout=180s
curl -fsS "${BASE_URL%/}/api/health/deep"
bash scripts/k3s-review-test.sh
