"""Checks the routing predicate without requiring Docker or a database."""
import ast
from pathlib import Path
path=Path(__file__).resolve().parents[1]/'ha/galera-check/check.py'
tree=ast.parse(path.read_text());fn=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='eligible')
scope={};exec(compile(ast.Module(body=[fn],type_ignores=[]),'predicate','exec'),scope)
eligible=scope['eligible']
good={'wsrep_cluster_status':'Primary','wsrep_local_state':'4','wsrep_ready':'ON','wsrep_connected':'ON'}
assert eligible(good)
for key,bad in [('wsrep_cluster_status','Non-Primary'),('wsrep_local_state','2'),('wsrep_ready','OFF'),('wsrep_connected','OFF')]:
    assert not eligible({**good,key:bad}),key
for key in good:
    missing=good.copy();missing.pop(key);assert not eligible(missing)
print('PASS: valid Primary/Synced accepted; non-primary, unsynced, disconnected, not-ready and incomplete states rejected.')
