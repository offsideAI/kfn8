from httpx import ASGITransport, AsyncClient

from kfn8.api.app import RateLimiter, create_app
from kfn8.api.telemetry import RequestTelemetry


async def test_request_telemetry_is_redacted(settings, sessions):
    records = []
    app = RequestTelemetry(create_app(settings, sessions, RateLimiter(10_000)), sink=records.append)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        await c.get("/v1/assets", params={"q": "secret search"}, headers={"Authorization": "Bearer should-not-appear"})
        await c.get("/v1/assets/00000000-0000-4000-8000-000000000000")
    assert records[0]["route"] == "/v1/assets" and records[0]["status"] == 200 and records[0]["bytes"] > 0
    assert records[1]["route"] == "/v1/assets/{asset_id}" and records[1]["status"] == 404
    flat = str(records)
    assert "secret" not in flat and "Bearer" not in flat and "00000000-0000-4000-8000-000000000000" not in flat
    assert all(r["request_id"] for r in records)
