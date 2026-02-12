'use strict';

/**
 * Admin & Health Check Routes
 * ============================
 *
 * Administrative endpoints for debugging, monitoring, and managing the mock server.
 * These are NOT Salesforce API endpoints — they're custom admin tools.
 *
 * Routes:
 *   GET    /__admin/db              - View all in-memory data
 *   GET    /__admin/db/:object      - View records for one object
 *   POST   /__admin/reset           - Clear all data (records + bulk jobs + events)
 *   GET    /__admin/schemas         - View loaded schema definitions
 *   GET    /__admin/health          - Simple health check (WireMock-compatible)
 *   GET    /__admin/bulk-jobs       - View all bulk job metadata
 *   GET    /__admin/events          - View all published Platform Events
 *   GET    /__admin/streaming-clients - View active CometD client sessions
 *   GET    /health                  - Detailed health check (Docker HEALTHCHECK)
 */

/**
 * Registers all admin and health check route handlers.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @param {Object} config - Server configuration (unused currently, kept for consistency)
 * @param {Object} jobStore - Bulk job store instance (from job-store.js)
 * @param {Object} eventBus - Event bus instance (from event-bus.js)
 *
 * @example
 *   registerAdminRoutes(app, schemas, database, config, jobStore, eventBus);
 */
function registerAdminRoutes(app, schemas, database, config, jobStore, eventBus) {

  /**
   * GET /__admin/db
   *
   * Returns ALL data in the in-memory database, grouped by object.
   *
   * @example
   *   // GET /__admin/db
   *   // Response: { "Account": { "count": 2, "records": [...] }, ... }
   */
  app.get('/__admin/db', (req, res) => {
    const summary = {};
    for (const [name, records] of Object.entries(database)) {
      summary[name] = { count: records.length, records };
    }
    res.json(summary);
  });

  /**
   * GET /__admin/db/:object
   *
   * Returns all records for a specific object.
   *
   * @example
   *   // GET /__admin/db/Account
   *   // Response: { "count": 2, "records": [...] }
   */
  app.get('/__admin/db/:object', (req, res) => {
    const objectName = req.params.object;
    if (!database[objectName]) {
      return res.status(404).json({ error: `Object '${objectName}' not found` });
    }
    res.json({ count: database[objectName].length, records: database[objectName] });
  });

  /**
   * POST /__admin/reset
   *
   * Clears ALL data: in-memory records, bulk jobs, AND events.
   * Schema definitions are preserved — only data is removed.
   * Useful between test runs to start with a clean slate.
   *
   * @example
   *   // POST /__admin/reset
   *   // Response: { "status": "reset", "message": "All data cleared...", ... }
   */
  app.post('/__admin/reset', (req, res) => {
    let totalCleared = 0;
    for (const name of Object.keys(database)) {
      totalCleared += database[name].length;
      database[name] = [];
    }

    // Also clear bulk jobs if jobStore is available
    let jobsCleared = 0;
    if (jobStore) {
      jobsCleared = jobStore.clear();
    }

    // Also clear events and streaming clients if eventBus is available
    let eventsCleared = 0;
    let clientsCleared = 0;
    if (eventBus) {
      const eventResult = eventBus.clear();
      eventsCleared = eventResult.eventsCleared;
      clientsCleared = eventResult.clientsCleared;
    }

    console.log(`  🧹 Database reset: cleared ${totalCleared} records, ${jobsCleared} bulk jobs, ${eventsCleared} events, ${clientsCleared} streaming clients`);
    res.json({
      status: 'reset',
      message: `All data cleared. ${totalCleared} records, ${jobsCleared} bulk jobs, ${eventsCleared} events, ${clientsCleared} streaming clients removed.`,
      objects: Object.keys(database)
    });
  });

  /**
   * GET /__admin/schemas
   *
   * Returns all loaded schema definitions.
   *
   * @example
   *   // GET /__admin/schemas
   *   // Response: { "Account": { "name": "Account", "idPrefix": "001", "fields": {...} }, ... }
   */
  app.get('/__admin/schemas', (req, res) => {
    res.json(schemas);
  });

  /**
   * GET /__admin/bulk-jobs
   *
   * Returns all bulk job metadata for debugging.
   * Shows both ingest and query jobs with their current state.
   *
   * @example
   *   // GET /__admin/bulk-jobs
   *   // Response: { "count": 3, "jobs": [...] }
   */
  app.get('/__admin/bulk-jobs', (req, res) => {
    if (jobStore) {
      res.json(jobStore.listAll());
    } else {
      res.json({ count: 0, jobs: [] });
    }
  });

  /**
   * GET /__admin/events
   *
   * Returns all published Platform Events across all channels.
   * Useful for verifying that events were published correctly.
   *
   * @example
   *   // GET /__admin/events
   *   // Response: { "channels": { "/event/PlatformEvent__e": { "count": 2, "events": [...] } }, "totalEvents": 2 }
   */
  app.get('/__admin/events', (req, res) => {
    if (eventBus) {
      res.json(eventBus.getAllEvents());
    } else {
      res.json({ channels: {}, totalEvents: 0 });
    }
  });

  /**
   * GET /__admin/streaming-clients
   *
   * Returns all active CometD client sessions.
   * Shows client IDs, their subscriptions, and replay positions.
   *
   * @example
   *   // GET /__admin/streaming-clients
   *   // Response: { "count": 1, "clients": [{ "id": "mock-client-1-...", "subscriptions": [...] }] }
   */
  app.get('/__admin/streaming-clients', (req, res) => {
    if (eventBus) {
      res.json(eventBus.getClients());
    } else {
      res.json({ count: 0, clients: [] });
    }
  });

  /**
   * GET /health
   *
   * Detailed health check. Used by Docker HEALTHCHECK and Makefile status target.
   *
   * @example
   *   // GET /health
   *   // Response: { "status": "UP", "objects": 5, "totalRecords": 12, ... }
   */
  app.get('/health', (req, res) => {
    const eventInfo = eventBus ? eventBus.getAllEvents() : { totalEvents: 0 };
    const clientInfo = eventBus ? eventBus.getClients() : { count: 0 };

    res.json({
      status: 'UP',
      timestamp: new Date().toISOString(),
      objects: Object.keys(schemas).length,
      totalRecords: Object.values(database).reduce((sum, records) => sum + records.length, 0),
      bulkJobs: jobStore ? jobStore.listAll().count : 0,
      events: eventInfo.totalEvents,
      streamingClients: clientInfo.count
    });
  });

  /**
   * GET /__admin/health
   *
   * Simplified health check (compatible with WireMock admin health endpoint).
   *
   * @example
   *   // GET /__admin/health
   *   // Response: { "status": "healthy" }
   */
  app.get('/__admin/health', (req, res) => {
    res.json({ status: 'healthy' });
  });
}

module.exports = { registerAdminRoutes };
