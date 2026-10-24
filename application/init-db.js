import { readFile } from "node:fs/promises";
import { MongoClient } from "mongodb";
import mysql from "mysql2/promise";

import {required,dbHosts,mysqlOptions,mongoUri,mongoOptions} from './db.js';
let connection;
for(let attempt=0;attempt<90 && !connection;attempt++) {
 for(const host of dbHosts) {
  try {connection=await mysql.createConnection({...mysqlOptions(host),multipleStatements:true});break;}
  catch { /* proxies may be waiting for cluster-aware checks */ }
 }
 if(!connection) await new Promise(r=>setTimeout(r,2000));
}
if(!connection) throw new Error('No Galera proxy is ready');
const mongo=new MongoClient(mongoUri(),mongoOptions());

try {
  const schema = await readFile(new URL("./database/catalog.sql", import.meta.url), "utf8");
  await connection.query(schema);
  console.log("Product catalog schema initialized");
} finally {
  await connection.end();
}

try {
  await mongo.connect();
  const reviews = mongo.db(required("MONGO_DB")).collection("product_reviews");
  await reviews.createIndex({ sku: 1, createdAt: -1 });
  await reviews.updateOne(
    { sampleId: "sample-st-001" },
    {
      $setOnInsert: {
        sampleId: "sample-st-001",
        sku: "ST-001",
        reviewer: "Alex",
        rating: 5,
        comment: "Sturdy and convenient for grocery shopping.",
        createdAt: new Date("2025-01-15T12:00:00.000Z"),
      },
    },
    { upsert: true },
  );
  await reviews.updateOne(
    { sampleId: "sample-st-003" },
    {
      $setOnInsert: {
        sampleId: "sample-st-003",
        sku: "ST-003",
        reviewer: "Sam",
        rating: 4,
        comment: "A comfortable everyday mug.",
        createdAt: new Date("2025-01-16T12:00:00.000Z"),
      },
    },
    { upsert: true },
  );
  await reviews.createIndex({ sampleId: 1 }, { unique: true, sparse: true });
  console.log("Product reviews initialized in MongoDB");
} finally {
  await mongo.close();
}

