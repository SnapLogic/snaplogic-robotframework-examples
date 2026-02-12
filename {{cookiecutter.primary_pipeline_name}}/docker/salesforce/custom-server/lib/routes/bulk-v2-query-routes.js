'use strict';

/**
 * Salesforce Bulk API 2.0 — Query (Read) Routes
 * ================================================
 *
 * Handles bulk read operations via SOQL queries.
 * Results are returned as CSV (not JSON like REST API /query endpoint).
 *
 * Bulk API 2.0 Query Job Lifecycle:
 *   1. POST   .../jobs/query           → Create query job (processed immediately)
 *   2. GET    .../jobs/query/:id       → Poll status (state: JobComplete)
 *   3. GET    .../jobs/query/:id/results → Download results as CSV
 *
 * Processing is SYNCHRONOUS — the query executes immediately on job creation.
 * SnapLogic's first poll will see the completed state.
 *
 * Uses the SAME SOQL parser as the REST API query endpoint (lib/soql-parser.js),
 * and queries the SAME in-memory database.
 *
 * Routes:
 *   POST   /services/data/:version/jobs/query              - Create query job
 *   GET    /services/data/:version/jobs/query/:jobId        - Get job status
 *   GET    /services/data/:version/jobs/query/:jobId/results - Get CSV results
 *   PATCH  /services/data/:version/jobs/query/:jobId        - Abort job
 *   GET    /services/data/:version/jobs/query               - List all query jobs
 */

const { formatError } = require('../error-formatter');
const { processQueryJob } = require('../bulk/bulk-processor');

/**
 * Registers all Bulk API 2.0 query route handlers.
 *
 * @param {Object} app - Express app instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @param {Object} config - Server configuration
 * @param {Object} jobStore - Bulk job store instance
 *
 * @example
 *   registerBulkQueryRoutes(app, schemas, database, config, jobStore);
 */
function registerBulkQueryRoutes(app, schemas, database, config, jobStore) {

  // ═══════════════════════════════════════════════════════════════════════
  // CREATE BULK QUERY JOB
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * POST /services/data/:version/jobs/query
   *
   * Creates a bulk query job. The SOQL query is executed immediately
   * and results are available right away via GET .../results.
   *
   * @example
   *   // POST /services/data/v59.0/jobs/query
   *   // Body: { "operation": "query", "query": "SELECT Id, Name FROM Account WHERE Type = 'Customer'" }
   *   // Response (201): { "id": "750XYZ...", "state": "JobComplete", "numberRecordsProcessed": 5, ... }
   *
   * @example
   *   // queryAll (includes deleted/archived records — same behavior in mock):
   *   // Body: { "operation": "queryAll", "query": "SELECT Id FROM Account" }
   */
  app.post('/services/data/:version/jobs/query', (req, res) => {
    const { operation, query } = req.body;

    if (!query) {
      return res.status(400).json(formatError('MALFORMED_QUERY', 'query field is required'));
    }

    const validOps = ['query', 'queryAll'];
    if (operation && !validOps.includes(operation)) {
      return res.status(400).json(formatError('INVALID_FIELD',
        `operation must be one of: ${validOps.join(', ')}`));
    }

    const job = jobStore.create({
      object: '', // Will be extracted from SOQL by processor
      operation: operation || 'query',
      query,
      jobType: 'V2Query'
    });

    // Process the query immediately (synchronous)
    processQueryJob(job, schemas, database);
    jobStore.update(job.id, {
      state: job.state,
      object: job.object || '',
      numberRecordsProcessed: job.numberRecordsProcessed,
      numberRecordsFailed: job.numberRecordsFailed,
      queryResults: job.queryResults
    });

    console.log(`  🔍 Bulk query job created and completed: ${job.id} (${job.numberRecordsProcessed} records)`);
    res.status(201).json(formatQueryJobResponse(job));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // GET QUERY JOB STATUS
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/jobs/query/:jobId
   *
   * Returns query job metadata. SnapLogic polls this to check completion.
   *
   * @example
   *   // GET /services/data/v59.0/jobs/query/750XYZ...
   *   // Response: { "id": "750XYZ...", "state": "JobComplete", "numberRecordsProcessed": 5, ... }
   */
  app.get('/services/data/:version/jobs/query/:jobId', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    if (job.jobType !== 'V2Query') {
      return res.status(400).json(formatError('INVALID_TYPE', 'This is not a query job'));
    }

    res.json(formatQueryJobResponse(job));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // GET QUERY RESULTS (CSV)
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/jobs/query/:jobId/results
   *
   * Returns query results as CSV. Includes Sforce-Locator and
   * Sforce-NumberOfRecords headers (matching real Salesforce).
   *
   * @example
   *   // GET /services/data/v59.0/jobs/query/750XYZ.../results
   *   // Headers:
   *   //   Sforce-Locator: null
   *   //   Sforce-NumberOfRecords: 5
   *   // Response (text/csv):
   *   //   Id,Name,Type
   *   //   001ABC...,Acme Corp,Customer
   *   //   001DEF...,Beta Inc,Partner
   */
  app.get('/services/data/:version/jobs/query/:jobId/results', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    if (job.jobType !== 'V2Query') {
      return res.status(400).json(formatError('INVALID_TYPE', 'This is not a query job'));
    }

    if (job.state !== 'JobComplete') {
      return res.status(400).json(formatError('INVALID_STATE',
        'Results are only available when job state is JobComplete'));
    }

    // Set Salesforce-specific headers
    res.set('Content-Type', 'text/csv');
    res.set('Sforce-Locator', 'null'); // No pagination in mock
    res.set('Sforce-NumberOfRecords', String(job.numberRecordsProcessed));

    res.send(job.queryResults || '');
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ABORT QUERY JOB
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * PATCH /services/data/:version/jobs/query/:jobId
   *
   * Aborts a query job. In practice, since our mock processes queries
   * synchronously, the job is already complete before this is called.
   *
   * @example
   *   // PATCH /services/data/v59.0/jobs/query/750XYZ...
   *   // Body: { "state": "Aborted" }
   */
  app.patch('/services/data/:version/jobs/query/:jobId', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    if (job.jobType !== 'V2Query') {
      return res.status(400).json(formatError('INVALID_TYPE', 'This is not a query job'));
    }

    if (req.body.state === 'Aborted') {
      jobStore.update(job.id, { state: 'Aborted' });
      console.log(`  ⚠️  Bulk query job ${job.id} aborted`);
    } else {
      return res.status(400).json(formatError('INVALID_FIELD',
        `Invalid state: '${req.body.state}'. Only 'Aborted' is allowed.`));
    }

    res.json(formatQueryJobResponse(jobStore.get(job.id)));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // LIST ALL QUERY JOBS
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/jobs/query
   *
   * Lists all bulk query jobs, sorted by creation date (newest first).
   *
   * @example
   *   // GET /services/data/v59.0/jobs/query
   *   // Response: { "done": true, "records": [...], "nextRecordsUrl": null }
   */
  app.get('/services/data/:version/jobs/query', (req, res) => {
    const jobs = jobStore.list('V2Query').map(formatQueryJobResponse);
    res.json({
      done: true,
      records: jobs,
      nextRecordsUrl: null
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════
// HELPER — Format query job response
// ═══════════════════════════════════════════════════════════════════════

/**
 * Formats a query job object for API response, stripping internal fields.
 *
 * @param {Object} job - Internal job object
 * @returns {Object} Sanitized job response
 */
function formatQueryJobResponse(job) {
  return {
    id: job.id,
    operation: job.operation,
    object: job.object,
    createdById: job.createdById,
    createdDate: job.createdDate,
    systemModstamp: job.systemModstamp,
    state: job.state,
    concurrencyMode: job.concurrencyMode,
    contentType: job.contentType,
    apiVersion: job.apiVersion,
    jobType: job.jobType,
    lineEnding: job.lineEnding,
    numberRecordsProcessed: job.numberRecordsProcessed,
    retries: job.retries,
    totalProcessingTime: job.totalProcessingTime
  };
}

module.exports = { registerBulkQueryRoutes };
