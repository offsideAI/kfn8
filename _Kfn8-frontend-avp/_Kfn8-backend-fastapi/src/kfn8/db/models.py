"""Relational schema from TECHNICAL-PLAN §6. Published records use RESTRICT deletes; no binaries in the database."""
from __future__ import annotations

import datetime as dt
import uuid

from sqlalchemy import (BigInteger, Boolean, CheckConstraint, DateTime, ForeignKey, ForeignKeyConstraint, Identity, Index,
                        Integer, Numeric, SmallInteger, String, Text, UniqueConstraint, func)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


def uid() -> Mapped[uuid.UUID]:
    return mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)


SHA = String(64)
NOW = dict(server_default=func.now())


class Tenant(Base):
    __tablename__ = "tenant"
    id: Mapped[uuid.UUID] = uid()
    name: Mapped[str] = mapped_column(Text, nullable=False)


class Catalogue(Base):
    __tablename__ = "catalogue"
    id: Mapped[uuid.UUID] = uid()
    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenant.id", ondelete="RESTRICT"), nullable=False)
    slug: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    # Target for the composite tenant/catalogue integrity constraint on asset.
    __table_args__ = (UniqueConstraint("id", "tenant_id", name="uq_catalogue_id_tenant"),)


class Asset(Base):
    __tablename__ = "asset"
    id: Mapped[uuid.UUID] = uid()
    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenant.id", ondelete="RESTRICT"), nullable=False)
    catalogue_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    sku: Mapped[str | None] = mapped_column(Text)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(Text, nullable=False)
    affinity: Mapped[str] = mapped_column(Text, nullable=False)
    delivery_mode: Mapped[str] = mapped_column(Text, nullable=False, default="public")
    provenance: Mapped[str] = mapped_column(Text, nullable=False)
    style_tags: Mapped[list[str]] = mapped_column(ARRAY(Text), nullable=False, default=list)
    dominant_colour: Mapped[str | None] = mapped_column(Text)
    weight_class: Mapped[str | None] = mapped_column(Text)
    is_floor_covering: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    revisions: Mapped[list[AssetRevision]] = relationship(back_populates="asset", order_by="AssetRevision.revision")
    __table_args__ = (
        CheckConstraint("affinity IN ('floor','wall','ceiling','tabletop','freestanding-outdoor')", name="ck_asset_affinity"),
        CheckConstraint("delivery_mode IN ('public','restricted')", name="ck_asset_delivery_mode"),
        CheckConstraint("provenance IN ('licensed','commissioned','captured','generated')", name="ck_asset_provenance"),
        UniqueConstraint("tenant_id", "sku", name="uq_asset_tenant_sku"),
        ForeignKeyConstraint(["catalogue_id", "tenant_id"], ["catalogue.id", "catalogue.tenant_id"], ondelete="RESTRICT",
                             name="fk_asset_catalogue_tenant"),
        Index("ix_asset_filters", "catalogue_id", "category", "affinity"),
        Index("ix_asset_name_id", "name", "id"),
    )


class DimensionSpec(Base):
    __tablename__ = "dimension_spec"
    id: Mapped[uuid.UUID] = uid()
    width_m: Mapped[float] = mapped_column(Numeric(8, 4), nullable=False)
    depth_m: Mapped[float] = mapped_column(Numeric(8, 4), nullable=False)
    height_m: Mapped[float] = mapped_column(Numeric(8, 4), nullable=False)
    authority_kind: Mapped[str] = mapped_column(Text, nullable=False)
    source: Mapped[str] = mapped_column(Text, nullable=False)
    approved_by: Mapped[str] = mapped_column(Text, nullable=False)
    approved_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    evidence_sha256: Mapped[str] = mapped_column(SHA, nullable=False)
    __table_args__ = (
        CheckConstraint("width_m > 0 AND depth_m > 0 AND height_m > 0", name="ck_dimension_positive"),
        CheckConstraint("authority_kind IN ('retailer','operator')", name="ck_dimension_authority"),
        CheckConstraint("evidence_sha256 ~ '^[0-9a-f]{64}$'", name="ck_dimension_evidence_hash"),
    )


REVISION_STATES = ("draft", "validating", "review", "approved", "publishing", "published", "revoking", "revoked", "rejected")


class AssetRevision(Base):
    __tablename__ = "asset_revision"
    id: Mapped[uuid.UUID] = uid()
    asset_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset.id", ondelete="RESTRICT"), nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False)
    state: Mapped[str] = mapped_column(Text, nullable=False, default="draft")
    contract_version: Mapped[str] = mapped_column(Text, nullable=False)
    source_sha256: Mapped[str] = mapped_column(SHA, nullable=False)
    dimension_spec_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("dimension_spec.id", ondelete="RESTRICT"), nullable=False)
    attachment_metadata: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False, **NOW)
    published_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True))
    asset: Mapped[Asset] = relationship(back_populates="revisions")
    dimension_spec: Mapped[DimensionSpec] = relationship()
    renditions: Mapped[list[Rendition]] = relationship(back_populates="revision_row", order_by="(Rendition.lod, Rendition.format)")
    variants: Mapped[list[MaterialVariant]] = relationship()
    __table_args__ = (
        UniqueConstraint("asset_id", "revision", name="uq_revision_asset_revision"),
        CheckConstraint("revision > 0", name="ck_revision_positive"),
        CheckConstraint(f"state IN {REVISION_STATES}", name="ck_revision_state"),
        CheckConstraint("source_sha256 ~ '^[0-9a-f]{64}$'", name="ck_revision_source_sha"),
        CheckConstraint("(state = 'published') = (published_at IS NOT NULL) OR state IN ('revoking','revoked')", name="ck_revision_published_at"),
        Index("ix_revision_published", "asset_id", "state", "revision"),
    )


class LicenceLedger(Base):
    __tablename__ = "licence_ledger"
    id: Mapped[uuid.UUID] = uid()
    revision_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset_revision.id", ondelete="RESTRICT"), unique=True, nullable=False)
    source_url: Mapped[str] = mapped_column(Text, nullable=False)
    author: Mapped[str] = mapped_column(Text, nullable=False)
    licence_id: Mapped[str] = mapped_column(Text, nullable=False)
    attribution_required: Mapped[bool] = mapped_column(Boolean, nullable=False)
    attribution_text: Mapped[str | None] = mapped_column(Text)
    evidence_reference: Mapped[str] = mapped_column(Text, nullable=False)
    evidence_sha256: Mapped[str] = mapped_column(SHA, nullable=False)
    recorded_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    __table_args__ = (
        CheckConstraint("evidence_sha256 ~ '^[0-9a-f]{64}$'", name="ck_licence_evidence_hash"),
        CheckConstraint("NOT attribution_required OR attribution_text IS NOT NULL", name="ck_licence_attribution_text"),
    )


class Approval(Base):
    __tablename__ = "approval"
    id: Mapped[uuid.UUID] = uid()
    revision_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset_revision.id", ondelete="RESTRICT"), nullable=False)
    kind: Mapped[str] = mapped_column(Text, nullable=False)
    actor: Mapped[str] = mapped_column(Text, nullable=False)
    decided_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    evidence_reference: Mapped[str] = mapped_column(Text, nullable=False)
    evidence_sha256: Mapped[str] = mapped_column(SHA, nullable=False)
    # Hash of the exact revision inputs the approver saw; a changed input needs a new revision and new approvals.
    input_sha256: Mapped[str] = mapped_column(SHA, nullable=False)
    approved: Mapped[bool] = mapped_column(Boolean, nullable=False)
    __table_args__ = (
        CheckConstraint("kind IN ('provenance','visual_dimensions')", name="ck_approval_kind"),
        CheckConstraint("evidence_sha256 ~ '^[0-9a-f]{64}$' AND input_sha256 ~ '^[0-9a-f]{64}$'", name="ck_approval_hashes"),
        Index("ix_approval_revision_kind", "revision_id", "kind"),
    )


class Rendition(Base):
    __tablename__ = "rendition"
    id: Mapped[uuid.UUID] = uid()
    revision_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset_revision.id", ondelete="RESTRICT"), nullable=False)
    lod: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    format: Mapped[str] = mapped_column(Text, nullable=False)
    variant_key: Mapped[str] = mapped_column(Text, nullable=False, default="default")
    object_key: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    sha256: Mapped[str] = mapped_column(SHA, nullable=False)
    size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    triangles: Mapped[int] = mapped_column(Integer, nullable=False)
    max_texture_edge: Mapped[int] = mapped_column(Integer, nullable=False)
    revision_row: Mapped[AssetRevision] = relationship(back_populates="renditions")
    __table_args__ = (
        UniqueConstraint("revision_id", "lod", "format", "variant_key", name="uq_rendition_slot"),
        CheckConstraint("lod BETWEEN 0 AND 2", name="ck_rendition_lod"),
        CheckConstraint("format IN ('glb','usdz')", name="ck_rendition_format"),
        CheckConstraint("size_bytes > 0", name="ck_rendition_size"),
        CheckConstraint("triangles >= 0", name="ck_rendition_triangles"),
        CheckConstraint("max_texture_edge <= 2048", name="ck_rendition_texture"),
        CheckConstraint("sha256 ~ '^[0-9a-f]{64}$'", name="ck_rendition_sha"),
    )


class MaterialVariant(Base):
    __tablename__ = "material_variant"
    id: Mapped[str] = mapped_column(Text, primary_key=True)
    revision_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset_revision.id", ondelete="RESTRICT"), primary_key=True)
    label: Mapped[str] = mapped_column(Text, nullable=False)
    material_mapping: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)


class Offer(Base):
    __tablename__ = "offer"
    asset_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset.id", ondelete="RESTRICT"), primary_key=True)
    market: Mapped[str] = mapped_column(Text, primary_key=True)
    currency: Mapped[str] = mapped_column(String(3), primary_key=True)
    amount_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    available: Mapped[bool] = mapped_column(Boolean, nullable=False)
    retailer_url: Mapped[str | None] = mapped_column(Text)
    fetched_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    __table_args__ = (
        CheckConstraint("amount_minor >= 0", name="ck_offer_amount"),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="ck_offer_currency"),
        Index("ix_offer_asset", "asset_id"),
    )


class IngestionStage(Base):
    __tablename__ = "ingestion_stage"
    revision_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset_revision.id", ondelete="RESTRICT"), primary_key=True)
    stage: Mapped[str] = mapped_column(Text, primary_key=True)
    input_fingerprint: Mapped[str] = mapped_column(SHA, nullable=False)
    tool_version: Mapped[str] = mapped_column(Text, nullable=False)
    state: Mapped[str] = mapped_column(Text, nullable=False)
    started_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True))
    ended_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True))
    report: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    output_manifest: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    __table_args__ = (CheckConstraint("state IN ('pending','running','passed','failed')", name="ck_stage_state"),)


class Revocation(Base):
    __tablename__ = "revocation"
    sequence: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    revision_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("asset_revision.id", ondelete="RESTRICT"), unique=True, nullable=False)
    reason: Mapped[str] = mapped_column(Text, nullable=False, default="rights")
    effective_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False, **NOW)
    removal_verified_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True))
    purge_verified_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (CheckConstraint("reason = 'rights'", name="ck_revocation_reason"),)
