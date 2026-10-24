#!/bin/bash
# Only repairs the original 48-character password error before DB initialization.
set -euo pipefail
cd "$(dirname "$0")/.."
test -s .env
docker compose stop galera1 galera2 galera3
bash scripts/assert-empty-galera.sh
python3 - <<'PY'
from pathlib import Path
import re, shutil, time, os
p=Path('.env')
lines=p.read_text().splitlines()
keys={'MARIADB_ROOT_PASSWORD','MARIADB_BACKUP_PASSWORD','CATALOG_DB_PASSWORD'}
found=set(); output=[]; changed=[]
for line in lines:
    k,sep,v=line.partition('=')
    if k in keys:
        found.add(k)
        if not re.fullmatch(r'[0-9a-fA-F]{32}|[0-9a-fA-F]{48}',v):
            raise SystemExit('Formato inesperado en '+k+'. No se modificó .env.')
        if len(v)==48:
            line=k+'='+v[:32]; changed.append(k)
    output.append(line)
if found!=keys: raise SystemExit('Faltan variables SQL. No se modificó .env.')
if changed:
    Path('secrets').mkdir(exist_ok=True)
    backup=Path('secrets')/('.env.before-password-fix-'+str(time.time_ns()))
    shutil.copyfile(p,backup); os.chmod(backup,0o600)
    p.write_text('\n'.join(output)+'\n'); os.chmod(p,0o600)
print('Contraseñas SQL compatibles (32 caracteres); valores no mostrados.')
PY
bash scripts/first-start.sh --resume-empty
