'use strict';

/**
 * Salesforce Bulk API v1 Routes
 * ==============================
 *
 * Implements the legacy Salesforce Bulk API v1 (XML-based) used by
 * SnapLogic's "Salesforce Create/Update/Delete" snaps when set to "Bulk API" mode.
 *
 * This is DIFFERENT from Bulk API 2.0 (which uses JSON + CSV and
 * lives under /services/data/:version/jobs/...).
 *
 * Bulk API v1 URL pattern: /services/async/{version}/job[/...]
 * XML Namespace: http://www.force.com/2009/06/asyncapi/dataload
 *
 * Routes:
 *   POST   /services/async/:version/job                           - Create job
 *   POST   /services/async/:version/job/:jobId/batch              - Add batch
 *   POST   /services/async/:version/job/:jobId                    - Close/Abort job
 *   GET    /services/async/:version/job/:jobId                    - Get job info
 *   GET    /services/async/:version/job/:jobId/batch              - List all batches
 *   GET    /services/async/:version/job/:jobId/batch/:batchId     - Get batch info
 *   GET    /services/async/:version/job/:jobId/batch/:batchId/result - Get batch results
 *
 * Job States: Open, Closed, Aborted, Failed
 * Batch States: Queued, InProgress, Completed, Failed, Not Processed
 *
 * Processing is SYNCHRONOUS — batches complete immediately when added.
 */

const { generateId } = require('../id-generator');
const { validate } = require('../validator');
const { parseCSV } = require('../bulk/csv-parser');

// XML namespace for Bulk API v1
const NS = 'http://www.force.com/2009/06/asyncapi/dataload';

// ═══════════════════════════════════════════════════════════════════════
// XML Helpers (zero-dependency — no xml2js needed)
// ═══════════════════════════════════════════════════════════════════════

/**
 * Extracts a value from an XML element.
 * Works with both <tag>value</tag> and <ns:tag>value</ns:tag>.
 *
 * @param {string} xml - XML string
 * @param {string} tag - Element name
 * @returns {string|null} Element text content, or null
 */
function xmlGet(xml, tag) {
  // Match <tag>value</tag> or <ns:tag>value</ns:tag>
  const regex = new RegExp(`<(?:[a-zA-Z0-9_]+:)?${tag}[^>]*>([^<]*)</(?:[a-zA-Z0-9_]+:)?${tag}>`, 'i');
  const match = xml.match(regex);
  return match ? match[1].trim() : null;
}

/**
 * Builds a <jobInfo> XML response.
 *
 * @param {Object} job - Job object from the job store
 * @returns {string} XML string
 */
function jobInfoXml(job) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<jobInfo xmlns="${NS}">
  <id>${job.id}</id>
  <operation>${job.operation}</operation>
  <object>${job.object}</object>
  <createdById>${job.createdById}</createdById>
  <createdDate>${job.createdDate}</createdDate>
  <systemModstamp>${job.systemModstamp}</systemModstamp>
  <state>${job.v1State}</state>
  <externalIdFieldName>${job.externalIdFieldName || ''}</externalIdFieldName>
  <concurrencyMode>${job.concurrencyMode}</concurrencyMode>
  <contentType>${job.contentType}</contentType>
  <numberBatchesQueued>${job.numberBatchesQueued || 0}</numberBatchesQueued>
  <numberBatchesInProgress>${job.numberBatchesInProgress || 0}</numberBatchesInProgress>
  <numberBatchesCompleted>${job.numberBatchesCompleted || 0}</numberBatchesCompleted>
  <numberBatchesFailed>${job.numberBatchesFailed || 0}</numberBatchesFailed>
  <numberBatchesTotal>${job.numberBatchesTotal || 0}</numberBatchesTotal>
  <numberRecordsProcessed>${job.numberRecordsProcessed || 0}</numberRecordsProcessed>
  <numberRetries>${job.retries || 0}</numberRetries>
  <apiVersion>${job.apiVersion}</apiVersion>
  <numberRecordsFailed>${job.numberRecordsFailed || 0}</numberRecordsFailed>
  <totalProcessingTime>${job.totalProcessingTime || 0}</totalProcessingTime>
  <apiActiveProcessingTime>${job.apiActiveProcessingTime || 0}</apiActiveProcessingTime>
  <apexProcessingTime>${job.apexProcessingTime || 0}</apexProcessingTime>
</jobInfo>`;
}

/**
 * Builds a <batchInfo> XML response.
 *
 * @param {Object} batch - Batch object
 * @returns {string} XML string
 */
function batchInfoXml(batch) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<batchInfo xmlns="${NS}">
  <id>${batch.id}</id>
  <jobId>${batch.jobId}</jobId>
  <state>${batch.state}</state>
  <createdDate>${batch.createdDate}</createdDate>
  <systemModstamp>${batch.systemModstamp}</systemModstamp>
  <numberRecordsProcessed>${batch.numberRecordsProcessed || 0}</numberRecordsProcessed>
  <numberRecordsFailed>${batch.numberRecordsFailed || 0}</numberRecordsFailed>
  <totalProcessingTime>${batch.totalProcessingTime || 0}</totalProcessingTime>
  <apiActiveProcessingTime>${batch.apiActiveProcessingTime || 0}</apiActiveProcessingTime>
  <apexProcessingTime>${batch.apexProcessingTime || 0}</apexProcessingTime>
</batchInfo>`;
}

/**
 * Builds an XML error response.
 *
 * @param {string} code - Error code
 * @param {string} message - Error message
 * @returns {string} XML string
 */
function errorXml(code, message) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<error xmlns="${NS}">
  <exceptionCode>${code}</exceptionCode>
  <exceptionMessage>${message}</exceptionMessage>
</error>`;
}

/**
 * Builds batch results XML for insert/update operations.
 *
 * @param {Object[]} results - Array of { id, success, created, errors }
 * @returns {string} XML string
 */
function resultsXml(results) {
  const items = results.map(r => {
    if (r.success) {
      return `  <result>
    <id>${r.id}</id>
    <success>true</success>
    <created>${r.created ? 'true' : 'false'}</created>
  </result>`;
    } else {
      return `  <result>
    <id xsi:nil="true" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"/>
    <success>false</success>
    <created>false</created>
    <errors>
      <message>${escapeXml(r.errorMessage || 'Unknown error')}</message>
      <statusCode>${r.errorCode || 'UNKNOWN_EXCEPTION'}</statusCode>
    </errors>
  </result>`;
    }
  }).join('\n');

  return `<?xml version="1.0" encoding="UTF-8"?>
<results xmlns="${NS}">
${items}
</results>`;
}

/**
 * Builds batch results as CSV (used when job contentType is CSV).
 * Real Salesforce returns: "Id","Success","Created","Error"
 *
 * @param {Object[]} results - Array of { id, success, created, errorMessage }
 * @returns {string} CSV string
 */
function resultsCsv(results) {
  const rows = ['"Id","Success","Created","Error"'];
  for (const r of results) {
    const id = r.id || '';
    const success = r.success ? 'true' : 'false';
    const created = r.created ? 'true' : 'false';
    const error = r.errorMessage || '';
    rows.push(`"${id}","${success}","${created}","${escapeCsvField(error)}"`);
  }
  return rows.join('\n');
}

/**
 * Escape a CSV field value (double quotes inside the value).
 */
function escapeCsvField(str) {
  return String(str).replace(/"/g, '""');
}

/**
 * Escape special XML characters.
 */
function escapeXml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

// ═══════════════════════════════════════════════════════════════════════
// Route Registration
// ═══════════════════════════════════════════════════════════════════════

/**
 * Registers all Bulk API v1 route handlers.
 *
 * @param {Object} app - Express app instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @param {Object} config - Server configuration
 * @param {Object} jobStore - Bulk job store instance (shared with v2)
 */
function registerBulkV1Routes(app, schemas, database, config, jobStore) {

  // ─────────────────────────────────────────────────────────────────────
  // CREATE JOB
  // ─────────────────────────────────────────────────────────────────────

  /**
   * POST /services/async/:version/job
   *
   * Creates a new Bulk API v1 job. Accepts XML body with operation, object, contentType.
   */
  app.post('/services/async/:version/job', (req, res) => {
    const xml = req.body || '';
    const operation = xmlGet(xml, 'operation');
    const object = xmlGet(xml, 'object');
    const contentType = xmlGet(xml, 'contentType') || 'CSV';
    const externalIdFieldName = xmlGet(xml, 'externalIdFieldName');
    const version = req.params.version;

    if (!operation) {
      return res.status(400).type('application/xml').send(
        errorXml('InvalidJob', 'operation is required'));
    }

    if (!object) {
      return res.status(400).type('application/xml').send(
        errorXml('InvalidJob', 'object is required'));
    }

    if (!schemas[object]) {
      return res.status(400).type('application/xml').send(
        errorXml('InvalidJob', `sObject type '${object}' is not supported.`));
    }

    const job = jobStore.create({
      object,
      operation,
      jobType: 'V1Bulk',
      contentType,
      externalIdFieldName: externalIdFieldName || null
    });

    // Add v1-specific fields
    jobStore.update(job.id, {
      v1State: 'Open',
      apiVersion: parseFloat(version) || 52.0,
      batches: [],
      numberBatchesQueued: 0,
      numberBatchesInProgress: 0,
      numberBatchesCompleted: 0,
      numberBatchesFailed: 0,
      numberBatchesTotal: 0,
      apiActiveProcessingTime: 0,
      apexProcessingTime: 0
    });

    console.log(`  📦 Bulk v1: Created ${operation} job ${job.id} for ${object} (${contentType})`);

    res.status(201).type('application/xml').send(jobInfoXml(jobStore.get(job.id)));
  });

  // ─────────────────────────────────────────────────────────────────────
  // ADD BATCH
  // ─────────────────────────────────────────────────────────────────────

  /**
   * POST /services/async/:version/job/:jobId/batch
   *
   * Adds a batch of data to an open job. Data format depends on job's contentType.
   * For CSV: raw CSV text. For XML: <sObjects> wrapper.
   * Processing is synchronous — batch completes immediately.
   */
  app.post('/services/async/:version/job/:jobId/batch', (req, res) => {
    const job = jobStore.get(req.params.jobId);

    if (!job) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidJob', `Job not found: ${req.params.jobId}`));
    }

    if (job.v1State !== 'Open') {
      return res.status(400).type('application/xml').send(
        errorXml('InvalidJobState', `Job ${job.id} is not open. Current state: ${job.v1State}`));
    }

    const rawData = req.body || '';
    const schema = schemas[job.object];
    const batchId = generateId('751');
    const now = new Date().toISOString();

    // Parse the batch data
    let records = [];
    try {
      if (job.contentType === 'CSV' || job.contentType === 'ZIP_CSV') {
        records = parseCSV(rawData);
      } else if (job.contentType === 'XML' || job.contentType === 'ZIP_XML') {
        records = parseXmlSObjects(rawData);
      } else if (job.contentType === 'JSON' || job.contentType === 'ZIP_JSON') {
        records = Array.isArray(JSON.parse(rawData)) ? JSON.parse(rawData) : [JSON.parse(rawData)];
      }
    } catch (err) {
      // Batch failed to parse
      const batch = {
        id: batchId,
        jobId: job.id,
        state: 'Failed',
        stateMessage: `Failed to parse batch data: ${err.message}`,
        createdDate: now,
        systemModstamp: now,
        numberRecordsProcessed: 0,
        numberRecordsFailed: 0,
        totalProcessingTime: 0,
        apiActiveProcessingTime: 0,
        apexProcessingTime: 0,
        results: []
      };

      job.batches.push(batch);
      jobStore.update(job.id, {
        numberBatchesFailed: (job.numberBatchesFailed || 0) + 1,
        numberBatchesTotal: (job.numberBatchesTotal || 0) + 1
      });

      console.log(`  ❌ Bulk v1: Batch ${batchId} failed to parse: ${err.message}`);
      return res.status(201).type('application/xml').send(batchInfoXml(batch));
    }

    // Process the records synchronously
    const results = [];
    let processed = 0;
    let failed = 0;

    for (const record of records) {
      try {
        if (job.operation === 'insert') {
          const errors = validate(record, schema, 'create');
          if (errors.length > 0) {
            results.push({
              success: false,
              created: false,
              errorCode: errors[0].errorCode || 'VALIDATION_ERROR',
              errorMessage: errors[0].message || 'Validation failed'
            });
            failed++;
          } else {
            const id = generateId(schema.idPrefix);
            const newRecord = {
              Id: id,
              ...record,
              CreatedDate: now,
              LastModifiedDate: now,
              SystemModstamp: now,
              attributes: {
                type: job.object,
                url: `/services/data/v${job.apiVersion}/sobjects/${job.object}/${id}`
              }
            };
            database[job.object].push(newRecord);
            results.push({ id, success: true, created: true });
          }
        } else if (job.operation === 'update') {
          const recordId = record.Id || record.id;
          if (!recordId) {
            results.push({
              success: false, created: false,
              errorCode: 'MISSING_ARGUMENT',
              errorMessage: 'Id field is required for update'
            });
            failed++;
            continue;
          }
          const existing = database[job.object].find(r => r.Id === recordId);
          if (!existing) {
            results.push({
              success: false, created: false,
              errorCode: 'ENTITY_IS_DELETED',
              errorMessage: `Record not found: ${recordId}`
            });
            failed++;
          } else {
            const updateData = { ...record };
            delete updateData.Id;
            delete updateData.id;
            Object.assign(existing, updateData, {
              LastModifiedDate: now,
              SystemModstamp: now
            });
            results.push({ id: recordId, success: true, created: false });
          }
        } else if (job.operation === 'upsert') {
          const extField = job.externalIdFieldName || 'Id';
          const extValue = record[extField];
          const existing = database[job.object].find(r => String(r[extField]) === String(extValue));

          if (existing) {
            const updateData = { ...record };
            delete updateData[extField];
            Object.assign(existing, updateData, {
              LastModifiedDate: now,
              SystemModstamp: now
            });
            results.push({ id: existing.Id, success: true, created: false });
          } else {
            const errors = validate(record, schema, 'create');
            if (errors.length > 0) {
              results.push({
                success: false, created: false,
                errorCode: errors[0].errorCode || 'VALIDATION_ERROR',
                errorMessage: errors[0].message || 'Validation failed'
              });
              failed++;
            } else {
              const id = generateId(schema.idPrefix);
              const newRecord = {
                Id: id, ...record,
                CreatedDate: now, LastModifiedDate: now, SystemModstamp: now,
                attributes: { type: job.object, url: `/services/data/v${job.apiVersion}/sobjects/${job.object}/${id}` }
              };
              database[job.object].push(newRecord);
              results.push({ id, success: true, created: true });
            }
          }
        } else if (job.operation === 'delete') {
          const recordId = record.Id || record.id;
          if (!recordId) {
            results.push({
              success: false, created: false,
              errorCode: 'MISSING_ARGUMENT',
              errorMessage: 'Id field is required for delete'
            });
            failed++;
            continue;
          }
          const idx = database[job.object].findIndex(r => r.Id === recordId);
          if (idx === -1) {
            results.push({
              success: false, created: false,
              errorCode: 'ENTITY_IS_DELETED',
              errorMessage: `Record not found: ${recordId}`
            });
            failed++;
          } else {
            database[job.object].splice(idx, 1);
            results.push({ id: recordId, success: true, created: false });
          }
        }
        processed++;
      } catch (err) {
        results.push({
          success: false, created: false,
          errorCode: 'UNKNOWN_EXCEPTION',
          errorMessage: err.message
        });
        failed++;
        processed++;
      }
    }

    const batch = {
      id: batchId,
      jobId: job.id,
      state: failed === records.length ? 'Failed' : 'Completed',
      createdDate: now,
      systemModstamp: now,
      numberRecordsProcessed: processed,
      numberRecordsFailed: failed,
      totalProcessingTime: 10,
      apiActiveProcessingTime: 5,
      apexProcessingTime: 2,
      results
    };

    job.batches.push(batch);
    jobStore.update(job.id, {
      numberBatchesCompleted: (job.numberBatchesCompleted || 0) + (batch.state === 'Completed' ? 1 : 0),
      numberBatchesFailed: (job.numberBatchesFailed || 0) + (batch.state === 'Failed' ? 1 : 0),
      numberBatchesTotal: (job.numberBatchesTotal || 0) + 1,
      numberRecordsProcessed: (job.numberRecordsProcessed || 0) + processed,
      numberRecordsFailed: (job.numberRecordsFailed || 0) + failed
    });

    console.log(`  📦 Bulk v1: Batch ${batchId} — ${processed} processed, ${failed} failed (${job.operation} ${job.object})`);

    res.status(201).type('application/xml').send(batchInfoXml(batch));
  });

  // ─────────────────────────────────────────────────────────────────────
  // CLOSE / ABORT JOB
  // ─────────────────────────────────────────────────────────────────────

  /**
   * POST /services/async/:version/job/:jobId
   *
   * Closes or aborts a job. Accepts XML body with <state>Closed</state>
   * or <state>Aborted</state>.
   */
  app.post('/services/async/:version/job/:jobId', (req, res) => {
    const job = jobStore.get(req.params.jobId);

    if (!job) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidJob', `Job not found: ${req.params.jobId}`));
    }

    const xml = req.body || '';
    const newState = xmlGet(xml, 'state');

    if (newState === 'Closed') {
      jobStore.update(job.id, { v1State: 'Closed' });
      console.log(`  📦 Bulk v1: Job ${job.id} closed`);
    } else if (newState === 'Aborted') {
      jobStore.update(job.id, { v1State: 'Aborted' });
      // Mark queued/in-progress batches as "Not Processed"
      for (const batch of (job.batches || [])) {
        if (batch.state === 'Queued' || batch.state === 'InProgress') {
          batch.state = 'Not Processed';
        }
      }
      console.log(`  📦 Bulk v1: Job ${job.id} aborted`);
    } else {
      return res.status(400).type('application/xml').send(
        errorXml('InvalidJobState', `Invalid state: ${newState}. Use 'Closed' or 'Aborted'.`));
    }

    res.type('application/xml').send(jobInfoXml(jobStore.get(job.id)));
  });

  // ─────────────────────────────────────────────────────────────────────
  // GET JOB INFO
  // ─────────────────────────────────────────────────────────────────────

  /**
   * GET /services/async/:version/job/:jobId
   *
   * Returns job status and metadata as XML.
   */
  app.get('/services/async/:version/job/:jobId', (req, res) => {
    const job = jobStore.get(req.params.jobId);

    if (!job) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidJob', `Job not found: ${req.params.jobId}`));
    }

    res.type('application/xml').send(jobInfoXml(job));
  });

  // ─────────────────────────────────────────────────────────────────────
  // LIST ALL BATCHES
  // ─────────────────────────────────────────────────────────────────────

  /**
   * GET /services/async/:version/job/:jobId/batch
   *
   * Returns all batches for a job as XML.
   */
  app.get('/services/async/:version/job/:jobId/batch', (req, res) => {
    const job = jobStore.get(req.params.jobId);

    if (!job) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidJob', `Job not found: ${req.params.jobId}`));
    }

    const batches = (job.batches || []).map(b =>
      `<batchInfo>
    <id>${b.id}</id>
    <jobId>${b.jobId}</jobId>
    <state>${b.state}</state>
    <createdDate>${b.createdDate}</createdDate>
    <systemModstamp>${b.systemModstamp}</systemModstamp>
    <numberRecordsProcessed>${b.numberRecordsProcessed || 0}</numberRecordsProcessed>
    <numberRecordsFailed>${b.numberRecordsFailed || 0}</numberRecordsFailed>
    <totalProcessingTime>${b.totalProcessingTime || 0}</totalProcessingTime>
    <apiActiveProcessingTime>${b.apiActiveProcessingTime || 0}</apiActiveProcessingTime>
    <apexProcessingTime>${b.apexProcessingTime || 0}</apexProcessingTime>
  </batchInfo>`
    ).join('\n  ');

    res.type('application/xml').send(`<?xml version="1.0" encoding="UTF-8"?>
<batchInfoList xmlns="${NS}">
  ${batches}
</batchInfoList>`);
  });

  // ─────────────────────────────────────────────────────────────────────
  // GET SINGLE BATCH INFO
  // ─────────────────────────────────────────────────────────────────────

  /**
   * GET /services/async/:version/job/:jobId/batch/:batchId
   *
   * Returns status of a specific batch.
   */
  app.get('/services/async/:version/job/:jobId/batch/:batchId', (req, res) => {
    const job = jobStore.get(req.params.jobId);

    if (!job) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidJob', `Job not found: ${req.params.jobId}`));
    }

    const batch = (job.batches || []).find(b => b.id === req.params.batchId);

    if (!batch) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidBatch', `Batch not found: ${req.params.batchId}`));
    }

    res.type('application/xml').send(batchInfoXml(batch));
  });

  // ─────────────────────────────────────────────────────────────────────
  // GET BATCH RESULTS
  // ─────────────────────────────────────────────────────────────────────

  /**
   * GET /services/async/:version/job/:jobId/batch/:batchId/result
   *
   * Returns results for a completed batch.
   * For insert/update/upsert/delete: returns XML with per-record results.
   * For query: returns list of result IDs.
   */
  app.get('/services/async/:version/job/:jobId/batch/:batchId/result', (req, res) => {
    const job = jobStore.get(req.params.jobId);

    if (!job) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidJob', `Job not found: ${req.params.jobId}`));
    }

    const batch = (job.batches || []).find(b => b.id === req.params.batchId);

    if (!batch) {
      return res.status(404).type('application/xml').send(
        errorXml('InvalidBatch', `Batch not found: ${req.params.batchId}`));
    }

    if (batch.state !== 'Completed' && batch.state !== 'Failed') {
      return res.status(400).type('application/xml').send(
        errorXml('InvalidBatchState', `Batch ${batch.id} is not complete. State: ${batch.state}`));
    }

    // Return results in the format matching the job's contentType
    // Real Salesforce returns CSV results when contentType=CSV, XML when contentType=XML
    if (job.contentType === 'CSV' || job.contentType === 'ZIP_CSV') {
      res.type('text/csv').send(resultsCsv(batch.results || []));
    } else {
      res.type('application/xml').send(resultsXml(batch.results || []));
    }
  });
}

// ═══════════════════════════════════════════════════════════════════════
// XML Data Parser (for XML contentType batches)
// ═══════════════════════════════════════════════════════════════════════

/**
 * Parses <sObjects><sObject>...</sObject></sObjects> XML into an array of objects.
 * Simple regex-based parser (no external XML library needed).
 *
 * @param {string} xml - XML string with <sObjects> wrapper
 * @returns {Object[]} Array of record objects
 */
function parseXmlSObjects(xml) {
  const records = [];
  // Match each <sObject>...</sObject> block
  const sObjectRegex = /<sObject[^>]*>([\s\S]*?)<\/sObject>/gi;
  let match;

  while ((match = sObjectRegex.exec(xml)) !== null) {
    const block = match[1];
    const record = {};
    // Match each field: <FieldName>value</FieldName>
    const fieldRegex = /<([a-zA-Z_][a-zA-Z0-9_]*)>([^<]*)<\/\1>/g;
    let fieldMatch;
    while ((fieldMatch = fieldRegex.exec(block)) !== null) {
      record[fieldMatch[1]] = fieldMatch[2].trim();
    }
    if (Object.keys(record).length > 0) {
      records.push(record);
    }
  }

  return records;
}

module.exports = { registerBulkV1Routes };
