import datetime as dt
import subprocess
import sys
import uuid
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

sys.path.insert(0, str(Path(__file__).parent))
ROOT = Path(__file__).resolve().parents[1]

from kfn8.api.app import RateLimiter, create_app  # noqa: E402
from kfn8.db.ephemeral import ephemeral_postgres  # noqa: E402
from kfn8.db.models import (Asset, AssetRevision, DimensionSpec, MaterialVariant, Offer, Rendition,  # noqa: E402
                            Revocation)
from kfn8.db.session import make_engine, make_sessionmaker  # noqa: E402
from kfn8.settings import Settings  # noqa: E402

TENANT = uuid.UUID("00000000-0000-4000-8000-00000000c0de")
CATALOGUE = uuid.UUID("00000000-0000-4000-8000-0000000c0a70")
HASH = "b" * 64


@pytest.fixture(scope="session")
def database_url():
    with ephemeral_postgres() as url:
        subprocess.run([str(ROOT / "venv/bin/alembic"), "-x", f"url={url}", "upgrade", "head"], cwd=ROOT, check=True, capture_output=True)
        yield url


@pytest_asyncio.fixture(scope="session")
async def sessions(database_url):
    engine = make_engine(database_url)
    yield make_sessionmaker(engine)
    await engine.dispose()


@pytest_asyncio.fixture
async def db(sessions):
    """Each test runs in its own data; tables are cleaned afterwards (seed tenant/catalogue kept)."""
    async with sessions() as s:
        yield s
    async with sessions() as s:
        from sqlalchemy import text
        await s.execute(text("TRUNCATE revocation, ingestion_stage, offer, material_variant, rendition, approval, licence_ledger, "
                             "asset_revision, dimension_spec, asset RESTART IDENTITY CASCADE"))
        await s.commit()


@pytest.fixture
def settings(database_url):
    return Settings(database_url=database_url, cdn_base_url="https://cdn.example.test", cursor_secret="test-secret")


@pytest_asyncio.fixture
async def client(settings, sessions):
    app = create_app(settings, sessions, RateLimiter(per_minute=10_000))
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


async def make_asset(s, name, *, state="published", delivery="public", affinity="floor", category="seating", offers=(), revision=1,
                     style=("modern",), colour="walnut"):
    asset = Asset(id=uuid.uuid4(), tenant_id=TENANT, catalogue_id=CATALOGUE, name=name, category=category, affinity=affinity,
                  delivery_mode=delivery, provenance="licensed", style_tags=list(style), dominant_colour=colour)
    s.add(asset)
    spec = DimensionSpec(id=uuid.uuid4(), width_m=0.8, depth_m=0.9, height_m=1.0, authority_kind="operator", source="t",
                         approved_by="founder", approved_at=dt.datetime.now(dt.UTC), evidence_sha256=HASH)
    s.add(spec)
    await s.flush()
    rev = AssetRevision(id=uuid.uuid4(), asset_id=asset.id, revision=revision, state=state, contract_version="1.0.0",
                        source_sha256=HASH, dimension_spec_id=spec.id,
                        published_at=dt.datetime.now(dt.UTC) if state == "published" else None)
    s.add(rev)
    await s.flush()
    for lod, fmt in ((0, "glb"), (0, "usdz")):
        s.add(Rendition(revision_id=rev.id, lod=lod, format=fmt, variant_key="default", object_key=f"a/{asset.id}/r{revision}/lod{lod}.{fmt}",
                        sha256=HASH, size_bytes=1000, triangles=100, max_texture_edge=1024))
    s.add(MaterialVariant(id="default", revision_id=rev.id, label="Default"))
    for market, currency, amount in offers:
        s.add(Offer(asset_id=asset.id, market=market, currency=currency, amount_minor=amount, available=True,
                    retailer_url="https://example.test/p", fetched_at=dt.datetime.now(dt.UTC)))
    await s.commit()
    return asset, rev
