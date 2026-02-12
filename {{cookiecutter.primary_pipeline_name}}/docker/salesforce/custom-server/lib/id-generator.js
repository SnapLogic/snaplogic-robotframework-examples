'use strict';

/**
 * Salesforce ID Generator
 * =======================
 *
 * Generates 18-character IDs matching Salesforce format:
 * - First 3 chars: Object key prefix (e.g., 001 for Account, 003 for Contact)
 * - Next 15 chars: Random alphanumeric (uppercase)
 *
 * Real Salesforce IDs are 15-char (case-sensitive) or 18-char (case-insensitive).
 * We generate 18-char IDs since that's what SnapLogic Salesforce snaps expect.
 *
 * Common Salesforce ID Prefixes:
 *   001 = Account
 *   003 = Contact
 *   006 = Opportunity
 *   00Q = Lead
 *   500 = Case
 */

const ID_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/**
 * Generates a Salesforce-style 18-character ID with the given object prefix.
 *
 * The prefix identifies which Salesforce object the record belongs to.
 * Each schema file defines its own prefix (e.g., Account.json has idPrefix: "001").
 *
 * @param {string} prefix - The 3-character Salesforce object key prefix (e.g., "001", "003", "00Q")
 * @returns {string} An 18-character Salesforce-style ID
 *
 * @example
 *   // Generate an Account ID (prefix "001"):
 *   generateId('001');
 *   // Returns: "001A3B4C5D6E7F8G9H0" (random 15 chars after prefix)
 *
 * @example
 *   // Generate a Contact ID (prefix "003"):
 *   generateId('003');
 *   // Returns: "003X7Y8Z1A2B3C4D5E6"
 *
 * @example
 *   // Generate a Lead ID (prefix "00Q"):
 *   generateId('00Q');
 *   // Returns: "00QM4N5O6P7Q8R9S0T1"
 *
 * @example
 *   // Used internally by routes.js during record creation:
 *   const id = generateId(schema.idPrefix);
 *   // schema.idPrefix comes from the schema JSON file (e.g., Account.json → "001")
 */
function generateId(prefix) {
  let id = prefix;
  for (let i = 0; i < 15; i++) {
    id += ID_CHARS.charAt(Math.floor(Math.random() * ID_CHARS.length));
  }
  return id;
}

module.exports = { generateId };
