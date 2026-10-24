import json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import pymysql

def eligible(state):
    return all(state.get(k)==v for k,v in {'wsrep_cluster_status':'Primary','wsrep_local_state':'4','wsrep_ready':'ON','wsrep_connected':'ON'}.items())

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status=503; body={'ready':False}
        try:
            with pymysql.connect(host='127.0.0.1',user=os.environ['DB_USER'],password=os.environ['DB_PASSWORD'],connect_timeout=1,read_timeout=1,write_timeout=1) as db:
                with db.cursor() as cursor:
                    cursor.execute("SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_status','wsrep_local_state','wsrep_ready','wsrep_connected','wsrep_cluster_size')")
                    state=dict(cursor.fetchall())
            body={'ready':eligible(state),'state':state}; status=200 if body['ready'] else 503
        except Exception as e:
            body={'ready':False,'error':type(e).__name__}
        data=json.dumps(body).encode()
        self.send_response(status); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
    def log_message(self,*args): pass

if __name__=='__main__': ThreadingHTTPServer(('0.0.0.0',9200),Handler).serve_forever()
