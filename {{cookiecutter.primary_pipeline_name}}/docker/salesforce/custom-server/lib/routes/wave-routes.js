'use strict';

/**
 * Salesforce Wave Analytics (Einstein Analytics) Routes
 * ======================================================
 *
 * Implements the Salesforce Wave Analytics REST API endpoints.
 * Used by the SnapLogic "Salesforce Wave Analytics" snap.
 *
 * Routes:
 *   GET  /services/data/:version/wave/datasets                  - List all datasets
 *   GET  /services/data/:version/wave/datasets/:id              - Get dataset details
 *   GET  /services/data/:version/wave/datasets/:id/versions     - List dataset versions
 *   POST /services/data/:version/wave/query                     - Execute SAQL query
 *
 * Wave Analytics uses SAQL (Salesforce Analytics Query Language), which is
 * completely different from SOQL/SOSL. It uses a pipeline syntax:
 *   q = load "datasetId/versionId";
 *   q = foreach q generate 'Field1', 'Field2';
 *   q = filter q by 'Field1' == "value";
 *   q = order q by 'Field1' asc;
 *   q = limit q 10;
 *
 * For the mock, we provide pre-seeded sample datasets and return
 * realistic-looking query results.
 */

const { generateId } = require('../id-generator');
const { formatError } = require('../error-formatter');

/**
 * Registers Wave Analytics route handlers on the Express app.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records
 * @param {Object} config - Server configuration
 */
function registerWaveRoutes(app, schemas, database, config) {

  // ═══════════════════════════════════════════════════════════════════════
  // IN-MEMORY WAVE DATASET STORAGE
  // ═══════════════════════════════════════════════════════════════════════

  // Pre-seeded sample datasets (Salesforce Wave uses 0Fb prefix for datasets)
  const waveDatasets = new Map();
  const waveVersions = new Map();

  // Seed with sample datasets
  seedSampleDatasets(waveDatasets, waveVersions);

  // ═══════════════════════════════════════════════════════════════════════
  // LIST DATASETS
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/wave/datasets
   *
   * Lists all available Wave Analytics datasets.
   *
   * @example
   *   // GET /services/data/v59.0/wave/datasets
   *   // Response: { "datasets": [...], "totalSize": 2, "url": "..." }
   */
  app.get('/services/data/:version/wave/datasets', (req, res) => {
    const datasets = Array.from(waveDatasets.values()).map(ds => {
      const { _sampleData, ...publicData } = ds;
      return { ...publicData, url: `/services/data/${req.params.version}/wave/datasets/${ds.id}` };
    });

    console.log(`  📊 Wave: Listed ${datasets.length} datasets`);

    res.json({
      datasets,
      totalSize: datasets.length,
      url: `/services/data/${req.params.version}/wave/datasets`
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // GET DATASET DETAILS
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/wave/datasets/:id
   *
   * Returns detailed information about a specific dataset.
   *
   * @example
   *   // GET /services/data/v59.0/wave/datasets/0FbXXX
   *   // Response: { "id": "0FbXXX", "name": "SalesData", "currentVersionId": "0FcXXX", ... }
   */
  app.get('/services/data/:version/wave/datasets/:id', (req, res) => {
    const datasetId = req.params.id;
    const dataset = waveDatasets.get(datasetId);

    if (!dataset) {
      return res.status(404).json(formatError('NOT_FOUND',
        `Dataset not found: ${datasetId}`));
    }

    console.log(`  📊 Wave: Dataset details for ${dataset.name}`);

    const { _sampleData, ...publicData } = dataset;
    res.json({
      ...publicData,
      url: `/services/data/${req.params.version}/wave/datasets/${datasetId}`,
      versionsUrl: `/services/data/${req.params.version}/wave/datasets/${datasetId}/versions`
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // LIST DATASET VERSIONS
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * GET /services/data/:version/wave/datasets/:id/versions
   *
   * Lists all versions of a dataset.
   *
   * @example
   *   // GET /services/data/v59.0/wave/datasets/0FbXXX/versions
   *   // Response: { "versions": [...], "url": "..." }
   */
  app.get('/services/data/:version/wave/datasets/:id/versions', (req, res) => {
    const datasetId = req.params.id;
    const dataset = waveDatasets.get(datasetId);

    if (!dataset) {
      return res.status(404).json(formatError('NOT_FOUND',
        `Dataset not found: ${datasetId}`));
    }

    const versions = waveVersions.get(datasetId) || [];

    console.log(`  📊 Wave: ${versions.length} versions for ${dataset.name}`);

    res.json({
      versions,
      url: `/services/data/${req.params.version}/wave/datasets/${datasetId}/versions`
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // EXECUTE SAQL QUERY
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * POST /services/data/:version/wave/query
   *
   * Executes a SAQL (Salesforce Analytics Query Language) query.
   * For the mock, we parse basic SAQL patterns and return sample results.
   *
   * SAQL is a pipeline-based query language:
   *   q = load "datasetId/versionId";
   *   q = foreach q generate 'Field1' as 'Field1', 'Field2' as 'Field2';
   *   q = filter q by 'Amount' > 1000;
   *   q = order q by 'Amount' desc;
   *   q = limit q 10;
   *
   * @example
   *   // POST /services/data/v59.0/wave/query
   *   // Body: { "query": "q = load \"0FbXXX/0FcXXX\"; q = foreach q generate 'Name', 'Amount';" }
   *   // Response: { "results": { "records": [...] }, "query": "...", "responseTime": 42 }
   */
  app.post('/services/data/:version/wave/query', (req, res) => {
    const saql = req.body.query;

    if (!saql) {
      return res.status(400).json(formatError('MALFORMED_QUERY',
        'SAQL query is required in the "query" field'));
    }

    // Parse the SAQL query to extract dataset reference and fields
    const queryResult = executeSAQL(saql, waveDatasets, waveVersions);

    console.log(`  📊 Wave: SAQL query → ${queryResult.results.records.length} records`);

    res.json(queryResult);
  });
}

// ═══════════════════════════════════════════════════════════════════════
// SEED SAMPLE DATASETS
// ═══════════════════════════════════════════════════════════════════════

/**
 * Seeds the wave storage with sample datasets for testing.
 *
 * @param {Map} datasets - Dataset storage map
 * @param {Map} versions - Version storage map
 */
function seedSampleDatasets(datasets, versions) {
  // Dataset 1: Sales Pipeline
  const salesId = '0Fb' + 'SALES00000001';
  const salesVersionId = '0Fc' + 'SALESV0000001';
  datasets.set(salesId, {
    id: salesId,
    name: 'SalesPipeline',
    label: 'Sales Pipeline',
    currentVersionId: salesVersionId,
    datasetType: 'default',
    createdDate: '2024-01-15T10:00:00.000Z',
    lastModifiedDate: '2024-06-01T15:30:00.000Z',
    folder: {
      id: '00l000000000001AAA',
      label: 'Shared App'
    },
    permissions: {
      create: true,
      modify: true,
      view: true
    },
    _sampleData: [
      { Name: 'Acme Corp', Amount: 50000, Stage: 'Closed Won', Region: 'West' },
      { Name: 'Beta Inc', Amount: 30000, Stage: 'Negotiation', Region: 'East' },
      { Name: 'Gamma LLC', Amount: 75000, Stage: 'Closed Won', Region: 'West' },
      { Name: 'Delta Co', Amount: 12000, Stage: 'Prospecting', Region: 'Central' },
      { Name: 'Epsilon Ltd', Amount: 95000, Stage: 'Proposal', Region: 'East' }
    ]
  });
  versions.set(salesId, [{
    id: salesVersionId,
    datasetId: salesId,
    createdDate: '2024-06-01T15:30:00.000Z',
    totalRows: 5
  }]);

  // Dataset 2: Customer Metrics
  const metricsId = '0Fb' + 'METRICS000001';
  const metricsVersionId = '0Fc' + 'METRICSV00001';
  datasets.set(metricsId, {
    id: metricsId,
    name: 'CustomerMetrics',
    label: 'Customer Metrics',
    currentVersionId: metricsVersionId,
    datasetType: 'default',
    createdDate: '2024-02-20T08:00:00.000Z',
    lastModifiedDate: '2024-06-10T12:00:00.000Z',
    folder: {
      id: '00l000000000002AAA',
      label: 'Analytics App'
    },
    permissions: {
      create: true,
      modify: true,
      view: true
    },
    _sampleData: [
      { Customer: 'Acme Corp', Score: 92, Segment: 'Enterprise', Revenue: 500000 },
      { Customer: 'Beta Inc', Score: 78, Segment: 'Mid-Market', Revenue: 150000 },
      { Customer: 'Gamma LLC', Score: 85, Segment: 'Enterprise', Revenue: 320000 }
    ]
  });
  versions.set(metricsId, [{
    id: metricsVersionId,
    datasetId: metricsId,
    createdDate: '2024-06-10T12:00:00.000Z',
    totalRows: 3
  }]);
}

// ═══════════════════════════════════════════════════════════════════════
// SAQL QUERY EXECUTION
// ═══════════════════════════════════════════════════════════════════════

/**
 * Executes a simplified SAQL query against the mock wave datasets.
 *
 * Supports basic SAQL patterns:
 *   - load "datasetId/versionId" or load "datasetName"
 *   - foreach (field selection)
 *   - filter (basic conditions)
 *   - limit
 *
 * @param {string} saql - The SAQL query string
 * @param {Map} datasets - Dataset storage
 * @param {Map} versions - Version storage
 * @returns {Object} Query result in Wave format
 */
function executeSAQL(saql, datasets, versions) {
  const startTime = Date.now();

  // Try to extract the dataset reference from the load statement
  // Patterns: load "datasetId/versionId", load "datasetName"
  const loadMatch = saql.match(/load\s+"([^"]+)"/i);
  let records = [];
  let datasetName = 'unknown';

  if (loadMatch) {
    const ref = loadMatch[1];
    // Try exact dataset ID match first
    let dataset = datasets.get(ref);

    if (!dataset) {
      // Try matching by datasetId/versionId
      const parts = ref.split('/');
      dataset = datasets.get(parts[0]);
    }

    if (!dataset) {
      // Try matching by name
      for (const ds of datasets.values()) {
        if (ds.name === ref || ds.label === ref) {
          dataset = ds;
          break;
        }
      }
    }

    if (dataset) {
      datasetName = dataset.name;
      records = [...(dataset._sampleData || [])];
    }
  }

  // If no dataset found, return sample data from first available
  if (records.length === 0 && datasets.size > 0) {
    const firstDataset = datasets.values().next().value;
    datasetName = firstDataset.name;
    records = [...(firstDataset._sampleData || [])];
  }

  // Parse foreach (field selection)
  const foreachMatch = saql.match(/foreach\s+\w+\s+generate\s+(.+?)(?:;|$)/i);
  if (foreachMatch) {
    const fieldStr = foreachMatch[1];
    // Extract field names from 'Field1' as 'Alias1', 'Field2'
    const fields = fieldStr.match(/'([^']+)'/g);
    if (fields) {
      const fieldNames = fields.map(f => f.replace(/'/g, ''));
      // Project only the requested fields (use unique field names)
      const uniqueFields = [...new Set(fieldNames)];
      records = records.map(record => {
        const projected = {};
        uniqueFields.forEach(field => {
          if (record[field] !== undefined) {
            projected[field] = record[field];
          }
        });
        return projected;
      });
    }
  }

  // Parse filter
  const filterMatch = saql.match(/filter\s+\w+\s+by\s+'([^']+)'\s*(==|!=|>|>=|<|<=)\s*(?:"([^"]*)"|([\d.]+))/i);
  if (filterMatch) {
    const field = filterMatch[1];
    const operator = filterMatch[2];
    const strValue = filterMatch[3];
    const numValue = filterMatch[4] !== undefined ? Number(filterMatch[4]) : null;
    const value = strValue !== undefined ? strValue : numValue;

    records = records.filter(record => {
      const recordVal = record[field];
      switch (operator) {
        case '==': return String(recordVal) === String(value);
        case '!=': return String(recordVal) !== String(value);
        case '>':  return Number(recordVal) > Number(value);
        case '>=': return Number(recordVal) >= Number(value);
        case '<':  return Number(recordVal) < Number(value);
        case '<=': return Number(recordVal) <= Number(value);
        default: return true;
      }
    });
  }

  // Parse limit
  const limitMatch = saql.match(/limit\s+\w+\s+(\d+)/i);
  if (limitMatch) {
    records = records.slice(0, parseInt(limitMatch[1], 10));
  }

  // Parse order
  const orderMatch = saql.match(/order\s+\w+\s+by\s+'([^']+)'\s*(asc|desc)?/i);
  if (orderMatch) {
    const orderField = orderMatch[1];
    const direction = (orderMatch[2] || 'asc').toLowerCase();
    records.sort((a, b) => {
      const aVal = a[orderField];
      const bVal = b[orderField];
      if (aVal === bVal) return 0;
      const comparison = typeof aVal === 'number' ? aVal - bVal : String(aVal).localeCompare(String(bVal));
      return direction === 'desc' ? -comparison : comparison;
    });
  }

  const responseTime = Date.now() - startTime;

  return {
    action: 'query',
    responseId: generateId('0Ag'),
    results: {
      metadata: records.length > 0
        ? Object.keys(records[0]).map(key => ({
            lineage: { type: 'foreach' },
            type: typeof records[0][key] === 'number' ? 'numeric' : 'string'
          }))
        : [],
      records: records
    },
    query: saql,
    responseTime,
    warnings: []
  };
}

module.exports = { registerWaveRoutes };
