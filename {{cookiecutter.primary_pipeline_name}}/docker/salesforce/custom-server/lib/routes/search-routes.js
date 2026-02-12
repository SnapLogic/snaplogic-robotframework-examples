'use strict';

/**
 * Salesforce SOSL Search Routes
 * ==============================
 *
 * Implements the Salesforce SOSL (Salesforce Object Search Language) search endpoint.
 * SOSL performs cross-object text searches, unlike SOQL which queries a single object.
 *
 * Routes:
 *   GET /services/data/:version/search   - Execute SOSL query via ?q= parameter
 *
 * Used by the SnapLogic "Salesforce SOSL" snap.
 *
 * SOSL syntax:
 *   FIND {searchTerm} [IN scope] RETURNING Object1(Field1, Field2), Object2(Field1)
 */

const { parseSOSL, searchRecords } = require('../sosl-parser');
const { applyWhere } = require('../soql-parser');
const { formatError } = require('../error-formatter');

/**
 * Registers SOSL search route handler on the Express app.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @param {Object} config - Server configuration
 *
 * @example
 *   registerSearchRoutes(app, schemas, database, config);
 */
function registerSearchRoutes(app, schemas, database, config) {

  /**
   * GET /services/data/:version/search
   *
   * Executes a SOSL search query across multiple objects.
   *
   * @example
   *   // GET /services/data/v59.0/search?q=FIND+{Acme}+RETURNING+Account(Id,Name)
   *   // Response: { "searchRecords": [{ "attributes": {...}, "Id": "001...", "Name": "Acme Corp" }] }
   *
   * @example
   *   // Multi-object search:
   *   // GET /services/data/v59.0/search?q=FIND+{test}+RETURNING+Account(Id,Name),Contact(Id,Email)
   *   // Response: { "searchRecords": [...accounts, ...contacts] }
   */
  app.get('/services/data/:version/search', (req, res) => {
    const sosl = req.query.q;

    if (!sosl) {
      return res.status(400).json(formatError('MALFORMED_QUERY',
        'SOSL query is required. Use ?q=FIND+{term}+RETURNING+Object(fields)'));
    }

    let parsed;
    try {
      parsed = parseSOSL(sosl);
    } catch (err) {
      return res.status(400).json(formatError('MALFORMED_QUERY', err.message));
    }

    const allResults = [];

    // Process each RETURNING object
    for (const returning of parsed.returning) {
      const objectName = returning.object;

      // Check if object exists in schemas
      if (!schemas[objectName]) {
        // Skip unknown objects (Salesforce silently skips them in SOSL)
        console.log(`  ⚠️  SOSL: Skipping unknown object '${objectName}'`);
        continue;
      }

      // Get records for this object
      let records = [...(database[objectName] || [])];

      // Search: filter records by search term
      records = searchRecords(records, parsed.searchTerm, parsed.scope);

      // Apply WHERE filter if specified in RETURNING clause
      if (returning.where) {
        // Parse the WHERE string into conditions using the same pattern as SOQL
        // Simple parsing: split by AND/OR and build condition objects
        const conditions = parseSimpleWhere(returning.where);
        if (conditions.length > 0) {
          records = applyWhere(records, conditions);
        }
      }

      // Apply LIMIT if specified
      if (returning.limit) {
        records = records.slice(0, returning.limit);
      }

      // Project fields
      const projected = records.map(record => {
        const row = {
          attributes: {
            type: objectName,
            url: record.attributes?.url || `/services/data/${req.params.version}/sobjects/${objectName}/${record.Id}`
          }
        };

        if (returning.fields.length === 0 || returning.fields.includes('*')) {
          // No fields specified or wildcard — return all fields
          Object.keys(record).forEach(key => {
            if (key !== 'attributes') row[key] = record[key];
          });
        } else {
          // Project only requested fields
          returning.fields.forEach(field => {
            if (record[field] !== undefined) row[field] = record[field];
          });
        }

        return row;
      });

      allResults.push(...projected);
    }

    console.log(`  🔍 SOSL: FIND {${parsed.searchTerm}} → ${allResults.length} results`);
    res.json({ searchRecords: allResults });
  });
}

/**
 * Parses a simple WHERE string into condition objects compatible with applyWhere().
 *
 * This is a simplified parser for RETURNING WHERE clauses.
 * Supports: field = 'value', field != 'value', AND, OR
 *
 * @param {string} whereStr - The WHERE clause content (without "WHERE" keyword)
 * @returns {Object[]} Array of condition objects
 */
function parseSimpleWhere(whereStr) {
  const conditions = [];
  const parts = whereStr.split(/\b(AND|OR)\b/i);
  let logical = null;

  for (const part of parts) {
    const trimmed = part.trim();
    if (trimmed.toUpperCase() === 'AND' || trimmed.toUpperCase() === 'OR') {
      logical = trimmed.toUpperCase();
      continue;
    }

    // Parse: field operator value
    const match = trimmed.match(/^(\w+)\s*(!=|<>|>=|<=|>|<|=)\s*(.+)$/);
    if (match) {
      let value = match[3].trim();
      if (value.startsWith("'") && value.endsWith("'")) {
        value = value.slice(1, -1);
      } else if (!isNaN(value)) {
        value = Number(value);
      } else if (value.toLowerCase() === 'true') {
        value = true;
      } else if (value.toLowerCase() === 'false') {
        value = false;
      } else if (value.toLowerCase() === 'null') {
        value = null;
      }

      conditions.push({
        field: match[1],
        operator: match[2] === '<>' ? '!=' : match[2],
        value,
        logical
      });
      logical = null;
    }
  }

  return conditions;
}

module.exports = { registerSearchRoutes };
