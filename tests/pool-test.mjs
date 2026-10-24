import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const text=fs.readFileSync(new URL('../application/db.js',import.meta.url),'utf8').replace("import mysql from 'mysql2/promise';",'').replaceAll('export ','');
let calls=[],failFirst=true,failAll=false;
const mysql={createPool:opt=>({on:()=>{},query:async q=>{
 calls.push([opt.host,q.sql]);if(failAll || (opt.host==='p1'&&failFirst))throw new Error('offline');return [[{node:opt.host}]];
},execute:async q=>{calls.push([opt.host,q.sql]);throw new Error('write outcome unknown');},end:async()=>{}})};
const env={DB_HOST:'p1',DB_HOSTS:'p1,p2',DB_NAME:'store',DB_USER:'u',DB_PASSWORD:'p'};
const scope={mysql,process:{env}};vm.createContext(scope);vm.runInContext(text+';globalThis.pool=createDbPool();',scope);
assert.equal((await scope.pool.query('SELECT 1'))[0][0].node,'p2');assert.equal(calls.length,2);
calls=[];await scope.pool.query('SELECT 2');assert.deepEqual(calls.map(x=>x[0]),['p2']);
calls=[];await assert.rejects(()=>scope.pool.execute('UPDATE products SET price=1'));assert.equal(calls.length,1);
calls=[];failAll=true;await assert.rejects(()=>scope.pool.query('SELECT 3'));assert.equal(calls.length,2);
await scope.pool.end();console.log('PASS: SELECT failover, preferred endpoint, bounded attempts, no automatic write replay.');
