'use strict';

/**
 * Route Orchestrator
 * ===================
 *
 * Thin orchestrator that imports and registers all route groups in order.
 * Each route group is a separate module under lib/routes/ for modularity.
 *
 * Route Groups (registered in this order):
 *   1. SOSL Search      (lib/routes/search-routes.js)      — Cross-object text search
 *   2. Download          (lib/routes/download-routes.js)    — File body download
 *   3. Platform Events   (lib/routes/event-routes.js)       — Publisher + CometD subscriber
 *   4. REST API          (lib/routes/rest-routes.js)        — Single-record CRUD + SOQL
 *   5. Bulk API v1       (lib/routes/bulk-v1-routes.js)     — Legacy XML-based bulk (/services/async/...)
 *   6. Bulk v2 Ingest    (lib/routes/bulk-v2-ingest-routes.js) — Bulk API 2.0 write (CSV)
 *   7. Bulk v2 Query     (lib/routes/bulk-v2-query-routes.js) — Bulk API 2.0 read (CSV)
 *   8. Wave Analytics    (lib/routes/wave-routes.js)        — Einstein Analytics
 *   9. Admin Routes      (lib/routes/admin-routes.js)       — Health, debug, reset
 *
 * CRITICAL ROUTE ORDER:
 *   - Search, Download, and Event routes MUST be registered BEFORE rest-routes.js
 *   - Download routes (/sobjects/Attachment/:id/Body) would otherwise match
 *     the generic /sobjects/:object/:id pattern in rest-routes.js
 *   - Event routes intercept __e objects before rest-routes tries to CRUD them
 *
 * Why this file exists:
 *   - server.js calls registerRoutes() and registerErrorHandlers()
 *   - This file delegates to the individual route modules
 *   - Error handlers (404 catch-all + global error) are registered LAST
 *     via registerErrorHandlers(), solving the Express route ordering requirement
 *
 * Adding a new API group:
 *   1. Create lib/routes/new-api-routes.js
 *   2. Import it here
 *   3. Call it inside registerRoutes() before admin routes
 *   4. Zero changes to server.js needed
 */

const { registerSearchRoutes } = require('./routes/search-routes');
const { registerDownloadRoutes } = require('./routes/download-routes');
const { registerEventRoutes } = require('./routes/event-routes');
const { registerRestRoutes } = require('./routes/rest-routes');
const { registerBulkV1Routes } = require('./routes/bulk-v1-routes');
const { registerBulkIngestRoutes } = require('./routes/bulk-v2-ingest-routes');
const { registerBulkQueryRoutes } = require('./routes/bulk-v2-query-routes');
const { registerWaveRoutes } = require('./routes/wave-routes');
const { registerAdminRoutes } = require('./routes/admin-routes');
const { createJobStore } = require('./bulk/job-store');
const { createEventBus } = require('./streaming/event-bus');
const { formatError } = require('./error-formatter');

/**
 * Registers all API route handlers on the Express app.
 *
 * Creates the shared bulk job store and event bus, then passes them
 * (along with schemas and database) to each route module via dependency injection.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @param {Object} config - Server configuration { HTTP_PORT, HTTPS_PORT }
 *
 * @example
 *   registerRoutes(app, schemas, database, { HTTP_PORT: 8080, HTTPS_PORT: 8443 });
 */
function registerRoutes(app, schemas, database, config) {
  // Create shared state stores (in-memory, analogous to database{})
  const jobStore = createJobStore();
  const eventBus = createEventBus();

  // Register route groups in order
  // (order matters for Express: first match wins for same-pattern routes)
  //
  // CRITICAL: Search, Download, and Event routes BEFORE rest-routes!
  // - Download routes have specific paths like /sobjects/Attachment/:id/Body
  //   that would match /sobjects/:object/:id in rest-routes (with :id = "Body")
  // - Event routes intercept POST /sobjects/*__e before rest-routes tries to CRUD them
  registerSearchRoutes(app, schemas, database, config);                  // SOSL search (/search)
  registerDownloadRoutes(app, schemas, database, config);                // File download (/sobjects/.../Body)
  registerEventRoutes(app, schemas, database, config, eventBus);         // Platform Events + CometD
  registerRestRoutes(app, schemas, database, config);                    // REST CRUD + SOQL
  registerBulkV1Routes(app, schemas, database, config, jobStore);        // Bulk API v1 (/services/async/...)
  registerBulkIngestRoutes(app, schemas, database, config, jobStore);    // Bulk API 2.0 (/services/data/.../jobs/ingest)
  registerBulkQueryRoutes(app, schemas, database, config, jobStore);     // Bulk API 2.0 (/services/data/.../jobs/query)
  registerWaveRoutes(app, schemas, database, config);                    // Wave Analytics (/wave/...)
  registerAdminRoutes(app, schemas, database, config, jobStore, eventBus);
}

/**
 * Registers error handlers (404 catch-all + global error handler).
 *
 * MUST be called AFTER registerRoutes() — Express matches routes in
 * registration order, so these catch-all handlers must come last.
 *
 * Separated from registerRoutes() so that server.js can call them
 * in the correct order without worrying about route group internals.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition (for listing available objects)
 *
 * @example
 *   // In server.js:
 *   registerRoutes(app, schemas, database, config);    // All route groups
 *   registerErrorHandlers(app, schemas);                // 404 + error handler (LAST)
 */
function registerErrorHandlers(app, schemas) {
  // 404 catch-all — returns helpful error listing available objects
  app.use((req, res) => {
    res.status(404).json(formatError('NOT_FOUND',
      `No matching endpoint for ${req.method} ${req.path}. Available objects: ${Object.keys(schemas).join(', ')}`));
  });

  // Global error handler — catches unhandled exceptions in route handlers
  app.use((err, req, res, _next) => {
    console.error(`  ❌ Error: ${err.message}`);
    res.status(500).json(formatError('UNKNOWN_EXCEPTION', err.message));
  });
}

module.exports = { registerRoutes, registerErrorHandlers };
