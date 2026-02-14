#!/usr/bin/env python3
"""
Dual-Protocol WSGI Server (HTTP + HTTPS)
=========================================
Serves the Django WSGI application on both HTTP and HTTPS in a SINGLE process,
so all in-memory state (database, job_store, event_bus) is shared across
both protocols — matching the Node.js custom server behavior.

Why not gunicorn?
  gunicorn with --workers N forks N separate processes. In-memory Python dicts
  (database, job_store) are NOT shared between processes. Even with --workers 1,
  running two gunicorn instances (one HTTP, one HTTPS) creates two processes
  with isolated state. This script solves that by running both protocols in
  the same process with threading.

Architecture:
  Main Thread  → HTTPS server (ssl-wrapped WSGIServer)
  Child Thread → HTTP server  (plain WSGIServer)
  Both share the same Django WSGI application and in-memory state.

Usage:
  python run_server.py
  (configured via environment variables — see entrypoint.sh)
"""
import os
import ssl
import sys
import threading
import logging
from socketserver import ThreadingMixIn
from wsgiref.simple_server import make_server, WSGIServer, WSGIRequestHandler

# =====================================================================
# Setup Django before importing the WSGI application
# =====================================================================
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'salesforce_mock.settings')

import django
django.setup()

from salesforce_mock.wsgi import application

# =====================================================================
# Configuration
# =====================================================================
HTTP_PORT = int(os.environ.get('HTTP_PORT', '8080'))
HTTPS_PORT = int(os.environ.get('HTTPS_PORT', '8443'))
CERT_PEM = os.environ.get('CERT_PEM', '/app/certs/cert.pem')
KEY_PEM = os.environ.get('KEY_PEM', '/app/certs/key.pem')

logger = logging.getLogger('salesforce_mock')


# =====================================================================
# Custom WSGI Request Handler (suppress noisy default logging)
# =====================================================================
class QuietWSGIHandler(WSGIRequestHandler):
    """Custom handler that logs in a cleaner format."""

    def log_message(self, format, *args):
        # Log using Python logging instead of stderr
        logger.info("%s %s", self.client_address[0], format % args)

    def log_request(self, code='-', size='-'):
        # Log each request on a single line
        logger.info('%s "%s" %s %s',
                    self.client_address[0],
                    self.requestline,
                    str(code),
                    str(size))


# =====================================================================
# Threading WSGI Server (handles concurrent requests)
# =====================================================================
class ThreadingWSGIServer(ThreadingMixIn, WSGIServer):
    """WSGIServer that handles each request in a new thread.

    The default WSGIServer handles requests serially. This subclass
    uses ThreadingMixIn so multiple requests can be processed concurrently,
    which is important when SnapLogic sends overlapping requests (e.g.,
    a bulk upload while polling job status).

    All threads share the same process memory, so in-memory state
    (database, job_store) is consistent across all requests.
    """
    daemon_threads = True


class HTTPSSchemeMiddleware:
    """WSGI middleware that forces wsgi.url_scheme='https' for HTTPS server.

    wsgiref.simple_server does NOT detect SSL-wrapped sockets, so
    Django's request.is_secure() returns False even for HTTPS requests.
    This middleware wraps the WSGI app for the HTTPS server to set the
    correct scheme, which Django uses for request.is_secure() and for
    building the instance_url in OAuth token responses.
    """

    def __init__(self, app):
        self.app = app

    def __call__(self, environ, start_response):
        environ['wsgi.url_scheme'] = 'https'
        return self.app(environ, start_response)


class StoppableWSGIServer:
    """Wraps ThreadingWSGIServer with start/stop lifecycle."""

    def __init__(self, host, port, app, ssl_context=None, name='HTTP'):
        self.name = name
        self.port = port

        # Wrap app with HTTPS scheme middleware for SSL servers
        if ssl_context:
            app = HTTPSSchemeMiddleware(app)

        self.server = make_server(
            host, port, app,
            server_class=ThreadingWSGIServer,
            handler_class=QuietWSGIHandler,
        )

        if ssl_context:
            self.server.socket = ssl_context.wrap_socket(
                self.server.socket,
                server_side=True,
            )

    def serve_forever(self):
        """Blocking call — runs until shutdown() is called."""
        self.server.serve_forever()

    def shutdown(self):
        """Graceful shutdown."""
        self.server.shutdown()


# =====================================================================
# Main: Start both HTTP and HTTPS servers
# =====================================================================
def main():
    print("======================================================")
    print("  Salesforce Django Mock API Server")
    print("======================================================")
    print(f"  HTTP Port:  {HTTP_PORT}")
    print(f"  HTTPS Port: {HTTPS_PORT}")
    print(f"  Schema Dir: {os.environ.get('SCHEMA_DIR', '/app/schemas')}")
    print("  Mode:       Single-process (shared in-memory state)")
    print("======================================================")
    print()

    servers = []

    # -----------------------------------------------------------------
    # Start HTTP server in a background thread
    # -----------------------------------------------------------------
    http_server = StoppableWSGIServer('0.0.0.0', HTTP_PORT, application, name='HTTP')
    http_thread = threading.Thread(
        target=http_server.serve_forever,
        name='http-server',
        daemon=True,
    )
    http_thread.start()
    servers.append(http_server)
    print(f"  🌐 HTTP  server listening on port {HTTP_PORT}")

    # -----------------------------------------------------------------
    # Start HTTPS server in the main thread (if cert available)
    # -----------------------------------------------------------------
    if os.path.isfile(CERT_PEM) and os.path.isfile(KEY_PEM):
        ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ssl_context.load_cert_chain(certfile=CERT_PEM, keyfile=KEY_PEM)
        # Accept self-signed certs (this IS a mock server)
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        https_server = StoppableWSGIServer(
            '0.0.0.0', HTTPS_PORT, application,
            ssl_context=ssl_context, name='HTTPS',
        )
        servers.append(https_server)
        print(f"  🔒 HTTPS server listening on port {HTTPS_PORT}")
        print(f"     📌 Using certificate: {CERT_PEM}")
        print()

        # Run HTTPS in main thread (blocks until Ctrl+C / SIGTERM)
        try:
            https_server.serve_forever()
        except KeyboardInterrupt:
            print("\n  Shutting down...")
    else:
        print(f"  ⚠️  Certificate not found: {CERT_PEM}")
        print(f"     HTTPS will not be available")
        print()

        # No HTTPS — block on HTTP thread instead
        try:
            http_thread.join()
        except KeyboardInterrupt:
            print("\n  Shutting down...")

    # Graceful shutdown
    for server in servers:
        server.shutdown()

    print("  Server stopped.")


if __name__ == '__main__':
    main()
