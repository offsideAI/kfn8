"""Anonymous catalogue API v1. Public reads only: no accounts, no Design or scan endpoints, no byte proxying."""
from __future__ import annotations

import time
import uuid
from collections import defaultdict
from collections.abc import AsyncIterator

from fastapi import Depends, FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import and_, exists, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from ..db.models import Asset, AssetRevision, Catalogue, MaterialVariant, Offer, Rendition, Revocation
from ..settings import Settings
from . import cursor as cursors
from .schemas import (AssetDetail, AssetPage, AssetSummary, CataloguePage, CatalogueSummary, Dimensions, ErrorBody,
                      MaterialVariantOut, Offer as OfferOut, RenditionOut, RevisionDetail, RevocationItem, RevocationPage)

API_VERSION = "1.0.0"


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status, self.code, self.message = status, code, message


class RateLimiter:
    """Operational abuse protection per client address. Not identity; nothing is stored beyond a sliding window."""

    def __init__(self, per_minute: int = 600):
        self.per_minute = per_minute
        self.hits: dict[str, list[float]] = defaultdict(list)

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        window = [t for t in self.hits[key] if now - t < 60]
        window.append(now)
        self.hits[key] = window
        return len(window) <= self.per_minute


def create_app(settings: Settings, sessions: async_sessionmaker[AsyncSession], limiter: RateLimiter | None = None) -> FastAPI:
    app = FastAPI(title="Kfn8 catalogue", version=API_VERSION,
                  description="Anonymous read-only catalogue of approved, published generic assets. Contract v1.",
                  responses={429: {"model": ErrorBody}, 503: {"model": ErrorBody}})
    limiter = limiter or RateLimiter()

    async def db() -> AsyncIterator[AsyncSession]:
        async with sessions() as s:
            yield s

    def error(request: Request, status: int, code: str, message: str) -> JSONResponse:
        rid = getattr(request.state, "request_id", str(uuid.uuid4()))
        return JSONResponse(status_code=status, content={"code": code, "message": message, "request_id": rid})

    @app.middleware("http")
    async def request_context(request: Request, call_next):
        request.state.request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        client = request.client.host if request.client else "unknown"
        if request.url.path.startswith("/v1/") and not limiter.allow(client):
            return error(request, 429, "rate_limited", "Too many requests; slow down.")
        response = await call_next(request)
        response.headers["x-request-id"] = request.state.request_id
        return response

    @app.exception_handler(ApiError)
    async def api_error(request: Request, exc: ApiError):
        return error(request, exc.status, exc.code, exc.message)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, exc: RequestValidationError):
        first = exc.errors()[0] if exc.errors() else {"loc": [], "msg": "invalid request"}
        return error(request, 400, "invalid_request", f"{'.'.join(map(str, first['loc']))}: {first['msg']}")

    @app.exception_handler(cursors.CursorError)
    async def cursor_error(request: Request, exc: cursors.CursorError):
        return error(request, 400, "invalid_cursor", str(exc))

    # ------------------------------------------------------------------ health

    @app.get("/health/live", tags=["health"])
    async def live() -> dict:
        return {"status": "ok"}

    @app.get("/health/ready", tags=["health"], responses={503: {"model": ErrorBody}})
    async def ready(request: Request, session: AsyncSession = Depends(db)):
        try:
            await session.execute(text("SELECT 1"))
        except Exception:  # noqa: BLE001 - any DB failure means not ready
            return error(request, 503, "not_ready", "Database unreachable")
        return {"status": "ok"}

    # ------------------------------------------------------------------ queries

    def published_revision_filter():
        return and_(AssetRevision.asset_id == Asset.id, AssetRevision.state == "published")

    latest_published = (select(AssetRevision.id).where(published_revision_filter())
                        .order_by(AssetRevision.revision.desc()).limit(1).correlate(Asset).scalar_subquery())

    def page_limit(limit: int) -> int:
        return min(limit, settings.page_max)

    async def summaries(session: AsyncSession, assets: list[Asset], market: str) -> list[dict]:
        out = []
        for a in assets:
            rev = max((r for r in a.revisions if r.state == "published"), key=lambda r: r.revision)
            offer = (await session.execute(select(Offer).where(Offer.asset_id == a.id, Offer.market == market)
                                           .order_by(Offer.currency).limit(1))).scalar_one_or_none()
            spec = rev.dimension_spec
            out.append(dict(
                id=a.id, tenant_id=a.tenant_id, name=a.name, category=a.category, affinity=a.affinity, delivery_mode="public",
                latest_revision_id=rev.id, latest_revision=rev.revision,
                dimensions_m=Dimensions(width=float(spec.width_m), depth=float(spec.depth_m), height=float(spec.height_m)),
                thumbnail_url=None,
                offer=OfferOut(amount_minor=offer.amount_minor, currency=offer.currency, available=offer.available,
                               retailer_url=offer.retailer_url, fetched_at=offer.fetched_at) if offer else None,
                _asset=a,
            ))
        return out

    # ------------------------------------------------------------------ routes

    @app.get("/v1/catalogues", response_model=CataloguePage, tags=["catalogue"])
    async def catalogues(cursor: str | None = None, limit: int = Query(30, ge=1, le=100), session: AsyncSession = Depends(db)):
        filters = {"route": "catalogues"}
        q = select(Catalogue).order_by(Catalogue.name, Catalogue.id)
        if cursor:
            name, cid = cursors.decode(settings.cursor_secret, cursor, filters)
            q = q.where(or_(Catalogue.name > name, and_(Catalogue.name == name, Catalogue.id > uuid.UUID(cid))))
        rows = (await session.execute(q.limit(page_limit(limit) + 1))).scalars().all()
        more = len(rows) > page_limit(limit)
        rows = rows[:page_limit(limit)]
        nxt = cursors.encode(settings.cursor_secret, [rows[-1].name, str(rows[-1].id)], filters) if more and rows else None
        return CataloguePage(items=[CatalogueSummary(id=r.id, name=r.name) for r in rows], next_cursor=nxt)

    @app.get("/v1/assets", response_model=AssetPage, tags=["catalogue"])
    async def assets(q: str | None = Query(None, max_length=100), category: str | None = None, affinity: str | None = None,
                     style: str | None = None, colour: str | None = None, catalogue_id: uuid.UUID | None = None,
                     market: str = Query("US", pattern="^[A-Z]{2}$"), cursor: str | None = None,
                     limit: int = Query(30, ge=1, le=100), session: AsyncSession = Depends(db)):
        filters = {"q": q, "category": category, "affinity": affinity, "style": style, "colour": colour,
                   "catalogue_id": catalogue_id, "market": market}
        stmt = (select(Asset).where(Asset.delivery_mode == "public", exists(select(AssetRevision.id).where(published_revision_filter())))
                .options(selectinload(Asset.revisions).selectinload(AssetRevision.dimension_spec))
                .order_by(Asset.name, Asset.id))
        if q:
            stmt = stmt.where(Asset.name.ilike(f"%{q}%"))
        if category:
            stmt = stmt.where(Asset.category == category)
        if affinity:
            stmt = stmt.where(Asset.affinity == affinity)
        if style:
            stmt = stmt.where(Asset.style_tags.any(style))
        if colour:
            stmt = stmt.where(Asset.dominant_colour == colour)
        if catalogue_id:
            stmt = stmt.where(Asset.catalogue_id == catalogue_id)
        if cursor:
            name, aid = cursors.decode(settings.cursor_secret, cursor, filters)
            stmt = stmt.where(or_(Asset.name > name, and_(Asset.name == name, Asset.id > uuid.UUID(aid))))
        n = page_limit(limit)
        rows = (await session.execute(stmt.limit(n + 1))).scalars().unique().all()
        more = len(rows) > n
        rows = rows[:n]
        items = [AssetSummary(**{k: v for k, v in s.items() if k != "_asset"}) for s in await summaries(session, rows, market)]
        nxt = cursors.encode(settings.cursor_secret, [rows[-1].name, str(rows[-1].id)], filters) if more and rows else None
        return AssetPage(items=items, next_cursor=nxt)

    async def public_asset(session: AsyncSession, asset_id: uuid.UUID) -> Asset:
        a = (await session.execute(select(Asset).where(Asset.id == asset_id)
                                   .options(selectinload(Asset.revisions).selectinload(AssetRevision.dimension_spec),
                                            selectinload(Asset.revisions).selectinload(AssetRevision.variants)))).scalar_one_or_none()
        if a is None or a.delivery_mode != "public" or not any(r.state == "published" for r in a.revisions):
            raise ApiError(404, "not_found", "No such asset")
        return a

    @app.get("/v1/assets/{asset_id}", response_model=AssetDetail, responses={404: {"model": ErrorBody}}, tags=["catalogue"])
    async def asset_detail(asset_id: uuid.UUID, market: str = Query("US", pattern="^[A-Z]{2}$"), session: AsyncSession = Depends(db)):
        a = await public_asset(session, asset_id)
        s = (await summaries(session, [a], market))[0]
        rev = next(r for r in a.revisions if r.id == s["latest_revision_id"])
        s.pop("_asset")
        return AssetDetail(**s, style_tags=a.style_tags, dominant_colour=a.dominant_colour, is_floor_covering=a.is_floor_covering,
                           variants=[MaterialVariantOut(id=v.id, label=v.label) for v in rev.variants])

    @app.get("/v1/assets/{asset_id}/revisions/{revision}", response_model=RevisionDetail,
             responses={404: {"model": ErrorBody}, 410: {"model": ErrorBody}}, tags=["catalogue"])
    async def revision_detail(asset_id: uuid.UUID, revision: int, session: AsyncSession = Depends(db)):
        row = (await session.execute(
            select(AssetRevision).join(Asset).where(AssetRevision.asset_id == asset_id, AssetRevision.revision == revision,
                                                    Asset.delivery_mode == "public")
            .options(selectinload(AssetRevision.renditions), selectinload(AssetRevision.dimension_spec),
                     selectinload(AssetRevision.variants)))).scalar_one_or_none()
        if row is None or row.state not in ("published", "revoking", "revoked"):
            raise ApiError(404, "not_found", "No such revision")
        if row.state in ("revoking", "revoked"):
            raise ApiError(410, "revoked", "This revision is no longer available")
        spec = row.dimension_spec
        return RevisionDetail(
            asset_id=asset_id, revision_id=row.id, revision=row.revision, contract_version=row.contract_version,
            dimensions_m=Dimensions(width=float(spec.width_m), depth=float(spec.depth_m), height=float(spec.height_m)),
            attachment=row.attachment_metadata, variants=[MaterialVariantOut(id=v.id, label=v.label) for v in row.variants],
            renditions=[RenditionOut(lod=r.lod, format=r.format, variant_key=r.variant_key,
                                     url=f"{settings.cdn_base_url.rstrip('/')}/{r.object_key}", sha256=r.sha256,
                                     size_bytes=r.size_bytes, triangles=r.triangles) for r in row.renditions])

    @app.get("/v1/revocations", response_model=RevocationPage, tags=["catalogue"])
    async def revocations(cursor: str | None = None, limit: int = Query(30, ge=1, le=100), session: AsyncSession = Depends(db)):
        filters = {"route": "revocations"}
        after = int(cursors.decode(settings.cursor_secret, cursor, filters)[0]) if cursor else 0
        n = page_limit(limit)
        rows = (await session.execute(select(Revocation).where(Revocation.sequence > after)
                                      .order_by(Revocation.sequence).limit(n + 1))).scalars().all()
        more = len(rows) > n
        rows = rows[:n]
        last = rows[-1].sequence if rows else after
        # Durable tombstones: a cursor is always returned so clients can resume from the last applied sequence.
        return RevocationPage(items=[RevocationItem(sequence=r.sequence, revision_id=r.revision_id, reason="rights") for r in rows],
                              next_cursor=cursors.encode(settings.cursor_secret, [last], filters), has_more=more)

    return app
