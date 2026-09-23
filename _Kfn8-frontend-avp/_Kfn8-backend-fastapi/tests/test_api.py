import datetime as dt
import uuid

import pytest
from conftest import CATALOGUE, HASH, TENANT, make_asset
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError

from kfn8.db.models import Asset, AssetRevision, DimensionSpec, Offer, Revocation


async def test_health(client):
    assert (await client.get("/health/live")).json() == {"status": "ok"}
    assert (await client.get("/health/ready")).status_code == 200


async def test_only_published_public_assets_are_listed(client, db):
    await make_asset(db, "Chair")
    await make_asset(db, "Draft chair", state="review")
    await make_asset(db, "Private chair", delivery="restricted")
    body = (await client.get("/v1/assets")).json()
    assert [a["name"] for a in body["items"]] == ["Chair"]
    assert body["items"][0]["offer"] is None, "generic items have no fabricated price"


async def test_filters_and_search(client, db):
    await make_asset(db, "Oak chair", category="seating", affinity="floor", style=("scandi",))
    await make_asset(db, "Brass sconce", category="lighting", affinity="wall", colour="brass")
    names = lambda r: [a["name"] for a in r.json()["items"]]  # noqa: E731
    assert names(await client.get("/v1/assets", params={"affinity": "wall"})) == ["Brass sconce"]
    assert names(await client.get("/v1/assets", params={"q": "oak"})) == ["Oak chair"]
    assert names(await client.get("/v1/assets", params={"style": "scandi"})) == ["Oak chair"]
    assert names(await client.get("/v1/assets", params={"colour": "brass"})) == ["Brass sconce"]


async def test_pagination_is_stable_without_duplicates(client, db):
    for i in range(7):
        await make_asset(db, f"Item {i:02d}")
    await make_asset(db, "Item 03")  # duplicate name: ordering by (name, id) must still be stable
    seen, cursor = [], None
    while True:
        r = (await client.get("/v1/assets", params={"limit": 3, **({"cursor": cursor} if cursor else {})})).json()
        seen += [a["id"] for a in r["items"]]
        cursor = r["next_cursor"]
        if not cursor:
            break
    assert len(seen) == 8 and len(set(seen)) == 8


async def test_cursor_filter_mismatch_and_tampering_rejected(client, db):
    for i in range(3):
        await make_asset(db, f"Item {i}")
    cursor = (await client.get("/v1/assets", params={"limit": 1})).json()["next_cursor"]
    r = await client.get("/v1/assets", params={"limit": 1, "cursor": cursor, "category": "lighting"})
    assert r.status_code == 400 and r.json()["code"] == "invalid_cursor" and r.json()["request_id"]
    r = await client.get("/v1/assets", params={"cursor": cursor[:-2] + "AA"})
    assert r.status_code == 400


async def test_limit_is_bounded(client):
    r = await client.get("/v1/assets", params={"limit": 500})
    assert r.status_code == 400 and r.json()["code"] == "invalid_request"


async def test_detail_and_revision_with_cdn_urls(client, db):
    asset, rev = await make_asset(db, "Chair", offers=[("US", "USD", 49900)])
    d = (await client.get(f"/v1/assets/{asset.id}")).json()
    assert d["offer"]["amount_minor"] == 49900 and d["variants"] == [{"id": "default", "label": "Default"}]
    r = (await client.get(f"/v1/assets/{asset.id}/revisions/1")).json()
    assert r["revision_id"] == str(rev.id)
    assert {x["url"] for x in r["renditions"]} == {f"https://cdn.example.test/a/{asset.id}/r1/lod0.glb",
                                                   f"https://cdn.example.test/a/{asset.id}/r1/lod0.usdz"}
    assert all(x["sha256"] == HASH and x["size_bytes"] == 1000 for x in r["renditions"])


async def test_private_unknown_and_revoked(client, db):
    private, _ = await make_asset(db, "Private", delivery="restricted")
    assert (await client.get(f"/v1/assets/{private.id}")).status_code == 404
    assert (await client.get(f"/v1/assets/{uuid.uuid4()}")).json()["code"] == "not_found"
    asset, rev = await make_asset(db, "Revoked")
    await db.execute(update(AssetRevision).where(AssetRevision.id == rev.id).values(state="revoked"))
    db.add(Revocation(revision_id=rev.id, reason="rights"))
    await db.commit()
    r = await client.get(f"/v1/assets/{asset.id}/revisions/1")
    assert r.status_code == 410 and r.json()["code"] == "revoked"
    assert (await client.get(f"/v1/assets/{asset.id}/revisions/9")).status_code == 404


async def test_revocation_deltas_resume_from_cursor(client, db):
    revs = []
    for i in range(3):
        _, rev = await make_asset(db, f"R{i}")
        revs.append(rev)
    for rev in revs[:2]:
        db.add(Revocation(revision_id=rev.id, reason="rights"))
    await db.commit()
    first = (await client.get("/v1/revocations")).json()
    assert [i["revision_id"] for i in first["items"]] == [str(r.id) for r in revs[:2]] and not first["has_more"]
    db.add(Revocation(revision_id=revs[2].id, reason="rights"))
    await db.commit()
    delta = (await client.get("/v1/revocations", params={"cursor": first["next_cursor"]})).json()
    assert [i["revision_id"] for i in delta["items"]] == [str(revs[2].id)]
    empty = (await client.get("/v1/revocations", params={"cursor": delta["next_cursor"]})).json()
    assert empty["items"] == [] and empty["next_cursor"] == delta["next_cursor"]


async def test_rate_limit_returns_429(settings, sessions):
    from httpx import ASGITransport, AsyncClient

    from kfn8.api.app import RateLimiter, create_app
    app = create_app(settings, sessions, RateLimiter(per_minute=2))
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        codes = [(await c.get("/v1/catalogues")).status_code for _ in range(3)]
    assert codes == [200, 200, 429]


async def test_catalogues_lists_seeded_catalogue(client):
    assert (await client.get("/v1/catalogues")).json()["items"] == [{"id": str(CATALOGUE), "name": "Kfn8 generics"}]


# ---------------------------------------------------------------------------------------------- constraints


async def test_asset_tenant_must_match_catalogue_tenant(db):
    from kfn8.db.models import Tenant
    other = Tenant(id=uuid.uuid4(), name="Other")
    db.add(other)
    await db.commit()
    db.add(Asset(tenant_id=other.id, catalogue_id=CATALOGUE, name="x", category="c", affinity="floor", provenance="licensed"))
    with pytest.raises(IntegrityError):
        await db.commit()
    await db.rollback()


@pytest.mark.parametrize("field,value", [("state", "live"), ("revision", 0), ("source_sha256", "short")])
async def test_revision_constraints(db, field, value):
    asset, _ = await make_asset(db, "A")
    spec = DimensionSpec(width_m=1, depth_m=1, height_m=1, authority_kind="operator", source="s", approved_by="a",
                         approved_at=dt.datetime.now(dt.UTC), evidence_sha256=HASH)
    db.add(spec)
    await db.flush()
    values = dict(asset_id=asset.id, revision=2, state="draft", contract_version="1.0.0", source_sha256=HASH, dimension_spec_id=spec.id)
    values[field] = value
    db.add(AssetRevision(**values))
    with pytest.raises(Exception):  # noqa: B017 - CHECK or length violation
        await db.commit()
    await db.rollback()


async def test_offer_rejects_negative_price_and_bad_currency(db):
    asset, _ = await make_asset(db, "A")
    asset_id = asset.id
    for amount, currency in ((-1, "USD"), (10, "usd")):
        db.add(Offer(asset_id=asset_id, market="US", currency=currency, amount_minor=amount, available=True, fetched_at=dt.datetime.now(dt.UTC)))
        with pytest.raises(IntegrityError):
            await db.commit()
        await db.rollback()


async def test_published_record_cannot_be_deleted(db):
    asset, _ = await make_asset(db, "A")
    await db.delete(await db.get(Asset, asset.id))
    with pytest.raises(IntegrityError):
        await db.commit()
    await db.rollback()
