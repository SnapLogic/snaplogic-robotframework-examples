'use strict';

/**
 * Event Bus — In-Memory Event Pub/Sub + CometD Client State
 * ===========================================================
 *
 * Manages Platform Event publishing, CometD client sessions, and event delivery.
 * This is the shared state between the Publisher (writes events) and
 * Subscriber (reads events via CometD long-polling).
 *
 * Two responsibilities:
 *   1. EVENT STORAGE: Store published Platform Events with replayIds
 *   2. COMETD CLIENTS: Track handshake sessions, subscriptions, replay positions
 *
 * Usage:
 *   const { createEventBus } = require('./streaming/event-bus');
 *   const eventBus = createEventBus();
 *   eventBus.publish('/event/MyEvent__e', { Message__c: 'Hello' });
 *   const events = eventBus.getEvents('/event/MyEvent__e', 0);
 */

/**
 * Creates a new Event Bus instance.
 *
 * Uses the factory pattern (same as createJobStore) so that each
 * server instance gets its own isolated event state.
 *
 * @returns {Object} Event bus with publish, subscribe, CometD client management methods
 *
 * @example
 *   const eventBus = createEventBus();
 *
 *   // Publish an event
 *   const event = eventBus.publish('/event/PlatformEvent__e', {
 *     Message__c: 'Order completed',
 *     Priority__c: 'High'
 *   });
 *   // event = { replayId: 1, channel: '/event/PlatformEvent__e', payload: {...}, createdDate: '...' }
 *
 *   // Create a CometD client (handshake)
 *   const clientId = eventBus.createClient();
 *
 *   // Subscribe to a channel
 *   eventBus.subscribe(clientId, '/event/PlatformEvent__e');
 *
 *   // Get new events (connect/long-poll)
 *   const newEvents = eventBus.connect(clientId);
 *   // Returns events published after the client's last seen replayId
 */
function createEventBus() {
  // ═══════════════════════════════════════════════════════════════════════
  // EVENT STORAGE
  // ═══════════════════════════════════════════════════════════════════════

  /** @type {Map<string, Object[]>} channel → array of events */
  const events = new Map();

  /** @type {number} Global auto-incrementing replay ID counter */
  let replayCounter = 0;

  // ═══════════════════════════════════════════════════════════════════════
  // COMETD CLIENT STATE
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * @type {Map<string, Object>} clientId → client session
   * Each session: {
   *   id: string,
   *   subscriptions: Set<string>,       // channels subscribed to
   *   lastReplayIds: Map<string, number>, // channel → last seen replayId
   *   createdAt: string
   * }
   */
  const clients = new Map();

  /** @type {number} Auto-incrementing client ID counter */
  let clientCounter = 0;

  // ═══════════════════════════════════════════════════════════════════════
  // EVENT PUBLISHING
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * Publishes an event to a channel.
   *
   * @param {string} channel - Event channel (e.g., '/event/PlatformEvent__e')
   * @param {Object} payload - Event payload data
   * @returns {Object} The stored event with replayId
   */
  function publish(channel, payload) {
    replayCounter++;
    const event = {
      replayId: replayCounter,
      channel,
      payload: { ...payload },
      createdDate: new Date().toISOString()
    };

    if (!events.has(channel)) {
      events.set(channel, []);
    }
    events.get(channel).push(event);

    console.log(`  📢 Event published: ${channel} (replayId: ${replayCounter})`);
    return event;
  }

  /**
   * Gets events on a channel after a given replayId.
   *
   * @param {string} channel - Event channel
   * @param {number} fromReplayId - Return events with replayId > this value
   *   Special values:
   *     -1 = get only new events (from tip)
   *     -2 = get all events from the earliest available
   * @returns {Object[]} Array of matching events
   */
  function getEvents(channel, fromReplayId) {
    const channelEvents = events.get(channel) || [];

    if (fromReplayId === -2) {
      // All available events
      return [...channelEvents];
    }

    if (fromReplayId === -1) {
      // Only new events (nothing available yet — will be delivered on next connect)
      return [];
    }

    // Events after the given replayId
    return channelEvents.filter(e => e.replayId > fromReplayId);
  }

  /**
   * Returns all channels that have events.
   * @returns {string[]} Array of channel names
   */
  function getChannels() {
    return Array.from(events.keys());
  }

  /**
   * Returns all events across all channels.
   * @returns {Object} { channels: { channelName: { count, events } }, totalEvents }
   */
  function getAllEvents() {
    const result = { channels: {}, totalEvents: 0 };
    for (const [channel, channelEvents] of events) {
      result.channels[channel] = {
        count: channelEvents.length,
        events: channelEvents
      };
      result.totalEvents += channelEvents.length;
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COMETD CLIENT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /**
   * Creates a new CometD client session (handshake).
   *
   * @returns {string} The new client ID
   */
  function createClient() {
    clientCounter++;
    const clientId = `mock-client-${clientCounter}-${Date.now()}`;
    clients.set(clientId, {
      id: clientId,
      subscriptions: new Set(),
      lastReplayIds: new Map(),
      createdAt: new Date().toISOString()
    });
    console.log(`  🤝 CometD client created: ${clientId}`);
    return clientId;
  }

  /**
   * Subscribes a client to a channel.
   *
   * @param {string} clientId - The client ID from handshake
   * @param {string} channel - Event channel to subscribe to
   * @param {number} [replayId=-1] - Starting replay position (-1=tip, -2=earliest)
   * @returns {boolean} true if subscription succeeded
   */
  function subscribe(clientId, channel, replayId) {
    const client = clients.get(clientId);
    if (!client) return false;

    client.subscriptions.add(channel);
    // Default replay position: -1 (tip — only new events)
    client.lastReplayIds.set(channel, replayId !== undefined ? replayId : -1);
    console.log(`  📫 CometD subscribe: ${clientId} → ${channel} (replayId: ${client.lastReplayIds.get(channel)})`);
    return true;
  }

  /**
   * Processes a CometD connect (long-poll) request.
   * Returns new events for all of the client's subscribed channels.
   *
   * For each subscribed channel, returns events after the client's
   * last seen replayId, then advances the replay position.
   *
   * @param {string} clientId - The client ID
   * @returns {Object[]} Array of CometD event messages to deliver
   */
  function connect(clientId) {
    const client = clients.get(clientId);
    if (!client) return [];

    const deliverableEvents = [];

    for (const channel of client.subscriptions) {
      const lastReplayId = client.lastReplayIds.get(channel) || -1;
      const newEvents = getEvents(channel, lastReplayId);

      for (const event of newEvents) {
        deliverableEvents.push({
          channel: event.channel,
          data: {
            payload: event.payload,
            event: { replayId: event.replayId }
          }
        });
        // Advance the client's replay position
        client.lastReplayIds.set(channel, event.replayId);
      }
    }

    return deliverableEvents;
  }

  /**
   * Disconnects a CometD client, cleaning up its session.
   *
   * @param {string} clientId - The client ID to disconnect
   * @returns {boolean} true if the client existed and was removed
   */
  function disconnect(clientId) {
    const existed = clients.delete(clientId);
    if (existed) {
      console.log(`  👋 CometD client disconnected: ${clientId}`);
    }
    return existed;
  }

  /**
   * Returns all active CometD client sessions (for admin endpoint).
   * @returns {Object} { count, clients: [...] }
   */
  function getClients() {
    const clientList = [];
    for (const [id, session] of clients) {
      clientList.push({
        id,
        subscriptions: Array.from(session.subscriptions),
        lastReplayIds: Object.fromEntries(session.lastReplayIds),
        createdAt: session.createdAt
      });
    }
    return { count: clientList.length, clients: clientList };
  }

  /**
   * Clears all events and client sessions.
   * Called by POST /__admin/reset.
   *
   * @returns {Object} { eventsCleared, clientsCleared }
   */
  function clear() {
    let eventsCleared = 0;
    for (const channelEvents of events.values()) {
      eventsCleared += channelEvents.length;
    }
    const clientsCleared = clients.size;

    events.clear();
    clients.clear();
    replayCounter = 0;
    clientCounter = 0;

    return { eventsCleared, clientsCleared };
  }

  return {
    // Event operations
    publish,
    getEvents,
    getChannels,
    getAllEvents,

    // CometD client operations
    createClient,
    subscribe,
    connect,
    disconnect,
    getClients,

    // Admin
    clear
  };
}

module.exports = { createEventBus };
