'use strict';

/**
 /**
 * Fake Salesforce API Server (for testing)
 * 
 * This server pretends to be Salesforce so our Robot Framework tests can run
 * without hitting the real Salesforce API. It supports:
 * 
 *   - CRUD operations (create, read, update, delete records)
 *   - SOQL queries (SELECT ... FROM ... WHERE ...)
 *   - SOSL search (cross-object text search)
 *   - Bulk API v1 (XML) and v2 (CSV) for large data operations
 *   - Platform Events (publish/subscribe)
 *   - Wave/Einstein Analytics queries
 *   - OAuth token endpoint (returns a fake token)
 * 
 * How it works:
 *   1. On startup, reads JSON schema files from /schemas (e.g., Account.json, Contact.json)
 *   2. Stores all records in memory (wiped on restart — by design for clean tests)
 *   3. Listens on HTTP (8080) and HTTPS (8443)
 * 
 * To add a new Salesforce object: just add a new JSON file in schemas/. No code changes needed.
 * 
 */



const express = require('express');
const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

const { registerRoutes, registerErrorHandlers } = require('./lib/routes');

// ═══════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════

const HTTP_PORT = parseInt(process.env.HTTP_PORT || '8080', 10);
const HTTPS_PORT = parseInt(process.env.HTTPS_PORT || '8443', 10);
const P12_FILE = process.env.P12_FILE || path.join(__dirname, 'certs', 'custom-keystore.p12');
const P12_PASSWORD = process.env.P12_PASSWORD || 'password';
const SCHEMA_DIR = process.env.SCHEMA_DIR || path.join(__dirname, 'schemas');

// ═══════════════════════════════════════════════════════════════════════
// SCHEMA LOADING & IN-MEMORY DATABASE
// ═══════════════════════════════════════════════════════════════════════
//
// Schema files (Account.json, Contact.json, etc.) are placed on disk via:
//   1. Dockerfile: COPY schemas/ ./schemas/        → baked into the image at build time
//   2. docker-compose: volumes: ./schemas:/app/schemas:ro → overlays at runtime
//
// The volume mount overrides the baked-in copy, so you can edit schemas on
// the host and restart the container without rebuilding the image.
//
// However, files on disk alone do nothing. This code reads and parses each
// JSON schema into JavaScript objects so the route handlers can:
//   - Look up ID prefixes (e.g., 001 for Account)
//   - Validate required fields and picklist values
//   - Know which Salesforce objects are supported
//
// The 'database' object holds all CRUD records in memory (lost on restart).

const schemas = {};
const database = {};

console.log('═══════════════════════════════════════════════════');
console.log('  Salesforce Mock API Server - Loading Schemas');
console.log('═══════════════════════════════════════════════════');

if (fs.existsSync(SCHEMA_DIR)) {
  fs.readdirSync(SCHEMA_DIR)
    .filter(file => file.endsWith('.json'))
    .forEach(file => {
      try {
        const schema = JSON.parse(fs.readFileSync(path.join(SCHEMA_DIR, file), 'utf8'));
        schemas[schema.name] = schema;
        database[schema.name] = [];
        console.log(`  ✅ Loaded: ${schema.name} (prefix: ${schema.idPrefix}, fields: ${Object.keys(schema.fields).length})`);
      } catch (err) {
        console.error(`  ❌ Failed to load ${file}: ${err.message}`);
      }
    });
} else {
  console.error(`  ❌ Schema directory not found: ${SCHEMA_DIR}`);
}

console.log(`  📦 Total objects: ${Object.keys(schemas).length}`);
console.log('═══════════════════════════════════════════════════\n');

// ═══════════════════════════════════════════════════════════════════════
// EXPRESS APPLICATION
// ═══════════════════════════════════════════════════════════════════════

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.text({ type: 'text/csv', limit: '50mb' }));           // CSV body parser for Bulk API 2.0 uploads
app.use(express.text({ type: ['application/xml', 'text/xml'], limit: '50mb' })); // XML body parser for Bulk API v1

// CORS support (matching WireMock --enable-stub-cors)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, PUT, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-SFDC-Session');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// Request logging
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.originalUrl}`);
  next();
});

// Register all API routes (REST + Bulk + Admin)
registerRoutes(app, schemas, database, { HTTP_PORT, HTTPS_PORT });

// Register error handlers LAST (404 catch-all + global error handler)
// Must come after all route groups so they don't intercept valid routes
registerErrorHandlers(app, schemas);

// ═══════════════════════════════════════════════════════════════════════
// SERVER STARTUP (HTTP + HTTPS)
// ═══════════════════════════════════════════════════════════════════════

const httpServer = http.createServer(app);
httpServer.listen(HTTP_PORT, () => {
  console.log(`🌐 HTTP  server listening on port ${HTTP_PORT}`);
});

// HTTPS Certificate Strategy:
// We reuse the SAME PKCS12 certificate (custom-keystore.p12) that WireMock uses.
// This is critical because Groundplex's Java truststore already has this cert imported.
// Generating a NEW certificate would require re-importing into the Groundplex truststore.
//
// WireMock (Java) loads .p12 files natively via --https-keystore.
// Node.js cannot use .p12 with the cert/key options (those require PEM format).
// However, Node.js supports .p12 directly via the "pfx" option, so no conversion
// is needed — we load the same .p12 file as-is.
if (fs.existsSync(P12_FILE)) {
  const httpsServer = https.createServer({
    pfx: fs.readFileSync(P12_FILE),       // Load PKCS12 keystore directly (same file WireMock uses)
    passphrase: P12_PASSWORD,              // Keystore password (matches WireMock --keystore-password)
    requestCert: false,
    rejectUnauthorized: false
  }, app);

  httpsServer.listen(HTTPS_PORT, () => {
    console.log(`🔒 HTTPS server listening on port ${HTTPS_PORT}`);
    console.log(`   📌 Using certificate: ${P12_FILE}`);
  });
} else {
  console.log(`⚠️  PKCS12 keystore not found: ${P12_FILE}`);
  console.log('   Ensure the keystore is mounted via docker-compose:');
  console.log('     - ./certs/custom-keystore.p12:/app/certs/custom-keystore.p12:ro');
  console.log(`   HTTPS server NOT started. Only HTTP available on port ${HTTP_PORT}`);
}

console.log('\n═══════════════════════════════════════════════════');
console.log('  Salesforce Mock API Server - Ready!');
console.log('═══════════════════════════════════════════════════');
console.log(`  📡 HTTP:  http://localhost:${HTTP_PORT}`);
console.log(`  🔒 HTTPS: https://localhost:${HTTPS_PORT}`);
console.log(`  🏥 Health: http://localhost:${HTTP_PORT}/health`);
console.log(`  📊 Admin:  http://localhost:${HTTP_PORT}/__admin/db`);
console.log(`  🧹 Reset:  POST http://localhost:${HTTP_PORT}/__admin/reset`);
console.log(`  📋 Schemas: http://localhost:${HTTP_PORT}/__admin/schemas`);
console.log('  ─── REST API ─────────────────────────────────');
console.log(`  🔑 OAuth:       POST http://localhost:${HTTP_PORT}/services/oauth2/token`);
console.log(`  📝 SOQL:        GET  http://localhost:${HTTP_PORT}/services/data/v59.0/query?q=...`);
console.log(`  🔍 SOSL:        GET  http://localhost:${HTTP_PORT}/services/data/v59.0/search?q=...`);
console.log(`  📥 Download:    GET  http://localhost:${HTTP_PORT}/services/data/v59.0/sobjects/{Object}/{Id}/Body`);
console.log('  ─── Bulk API ─────────────────────────────────');
console.log(`  📦 Bulk v1:     POST http://localhost:${HTTP_PORT}/services/async/{version}/job`);
console.log(`  📦 Bulk v2:     POST http://localhost:${HTTP_PORT}/services/data/v59.0/jobs/ingest`);
console.log(`  🔍 Bulk Query:  POST http://localhost:${HTTP_PORT}/services/data/v59.0/jobs/query`);
console.log(`  📋 Bulk Jobs:   http://localhost:${HTTP_PORT}/__admin/bulk-jobs`);
console.log('  ─── Platform Events & Streaming ─────────────');
console.log(`  📢 Publish:     POST http://localhost:${HTTP_PORT}/services/data/v59.0/sobjects/{Event}__e`);
console.log(`  📨 CometD:      POST http://localhost:${HTTP_PORT}/cometd/{version}`);
console.log(`  📫 Events:      http://localhost:${HTTP_PORT}/__admin/events`);
console.log(`  👥 Clients:     http://localhost:${HTTP_PORT}/__admin/streaming-clients`);
console.log('  ─── Wave Analytics ───────────────────────────');
console.log(`  📊 Datasets:    GET  http://localhost:${HTTP_PORT}/services/data/v59.0/wave/datasets`);
console.log(`  📊 SAQL Query:  POST http://localhost:${HTTP_PORT}/services/data/v59.0/wave/query`);
console.log('═══════════════════════════════════════════════════\n');
