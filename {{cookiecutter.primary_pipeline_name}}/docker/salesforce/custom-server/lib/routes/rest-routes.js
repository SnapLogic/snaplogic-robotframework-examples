'use strict';

/**
 * Salesforce REST API Routes
 * ==========================
 *
 * All Express route handlers for the Salesforce REST API (single-record operations).
 * No object-specific code — the :object URL parameter + schema files
 * handle everything dynamically.
 *
 * Routes:
 *   POST   /services/oauth2/token                              - OAuth mock
 *   GET    /services/data/:version/sobjects/:object/describe   - Describe
 *   POST   /services/data/:version/sobjects/:object            - Create
 *   GET    /services/data/:version/sobjects/:object/:id        - Read
 *   PATCH  /services/data/:version/sobjects/:object/:id        - Update
 *   DELETE /services/data/:version/sobjects/:object/:id        - Delete
 *   PATCH  /services/data/:version/sobjects/:object/:ext/:val  - Upsert
 *   GET    /services/data/:version/query                       - SOQL Query
 *   GET    /services/data/:version/limits                      - API Limits
 *
 * These are the standard Salesforce REST API endpoints that SnapLogic
 * Salesforce snaps (Create, Read, Update, Delete, SOQL) use when
 * configured with "REST API" (not "Bulk API").
 */

const { generateId } = require('../id-generator');
const { formatError } = require('../error-formatter');
const { validate } = require('../validator');
const { parseSOQL, applyWhere, applyOrderBy } = require('../soql-parser');

/**
 * Registers all Salesforce REST API route handlers on the Express app.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition (loaded from schemas/*.json)
 * @param {Object} database - Map of object name -> array of records (in-memory storage)
 * @param {Object} config - Server configuration { HTTP_PORT, HTTPS_PORT }
 *
 * @example
 *   registerRestRoutes(app, schemas, database, { HTTP_PORT: 8080, HTTPS_PORT: 8443 });
 */
function registerRestRoutes(app, schemas, database, config) {
  const { HTTP_PORT, HTTPS_PORT } = config;

  // ═══════════════════════════════════════════════════════════════════════
  // OAUTH ENDPOINT (Mock)
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * POST /services/oauth2/token
   *
   * Mock Salesforce OAuth2 token endpoint.
   * Accepts ANY credentials and returns a valid-looking token.
   * This is the first call every SnapLogic Salesforce snap makes.
   *
   * @example
   *   // POST /services/oauth2/token
   *   // Body: grant_type=password&username=test@test.com&password=pass123
   *   // Response: { "access_token": "00D...", "instance_url": "https://salesforce-api-mock:8443", ... }
   */
  app.post('/services/oauth2/token', (req, res) => {
    const token = `00D000000000000!mock.token.${Date.now()}.${Math.random().toString(36).substring(2, 15)}`;

    const protocol = req.secure ? 'https' : 'http';
    const containerName = 'salesforce-api-mock';
    const port = req.secure ? HTTPS_PORT : HTTP_PORT;

    res.json({
      access_token: token,
      instance_url: `${protocol}://${containerName}:${port}`,
      id: `${protocol}://${containerName}:${port}/id/00D000000000000EAA/005000000000000AAA`,
      token_type: 'Bearer',
      issued_at: String(Date.now()),
      signature: Math.random().toString(36).substring(2, 46)
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // DESCRIBE ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/sobjects/:object/describe
   *
   * Returns Salesforce object metadata (field definitions, types, picklist values).
   * SnapLogic calls this BEFORE every operation to discover available fields.
   *
   * @example
   *   // GET /services/data/v59.0/sobjects/Account/describe
   *   // Response: { "name": "Account", "fields": [...], "createable": true, ... }
   */
  app.get('/services/data/:version/sobjects/:object/describe', (req, res) => {
    const objectName = req.params.object;
    const schema = schemas[objectName];

    if (!schema) {
      return res.status(404).json(formatError('NOT_FOUND', `sObject type '${objectName}' is not supported.`));
    }

    const fields = [
      {
        name: 'Id', type: 'id', label: `${schema.label} ID`, length: 18,
        updateable: false, createable: false, nillable: false,
        queryable: true, filterable: true, picklistValues: []
      },
      ...Object.entries(schema.fields).map(([name, def]) => ({
        name,
        type: def.type,
        label: def.label || name,
        length: def.maxLength || (def.type === 'id' ? 18 : 0),
        precision: def.precision || 0,
        scale: def.scale || 0,
        digits: def.digits || 0,
        updateable: def.updateable !== false,
        createable: def.createable !== false,
        nillable: !def.required,
        queryable: true,
        filterable: true,
        referenceTo: def.referenceTo || [],
        picklistValues: (def.values || []).map((v, i) => ({
          value: v, label: v, active: true,
          defaultValue: i === 0 && def.required
        }))
      }))
    ];

    res.json({
      name: schema.name,
      label: schema.label,
      labelPlural: schema.labelPlural || schema.label + 's',
      keyPrefix: schema.keyPrefix || schema.idPrefix,
      fields,
      createable: true, updateable: true, deletable: true,
      queryable: true, searchable: true,
      urls: {
        sobject: `/services/data/${req.params.version}/sobjects/${objectName}`,
        describe: `/services/data/${req.params.version}/sobjects/${objectName}/describe`,
        rowTemplate: `/services/data/${req.params.version}/sobjects/${objectName}/{ID}`
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // CREATE ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * POST /services/data/:version/sobjects/:object
   *
   * Creates a new record. Validates against schema, generates SF-style ID.
   *
   * @example
   *   // POST /services/data/v59.0/sobjects/Account
   *   // Body: { "Name": "Acme Corp", "Type": "Customer" }
   *   // Response (201): { "id": "001ABC...", "success": true, "errors": [] }
   */
  app.post('/services/data/:version/sobjects/:object', (req, res) => {
    const objectName = req.params.object;
    const schema = schemas[objectName];

    if (!schema) {
      return res.status(404).json(formatError('NOT_FOUND', `sObject type '${objectName}' is not supported.`));
    }

    const errors = validate(req.body, schema, 'create');
    if (errors.length > 0) {
      return res.status(400).json(errors);
    }

    const id = generateId(schema.idPrefix);
    const record = {
      Id: id,
      ...req.body,
      CreatedDate: new Date().toISOString(),
      LastModifiedDate: new Date().toISOString(),
      SystemModstamp: new Date().toISOString(),
      attributes: {
        type: objectName,
        url: `/services/data/${req.params.version}/sobjects/${objectName}/${id}`
      }
    };

    database[objectName].push(record);
    console.log(`  ✅ Created ${objectName}: ${id}`);

    res.status(201).json({ id, success: true, errors: [] });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // UPSERT ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * PATCH /services/data/:version/sobjects/:object/:extIdField/:extIdValue
   *
   * Upserts a record by external ID field. Update if exists, Insert if not.
   *
   * @example
   *   // PATCH /services/data/v59.0/sobjects/Account/ExternalId__c/EXT-001
   *   // Body: { "Name": "Updated Corp" }
   *   // Response: 204 (updated) or 201 (created)
   */
  app.patch('/services/data/:version/sobjects/:object/:extIdField/:extIdValue', (req, res) => {
    const objectName = req.params.object;
    const extIdField = req.params.extIdField;
    const extIdValue = req.params.extIdValue;
    const schema = schemas[objectName];

    if (!schema) {
      return res.status(404).json(formatError('NOT_FOUND', `sObject type '${objectName}' is not supported.`));
    }

    const records = database[objectName];
    const existingIndex = records.findIndex(r => String(r[extIdField]) === String(extIdValue));

    if (existingIndex !== -1) {
      Object.assign(records[existingIndex], req.body, {
        LastModifiedDate: new Date().toISOString(),
        SystemModstamp: new Date().toISOString()
      });
      console.log(`  ✅ Upserted (updated) ${objectName}: ${records[existingIndex].Id}`);
      res.status(204).send();
    } else {
      const errors = validate(req.body, schema, 'create');
      if (errors.length > 0) {
        return res.status(400).json(errors);
      }

      const id = generateId(schema.idPrefix);
      const record = {
        Id: id, [extIdField]: extIdValue, ...req.body,
        CreatedDate: new Date().toISOString(),
        LastModifiedDate: new Date().toISOString(),
        SystemModstamp: new Date().toISOString(),
        attributes: { type: objectName, url: `/services/data/${req.params.version}/sobjects/${objectName}/${id}` }
      };

      records.push(record);
      console.log(`  ✅ Upserted (created) ${objectName}: ${id}`);
      res.status(201).json({ id, success: true, errors: [], created: true });
    }
  });

  // ═══════════════════════════════════════════════════════════════════════
  // READ SINGLE RECORD ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/sobjects/:object/:id
   *
   * Reads a single record by ID from the in-memory database.
   *
   * @example
   *   // GET /services/data/v59.0/sobjects/Account/001ABC...
   *   // Response: { "Id": "001ABC...", "Name": "Acme Corp", "attributes": {...} }
   */
  app.get('/services/data/:version/sobjects/:object/:id', (req, res) => {
    const objectName = req.params.object;
    const recordId = req.params.id;

    if (!schemas[objectName]) {
      return res.status(404).json(formatError('NOT_FOUND', `sObject type '${objectName}' is not supported.`));
    }

    const records = database[objectName] || [];
    const record = records.find(r => r.Id === recordId);

    if (!record) {
      return res.status(404).json(formatError('NOT_FOUND', `Provided external ID field does not exist or is not accessible: ${recordId}`));
    }

    const response = { ...record };
    if (!response.attributes) {
      response.attributes = { type: objectName, url: `/services/data/${req.params.version}/sobjects/${objectName}/${recordId}` };
    }
    res.json(response);
  });

  // ═══════════════════════════════════════════════════════════════════════
  // UPDATE ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * PATCH /services/data/:version/sobjects/:object/:id
   *
   * Updates an existing record. Returns 204 No Content on success.
   *
   * @example
   *   // PATCH /services/data/v59.0/sobjects/Account/001ABC...
   *   // Body: { "Name": "Acme Corp (Updated)" }
   *   // Response: 204 No Content
   */
  app.patch('/services/data/:version/sobjects/:object/:id', (req, res) => {
    const objectName = req.params.object;
    const recordId = req.params.id;
    const schema = schemas[objectName];

    if (!schema) {
      return res.status(404).json(formatError('NOT_FOUND', `sObject type '${objectName}' is not supported.`));
    }

    const records = database[objectName] || [];
    const index = records.findIndex(r => r.Id === recordId);

    if (index === -1) {
      return res.status(404).json(formatError('NOT_FOUND', `Provided external ID field does not exist or is not accessible: ${recordId}`));
    }

    const errors = validate(req.body, schema, 'update');
    if (errors.length > 0) {
      return res.status(400).json(errors);
    }

    Object.assign(records[index], req.body, {
      LastModifiedDate: new Date().toISOString(),
      SystemModstamp: new Date().toISOString()
    });

    console.log(`  ✅ Updated ${objectName}: ${recordId}`);
    res.status(204).send();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // DELETE ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * DELETE /services/data/:version/sobjects/:object/:id
   *
   * Deletes a record. Returns 204 No Content on success.
   *
   * @example
   *   // DELETE /services/data/v59.0/sobjects/Account/001ABC...
   *   // Response: 204 No Content
   */
  app.delete('/services/data/:version/sobjects/:object/:id', (req, res) => {
    const objectName = req.params.object;
    const recordId = req.params.id;

    if (!schemas[objectName]) {
      return res.status(404).json(formatError('NOT_FOUND', `sObject type '${objectName}' is not supported.`));
    }

    const records = database[objectName] || [];
    const index = records.findIndex(r => r.Id === recordId);

    if (index === -1) {
      return res.status(404).json(formatError('ENTITY_IS_DELETED', `Entity is deleted or does not exist: ${recordId}`));
    }

    records.splice(index, 1);
    console.log(`  ✅ Deleted ${objectName}: ${recordId}`);
    res.status(204).send();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // SOQL QUERY ENDPOINT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/query
   *
   * Parses and executes SOQL queries against the in-memory database.
   *
   * @example
   *   // GET /services/data/v59.0/query?q=SELECT+Id,Name+FROM+Account+WHERE+Type='Customer'
   *   // Response: { "totalSize": 2, "done": true, "records": [...] }
   */
  app.get('/services/data/:version/query', (req, res) => {
    const soql = req.query.q;

    if (!soql) {
      return res.status(400).json(formatError('MALFORMED_QUERY', 'SOQL query is required. Use ?q=SELECT...'));
    }

    let parsed;
    try {
      parsed = parseSOQL(soql);
    } catch (err) {
      return res.status(400).json(formatError('MALFORMED_QUERY', err.message));
    }

    if (!parsed.object || !schemas[parsed.object]) {
      return res.status(400).json(formatError('INVALID_TYPE',
        `sObject type '${parsed.object}' is not supported. Check the spelling or your schema files.`));
    }

    let records = [...(database[parsed.object] || [])];

    if (parsed.where && parsed.where.length > 0) {
      records = applyWhere(records, parsed.where);
    }

    if (parsed.orderBy) {
      records = applyOrderBy(records, parsed.orderBy);
    }

    if (parsed.offset) {
      records = records.slice(parsed.offset);
    }

    if (parsed.limit) {
      records = records.slice(0, parsed.limit);
    }

    if (parsed.isCount) {
      return res.json({ totalSize: records.length, done: true, records: [] });
    }

    const projected = records.map(record => {
      const row = {
        attributes: {
          type: parsed.object,
          url: record.attributes?.url || `/services/data/${req.params.version}/sobjects/${parsed.object}/${record.Id}`
        }
      };

      if (parsed.fields.includes('*')) {
        Object.keys(record).forEach(key => {
          if (key !== 'attributes') row[key] = record[key];
        });
      } else {
        parsed.fields.forEach(field => {
          if (record[field] !== undefined) row[field] = record[field];
        });
      }
      return row;
    });

    res.json({ totalSize: projected.length, done: true, records: projected });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // API LIMITS
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/limits
   *
   * Returns mock API limits. SnapLogic checks this during connection validation.
   *
   * @example
   *   // GET /services/data/v59.0/limits
   *   // Response: { "DailyApiRequests": { "Max": 1000000, "Remaining": 999000 }, ... }
   */
  app.get('/services/data/:version/limits', (req, res) => {
    res.json({
      DailyApiRequests: { Max: 1000000, Remaining: 999000 },
      DailyBulkApiRequests: { Max: 10000, Remaining: 9900 },
      ConcurrentAsyncGetReportInstances: { Max: 200, Remaining: 200 },
      ConcurrentSyncReportRuns: { Max: 20, Remaining: 20 },
      DailyAsyncApexExecutions: { Max: 250000, Remaining: 250000 },
      HourlyDashboardRefreshes: { Max: 200, Remaining: 200 }
    });
  });
}

module.exports = { registerRestRoutes };
