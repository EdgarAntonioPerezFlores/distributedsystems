import json, sys, urllib.request, uuid
base=sys.argv[1].rstrip('/')
def call(path,data=None):
    req=urllib.request.Request(base+path,data=json.dumps(data).encode() if data else None,headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=15) as r:return r.status,json.load(r),r.headers
assert call('/api/health/deep')[0]==200
status,products,_=call('/api/products/cheapest?nocache=1')
assert status==200 and len(products)>0
prices=[float(p['price']) for p in products];assert prices==sorted(prices)
sku=products[0]['sku'];marker='test-'+uuid.uuid4().hex
status,review,_=call('/api/products/'+sku+'/reviews',{'reviewer':'Prueba laboratorio','rating':5,'comment':marker})
assert status==201
_,data,_=call('/api/products/'+sku+'/reviews')
assert any(r['comment']==marker for r in data['reviews'])
print('PASS: health, SQL, catálogo ordenado, escritura/lectura MongoDB. Review:',marker)
print('La reseña queda guardada como evidencia de prueba.')
