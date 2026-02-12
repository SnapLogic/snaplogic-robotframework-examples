'use strict';

/**
 * Salesforce Bulk API 2.0 — Ingest (Write) Routes
 * =================================================
 *
 * Handles bulk write operations: insert, update, upsert, delete.
 * Uses CSV format for data upload/download (not JSON like REST API).
 *
 * Bulk API 2.0 Ingest Job Lifecycle:
 *   1. POST   .../jobs/ingest           → Create job (state: Open)
 *   2. PUT    .../jobs/ingest/:id/batches → Upload CSV data
 *   3. PATCH  .../jobs/ingest/:id       → Close job (state: UploadComplete → JobComplete)
 *   4. GET    .../jobs/ingest/:id       → Poll status (state: JobComplete)
 *   5. GET    .../jobs/ingest/:id/successfulResults → Download success CSV
 *   6. GET    .../jobs/ingest/:id/failedResults     → Download failure CSV
 *
 * Processing is SYNCHRONOUS in this mock server — when the job state changes
 * to UploadComplete, records are processed immediately and the state goes
 * directly to JobComplete. SnapLogic's first poll will see the completed state.
 *
 * Routes:
 *   POST   /services/data/:version/jobs/ingest                        - Create job
 *   PUT    /services/data/:version/jobs/ingest/:jobId/batches         - Upload CSV
 *   PATCH  /services/data/:version/jobs/ingest/:jobId                 - Close/Abort
 *   GET    /services/data/:version/jobs/ingest/:jobId                 - Get job info
 *   GET    /services/data/:version/jobs/ingest/:jobId/successfulResults - Success CSV
 *   GET    /services/data/:version/jobs/ingest/:jobId/failedResults   - Failure CSV
 *   GET    /services/data/:version/jobs/ingest/:jobId/unprocessedrecords - Unprocessed CSV
 *   DELETE /services/data/:version/jobs/ingest/:jobId                 - Delete job
 *   GET    /services/data/:version/jobs/ingest                        - List all jobs
 */

const { formatError } = require('../error-formatter');
const { processIngestJob } = require('../bulk/bulk-processor');
const { getCSVHeaders } = require('../bulk/csv-parser');

/**
 * Registers all Bulk API 2.0 ingest route handlers.
 *
 * @param {Object} app - Express app instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records (shared with REST API)
 * @param {Object} config - Server configuration
 * @param {Object} jobStore - Bulk job store instance
 *
 * @example
 *   registerBulkIngestRoutes(app, schemas, database, config, jobStore);
 */
function registerBulkIngestRoutes(app, schemas, database, config, jobStore) {

  // ═══════════════════════════════════════════════════════════════════════
  // CREATE BULK INGEST JOB
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * POST /services/data/:version/jobs/ingest
   *
   * Creates a new bulk ingest job. The job starts in 'Open' state,
   * ready to receive CSV data via PUT .../batches.
   *
   * @example
   *   // POST /services/data/v59.0/jobs/ingest
   *   // Body: { "object": "Account", "operation": "insert" }
   *   // Response (201): { "id": "750ABC...", "state": "Open", "object": "Account", ... }
   *
   * @example
   *   // Upsert with external ID:
   *   // Body: { "object": "Account", "operation": "upsert", "externalIdFieldName": "ExternalId__c" }
   */
  app.post('/services/data/:version/jobs/ingest', (req, res) => {
    const { object, operation, externalIdFieldName, contentType, lineEnding } = req.body;

    if (!object) {
      return res.status(400).json(formatError('INVALID_FIELD', 'object is required'));
    }

    if (!schemas[object]) {
      return res.status(400).json(formatError('INVALID_TYPE', `sObject type '${object}' is not supported.`));
    }

    const validOps = ['insert', 'update', 'upsert', 'delete'];
    if (!operation || !validOps.includes(operation)) {
      return res.status(400).json(formatError('INVALID_FIELD',
        `operation must be one of: ${validOps.join(', ')}`));
    }

    if (operation === 'upsert' && !externalIdFieldName) {
      return res.status(400).json(formatError('INVALID_FIELD',
        'externalIdFieldName is required for upsert operation'));
    }

    const job = jobStore.create({
      object,
      operation,
      externalIdFieldName,
      contentType,
      lineEnding,
      jobType: 'V2Ingest'
    });

    console.log(`  📦 Bulk ingest job created: ${job.id} (${operation} ${object})`);
    res.status(201).json(formatJobResponse(job));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // UPLOAD CSV DATA (BATCHES)
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * PUT /services/data/:version/jobs/ingest/:jobId/batches
   *
   * Uploads CSV data to an open bulk job. Can be called multiple times
   * to upload data in chunks. The Content-Type must be text/csv.
   *
   * On multi-batch uploads, duplicate header rows are automatically stripped.
   *
   * @example
   *   // PUT /services/data/v59.0/jobs/ingest/750ABC.../batches
   *   // Content-Type: text/csv
   *   // Body: Name,Type\nAcme Corp,Customer\nBeta Inc,Partner
   *   // Response: 201 Created
   */
  app.put('/services/data/:version/jobs/ingest/:jobId/batches', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    if (job.state !== 'Open') {
      return res.status(400).json(formatError('INVALID_STATE',
        `Job is in state '${job.state}'. Data can only be uploaded when job is 'Open'.`));
    }

    const csvData = typeof req.body === 'string' ? req.body : '';
    if (!csvData) {
      return res.status(400).json(formatError('INVALID_FIELD', 'CSV data is required'));
    }

    // Handle multi-batch uploads: strip duplicate header row
    if (job.csvData) {
      const existingHeader = getCSVHeaders(job.csvData);
      const newHeader = getCSVHeaders(csvData);
      if (existingHeader === newHeader) {
        // Strip header from new chunk and append data rows only
        const firstNewline = csvData.indexOf('\n');
        if (firstNewline !== -1) {
          job.csvData += '\n' + csvData.substring(firstNewline + 1);
        }
      } else {
        job.csvData += '\n' + csvData;
      }
    } else {
      job.csvData = csvData;
    }

    jobStore.update(job.id, { csvData: job.csvData });
    console.log(`  📤 CSV data uploaded to job ${job.id} (${csvData.split('\n').length - 1} rows)`);
    res.status(201).send();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // CLOSE / ABORT JOB
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * PATCH /services/data/:version/jobs/ingest/:jobId
   *
   * Changes the job state. When state is set to 'UploadComplete',
   * the server processes all uploaded CSV data synchronously.
   *
   * Valid state transitions:
   *   Open → UploadComplete (triggers processing → JobComplete)
   *   Open → Aborted
   *   UploadComplete → Aborted
   *
   * @example
   *   // Close job and trigger processing:
   *   // PATCH /services/data/v59.0/jobs/ingest/750ABC...
   *   // Body: { "state": "UploadComplete" }
   *   // Response: { "id": "750ABC...", "state": "JobComplete", "numberRecordsProcessed": 5, ... }
   *
   * @example
   *   // Abort a job:
   *   // Body: { "state": "Aborted" }
   */
  app.patch('/services/data/:version/jobs/ingest/:jobId', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    const newState = req.body.state;

    if (newState === 'UploadComplete') {
      if (job.state !== 'Open') {
        return res.status(400).json(formatError('INVALID_STATE',
          `Cannot close job in state '${job.state}'. Job must be 'Open'.`));
      }

      // Process the job synchronously (in a real Salesforce, this is async)
      jobStore.update(job.id, { state: 'UploadComplete' });
      processIngestJob(job, schemas, database);
      jobStore.update(job.id, {
        state: job.state,
        numberRecordsProcessed: job.numberRecordsProcessed,
        numberRecordsFailed: job.numberRecordsFailed,
        totalProcessingTime: job.totalProcessingTime,
        successfulResults: job.successfulResults,
        failedResults: job.failedResults
      });

      console.log(`  ✅ Bulk job ${job.id} completed: ${job.numberRecordsProcessed} processed, ${job.numberRecordsFailed} failed`);

    } else if (newState === 'Aborted') {
      jobStore.update(job.id, { state: 'Aborted' });
      console.log(`  ⚠️  Bulk job ${job.id} aborted`);

    } else {
      return res.status(400).json(formatError('INVALID_FIELD',
        `Invalid state: '${newState}'. Must be 'UploadComplete' or 'Aborted'.`));
    }

    res.json(formatJobResponse(jobStore.get(job.id)));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // GET JOB INFO
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/jobs/ingest/:jobId
   *
   * Returns job metadata including current state, record counts, and timestamps.
   * SnapLogic polls this endpoint to check if the job is complete.
   *
   * @example
   *   // GET /services/data/v59.0/jobs/ingest/750ABC...
   *   // Response: { "id": "750ABC...", "state": "JobComplete", "numberRecordsProcessed": 5, ... }
   */
  app.get('/services/data/:version/jobs/ingest/:jobId', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }
    res.json(formatJobResponse(job));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // GET RESULTS (CSV)
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/jobs/ingest/:jobId/successfulResults
   *
   * Returns CSV of successfully processed records.
   * Each row includes sf__Id (the created/updated record ID) and sf__Created ('true'/'false').
   *
   * @example
   *   // Response (text/csv):
   *   // "sf__Id","sf__Created","Name","Type"
   *   // "001ABC...","true","Acme Corp","Customer"
   *   // "001DEF...","true","Beta Inc","Partner"
   */
  app.get('/services/data/:version/jobs/ingest/:jobId/successfulResults', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    if (job.state !== 'JobComplete' && job.state !== 'Failed') {
      return res.status(400).json(formatError('INVALID_STATE',
        'Results are only available after job processing is complete'));
    }

    res.set('Content-Type', 'text/csv');
    if (job.successfulResults.length === 0) {
      return res.send('');
    }

    const headers = Object.keys(job.successfulResults[0]);
    const { toCSV } = require('../bulk/csv-parser');
    res.send(toCSV(headers, job.successfulResults));
  });

  /**
   * GET /services/data/:version/jobs/ingest/:jobId/failedResults
   *
   * Returns CSV of failed records with error details.
   * Each row includes sf__Id and sf__Error with the failure reason.
   *
   * @example
   *   // Response (text/csv):
   *   // "sf__Id","sf__Error","Name","Type"
   *   // "","REQUIRED_FIELD_MISSING:Required fields are missing: [Name]","","Customer"
   */
  app.get('/services/data/:version/jobs/ingest/:jobId/failedResults', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    if (job.state !== 'JobComplete' && job.state !== 'Failed') {
      return res.status(400).json(formatError('INVALID_STATE',
        'Results are only available after job processing is complete'));
    }

    res.set('Content-Type', 'text/csv');
    if (job.failedResults.length === 0) {
      return res.send('');
    }

    const headers = Object.keys(job.failedResults[0]);
    const { toCSV } = require('../bulk/csv-parser');
    res.send(toCSV(headers, job.failedResults));
  });

  /**
   * GET /services/data/:version/jobs/ingest/:jobId/unprocessedrecords
   *
   * Returns CSV of unprocessed records.
   * In this mock server, all records are processed synchronously,
   * so this always returns empty (matching behavior when processing succeeds).
   *
   * @example
   *   // Response (text/csv): (empty)
   */
  app.get('/services/data/:version/jobs/ingest/:jobId/unprocessedrecords', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    res.set('Content-Type', 'text/csv');
    res.send('');
  });

  // ═══════════════════════════════════════════════════════════════════════
  // DELETE JOB
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * DELETE /services/data/:version/jobs/ingest/:jobId
   *
   * Deletes a bulk job and all its associated data.
   *
   * @example
   *   // DELETE /services/data/v59.0/jobs/ingest/750ABC...
   *   // Response: 204 No Content
   */
  app.delete('/services/data/:version/jobs/ingest/:jobId', (req, res) => {
    const job = jobStore.get(req.params.jobId);
    if (!job) {
      return res.status(404).json(formatError('NOT_FOUND', 'Job not found'));
    }

    jobStore.remove(job.id);
    console.log(`  🗑️  Bulk job ${job.id} deleted`);
    res.status(204).send();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // LIST ALL INGEST JOBS
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/jobs/ingest
   *
   * Lists all bulk ingest jobs, sorted by creation date (newest first).
   *
   * @example
   *   // GET /services/data/v59.0/jobs/ingest
   *   // Response: { "done": true, "records": [{ "id": "750ABC...", ... }, ...], "nextRecordsUrl": null }
   */
  app.get('/services/data/:version/jobs/ingest', (req, res) => {
    const jobs = jobStore.list('V2Ingest').map(formatJobResponse);
    res.json({
      done: true,
      records: jobs,
      nextRecordsUrl: null
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════
// HELPER — Format job response (strip internal fields)
// ═══════════════════════════════════════════════════════════════════════

/**
 * Formats a job object for API response, stripping internal fields
 * (csvData, result arrays) that are not part of the Salesforce API response.
 *
 * @param {Object} job - Internal job object
 * @returns {Object} Sanitized job response
 */
function formatJobResponse(job) {
  return {
    id: job.id,
    operation: job.operation,
    object: job.object,
    createdById: job.createdById,
    createdDate: job.createdDate,
    systemModstamp: job.systemModstamp,
    state: job.state,
    externalIdFieldName: job.externalIdFieldName,
    concurrencyMode: job.concurrencyMode,
    contentType: job.contentType,
    apiVersion: job.apiVersion,
    jobType: job.jobType,
    lineEnding: job.lineEnding,
    numberRecordsProcessed: job.numberRecordsProcessed,
    numberRecordsFailed: job.numberRecordsFailed,
    retries: job.retries,
    totalProcessingTime: job.totalProcessingTime
  };
}

module.exports = { registerBulkIngestRoutes };
