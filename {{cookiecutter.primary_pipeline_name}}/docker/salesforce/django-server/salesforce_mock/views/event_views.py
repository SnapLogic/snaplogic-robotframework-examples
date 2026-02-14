"""
Platform Event & CometD Streaming Views
========================================
Port of: lib/routes/event-routes.js

Implements two related Salesforce features:

1. PUBLISHER -- Platform Event publishing via REST API
   POST /services/data/:version/sobjects/MyEvent__e
   Used by: SnapLogic "Salesforce Publisher" snap

2. SUBSCRIBER -- CometD (Bayeux) streaming protocol
   POST /cometd/:version
   Used by: SnapLogic "Salesforce Subscriber" snap

Platform Events are a special Salesforce object type (suffix __e).
Unlike regular sObjects, events are NOT stored in the database --
they're published to the event bus and delivered to subscribers via CometD.

IMPORTANT: These URL patterns MUST be registered BEFORE rest views!
The generic POST /sobjects/:object in rest_views.py would match __e objects
and try to store them as regular CRUD records.

CometD Protocol Flow:
  1. Handshake  -> returns clientId
  2. Subscribe  -> registers channel subscription
  3. Connect    -> long-poll for new events
  4. Disconnect -> cleanup
"""
import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from salesforce_mock.state.database import schemas
from salesforce_mock.utils.id_generator import generate_id
from salesforce_mock.utils.error_formatter import format_error
from salesforce_mock.state.event_bus import event_bus
from datetime import datetime, timezone


# ==========================================================================
# PLATFORM EVENT PUBLISHER
# ==========================================================================

@csrf_exempt
def publish_event(request, version, object_name):
    """
    POST /services/data/:version/sobjects/:object
    WHERE :object ends with __e (Platform Event)

    Publishes a Platform Event to the event bus.
    Unlike regular REST Create, events are NOT stored in database.
    They go to the event bus and are delivered via CometD.

    Example:
        POST /services/data/v59.0/sobjects/PlatformEvent__e
        Body: { "Message__c": "Order completed", "Priority__c": "High" }
        Response (201): { "id": "e00...", "success": true, "errors": [] }
    """
    body = json.loads(request.body)

    # Determine the event channel
    channel = f'/event/{object_name}'

    # Generate event ID
    schema = schemas.get(object_name)
    id_prefix = schema['idPrefix'] if schema and 'idPrefix' in schema else 'e00'
    event_id = generate_id(id_prefix)

    # Add system fields to the event payload
    payload = {
        **body,
        'CreatedDate': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
        'CreatedById': '005000000000000AAA',
    }

    # Publish to event bus
    event_bus.publish(channel, payload)

    print(f'  \U0001f4e2 Published Platform Event: {object_name} ({event_id})')

    # Return standard Salesforce create response
    return JsonResponse(
        {'id': event_id, 'success': True, 'errors': []},
        status=201,
    )


# ==========================================================================
# COMETD / BAYEUX STREAMING PROTOCOL
# ==========================================================================

@csrf_exempt
def cometd_handler(request, version):
    """
    POST /cometd/:version

    CometD Bayeux protocol handler. All CometD messages go to this single
    endpoint, differentiated by the "channel" field in the JSON body.

    The request body is an array of message objects. Each message has a
    "channel" field that determines the operation:
      /meta/handshake   -> Create client session
      /meta/subscribe   -> Subscribe to event channel
      /meta/unsubscribe -> Remove channel subscription
      /meta/connect     -> Long-poll for events
      /meta/disconnect  -> Cleanup client session

    Example (Handshake):
        POST /cometd/59.0
        Body: [{ "channel": "/meta/handshake", "version": "1.0",
                 "supportedConnectionTypes": ["long-polling"] }]
        Response: [{ "channel": "/meta/handshake", "successful": true,
                     "clientId": "mock-client-...", ... }]

    Example (Subscribe):
        POST /cometd/59.0
        Body: [{ "channel": "/meta/subscribe", "clientId": "...",
                 "subscription": "/event/PlatformEvent__e" }]
        Response: [{ "channel": "/meta/subscribe", "successful": true,
                     "subscription": "/event/PlatformEvent__e" }]

    Example (Connect / long-poll):
        POST /cometd/59.0
        Body: [{ "channel": "/meta/connect", "clientId": "...",
                 "connectionType": "long-polling" }]
        Response: [{ ...event data... },
                   { "channel": "/meta/connect", "successful": true }]
    """
    body = json.loads(request.body)

    # CometD sends an array of messages
    messages = body if isinstance(body, list) else [body]
    responses = []

    for message in messages:
        channel = message.get('channel', '')

        if channel == '/meta/handshake':
            responses.append(_handle_handshake(message))

        elif channel == '/meta/subscribe':
            responses.append(_handle_subscribe(message))

        elif channel == '/meta/unsubscribe':
            responses.append(_handle_unsubscribe(message))

        elif channel == '/meta/connect':
            # Connect returns MULTIPLE responses (events + acknowledgment)
            responses.extend(_handle_connect(message))

        elif channel == '/meta/disconnect':
            responses.append(_handle_disconnect(message))

        else:
            # Unknown channel -- return error
            responses.append({
                'channel': channel,
                'successful': False,
                'error': f'Unknown meta channel: {channel}',
                'id': message.get('id'),
            })

    return JsonResponse(responses, safe=False)


# ==========================================================================
# COMETD MESSAGE HANDLERS (private helpers)
# ==========================================================================

def _handle_handshake(message):
    """
    Handle CometD handshake -- creates a new client session.

    Returns:
        dict: CometD handshake response with clientId and session config.
    """
    client_id = event_bus.create_client()

    return {
        'channel': '/meta/handshake',
        'version': '1.0',
        'minimumVersion': '1.0',
        'clientId': client_id,
        'supportedConnectionTypes': ['long-polling'],
        'successful': True,
        'id': message.get('id'),
        'ext': {
            'replay': True,
            'payload': True,
        },
        'advice': {
            'reconnect': 'retry',
            'interval': 0,
            'timeout': 110000,
        },
    }


def _handle_subscribe(message):
    """
    Handle CometD subscribe -- adds a channel subscription for the client.

    Extracts the replay ID from the extension block if provided.
    SnapLogic sends: { ext: { replay: { "/event/MyEvent__e": -1 } } }

    Returns:
        dict: CometD subscribe response.
    """
    client_id = message.get('clientId')
    subscription = message.get('subscription')

    # Extract replay ID from extension if provided
    replay_id = message.get('ext', {}).get('replay', {}).get(subscription, -1)

    success = event_bus.subscribe(client_id, subscription, replay_id)

    response = {
        'channel': '/meta/subscribe',
        'clientId': client_id,
        'subscription': subscription,
        'successful': success,
        'id': message.get('id'),
    }

    if not success:
        response['error'] = f'Client {client_id} not found'

    return response


def _handle_unsubscribe(message):
    """
    Handle CometD unsubscribe -- acknowledges subscription removal.

    For simplicity, unsubscribe just acknowledges without removing
    (the mock doesn't need sophisticated subscription management).

    Returns:
        dict: CometD unsubscribe acknowledgment.
    """
    return {
        'channel': '/meta/unsubscribe',
        'clientId': message.get('clientId'),
        'subscription': message.get('subscription'),
        'successful': True,
        'id': message.get('id'),
    }


def _handle_connect(message):
    """
    Handle CometD connect (long-poll) -- returns new events.

    In a real Salesforce instance, this would hold the connection open
    until events arrive or timeout. For the mock, we respond immediately
    with any available events.

    Returns:
        list: Array of event messages + connect acknowledgment dict.
    """
    client_id = message.get('clientId')
    responses = []

    # Get new events for this client's subscriptions
    new_events = event_bus.connect(client_id)

    # Add event data messages
    for event in new_events:
        responses.append(event)

    # Always end with a connect acknowledgment
    responses.append({
        'channel': '/meta/connect',
        'clientId': client_id,
        'successful': True,
        'id': message.get('id'),
        'advice': {
            'reconnect': 'retry',
            'interval': 0,
            'timeout': 110000,
        },
    })

    if new_events:
        print(f'  \U0001f4e8 CometD delivered {len(new_events)} events to {client_id}')

    return responses


def _handle_disconnect(message):
    """
    Handle CometD disconnect -- cleans up the client session.

    Returns:
        dict: CometD disconnect acknowledgment.
    """
    client_id = message.get('clientId')
    event_bus.disconnect(client_id)

    return {
        'channel': '/meta/disconnect',
        'clientId': client_id,
        'successful': True,
        'id': message.get('id'),
    }
