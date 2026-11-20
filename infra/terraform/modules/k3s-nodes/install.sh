#!/usr/bin/env bash
set -euo pipefail
umask 077
read -ra hosts <<< "$SERVERS"
# Existing clusters must never silently be joined or re-initialized.
for ip in "${hosts[@]}"; do
  ssh -o BatchMode=yes "$SSH_USER@$ip" 'sudo -n true && (test ! -d /var/lib/rancher/k3s/server || sudo test -f /etc/rancher/catalog-lab-owned)'
done
first=${hosts[0]}
for i in 0 1 2; do
  ip=${hosts[i]}
  ssh "$SSH_USER@$ip" 'sudo install -d -m700 /etc/rancher && sudo touch /etc/rancher/catalog-lab-owned'
  ssh "$SSH_USER@$ip" 'sudo install -d -m700 /etc/rancher/k3s; sudo tee /etc/rancher/k3s/audit.yaml >/dev/null' <<'POLICY'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
POLICY
  if [[ $i == 0 ]]; then
    args="--cluster-init"
  else
    ssh "$SSH_USER@$first" 'sudo cat /var/lib/rancher/k3s/server/node-token' | ssh "$SSH_USER@$ip" 'sudo install -m600 /dev/stdin /etc/rancher/join-token'
    args="--server https://$first:6443 --token-file /etc/rancher/join-token"
  fi
  [[ "$K3S_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]]
  ssh "$SSH_USER@$ip" "set -e; f=\$(mktemp); curl -fsSL https://get.k3s.io -o \"\$f\"; sudo env INSTALL_K3S_VERSION='$K3S_VERSION' sh \"\$f\" server $args --node-ip '$ip' --node-name 'catalog-$i' --disable servicelb --secrets-encryption --kube-apiserver-arg=audit-policy-file=/etc/rancher/k3s/audit.yaml --kube-apiserver-arg=audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log --kube-apiserver-arg=audit-log-maxbackup=3 --kube-apiserver-arg=audit-log-maxsize=50; rm -f \"\$f\""
  ssh "$SSH_USER@$ip" 'sudo k3s kubectl wait --for=condition=Ready node/$(hostname) --timeout=2s >/dev/null 2>&1 || sudo k3s kubectl get --raw=/readyz' >/dev/null
done
mkdir -p "$(dirname "$KCFG")"
ssh "$SSH_USER@$first" 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed "s/127.0.0.1/$first/g" > "$KCFG"
chmod 600 "$KCFG"
for n in 0 1 2; do kubectl --kubeconfig="$KCFG" wait "node/catalog-$n" --for=condition=Ready --timeout=180s; done
