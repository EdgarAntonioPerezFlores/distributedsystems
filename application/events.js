import amqp from 'amqplib';
export const topics = ['reviews.created', 'catalog.changed', 'catalog.refresh'];
export async function connectBroker() {
  const conn = await amqp.connect(process.env.AMQP_URL, { timeout: 5000 });
  conn.on('error', () => console.error('AMQP connection lost'));
  conn.on('close', () => process.exit(1)); // Deployment reconnects on restart
  const ch = await conn.createConfirmChannel();
  await ch.assertExchange('catalog.events', 'direct', { durable: true });
  for (const topic of topics) {
    const dlq = topic === 'reviews.created' ? 'reviews.dlq' : topic + '.dlq';
    for (const [q, args] of [[dlq, {}],[topic, {'x-dead-letter-exchange':'','x-dead-letter-routing-key':dlq}]]) {
      await ch.assertQueue(q, { durable: true, arguments: { 'x-queue-type':'quorum', ...args } });
    }
    await ch.bindQueue(topic, 'catalog.events', topic);
    await ch.assertQueue(topic+'.retry',{durable:true,arguments:{'x-queue-type':'quorum','x-message-ttl':5000,'x-dead-letter-exchange':'catalog.events','x-dead-letter-routing-key':topic}});
  }
  return { ch, conn };
}
export const confirmed = (ch, ex, key, buf, opts) => new Promise((ok,fail) =>
  ch.publish(ex,key,buf,{persistent:true,contentType:'application/json',...opts},err=>err?fail(err):ok()));
