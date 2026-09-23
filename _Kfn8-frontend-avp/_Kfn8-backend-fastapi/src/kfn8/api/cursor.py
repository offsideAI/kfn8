"""Opaque, signed pagination cursors: last sort tuple + filter fingerprint, HMAC-SHA256. A cursor reused with a different
filter is rejected rather than silently returning wrong pages."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json


class CursorError(ValueError):
    pass


def fingerprint(filters: dict) -> str:
    canonical = json.dumps({k: v for k, v in sorted(filters.items()) if v is not None}, sort_keys=True, default=str)
    return hashlib.sha256(canonical.encode()).hexdigest()[:16]


def encode(secret: str, key: list, filters: dict) -> str:
    payload = json.dumps({"k": key, "f": fingerprint(filters)}, separators=(",", ":"), default=str).encode()
    sig = hmac.new(secret.encode(), payload, hashlib.sha256).digest()[:12]
    return base64.urlsafe_b64encode(payload + sig).decode().rstrip("=")


def decode(secret: str, token: str, filters: dict) -> list:
    try:
        raw = base64.urlsafe_b64decode(token + "=" * (-len(token) % 4))
        payload, sig = raw[:-12], raw[-12:]
    except (ValueError, TypeError) as e:
        raise CursorError("malformed cursor") from e
    if not hmac.compare_digest(sig, hmac.new(secret.encode(), payload, hashlib.sha256).digest()[:12]):
        raise CursorError("cursor signature invalid")
    data = json.loads(payload)
    if data.get("f") != fingerprint(filters):
        raise CursorError("cursor does not match these filters")
    return data["k"]
