'use strict';

/**
 * Bulk Job Store
 * ===============
 *
 * In-memory storage for Salesforce Bulk API 2.0 job state.
 * Analogous to the `database{}` object used for REST API records,
 * but tracks bulk job lifecycle (create -> upload -> process -> complete).
 *
 * Uses factory function pattern (not a class) to stay consistent with
 * the project's functional style (see parseSOQL(), validate(), formatError()).
 *
 * Salesforce Bulk API 2.0 Job States:
 *   Open            → Job created, accepting data uploads
 *   UploadComplete  → All data uploaded, ready for processing
 *   InProgress      → Server is processing the records
 *   JobComplete     → All records processed successfully
 *   Failed          → Job failed due to an error
 *   Aborted         → Job was manually aborted
 *
 * Job Types:
 *   V2Ingest  → Bulk write operations (insert, update, upsert, delete)
 *   V2Query   → Bulk read operations (SOQL query returning CSV)
 */

const { generateId } = require('../id-generator');

/**
 * Creates a new bulk job store instance.
 *
 * Returns an object with methods to manage bulk jobs.
 * Each job is stored in an internal Map keyed by job ID.
 *
 * @returns {Object} Job store with create, get, update, delete, list, listAll, clear methods
 *
 * @example
 *   const jobStore = createJobStore();
 *
 *   // Create an ingest job:
 *   const job = jobStore.create({
 *     object: 'Account',
 *     operation: 'insert',
 *     jobType: 'V2Ingest'
 *   });
 *   // job.id = '750ABC...' (Salesforce-style ID with 750 prefix)
 *   // job.state = 'Open'
 *
 *   // Update job state:
 *   jobStore.update(job.id, { state: 'UploadComplete' });
 *
 *   // List all ingest jobs:
 *   jobStore.list('V2Ingest');
 *   // Returns: [{ id: '750ABC...', state: 'UploadComplete', ... }]
 */
function createJobStore() {
  // Internal storage: Map of jobId -> job object
  const jobs = new Map();

  return {
    /**
     * Creates a new bulk job and stores it.
     *
     * @param {Object} params - Job parameters
     * @param {string} params.object - Salesforce object name (e.g., 'Account')
     * @param {string} params.operation - Operation type: 'insert', 'update', 'upsert', 'delete', 'query'
     * @param {string} params.jobType - Job type: 'V2Ingest' or 'V2Query'
     * @param {string} [params.externalIdFieldName] - External ID field for upsert operations
     * @param {string} [params.query] - SOQL query for V2Query jobs
     * @param {string} [params.contentType] - Content type: 'CSV' (default)
     * @param {string} [params.lineEnding] - Line ending: 'LF' or 'CRLF' (default: 'LF')
     * @returns {Object} The created job object
     *
     * @example
     *   // Create an insert job:
     *   create({ object: 'Account', operation: 'insert', jobType: 'V2Ingest' });
     *
     * @example
     *   // Create an upsert job:
     *   create({ object: 'Account', operation: 'upsert', jobType: 'V2Ingest', externalIdFieldName: 'ExternalId__c' });
     *
     * @example
     *   // Create a query job:
     *   create({ object: 'Account', operation: 'query', jobType: 'V2Query', query: 'SELECT Id, Name FROM Account' });
     */
    create(params) {
      const id = generateId('750'); // 750 = Salesforce prefix for async/bulk jobs
      const now = new Date().toISOString();
      const job = {
        id,
        object: params.object,
        operation: params.operation,
        jobType: params.jobType || 'V2Ingest',
        state: 'Open',
        contentType: params.contentType || 'CSV',
        lineEnding: params.lineEnding || 'LF',
        externalIdFieldName: params.externalIdFieldName || null,
        query: params.query || null,
        // Data storage (internal, not exposed in API responses)
        csvData: '',
        successfulResults: [],
        failedResults: [],
        unprocessedRecords: [],
        queryResults: '',
        // Counters
        numberRecordsProcessed: 0,
        numberRecordsFailed: 0,
        // Timestamps
        createdDate: now,
        systemModstamp: now,
        createdById: '005000000000000AAA',
        apiVersion: 59.0,
        concurrencyMode: 'Parallel',
        retries: 0,
        totalProcessingTime: 0
      };
      jobs.set(id, job);
      return job;
    },

    /**
     * Retrieves a job by ID.
     *
     * @param {string} id - The bulk job ID
     * @returns {Object|null} The job object, or null if not found
     *
     * @example
     *   const job = get('750ABC...');
     *   // Returns: { id: '750ABC...', state: 'Open', ... } or null
     */
    get(id) {
      return jobs.get(id) || null;
    },

    /**
     * Updates a job with new property values.
     *
     * @param {string} id - The bulk job ID
     * @param {Object} updates - Properties to merge into the job
     * @returns {Object|null} The updated job, or null if not found
     *
     * @example
     *   update('750ABC...', { state: 'JobComplete', numberRecordsProcessed: 100 });
     */
    update(id, updates) {
      const job = jobs.get(id);
      if (!job) return null;
      Object.assign(job, updates, { systemModstamp: new Date().toISOString() });
      return job;
    },

    /**
     * Deletes a job from the store.
     *
     * @param {string} id - The bulk job ID
     * @returns {boolean} true if the job was found and deleted
     *
     * @example
     *   remove('750ABC...'); // Returns: true
     */
    remove(id) {
      return jobs.delete(id);
    },

    /**
     * Lists all jobs of a specific type, sorted by creation date (newest first).
     *
     * @param {string} jobType - 'V2Ingest' or 'V2Query'
     * @returns {Object[]} Array of job objects matching the type
     *
     * @example
     *   list('V2Ingest');
     *   // Returns: [{ id: '750ABC...', jobType: 'V2Ingest', ... }, ...]
     */
    list(jobType) {
      return Array.from(jobs.values())
        .filter(j => j.jobType === jobType)
        .sort((a, b) => new Date(b.createdDate) - new Date(a.createdDate));
    },

    /**
     * Lists all jobs (all types) — used by admin endpoint.
     *
     * @returns {Object} { count, jobs }
     *
     * @example
     *   listAll();
     *   // Returns: { count: 5, jobs: [...] }
     */
    listAll() {
      const allJobs = Array.from(jobs.values());
      return { count: allJobs.length, jobs: allJobs };
    },

    /**
     * Clears all jobs from the store. Used by POST /__admin/reset.
     *
     * @returns {number} Number of jobs cleared
     *
     * @example
     *   clear(); // Returns: 5 (number of jobs removed)
     */
    clear() {
      const count = jobs.size;
      jobs.clear();
      return count;
    }
  };
}

module.exports = { createJobStore };
