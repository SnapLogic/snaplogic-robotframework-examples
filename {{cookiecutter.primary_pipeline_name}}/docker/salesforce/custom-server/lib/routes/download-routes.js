'use strict';

/**
 * Salesforce Download Routes
 * ===========================
 *
 * Implements file/attachment binary content download endpoints.
 * Used by the SnapLogic "Salesforce Download" snap.
 *
 * Routes:
 *   GET /services/data/:version/sobjects/Attachment/:id/Body         - Download Attachment body
 *   GET /services/data/:version/sobjects/ContentVersion/:id/VersionData - Download ContentVersion body
 *   GET /services/data/:version/sobjects/Document/:id/Body           - Download Document body
 *
 * IMPORTANT: These routes MUST be registered BEFORE rest-routes.js!
 * The generic /sobjects/:object/:id route in rest-routes.js would otherwise
 * match these paths (treating "Body"/"VersionData" as the :id parameter).
 *
 * How it works:
 *   1. Create a record with a base64-encoded Body/VersionData field (via REST Create)
 *   2. Download the binary content via these endpoints
 *   3. The mock decodes base64 and returns raw bytes with correct Content-Type
 */

const { formatError } = require('../error-formatter');

/**
 * Registers download route handlers on the Express app.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @param {Object} config - Server configuration
 */
function registerDownloadRoutes(app, schemas, database, config) {

  /**
   * GET /services/data/:version/sobjects/Attachment/:id/Body
   *
   * Downloads the binary body of an Attachment record.
   * The Body field is stored as a base64-encoded string when created via REST API.
   *
   * @example
   *   // 1. Create Attachment with base64 body:
   *   // POST /services/data/v59.0/sobjects/Attachment
   *   // { "Name": "test.txt", "ParentId": "001xxx", "Body": "SGVsbG8=", "ContentType": "text/plain" }
   *   //
   *   // 2. Download body:
   *   // GET /services/data/v59.0/sobjects/Attachment/00PXXX/Body
   *   // Response: raw bytes (decoded from base64), Content-Type: text/plain
   */
  app.get('/services/data/:version/sobjects/Attachment/:id/Body', (req, res) => {
    handleDownload(req, res, database, 'Attachment', req.params.id, 'Body');
  });

  /**
   * GET /services/data/:version/sobjects/ContentVersion/:id/VersionData
   *
   * Downloads the binary content of a ContentVersion record.
   * The VersionData field is stored as a base64-encoded string.
   *
   * @example
   *   // GET /services/data/v59.0/sobjects/ContentVersion/068XXX/VersionData
   *   // Response: raw bytes, Content-Type from record's ContentType field
   */
  app.get('/services/data/:version/sobjects/ContentVersion/:id/VersionData', (req, res) => {
    handleDownload(req, res, database, 'ContentVersion', req.params.id, 'VersionData');
  });

  /**
   * GET /services/data/:version/sobjects/Document/:id/Body
   *
   * Downloads the binary body of a Document record.
   *
   * @example
   *   // GET /services/data/v59.0/sobjects/Document/015XXX/Body
   *   // Response: raw bytes, Content-Type from record's ContentType field
   */
  app.get('/services/data/:version/sobjects/Document/:id/Body', (req, res) => {
    handleDownload(req, res, database, 'Document', req.params.id, 'Body');
  });
}

/**
 * Handles the download logic for any object/field combination.
 *
 * Steps:
 *   1. Look up the record by ID in the database
 *   2. Extract the binary field (Body or VersionData)
 *   3. Decode from base64 to Buffer
 *   4. Set Content-Type from the record's ContentType field
 *   5. Return the raw binary content
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Object} database - In-memory database
 * @param {string} objectName - Salesforce object name (Attachment, ContentVersion, Document)
 * @param {string} recordId - The record ID to download from
 * @param {string} bodyField - The field containing base64 data (Body or VersionData)
 */
function handleDownload(req, res, database, objectName, recordId, bodyField) {
  const records = database[objectName] || [];
  const record = records.find(r => r.Id === recordId);

  if (!record) {
    return res.status(404).json(formatError('NOT_FOUND',
      `${objectName} record not found: ${recordId}`));
  }

  const bodyData = record[bodyField];
  if (!bodyData) {
    return res.status(404).json(formatError('NOT_FOUND',
      `${objectName} record ${recordId} has no ${bodyField} data`));
  }

  // Decode base64 to binary buffer
  const buffer = Buffer.from(bodyData, 'base64');

  // Determine content type from the record's ContentType field
  const contentType = record.ContentType || 'application/octet-stream';

  // Determine filename for Content-Disposition header
  const filename = record.Name || record.Title || record.PathOnClient || `download`;

  console.log(`  📥 Download: ${objectName}/${recordId}/${bodyField} (${buffer.length} bytes, ${contentType})`);

  res.set({
    'Content-Type': contentType,
    'Content-Length': buffer.length,
    'Content-Disposition': `attachment; filename="${filename}"`
  });

  res.send(buffer);
}

module.exports = { registerDownloadRoutes };
