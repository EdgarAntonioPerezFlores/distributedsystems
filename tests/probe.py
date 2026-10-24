"""Remote probe. Serial sampling, not a load generator or an exact RTO clock."""
import argparse, csv, json, time, urllib.request, urllib.error
from pathlib import Path
from datetime import datetime, timezone
p=argparse.ArgumentParser()
p.add_argument('base');p.add_argument('--seconds',type=int,default=180);p.add_argument('--path',default='/api/products/cheapest?nocache=1');p.add_argument('--out',default='results/probe.csv')
a=p.parse_args();Path(a.out).parent.mkdir(parents=True,exist_ok=True)
end=time.monotonic()+a.seconds; rows=[]
with open(a.out,'w',newline='') as f:
    writer=csv.writer(f);writer.writerow(['utc','status','ms','ok','trace','error'])
    while time.monotonic()<end:
        t=time.monotonic();utc=datetime.now(timezone.utc).isoformat();status=0;trace='';err='';ok=False
        try:
            with urllib.request.urlopen(a.base.rstrip('/')+a.path,timeout=3) as r:
                status=r.status;trace=r.headers.get('x-request-trace','');body=r.read()
                if 200<=status<300:
                    value=json.loads(body)
                    ok=isinstance(value,list) and len(value)>0 if '/products/cheapest' in a.path else isinstance(value,dict)
        except urllib.error.HTTPError as e: status=e.code;err=str(e)
        except Exception as e: err=type(e).__name__
        ms=round((time.monotonic()-t)*1000,2);writer.writerow([utc,status,ms,ok,trace,err]);f.flush();rows.append((ok,ms))
        time.sleep(max(0,1-(time.monotonic()-t)))
good=[ms for ok,ms in rows if ok]
print(json.dumps({'samples':len(rows),'success':len(good),'sample_availability_pct':100*len(good)/len(rows) if rows else None,'note':'Use timestamps for outage bounds. This is sampled availability, not request availability under load.'},indent=2))
