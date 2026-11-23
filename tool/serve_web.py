"""Serves build/web on http://localhost:8081 with caching turned off, so a
browser refresh always loads the newest build.

Port 8081, not 8080: an earlier server on 8080 sent no cache headers, and
Chrome kept serving a stale main.dart.js from that origin even after reloads.
A new port is a new origin with an empty cache.

Usage: python3 tool/serve_web.py
"""
import functools
import http.server
from pathlib import Path


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


web = Path(__file__).resolve().parent.parent / 'build' / 'web'
handler = functools.partial(NoCacheHandler, directory=str(web))
print('Serving http://localhost:8081')
http.server.ThreadingHTTPServer(('', 8081), handler).serve_forever()
