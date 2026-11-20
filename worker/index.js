import { connectBroker, confirmed, topics } from './events.js';
import { createDbPool, mongoUri, mongoOptions, required } from './db.js';
import { createCache } from './cache.js';
import { MongoClient } from 'mongodb';
const pool=createDbPool(), redis=createCache(), mongo=await new MongoClient(mongoUri(),mongoOptions()).connect();
const reviews=mongo.db(required('MONGO_DB')).collection('product_reviews');
const {ch}=await connectBroker(), key='store:products:cheapest';
await ch.prefetch(1);
for (const topic of topics) await ch.consume(topic, async msg=>{
  if(!msg) return;
  try {
    const body=JSON.parse(msg.content);
    if(topic==='reviews.created') {
      await reviews.updateOne({_id:msg.properties.messageId},{$setOnInsert:{...body,createdAt:new Date(body.createdAt)}},{upsert:true});
    } else if(topic==='catalog.changed') {
      if(await redis.del(key)===null) throw Error('cache unavailable');
    } else if(!await redis.get(key)) {
      const [rows]=await pool.execute('SELECT id, sku, name, description, price FROM products ORDER BY price ASC, id ASC LIMIT 10');
      if(!await redis.set(key,JSON.stringify(rows))) throw Error('cache unavailable');
    }
    ch.ack(msg);
  } catch {
    const retry=Number(msg.properties.headers?.attempt||0);
    if(retry>=3) return ch.nack(msg,false,false);
    try {
      await confirmed(ch,'',topic+'.retry',msg.content,{messageId:msg.properties.messageId,headers:{...msg.properties.headers,attempt:retry+1}});
      ch.ack(msg);
    } catch { process.exit(1); }
  }
});
