#!/usr/bin/env bash
# Fresh installation only. No sample credentials or external services.
set -euo pipefail
: "${KUBECONFIG:?Select the lab kubeconfig}"
kubectl get node catalog-0 >/dev/null
if kubectl get namespace wazuh >/dev/null 2>&1; then echo 'Namespace existente: conservar certificados y credenciales; no reinstalar.' >&2; exit 1; fi
umask 077
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
git clone -q --depth 1 -b v4.12.0 https://github.com/wazuh/wazuh-kubernetes "$stage/up"
cd "$stage/up"
test "$(git rev-parse HEAD)" = 41065afb5a1bef9f064492a8abffdfebf63c6306
bash wazuh/certs/indexer_cluster/generate_certs.sh >/dev/null
bash wazuh/certs/dashboard_http/generate_certs.sh >/dev/null
python3 - <<'PY'
from pathlib import Path as P
import base64,bcrypt,yaml,secrets
root=P('wazuh')
sdir=root/'secrets'
def save(p,d):p.write_text(yaml.safe_dump(d,sort_keys=False))
def rotate(name,key,value):
 p=sdir/name;d=yaml.safe_load(p.read_text());d['data'][key]=base64.b64encode(value.encode()).decode();save(p,d)
idx=root/'indexer_stack/wazuh-indexer/indexer_conf/internal_users.yml';users=yaml.safe_load(idx.read_text())
for user,file in [('admin','indexer-cred-secret.yaml'),('kibanaserver','dashboard-cred-secret.yaml')]:
 pw=secrets.token_hex(24);rotate(file,'password',pw);users[user]['hash']=bcrypt.hashpw(pw.encode(),bcrypt.gensalt()).decode()
save(idx,{k:v for k,v in users.items() if k in ('_meta','admin','kibanaserver')})
rotate('wazuh-api-cred-secret.yaml','password','Wx!'+secrets.token_hex(18))
rotate('wazuh-cluster-key-secret.yaml','key',secrets.token_hex(16))
rotate('wazuh-authd-pass-secret.yaml','authd.pass',secrets.token_hex(24))
p=P('envs/local-env/storage-class.yaml');d=yaml.safe_load(p.read_text());d.update(provisioner='rancher.io/local-path',volumeBindingMode='WaitForFirstConsumer');save(p,d)
for p in root.rglob('*svc.yaml'):
 d=yaml.safe_load(p.read_text())
 if d and d['spec'].get('type')=='LoadBalancer': d['spec']['type']='ClusterIP';save(p,d)
PY
kubectl apply -k envs/local-env
