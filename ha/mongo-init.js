// Authenticated, repeatable initialization. Only mongo1 initiates the set.
try { rs.status(); } catch (e) {
  if (e.code !== 94) throw e;
  rs.initiate({_id:'rs0',members:[{_id:0,host:'mongo1:27017'},{_id:1,host:'mongo2:27017'},{_id:2,host:'mongo3:27017'}]});
}
let ready=false;
for(let n=0;n<120;n++) {
  if(rs.status().members.some(m=>m.state===1)) {ready=true;break;}
  sleep(1000);
}
if(!ready) throw new Error('No primary elected');
const user=encodeURIComponent(process.env.MONGO_ROOT_USERNAME);
const password=encodeURIComponent(process.env.MONGO_ROOT_PASSWORD);
const cluster=new Mongo(`mongodb://${user}:${password}@mongo1:27017,mongo2:27017,mongo3:27017/admin?replicaSet=rs0&serverSelectionTimeoutMS=15000`);
const appdb=cluster.getDB(process.env.MONGO_DB_NAME);
if(!appdb.getUser(process.env.MONGO_APP_USERNAME)) {
 appdb.createUser({user:process.env.MONGO_APP_USERNAME,pwd:process.env.MONGO_APP_PASSWORD,
 roles:[{role:'readWrite',db:process.env.MONGO_DB_NAME}]},{w:'majority',wtimeout:15000});
}
print('Replica set initialized; application user ready');
