from pathlib import Path
import re, subprocess, yaml, ast
P=Path(__file__).resolve().parents[1]
c=yaml.safe_load((P/'docker-compose.yml').read_text());services=c['services']
for name,s in services.items():
    for dep in s.get('depends_on',[]):assert dep in services,(name,dep)
    if 'network_mode' in s:assert s['network_mode'].split(':',1)[1] in services
    for volume in s.get('volumes',[]):
        src=volume.split(':')[0]
        if src.startswith('./') and not src.startswith('./secrets/'):
            assert (P/src).exists(),(name,src)
    for net in s.get('networks',[]): assert net in c['networks'],(name,net)
declared={l.split('=',1)[0] for l in (P/'.env.example').read_text().splitlines() if '=' in l and not l.startswith('#')}
used=set(re.findall(r'(?<!\$)\$\{([A-Z_]+)',(P/'docker-compose.yml').read_text()))
assert used <= declared,used-declared
for p in P.rglob('*.sh'):subprocess.run(['bash','-n',str(p)],check=True)
for p in P.rglob('*.py'):ast.parse(p.read_text())
for p in (P/'application').glob('*.js'):subprocess.run(['node','--check',str(p)],check=True)
subprocess.run(['node','--check',str(P/'ha/mongo-init.js')],check=True)
subprocess.run(['node',str(P/'tests/pool-test.mjs')],check=True)
subprocess.run(['python3',str(P/'tests/galera-gate-test.py')],check=True)
assert all(services[f'app{i}']['environment']['DB_HOSTS']=='db-proxy1,db-proxy2' for i in (1,2,3))
assert all(not s.get('ports') for n,s in services.items() if n.startswith(('galera','mongo','redis','sentinel','db-proxy')))
print(f'PASS: {len(services)} services; dependency names, mounted paths, env template, syntax and focused unit checks. Runtime Docker checks still required.')
