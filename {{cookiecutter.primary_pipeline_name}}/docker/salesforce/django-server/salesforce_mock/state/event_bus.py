"""
Platform Event Bus
==================
Port of: lib/streaming/event-bus.js

In-memory event bus for Platform Events and CometD streaming.
Singleton class replacing Node.js factory function.

Manages:
  - Event publishing with replay IDs
  - CometD client sessions
  - Channel subscriptions with replay positions
"""
import uuid
from datetime import datetime, timezone

from salesforce_mock.utils.id_generator import generate_id


class EventBus:
    """Manages Platform Events and CometD client sessions."""

    def __init__(self):
        self._events = {}      # channel -> [event, ...]
        self._clients = {}     # clientId -> {subscriptions, connectedAt}
        self._replay_counter = 0

    def publish(self, channel, payload):
        """
        Publish an event to a channel.
        Assigns a replay ID and stores the event.
        """
        self._replay_counter += 1
        event = {
            'replayId': self._replay_counter,
            'payload': payload,
            'createdDate': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        }
        if channel not in self._events:
            self._events[channel] = []
        self._events[channel].append(event)
        return generate_id('e00')

    def create_client(self):
        """Create a new CometD client session."""
        client_id = f'mock-client-{uuid.uuid4().hex[:12]}'
        self._clients[client_id] = {
            'subscriptions': {},
            'connectedAt': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        }
        return client_id

    def subscribe(self, client_id, channel, replay_id=-1):
        """Subscribe a client to a channel with a replay position."""
        client = self._clients.get(client_id)
        if not client:
            return False
        client['subscriptions'][channel] = {
            'replayFrom': replay_id,
        }
        return True

    def unsubscribe(self, client_id, channel):
        """Unsubscribe a client from a channel."""
        client = self._clients.get(client_id)
        if client and channel in client.get('subscriptions', {}):
            del client['subscriptions'][channel]
            return True
        return False

    def connect(self, client_id):
        """
        Poll for new events for a client.
        Returns events after the client's replay position.
        """
        client = self._clients.get(client_id)
        if not client:
            return []

        events = []
        for channel, sub in client['subscriptions'].items():
            replay_from = sub.get('replayFrom', -1)
            channel_events = self._events.get(channel, [])

            for event in channel_events:
                if replay_from == -2:
                    # Replay all events
                    events.append({'channel': channel, 'data': event})
                elif replay_from == -1:
                    # Only new events (tip) — none pending since this is synchronous
                    pass
                elif event['replayId'] > replay_from:
                    events.append({'channel': channel, 'data': event})

            # Update replay position to latest
            if channel_events:
                sub['replayFrom'] = channel_events[-1]['replayId']

        return events

    def disconnect(self, client_id):
        """Remove a client session."""
        return self._clients.pop(client_id, None) is not None

    def get_all_events(self):
        """Return all events grouped by channel (for admin inspection)."""
        channels = {}
        total = 0
        for channel, events in self._events.items():
            channels[channel] = {'count': len(events), 'events': events}
            total += len(events)
        return {'channels': channels, 'totalEvents': total}

    def get_clients(self):
        """Return all connected clients (for admin inspection)."""
        clients = []
        for client_id, data in self._clients.items():
            clients.append({
                'id': client_id,
                'subscriptions': list(data['subscriptions'].keys()),
                'connectedAt': data['connectedAt'],
            })
        return {'count': len(clients), 'clients': clients}

    def clear(self):
        """Reset all events and clients."""
        events_cleared = sum(len(v) for v in self._events.values())
        clients_cleared = len(self._clients)
        self._events.clear()
        self._clients.clear()
        self._replay_counter = 0
        return {'eventsCleared': events_cleared, 'clientsCleared': clients_cleared}


# Module-level singleton
event_bus = EventBus()
