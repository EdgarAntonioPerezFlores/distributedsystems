#!/usr/bin/env bash
# Local bootstrap from one trusted admin. Does not convert an existing backend.
set -euo pipefail
umask 077
repo=$(git rev-parse --show-toplevel)
dir="${CATALOG_TF_LOCAL_DIR:-$HOME/.local/state/catalog-k3s-dev}"
mkdir -p "$dir"
if [[ -e "$dir/.terraform/terraform.tfstate" ]]; then
  python3 - "$dir/.terraform/terraform.tfstate" <<'PY'
import json,sys
assert json.load(open(sys.argv[1])).get('backend',{}).get('type')=='local','No mezclar backends'
PY
fi
cp "$repo/infra/terraform/main.tf" "$repo/infra/terraform/.terraform.lock.hcl" "$dir/"
mkdir -p "$dir/modules"
cp -R "$repo/infra/terraform/modules/." "$dir/modules/"
# Keep the tracked S3 backend in the project; this private copy is explicitly dev-only.
sed -i 's/backend "s3" {}/backend "local" {}/' "$dir/main.tf"
grep -q 'backend "local" {}' "$dir/main.tf"
cp -n "$repo/infra/terraform/lab.tfvars.example" "$dir/lab.tfvars" || true
terraform -chdir="$dir" init -input=false
terraform -chdir="$dir" workspace select -or-create dev
echo "Directorio de Terraform para editar lab.tfvars y ejecutar los apply: $dir"
