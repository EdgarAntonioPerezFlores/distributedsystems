import Redis from 'ioredis';
import {required} from './db.js';
export function createCache() {
 const client=new Redis({name:'cachemaster',role:'master',
  sentinels:required('REDIS_SENTINELS').split(',').map(s=>{const [host,port]=s.split(':');return {host,port:Number(port)};}),
  password:required('REDIS_PASSWORD'),sentinelPassword:required('REDIS_PASSWORD'),
  enableOfflineQueue:false,maxRetriesPerRequest:1,connectTimeout:1000,commandTimeout:800,
  retryStrategy:n=>Math.min(n*200,2000),sentinelRetryStrategy:n=>Math.min(n*200,2000)});
 client.on('error',()=>{}); // Cache failures degrade to SQL; no credentials in logs.
 return {
  get:async k=>{try{return await client.get(k);}catch{return null;}},
  set:async(k,v)=>{try{await client.set(k,v,'EX',60);return true;}catch{return false;}},
  del:async k=>{try{return await client.del(k);}catch{return null;}},
  ready:()=>client.status==='ready',quit:async()=>client.disconnect()
 };
}
