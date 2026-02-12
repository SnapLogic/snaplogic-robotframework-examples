'use strict';

/**
 * Salesforce Platform Event & CometD Streaming Routes
 * =====================================================
 *
 * Implements two related Salesforce features:
 *
 * 1. PUBLISHER — Platform Event publishing via REST API
 *    POST /services/data/:version/sobjects/MyEvent__e
 *    Used by: SnapLogic "Salesforce Publisher" snap
 *
 * 2. SUBSCRIBER — CometD (Bayeux) streaming protocol
 *    POST /cometd/:version
 *    Used by: SnapLogic "Salesforce Subscriber" snap
 *
 * Platform Events are a special Salesforce object type (suffix __e).
 * Unlike regular sObjects, events are NOT stored in the database —
 * they're published to the event bus and delivered to subscribers via CometD.
 *
 * IMPORTANT: These routes MUST be registered BEFORE rest-routes.js!
 * The generic POST /sobjects/:object in rest-routes.js would match __e objects
 * and try to store them as regular CRUD records.
 *
 * CometD Protocol Flow:
 *   1. Handshake → returns clientId
 *   2. Subscribe → registers channel subscription
 *   3. Connect   → long-poll for new events
 *   4. Disconnect → cleanup
 */

const { generateId } = require('../id-generator');
const { formatError } = require('../error-formatter');

/**
 * Registers Platform Event publisher and CometD subscriber routes.
 *
 * @param {Object} app - The Express application instance
 * @param {Object} schemas - Map of object name -> schema definition
 * @param {Object} database - Map of object name -> array of records (not used for events)
 * @param {Object} config - Server configuration
 * @param {Object} eventBus - Event bus instance from event-bus.js
 */
function registerEventRoutes(app, schemas, database, config, eventBus) {

  // ═══════════════════════════════════════════════════════════════════════
  // PLATFORM EVENT PUBLISHER
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * POST /services/data/:version/sobjects/:object
   * WHERE :object ends with __e (Platform Event)
   *
   * Publishes a Platform Event to the event bus.
   * Unlike regular REST Create, events are NOT stored in database[].
   * They go to the event bus and are delivered via CometD.
   *
   * @example
   *   // POST /services/data/v59.0/sobjects/PlatformEvent__e
   *   // Body: { "Message__c": "Order completed", "Priority__c": "High" }
   *   // Response (201): { "id": "e00...", "success": true, "errors": [] }
   */
  app.post('/services/data/:version/sobjects/:object', (req, res, next) => {
    const objectName = req.params.object;

    // Only intercept Platform Event objects (suffix __e)
    if (!objectName.endsWith('__e')) {
      return next(); // Pass to rest-routes.js for regular CRUD
    }

    const schema = schemas[objectName];

    // Determine the event channel
    const channel = `/event/${objectName}`;

    // Generate event ID
    const idPrefix = schema ? schema.idPrefix : 'e00';
    const eventId = generateId(idPrefix);

    // Add system fields to the event payload
    const payload = {
      ...req.body,
      CreatedDate: new Date().toISOString(),
      CreatedById: '005000000000000AAA'
    };

    // Publish to event bus
    eventBus.publish(channel, payload);

    console.log(`  📢 Published Platform Event: ${objectName} (${eventId})`);

    // Return standard Salesforce create response
    res.status(201).json({
      id: eventId,
      success: true,
      errors: []
    });
  });

  /**
   * GET /services/data/:version/sobjects/:object/describe
   * WHERE :object ends with __e (Platform Event describe)
   *
   * Returns Platform Event metadata. We need to intercept this
   * before rest-routes.js to add event-specific metadata.
   *
   * Note: This is handled by rest-routes.js generic describe since
   * PlatformEvent__e has a schema file. No special handling needed.
   * The schema system already handles __e objects correctly.
   */

  // ═══════════════════════════════════════════════════════════════════════
  // COMETD / BAYEUX STREAMING PROTOCOL
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * POST /cometd/:version
   *
   * CometD Bayeux protocol handler. All CometD messages go to this single
   * endpoint, differentiated by the "channel" field in the JSON body.
   *
   * The request body is an array of message objects. Each message has a
   * "channel" field that determines the operation:
   *   /meta/handshake  → Create client session
   *   /meta/subscribe  → Subscribe to event channel
   *   /meta/connect    → Long-poll for events
   *   /meta/disconnect → Cleanup client session
   *
   * @example
   *   // Handshake:
   *   // POST /cometd/59.0
   *   // Body: [{ "channel": "/meta/handshake", "version": "1.0", "supportedConnectionTypes": ["long-polling"] }]
   *   // Response: [{ "channel": "/meta/handshake", "successful": true, "clientId": "mock-client-1-...", ... }]
   *
   * @example
   *   // Subscribe:
   *   // POST /cometd/59.0
   *   // Body: [{ "channel": "/meta/subscribe", "clientId": "...", "subscription": "/event/PlatformEvent__e" }]
   *   // Response: [{ "channel": "/meta/subscribe", "successful": true, "subscription": "/event/PlatformEvent__e" }]
   *
   * @example
   *   // Connect (long-poll):
   *   // POST /cometd/59.0
   *   // Body: [{ "channel": "/meta/connect", "clientId": "...", "connectionType": "long-polling" }]
   *   // Response: [{ ...event data... }, { "channel": "/meta/connect", "successful": true }]
   */
  app.post('/cometd/:version', (req, res) => {
    // CometD sends an array of messages
    const messages = Array.isArray(req.body) ? req.body : [req.body];
    const responses = [];

    for (const message of messages) {
      const channel = message.channel;

      switch (channel) {
        case '/meta/handshake':
          responses.push(handleHandshake(message, eventBus));
          break;

        case '/meta/subscribe':
          responses.push(handleSubscribe(message, eventBus));
          break;

        case '/meta/unsubscribe':
          responses.push(handleUnsubscribe(message, eventBus));
          break;

        case '/meta/connect':
          responses.push(...handleConnect(message, eventBus));
          break;

        case '/meta/disconnect':
          responses.push(handleDisconnect(message, eventBus));
          break;

        default:
          // Unknown channel — return error
          responses.push({
            channel: channel,
            successful: false,
            error: `Unknown meta channel: ${channel}`,
            id: message.id
          });
      }
    }

    res.json(responses);
  });
}

// ═══════════════════════════════════════════════════════════════════════
// COMETD MESSAGE HANDLERS
// ═══════════════════════════════════════════════════════════════════════

/**
 * Handles CometD handshake — creates a new client session.
 *
 * @param {Object} message - CometD handshake message
 * @param {Object} eventBus - Event bus instance
 * @returns {Object} CometD handshake response
 */
function handleHandshake(message, eventBus) {
  const clientId = eventBus.createClient();

  return {
    channel: '/meta/handshake',
    version: '1.0',
    minimumVersion: '1.0',
    clientId: clientId,
    supportedConnectionTypes: ['long-polling'],
    successful: true,
    id: message.id,
    ext: {
      replay: true,
      payload: true
    },
    advice: {
      reconnect: 'retry',
      interval: 0,
      timeout: 110000
    }
  };
}

/**
 * Handles CometD subscribe — adds a channel subscription for the client.
 *
 * @param {Object} message - CometD subscribe message
 * @param {Object} eventBus - Event bus instance
 * @returns {Object} CometD subscribe response
 */
function handleSubscribe(message, eventBus) {
  const clientId = message.clientId;
  const subscription = message.subscription;

  // Extract replay ID from extension if provided
  // SnapLogic sends: { ext: { replay: { "/event/MyEvent__e": -1 } } }
  let replayId = -1;
  if (message.ext && message.ext.replay && message.ext.replay[subscription] !== undefined) {
    replayId = message.ext.replay[subscription];
  }

  const success = eventBus.subscribe(clientId, subscription, replayId);

  return {
    channel: '/meta/subscribe',
    clientId: clientId,
    subscription: subscription,
    successful: success,
    id: message.id,
    error: success ? undefined : `Client ${clientId} not found`
  };
}

/**
 * Handles CometD unsubscribe — removes a channel subscription.
 *
 * @param {Object} message - CometD unsubscribe message
 * @param {Object} eventBus - Event bus instance
 * @returns {Object} CometD unsubscribe response
 */
function handleUnsubscribe(message, eventBus) {
  // For simplicity, unsubscribe just acknowledges without removing
  // (the mock doesn't need sophisticated subscription management)
  return {
    channel: '/meta/unsubscribe',
    clientId: message.clientId,
    subscription: message.subscription,
    successful: true,
    id: message.id
  };
}

/**
 * Handles CometD connect (long-poll) — returns new events.
 *
 * In a real Salesforce instance, this would hold the connection open
 * until events arrive or timeout. For the mock, we respond immediately
 * with any available events.
 *
 * @param {Object} message - CometD connect message
 * @param {Object} eventBus - Event bus instance
 * @returns {Object[]} Array of event messages + connect acknowledgment
 */
function handleConnect(message, eventBus) {
  const clientId = message.clientId;
  const responses = [];

  // Get new events for this client's subscriptions
  const newEvents = eventBus.connect(clientId);

  // Add event data messages
  for (const event of newEvents) {
    responses.push(event);
  }

  // Always end with a connect acknowledgment
  responses.push({
    channel: '/meta/connect',
    clientId: clientId,
    successful: true,
    id: message.id,
    advice: {
      reconnect: 'retry',
      interval: 0,
      timeout: 110000
    }
  });

  if (newEvents.length > 0) {
    console.log(`  📨 CometD delivered ${newEvents.length} events to ${clientId}`);
  }

  return responses;
}

/**
 * Handles CometD disconnect — cleans up the client session.
 *
 * @param {Object} message - CometD disconnect message
 * @param {Object} eventBus - Event bus instance
 * @returns {Object} CometD disconnect response
 */
function handleDisconnect(message, eventBus) {
  const clientId = message.clientId;
  eventBus.disconnect(clientId);

  return {
    channel: '/meta/disconnect',
    clientId: clientId,
    successful: true,
    id: message.id
  };
}

module.exports = { registerEventRoutes };
