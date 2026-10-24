#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -e .env ]; then echo '.env ya existe; no se sobrescribe.'; exit 1; fi
command -v openssl >/dev/null
umask 077
mkdir -p secrets results
cp .env.example .env
for name in MARIADB_ROOT_PASSWORD MARIADB_BACKUP_PASSWORD CATALOG_DB_PASSWORD MONGO_ROOT_PASSWORD MONGO_APP_PASSWORD REDIS_PASSWORD NAGIOSADMIN_PASSWORD; do
  value=$(openssl rand -hex 16)
  sed -i "s/^${name}=.*/${name}=${value}/" .env
done
openssl rand -base64 756 > secrets/mongo-keyfile
chmod 600 .env secrets/mongo-keyfile
echo 'Credenciales generadas. No subir .env ni secrets a GitHub.'
