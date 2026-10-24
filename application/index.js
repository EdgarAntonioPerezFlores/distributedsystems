import { createServer } from "node:http";
import { MongoClient } from "mongodb";
import {required, createDbPool, mongoUri, mongoOptions} from './db.js';
import {createCache} from './cache.js';
const pool=createDbPool();
const mongo=new MongoClient(mongoUri(),mongoOptions());
const redis=createCache();

class HttpError extends Error {
  constructor(statusCode, message, trace) {
    super(message);
    this.statusCode = statusCode;
    this.trace = trace;
  }
}

const readJsonBody = async (request) => {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 16_384) {
      throw new HttpError(413, "Request body is too large");
    }
    chunks.push(chunk);
  }

  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new HttpError(400, "Request body must be valid JSON");
  }
};

const sendJson = (response, statusCode, payload, trace = []) => {
  response.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "x-request-trace": trace.join(" -> "),
  });
  response.end(JSON.stringify(payload));
};

const start = async () => {
  await mongo.connect();
  const reviews = mongo.db(required("MONGO_DB")).collection("product_reviews");
  const productsCacheKey = "store:products:cheapest";
  const server = createServer((request, response) => {
    const started=performance.now();
    response.on('finish',()=>console.log(JSON.stringify({time:new Date().toISOString(),node:process.env.APPLICATION_NODE,method:request.method,path:request.url,status:response.statusCode,ms:Math.round(performance.now()-started)})));
    const trace = [
      request.headers["x-presentation-lb"] || "presentation-lb-unknown",
      request.headers["x-web-node"] || "web-node-unknown",
      request.headers["x-application-lb"] || "application-lb-unknown",
      process.env.APPLICATION_NODE || "app-node-unknown",
    ];
    void (async () => {
      const url = new URL(request.url, "http://localhost");
      const pathname=url.pathname;
      if (pathname === '/diagnostics/db' && request.method === 'GET' && process.env.ENABLE_LAB_TESTS==='true') {
        const [rows]=await pool.query('SELECT @@hostname AS node, @@max_connections AS maxConnections, NOW() AS time');
        sendJson(response,200,rows,trace); return;
      }
      if (pathname === '/health/deep' && request.method === 'GET') {
        await Promise.all([pool.query('SELECT 1'),mongo.db().command({ping:1})]);
        sendJson(response,redis.ready()?200:503,{sql:true,mongo:true,cache:redis.ready()},trace); return;
      }

      if (request.method === "GET" && pathname === "/health") {
        await pool.query("SELECT 1");
        sendJson(response, 200, { status: "ok", sql: "ready", cache: redis.ready() ? "ready" : "degraded", node: process.env.APPLICATION_NODE }, [...trace, "galera-via-proxy"]);
        return;
      }

      if (request.method === "GET" && pathname === "/") {
        sendJson(response, 200, {
          service: "store-catalog-api",
          products: "/products/cheapest",
          reviews: "/products/{sku}/reviews",
        }, trace);
        return;
      }

      if (request.method === "GET" && pathname === "/products/cheapest") {
        trace.push("redis");
        const bypass = process.env.ENABLE_LAB_TESTS==='true' && url.searchParams.get('nocache')==='1';
        const cached = bypass ? null : await redis.get(productsCacheKey);
        if (cached) {
          trace.push("cache hit");
          sendJson(response, 200, JSON.parse(cached), trace);
          return;
        }
        trace[trace.length - 1] = bypass ? "cache bypass" : (redis.ready() ? "redis (cache miss)" : "redis unavailable; SQL fallback");
        trace.push("galera-via-proxy");
        const [products] = await pool.execute(
          "SELECT id, sku, name, description, price FROM products ORDER BY price ASC, id ASC LIMIT 10",
        );
        if (!bypass) {
          const stored = await redis.set(productsCacheKey, JSON.stringify(products));
          trace.push(stored ? "redis (cache write)" : "redis (write skipped)");
        }
        sendJson(response, 200, products, trace);
        return;
      }

      if (request.method === "POST" && pathname === "/cache/clear") {
        const removed = await redis.del(productsCacheKey);
        sendJson(
          response,
          200,
          { cacheKey: productsCacheKey, cacheEntryRemoved: removed === 1, cacheAvailable: removed !== null },
          [...trace, "redis (delete catalog cache)"],
        );
        return;
      }

      const reviewMatch = pathname.match(/^\/products\/([A-Za-z0-9-]+)\/reviews$/);
      if (reviewMatch && request.method === "GET") {
        const productSku = reviewMatch[1];
        const productReviews = await reviews
          .find({ sku: productSku })
          .sort({ createdAt: -1 })
          .limit(50)
          .project({ _id: 0, reviewer: 1, rating: 1, comment: 1, createdAt: 1 })
          .toArray();
        sendJson(response, 200, { sku: productSku, reviews: productReviews }, [...trace, "mongodb"]);
        return;
      }

      if (reviewMatch && request.method === "POST") {
        if (!request.headers["content-type"]?.includes("application/json")) {
          throw new HttpError(415, "Content-Type must be application/json");
        }
        const body = await readJsonBody(request);
        if (body === null || typeof body !== "object" || Array.isArray(body)) {
          throw new HttpError(400, "Request body must be a JSON object");
        }
        const reviewer = typeof body.reviewer === "string" ? body.reviewer.trim() : "";
        const comment = typeof body.comment === "string" ? body.comment.trim() : "";
        if (
          reviewer.length < 1 ||
          reviewer.length > 80 ||
          !Number.isInteger(body.rating) ||
          body.rating < 1 ||
          body.rating > 5 ||
          comment.length < 1 ||
          comment.length > 1000
        ) {
          throw new HttpError(400, "Provide reviewer, rating (1-5), and comment within the allowed lengths");
        }
        trace.push("galera-via-proxy (product lookup)");
        const [matches] = await pool.execute("SELECT 1 FROM products WHERE sku = ? LIMIT 1", [
          reviewMatch[1],
        ]);
        if (matches.length === 0) {
          throw new HttpError(404, "Product not found", trace);
        }
        const review = {
          sku: reviewMatch[1],
          reviewer,
          rating: body.rating,
          comment,
          createdAt: new Date(),
        };
        const result = await reviews.insertOne(review);
        sendJson(response, 201, { id: result.insertedId.toString(), ...review }, [...trace, "mongodb (insert review)"]);
        return;
      }

      sendJson(response, 404, { error: "Not found" }, trace);
    })().catch((error) => {
      if (!(error instanceof HttpError)) {
        console.error("Request failed:", error);
      }
      if (response.headersSent) {
        response.destroy();
        return;
      }
      sendJson(
        response,
        error instanceof HttpError ? error.statusCode : 503,
        { error: error instanceof HttpError ? error.message : "Service temporarily unavailable" },
        error instanceof HttpError && error.trace ? error.trace : trace,
      );
    });
  });

  server.listen(8080, "0.0.0.0", () => {
    console.log("Store catalog API listening on port 8080");
  });

  const shutdown = () => {
    server.close(() => {
      void Promise.all([pool.end(), mongo.close(), redis.quit()]).then(() => process.exit(0));
    });
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
};

start().catch((error) => {
  console.error("Application startup failed:", error);
  process.exitCode = 1;
});

