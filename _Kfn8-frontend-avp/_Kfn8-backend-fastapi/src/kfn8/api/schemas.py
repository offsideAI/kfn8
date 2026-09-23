"""Transport schemas for API v1. These define the pinned OpenAPI contract consumed by the generated Swift client."""
from __future__ import annotations

import datetime as dt
import uuid
from typing import Literal

from pydantic import BaseModel, Field

Affinity = Literal["floor", "wall", "ceiling", "tabletop", "freestanding-outdoor"]


class ErrorBody(BaseModel):
    code: str
    message: str
    request_id: str


class Dimensions(BaseModel):
    width: float
    depth: float
    height: float


class Offer(BaseModel):
    amount_minor: int
    currency: str = Field(pattern="^[A-Z]{3}$")
    available: bool
    retailer_url: str | None
    fetched_at: dt.datetime


class CatalogueSummary(BaseModel):
    id: uuid.UUID
    name: str


class CataloguePage(BaseModel):
    items: list[CatalogueSummary]
    next_cursor: str | None


class AssetSummary(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    name: str
    category: str
    affinity: Affinity
    delivery_mode: Literal["public"]
    latest_revision_id: uuid.UUID
    latest_revision: int
    dimensions_m: Dimensions
    thumbnail_url: str | None
    offer: Offer | None


class AssetPage(BaseModel):
    items: list[AssetSummary]
    next_cursor: str | None


class MaterialVariantOut(BaseModel):
    id: str
    label: str


class AssetDetail(AssetSummary):
    style_tags: list[str]
    dominant_colour: str | None
    is_floor_covering: bool
    variants: list[MaterialVariantOut]


class RenditionOut(BaseModel):
    lod: int
    format: Literal["glb", "usdz"]
    variant_key: str
    url: str
    sha256: str
    size_bytes: int
    triangles: int


class RevisionDetail(BaseModel):
    asset_id: uuid.UUID
    revision_id: uuid.UUID
    revision: int
    contract_version: str
    dimensions_m: Dimensions
    attachment: dict | None
    variants: list[MaterialVariantOut]
    renditions: list[RenditionOut]


class RevocationItem(BaseModel):
    sequence: int
    revision_id: uuid.UUID
    reason: Literal["rights"]


class RevocationPage(BaseModel):
    items: list[RevocationItem]
    next_cursor: str | None
    has_more: bool
