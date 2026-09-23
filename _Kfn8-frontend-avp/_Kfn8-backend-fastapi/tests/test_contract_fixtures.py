"""Record real API v1 responses as fixtures for the Swift client's decoding tests (contract round trip, no server)."""
import json
from pathlib import Path

from conftest import make_asset
from sqlalchemy import update

from kfn8.db.models import AssetRevision, Revocation

FIXTURES = Path(__file__).resolve().parents[2] / "_Kfn8-frontend-avp-src/Packages/Kfn8Kit/Tests/Kfn8CatalogueTests/Fixtures"


async def test_record_fixtures(client, db):
    chair, rev = await make_asset(db, "Chair", offers=[("US", "USD", 49900)])
    await make_asset(db, "Vase", affinity="tabletop", category="decor")
    _, gone = await make_asset(db, "Gone")
    await db.execute(update(AssetRevision).where(AssetRevision.id == gone.id).values(state="revoked"))
    db.add(Revocation(revision_id=gone.id, reason="rights"))
    await db.commit()
    responses = {
        "assets_page.json": await client.get("/v1/assets", params={"limit": 1}),
        "asset_detail.json": await client.get(f"/v1/assets/{chair.id}"),
        "revision_detail.json": await client.get(f"/v1/assets/{chair.id}/revisions/1"),
        "revocations.json": await client.get("/v1/revocations"),
        "error_not_found.json": await client.get("/v1/assets/00000000-0000-4000-8000-000000000000"),
        "error_revoked.json": await client.get(f"/v1/assets/{gone.asset_id}/revisions/1"),
    }
    FIXTURES.mkdir(parents=True, exist_ok=True)
    for name, r in responses.items():
        (FIXTURES / name).write_text(json.dumps({"status": r.status_code, "body": r.json()}, indent=2, sort_keys=True))
    assert responses["asset_detail.json"].status_code == 200
    assert responses["error_revoked.json"].status_code == 410
