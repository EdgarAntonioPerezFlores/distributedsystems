#!/usr/bin/env bash
# Run against the new cluster only, before allowing client traffic.
set -euo pipefail
: "${KUBECONFIG:?Select the lab kubeconfig}" "${LAB_VIP:?IPv4 reserved outside DHCP}"
python3 -c 'import ipaddress,sys; ipaddress.IPv4Address(sys.argv[1])' "$LAB_VIP"
kubectl get node catalog-0 >/dev/null
kubectl create namespace catalog --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl get secret catalog-auth -n catalog >/dev/null 2>&1; then
  umask 077
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  for key in DB_ROOT_PASSWORD DB_PASSWORD MONGO_PASSWORD REDIS_PASSWORD; do openssl rand -hex 24 | tr -d '\n' > "$tmp/$key"; done
  kubectl -n catalog create secret generic catalog-auth --from-file="$tmp"
fi
if ! kubectl -n catalog get secret catalog-writers >/dev/null 2>&1; then
  : "${CATALOG_WRITER_PASSWORD:?Define la contraseña del usuario writer}"
  printf '%s\n' "$CATALOG_WRITER_PASSWORD" | htpasswd -niB writer | kubectl -n catalog create secret generic catalog-writers --from-file=users=/dev/stdin
fi
kubectl wait --for=condition=Available deploy/cert-manager-webhook -n cert-manager --timeout=180s
kubectl wait --for=condition=Available deploy/metallb-controller -n metallb-system --timeout=180s
cat <<YAML | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata: {name: lab, namespace: metallb-system}
spec: {addresses: ["$LAB_VIP/32"]}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata: {name: lab, namespace: metallb-system}
spec: {ipAddressPools: [lab]}
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata: {name: lab-local, namespace: catalog}
spec: {selfSigned: {}}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: catalog-tls, namespace: catalog}
spec:
  secretName: catalog-tls
  dnsNames: [catalog.lab.test]
  issuerRef: {name: lab-local, kind: Issuer}
YAML
