import test from 'node:test';
import assert from 'node:assert/strict';
import {confirmed} from '../application/events.js';
test('el publicador espera confirmación y conserva identidad y durabilidad',async()=>{
 let ack, props, resolved=false;
 const ch={publish:(x,k,b,o,f)=>{props=o;ack=f}};
 const p=confirmed(ch,'catalog.events','reviews.created',Buffer.from('{}'),{messageId:'ST-001:uno'}).then(()=>resolved=true);
 await Promise.resolve(); assert.equal(resolved,false);assert.equal(props.persistent,true);assert.equal(props.messageId,'ST-001:uno');
 ack();await p; assert.equal(resolved,true);
});
test('un rechazo del broker no se declara éxito',async()=>{
 const ch={publish:(x,k,b,o,f)=>f(Error('nack'))};
 await assert.rejects(confirmed(ch,'','q',Buffer.from('{}'),{}),/nack/);
});
