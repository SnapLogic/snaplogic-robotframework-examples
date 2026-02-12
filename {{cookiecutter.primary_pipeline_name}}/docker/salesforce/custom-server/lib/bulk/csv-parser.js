'use strict';

/**
 * CSV Parser & Serializer
 * ========================
 *
 * Zero-dependency CSV parsing and serialization for Salesforce Bulk API 2.0.
 *
 * Salesforce Bulk API uses CSV format (not JSON) for data upload and download.
 * This module handles the CSV <-> JavaScript object conversion.
 *
 * Follows RFC 4180:
 *   - First row is always the header (column names)
 *   - Fields containing commas, quotes, or newlines are wrapped in double quotes
 *   - Double quotes inside fields are escaped as "" (two double quotes)
 *
 * Why no external library:
 *   Salesforce Bulk API CSV is always machine-generated and well-formed.
 *   A focused ~60-line parser handles it correctly. This keeps the project
 *   at zero dependencies beyond Express (matching the soql-parser.js approach).
 */

/**
 * Parses a CSV string into an array of JavaScript objects.
 *
 * The first row is treated as headers (field names).
 * Each subsequent row becomes an object with header names as keys.
 * Empty rows are skipped.
 *
 * @param {string} csvString - The CSV string to parse
 * @returns {Object[]} Array of objects, one per data row
 *
 * @example
 *   // Simple CSV:
 *   parseCSV('Name,Type\nAcme Corp,Customer\nBeta Inc,Partner');
 *   // Returns: [
 *   //   { Name: 'Acme Corp', Type: 'Customer' },
 *   //   { Name: 'Beta Inc', Type: 'Partner' }
 *   // ]
 *
 * @example
 *   // CSV with quoted fields (commas inside values):
 *   parseCSV('Name,Description\n"Acme, Inc","A large company"');
 *   // Returns: [{ Name: 'Acme, Inc', Description: 'A large company' }]
 *
 * @example
 *   // Empty CSV (headers only):
 *   parseCSV('Name,Type');
 *   // Returns: []
 */
function parseCSV(csvString) {
  if (!csvString || typeof csvString !== 'string') return [];

  const lines = splitCSVLines(csvString.trim());
  if (lines.length < 2) return []; // Need at least header + 1 data row

  const headers = parseCSVLine(lines[0]);
  const records = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue; // Skip empty lines

    const values = parseCSVLine(line);
    const record = {};
    for (let j = 0; j < headers.length; j++) {
      record[headers[j]] = j < values.length ? values[j] : '';
    }
    records.push(record);
  }

  return records;
}

/**
 * Serializes an array of objects into a CSV string.
 *
 * The first row will be the headers, followed by one row per record.
 * Values containing commas, quotes, or newlines are automatically quoted.
 *
 * @param {string[]} headers - Array of column names (field names)
 * @param {Object[]} records - Array of objects to serialize
 * @returns {string} CSV string with headers and data rows
 *
 * @example
 *   // Simple serialization:
 *   toCSV(['Name', 'Type'], [
 *     { Name: 'Acme Corp', Type: 'Customer' },
 *     { Name: 'Beta Inc', Type: 'Partner' }
 *   ]);
 *   // Returns: "Name,Type\nAcme Corp,Customer\nBeta Inc,Partner"
 *
 * @example
 *   // With special characters (auto-quoted):
 *   toCSV(['Name'], [{ Name: 'Acme, Inc' }]);
 *   // Returns: 'Name\n"Acme, Inc"'
 *
 * @example
 *   // Empty records:
 *   toCSV(['Name', 'Type'], []);
 *   // Returns: "Name,Type"  (headers only)
 */
function toCSV(headers, records) {
  const rows = [headers.join(',')];

  for (const record of records) {
    const values = headers.map(header => {
      const val = record[header];
      if (val === null || val === undefined) return '';
      const str = String(val);
      // Quote if contains comma, quote, or newline
      if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return `"${str.replace(/"/g, '""')}"`;
      }
      return str;
    });
    rows.push(values.join(','));
  }

  return rows.join('\n');
}

/**
 * Gets the header row from a CSV string without parsing the entire file.
 * Useful for validating multi-batch uploads have matching headers.
 *
 * @param {string} csvString - The CSV string
 * @returns {string} The first line (header row) of the CSV
 *
 * @example
 *   getCSVHeaders('Name,Type\nAcme,Customer');
 *   // Returns: 'Name,Type'
 */
function getCSVHeaders(csvString) {
  if (!csvString) return '';
  const firstNewline = csvString.indexOf('\n');
  return firstNewline === -1 ? csvString.trim() : csvString.substring(0, firstNewline).trim();
}

// ═══════════════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ═══════════════════════════════════════════════════════════════════════

/**
 * Splits a CSV string into lines, respecting quoted fields that contain newlines.
 *
 * @param {string} text - The CSV text to split
 * @returns {string[]} Array of CSV lines
 */
function splitCSVLines(text) {
  const lines = [];
  let current = '';
  let inQuote = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];

    if (char === '"') {
      inQuote = !inQuote;
      current += char;
    } else if (char === '\n' && !inQuote) {
      lines.push(current);
      current = '';
    } else if (char === '\r' && !inQuote) {
      // Skip \r (handle \r\n line endings)
      continue;
    } else {
      current += char;
    }
  }

  if (current) lines.push(current);
  return lines;
}

/**
 * Parses a single CSV line into an array of field values.
 * Handles quoted fields and escaped double quotes per RFC 4180.
 *
 * @param {string} line - A single CSV line
 * @returns {string[]} Array of field values
 *
 * @example
 *   parseCSVLine('Acme Corp,Customer,Active');
 *   // Returns: ['Acme Corp', 'Customer', 'Active']
 *
 * @example
 *   parseCSVLine('"Acme, Inc","He said ""hello"""');
 *   // Returns: ['Acme, Inc', 'He said "hello"']
 */
function parseCSVLine(line) {
  const fields = [];
  let current = '';
  let inQuote = false;
  let i = 0;

  while (i < line.length) {
    const char = line[i];

    if (inQuote) {
      if (char === '"') {
        if (i + 1 < line.length && line[i + 1] === '"') {
          // Escaped double quote ""
          current += '"';
          i += 2;
        } else {
          // End of quoted field
          inQuote = false;
          i++;
        }
      } else {
        current += char;
        i++;
      }
    } else {
      if (char === '"') {
        inQuote = true;
        i++;
      } else if (char === ',') {
        fields.push(current);
        current = '';
        i++;
      } else {
        current += char;
        i++;
      }
    }
  }

  fields.push(current); // Push last field
  return fields;
}

module.exports = { parseCSV, toCSV, getCSVHeaders };
