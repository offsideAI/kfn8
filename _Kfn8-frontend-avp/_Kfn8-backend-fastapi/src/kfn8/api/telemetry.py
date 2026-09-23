"""Server-side operational telemetry: one structured log line per request (route template, status, latency, response
bytes, request id). No client identifiers beyond what the platform already sees, no query strings, no bodies, no
headers. This is service health, not product analytics; there is no client SDK or event endpoint."""
from __future__ import annotations

import json
import logging
import time

from starlette.types import ASGIApp, Message, Receive, Scope, Send

log = logging.getLogger("kfn8.requests")


class RequestTelemetry:
    def __init__(self, app: ASGIApp, sink=None):
        self.app = app
        self.sink = sink or (lambda record: log.info(json.dumps(record, separators=(",", ":"))))

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        start = time.perf_counter()
        status, size, request_id = 500, 0, None

        async def wrapped(message: Message) -> None:
            nonlocal status, size, request_id
            if message["type"] == "http.response.start":
                status = message["status"]
                for k, v in message.get("headers", []):
                    if k == b"x-request-id":
                        request_id = v.decode()
            elif message["type"] == "http.response.body":
                size += len(message.get("body", b""))
            await send(message)

        try:
            await self.app(scope, receive, wrapped)
        finally:
            route = scope.get("route")
            self.sink({
                "route": getattr(route, "path", None) or "unmatched",  # template, never the raw path with IDs/queries
                "method": scope.get("method"),
                "status": status,
                "ms": round((time.perf_counter() - start) * 1000, 2),
                "bytes": size,
                "request_id": request_id,
            })
