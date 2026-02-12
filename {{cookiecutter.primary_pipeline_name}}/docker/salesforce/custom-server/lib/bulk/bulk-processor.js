'use strict';

/**
 * Bulk Job Processor
 * ===================
 *
 * Core processing logic for Salesforce Bulk API 2.0 jobs.
 * Processes bulk jobs against the SAME in-memory database that REST API uses,
 * so records created via Bulk API are queryable via REST API (and vice versa).
 *
 * Two main functions:
 *   - processIngestJob() — Processes insert/update/upsert/delete from CSV data
 *   - processQueryJob()  — Executes SOQL query and returns results as CSV
 *
 * Reuses existing modules:
 *   - id-generator.js  — Generate Salesforce-style IDs for new records
 *   - validator.js      — Validate each CSV record against schema
 *   - soql-parser.js    — Parse SOQL for query jobs
 *   - csv-parser.js     — Parse/serialize CSV data
 */

const { generateId } = require('../id-generator');
const { validate } = require('../validator');
const { parseSOQL, applyWhere, applyOrderBy } = require('../soql-parser');
const { parseCSV, toCSV } = require('./csv-parser');

/**
 * Processes a bulk ingest job (insert, update, upsert, or delete).
 *
 * Parses the job's CSV data into records, then processes each record
 * according to the job's operation type. Results are stored in
 * job.successfulResults and job.failedResults arrays.
 *
 * Each record is processed independently — a failure in one record
 * does not affect others (matching real Salesforce behavior).
 *
 * @param {Object} job - The bulk job object from job-store
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records (shared with REST API)
 * @returns {Object} The updated job with results populated
 *
 * @example
 *   // Process a bulk insert job:
 *   // job.csvData = 'Name,Type\nAcme Corp,Customer\nBeta Inc,Partner'
 *   // job.operation = 'insert'
 *   // job.object = 'Account'
 *   processIngestJob(job, schemas, database);
 *   // After processing:
 *   //   job.state = 'JobComplete'
 *   //   job.numberRecordsProcessed = 2
 *   //   job.successfulResults = [
 *   //     { sf__Id: '001ABC...', sf__Created: 'true', Name: 'Acme Corp', Type: 'Customer' },
 *   //     { sf__Id: '001DEF...', sf__Created: 'true', Name: 'Beta Inc', Type: 'Partner' }
 *   //   ]
 *   //   database['Account'] now has 2 new records (also visible via REST API!)
 *
 * @example
 *   // Validation failure — record added to failedResults:
 *   // CSV row missing required field "Name"
 *   //   job.failedResults = [
 *   //     { sf__Id: '', sf__Error: 'REQUIRED_FIELD_MISSING:Required fields are missing: [Name]', Type: 'Customer' }
 *   //   ]
 */
function processIngestJob(job, schemas, database) {
  const schema = schemas[job.object];
  if (!schema) {
    job.state = 'Failed';
    job.failedResults = [];
    job.numberRecordsFailed = 0;
    return job;
  }

  // Initialize database array if it doesn't exist for this object
  if (!database[job.object]) {
    database[job.object] = [];
  }

  const records = parseCSV(job.csvData);
  job.state = 'InProgress';
  job.successfulResults = [];
  job.failedResults = [];

  const startTime = Date.now();

  for (const record of records) {
    try {
      switch (job.operation) {
        case 'insert':
          processInsert(record, schema, database[job.object], job);
          break;
        case 'update':
          processUpdate(record, schema, database[job.object], job);
          break;
        case 'upsert':
          processUpsert(record, schema, database[job.object], job);
          break;
        case 'delete':
          processDelete(record, database[job.object], job);
          break;
        default:
          job.failedResults.push({
            sf__Id: '',
            sf__Error: `INVALID_OPERATION:Unsupported operation: ${job.operation}`,
            ...record
          });
          job.numberRecordsFailed++;
      }
    } catch (err) {
      job.failedResults.push({
        sf__Id: record.Id || '',
        sf__Error: `UNKNOWN_EXCEPTION:${err.message}`,
        ...record
      });
      job.numberRecordsFailed++;
    }
  }

  job.totalProcessingTime = Date.now() - startTime;
  job.state = job.numberRecordsFailed > 0 && job.numberRecordsProcessed === 0
    ? 'Failed'
    : 'JobComplete';

  console.log(`  📦 Bulk ${job.operation}: ${job.numberRecordsProcessed} success, ${job.numberRecordsFailed} failed for ${job.object}`);

  return job;
}

/**
 * Processes a bulk query job.
 *
 * Parses the job's SOQL query using the existing soql-parser module,
 * executes it against the in-memory database, and serializes the results
 * as CSV stored in job.queryResults.
 *
 * @param {Object} job - The bulk job object from job-store
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @returns {Object} The updated job with queryResults populated
 *
 * @example
 *   // Process a bulk query job:
 *   // job.query = 'SELECT Id, Name, Type FROM Account WHERE Type = \'Customer\''
 *   processQueryJob(job, schemas, database);
 *   // After processing:
 *   //   job.state = 'JobComplete'
 *   //   job.queryResults = 'Id,Name,Type\n001ABC...,Acme Corp,Customer\n001DEF...,Beta Inc,Customer'
 *   //   job.numberRecordsProcessed = 2
 */
function processQueryJob(job, schemas, database) {
  try {
    const parsed = parseSOQL(job.query);

    if (!parsed.object || !schemas[parsed.object]) {
      job.state = 'Failed';
      job.numberRecordsFailed = 1;
      return job;
    }

    let records = [...(database[parsed.object] || [])];

    // Apply WHERE filters
    if (parsed.where && parsed.where.length > 0) {
      records = applyWhere(records, parsed.where);
    }

    // Apply ORDER BY
    if (parsed.orderBy) {
      records = applyOrderBy(records, parsed.orderBy);
    }

    // Apply OFFSET
    if (parsed.offset) {
      records = records.slice(parsed.offset);
    }

    // Apply LIMIT
    if (parsed.limit) {
      records = records.slice(0, parsed.limit);
    }

    // Determine which fields to include
    let headers;
    if (parsed.fields.includes('*')) {
      // All fields — get from first record or schema
      if (records.length > 0) {
        headers = Object.keys(records[0]).filter(k => k !== 'attributes');
      } else {
        headers = ['Id', ...Object.keys(schemas[parsed.object].fields)];
      }
    } else {
      headers = parsed.fields;
    }

    // Project only the selected fields
    const projected = records.map(record => {
      const row = {};
      for (const field of headers) {
        row[field] = record[field] !== undefined ? record[field] : '';
      }
      return row;
    });

    // Serialize to CSV
    job.queryResults = toCSV(headers, projected);
    job.numberRecordsProcessed = projected.length;
    job.state = 'JobComplete';

    console.log(`  🔍 Bulk query: ${projected.length} records from ${parsed.object}`);

  } catch (err) {
    job.state = 'Failed';
    job.numberRecordsFailed = 1;
    console.error(`  ❌ Bulk query failed: ${err.message}`);
  }

  return job;
}

// ═══════════════════════════════════════════════════════════════════════
// INTERNAL HELPERS — Individual record operations
// ═══════════════════════════════════════════════════════════════════════

/**
 * Processes a single INSERT record from bulk CSV data.
 * Validates, generates ID, and adds to the database.
 *
 * @param {Object} record - The parsed CSV record (field name -> value)
 * @param {Object} schema - The object schema
 * @param {Object[]} collection - The database array for this object
 * @param {Object} job - The job object (to track results)
 */
function processInsert(record, schema, collection, job) {
  const errors = validate(record, schema, 'create');
  if (errors.length > 0) {
    job.failedResults.push({
      sf__Id: '',
      sf__Error: errors.map(e => `${e.errorCode}:${e.message}`).join('; '),
      ...record
    });
    job.numberRecordsFailed++;
    return;
  }

  const id = generateId(schema.idPrefix);
  const newRecord = {
    Id: id,
    ...record,
    CreatedDate: new Date().toISOString(),
    LastModifiedDate: new Date().toISOString(),
    SystemModstamp: new Date().toISOString(),
    attributes: { type: schema.name }
  };

  collection.push(newRecord);
  job.successfulResults.push({ sf__Id: id, sf__Created: 'true', ...record });
  job.numberRecordsProcessed++;
}

/**
 * Processes a single UPDATE record from bulk CSV data.
 * Finds existing record by Id, validates, and merges changes.
 *
 * @param {Object} record - The parsed CSV record (must include Id field)
 * @param {Object} schema - The object schema
 * @param {Object[]} collection - The database array for this object
 * @param {Object} job - The job object (to track results)
 */
function processUpdate(record, schema, collection, job) {
  const recordId = record.Id;
  if (!recordId) {
    job.failedResults.push({
      sf__Id: '',
      sf__Error: 'MISSING_ARGUMENT:Id is required for update operation',
      ...record
    });
    job.numberRecordsFailed++;
    return;
  }

  const index = collection.findIndex(r => r.Id === recordId);
  if (index === -1) {
    job.failedResults.push({
      sf__Id: recordId,
      sf__Error: `INVALID_CROSS_REFERENCE_KEY:Record not found: ${recordId}`,
      ...record
    });
    job.numberRecordsFailed++;
    return;
  }

  // Validate fields (without required check — it's an update)
  const updateFields = { ...record };
  delete updateFields.Id; // Don't validate Id as a field to update
  const errors = validate(updateFields, schema, 'update');
  if (errors.length > 0) {
    job.failedResults.push({
      sf__Id: recordId,
      sf__Error: errors.map(e => `${e.errorCode}:${e.message}`).join('; '),
      ...record
    });
    job.numberRecordsFailed++;
    return;
  }

  Object.assign(collection[index], updateFields, {
    LastModifiedDate: new Date().toISOString(),
    SystemModstamp: new Date().toISOString()
  });

  job.successfulResults.push({ sf__Id: recordId, sf__Created: 'false', ...record });
  job.numberRecordsProcessed++;
}

/**
 * Processes a single UPSERT record from bulk CSV data.
 * Finds by external ID field — updates if found, inserts if not.
 *
 * @param {Object} record - The parsed CSV record
 * @param {Object} schema - The object schema
 * @param {Object[]} collection - The database array for this object
 * @param {Object} job - The job object (to track results, must have externalIdFieldName)
 */
function processUpsert(record, schema, collection, job) {
  const extIdField = job.externalIdFieldName || 'Id';
  const extIdValue = record[extIdField];

  if (!extIdValue) {
    // No external ID value — treat as insert
    processInsert(record, schema, collection, job);
    return;
  }

  const existingIndex = collection.findIndex(r => String(r[extIdField]) === String(extIdValue));

  if (existingIndex !== -1) {
    // Found — update existing record
    const updateFields = { ...record };
    delete updateFields[extIdField]; // Don't update the key field itself

    Object.assign(collection[existingIndex], updateFields, {
      LastModifiedDate: new Date().toISOString(),
      SystemModstamp: new Date().toISOString()
    });

    job.successfulResults.push({ sf__Id: collection[existingIndex].Id, sf__Created: 'false', ...record });
    job.numberRecordsProcessed++;
  } else {
    // Not found — insert new record
    processInsert(record, schema, collection, job);
  }
}

/**
 * Processes a single DELETE record from bulk CSV data.
 * Finds by Id and removes from the database.
 *
 * @param {Object} record - The parsed CSV record (must include Id field)
 * @param {Object[]} collection - The database array for this object
 * @param {Object} job - The job object (to track results)
 */
function processDelete(record, collection, job) {
  const recordId = record.Id;
  if (!recordId) {
    job.failedResults.push({
      sf__Id: '',
      sf__Error: 'MISSING_ARGUMENT:Id is required for delete operation',
      ...record
    });
    job.numberRecordsFailed++;
    return;
  }

  const index = collection.findIndex(r => r.Id === recordId);
  if (index === -1) {
    job.failedResults.push({
      sf__Id: recordId,
      sf__Error: `ENTITY_IS_DELETED:Entity is deleted or does not exist: ${recordId}`,
      ...record
    });
    job.numberRecordsFailed++;
    return;
  }

  collection.splice(index, 1);
  job.successfulResults.push({ sf__Id: recordId, sf__Created: 'false' });
  job.numberRecordsProcessed++;
}

module.exports = { processIngestJob, processQueryJob };
