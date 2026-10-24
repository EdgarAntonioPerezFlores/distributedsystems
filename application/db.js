import mysql from 'mysql2/promise';
export const required=(name)=>{if(!process.env[name]) throw new Error(`Missing ${name}`); return process.env[name];};
export const dbHosts=(process.env.DB_HOSTS || required('DB_HOST')).split(',');
export const mysqlOptions=(host)=>({host,port:Number(process.env.DB_PORT||3306),database:required('DB_NAME'),user:required('DB_USER'),password:required('DB_PASSWORD'),connectTimeout:2000});
export const mongoUri=()=>`mongodb://${required('MONGO_HOSTS')}/${encodeURIComponent(required('MONGO_DB'))}?replicaSet=rs0&retryWrites=true&w=majority&wtimeoutMS=5000`;
export const mongoOptions=()=>({auth:{username:required('MONGO_USER'),password:required('MONGO_PASSWORD')},authSource:required('MONGO_AUTH_SOURCE'),serverSelectionTimeoutMS:5000,connectTimeoutMS:2000,socketTimeoutMS:8000,maxPoolSize:10});
export function createDbPool() {
 const pools=dbHosts.map(host=>mysql.createPool({...mysqlOptions(host),waitForConnections:true,connectionLimit:Number(process.env.DB_POOL_LIMIT||5),queueLimit:50,enableKeepAlive:true}));
 for (const p of pools) p.on('connection', c=>c.query('SET SESSION wsrep_sync_wait=1'));
 let preferred=0;
 async function run(method,sql,args) {
   // Retry SELECT only; never replay a transaction or a write of unknown outcome.
   const safe=/^\s*SELECT\b/i.test(sql);
   const initial=preferred;
   for(let n=0;n<(safe?pools.length:1);n++) {
     const ix=(initial+n)%pools.length;
     try {const result=await pools[ix][method]({sql,timeout:5000},args);preferred=ix;return result;}
     catch(e) {if(!safe || n===pools.length-1) throw e;}
   }
 }
 return {query:(s,a)=>run('query',s,a),execute:(s,a)=>run('execute',s,a),end:()=>Promise.all(pools.map(p=>p.end()))};
}
