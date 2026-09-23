"""Operator-invoked, resumable ingestion (TECHNICAL-PLAN §7). No queue, no worker: each stage is a function of the
revision's inputs, records running/passed/failed with an input fingerprint, tool version and report, and is skipped on
re-run when already passed for the same fingerprint. A per-revision advisory lock prevents duplicate invocations."""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import shutil
import uuid
from dataclasses import dataclass
from pathlib import Path

from sqlalchemy import select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from ..contract.validator import sha256_file, validate_manifest
from ..db.models import (Approval, Asset, AssetRevision, DimensionSpec, IngestionStage, LicenceLedger, MaterialVariant, Rendition,
                         Revocation)
from .storage import CdnPurger, Storage

TOOL_VERSION = "kfn8-ingest 1.0.0"
STAGES = ("register", "validate", "approvals", "publish")
TENANT = uuid.UUID("00000000-0000-4000-8000-00000000c0de")
CATALOGUE = uuid.UUID("00000000-0000-4000-8000-0000000c0a70")


class IngestError(Exception):
    pass


@dataclass
class StageResult:
    stage: str
    state: str
    skipped: bool
    report: dict


def input_fingerprint(manifest_path: Path) -> str:
    """Hash of the manifest and every rendition's bytes: the exact inputs approvals are bound to."""
    manifest = json.loads(manifest_path.read_text())
    # Approvals are about the inputs, so they are excluded; recording one must not change what it approved.
    reviewed = {k: v for k, v in manifest.items() if k != "approvals"}
    h = hashlib.sha256(json.dumps(reviewed, sort_keys=True, separators=(",", ":")).encode())
    for r in sorted(manifest["renditions"], key=lambda r: r["path"]):
        h.update(sha256_file(manifest_path.parent / r["path"]).encode())
    return h.hexdigest()


async def _lock(session: AsyncSession, revision_id: uuid.UUID) -> None:
    await session.execute(text("SELECT pg_advisory_xact_lock(hashtext(:k))"), {"k": str(revision_id)})


async def _stage(session: AsyncSession, revision_id: uuid.UUID, stage: str, fingerprint: str, work) -> StageResult:
    row = await session.get(IngestionStage, (revision_id, stage))
    if row and row.state == "passed" and row.input_fingerprint == fingerprint:
        return StageResult(stage, "passed", True, row.report)
    if row is None:
        row = IngestionStage(revision_id=revision_id, stage=stage, input_fingerprint=fingerprint, tool_version=TOOL_VERSION, state="pending")
        session.add(row)
    row.input_fingerprint, row.tool_version = fingerprint, TOOL_VERSION
    row.state, row.started_at, row.ended_at = "running", dt.datetime.now(dt.UTC), None
    await session.flush()
    try:
        report, outputs = await work()
        row.state, row.report, row.output_manifest = "passed", report, outputs or {}
    except IngestError as e:
        row.state, row.report = "failed", {"error": str(e)}
    row.ended_at = dt.datetime.now(dt.UTC)
    await session.commit()
    return StageResult(stage, row.state, False, row.report)


async def register(session: AsyncSession, manifest_path: Path, private: Storage) -> uuid.UUID:
    """Create asset/revision/spec/ledger rows from a manifest and store private source copies. Idempotent by revision."""
    m = json.loads(manifest_path.read_text())
    asset_id = uuid.UUID(m["asset"]["id"])
    asset = await session.get(Asset, asset_id)
    if asset is None:
        a = m["asset"]
        asset = Asset(id=asset_id, tenant_id=TENANT, catalogue_id=CATALOGUE, sku=a.get("sku"), name=a["name"], category=a["category"],
                      affinity=a["affinity"], delivery_mode=a["delivery_mode"], provenance=a["provenance"], style_tags=a.get("style_tags", []),
                      dominant_colour=a.get("dominant_colour"), weight_class=a.get("weight_class"), is_floor_covering=a.get("is_floor_covering", False))
        session.add(asset)
    existing = (await session.execute(select(AssetRevision).where(AssetRevision.asset_id == asset_id,
                                                                   AssetRevision.revision == m["revision"]))).scalar_one_or_none()
    fingerprint = input_fingerprint(manifest_path)
    if existing:
        if existing.source_sha256 != fingerprint:
            raise IngestError("revision inputs changed: create a new revision instead of editing an immutable one")
        return existing.id
    s = m["dimension_spec"]
    spec = DimensionSpec(width_m=s["width_m"], depth_m=s["depth_m"], height_m=s["height_m"], authority_kind=s["authority_kind"],
                         source=s["source"], approved_by=s["approved_by"], approved_at=dt.datetime.fromisoformat(s["approved_at"]),
                         evidence_sha256=s["evidence_sha256"])
    session.add(spec)
    await session.flush()
    rev = AssetRevision(asset_id=asset_id, revision=m["revision"], state="draft", contract_version=m["contract_version"],
                        source_sha256=fingerprint, dimension_spec_id=spec.id, attachment_metadata=m.get("attachment"))
    session.add(rev)
    await session.flush()
    lic = m["licence"]
    session.add(LicenceLedger(revision_id=rev.id, source_url=lic["source_url"], author=lic["author"], licence_id=lic["licence_id"],
                              attribution_required=lic["attribution_required"], attribution_text=lic.get("attribution_text"),
                              evidence_reference=lic["evidence_reference"], evidence_sha256=lic["evidence_sha256"],
                              recorded_at=dt.datetime.fromisoformat(lic["recorded_at"])))
    session.add(MaterialVariant(id="default", revision_id=rev.id, label="Default"))
    for r in m["renditions"]:
        private.put_if_absent(f"sources/{asset_id}/r{m['revision']}/{r['path']}", manifest_path.parent / r["path"], r["sha256"])
    # Approvals recorded in the manifest (e.g. before a database existed) count only if bound to these exact inputs.
    for a in m.get("approvals", []):
        if a.get("input_sha256") == fingerprint:
            session.add(Approval(revision_id=rev.id, kind=a["kind"], actor=a["actor"], decided_at=dt.datetime.fromisoformat(a["decided_at"]),
                                 evidence_reference=a["evidence_reference"], evidence_sha256=a["evidence_sha256"], input_sha256=fingerprint,
                                 approved=a["approved"]))
    await session.commit()
    return rev.id


async def approve(session: AsyncSession, revision_id: uuid.UUID, manifest_path: Path, *, kind: str, actor: str, evidence: Path,
                  approved: bool = True) -> None:
    """Record an approval bound to the exact input hash. The founder runs this; the agent never approves."""
    rev = await session.get(AssetRevision, revision_id)
    if rev is None:
        raise IngestError("unknown revision")
    fp = input_fingerprint(manifest_path)
    if fp != rev.source_sha256:
        raise IngestError("inputs differ from the registered revision; approval refused")
    session.add(Approval(revision_id=revision_id, kind=kind, actor=actor, decided_at=dt.datetime.now(dt.UTC),
                         evidence_reference=str(evidence), evidence_sha256=sha256_file(evidence), input_sha256=fp, approved=approved))
    await session.commit()


def public_key(asset_id: uuid.UUID, revision: int, rendition: dict) -> str:
    ext = rendition["format"]
    return f"assets/{asset_id}/r{revision}/lod{rendition['lod']}-{rendition['variant_key']}-{rendition['sha256'][:16]}.{ext}"


async def run(session: AsyncSession, revision_id: uuid.UUID, manifest_path: Path, public: Storage) -> list[StageResult]:
    """Run stages in order, resuming at the first incomplete or invalidated one. Stops at the first failure."""
    await _lock(session, revision_id)
    rev = await session.get(AssetRevision, revision_id)
    if rev is None:
        raise IngestError("unknown revision")
    fp = input_fingerprint(manifest_path)
    if fp != rev.source_sha256:
        raise IngestError("inputs differ from the registered revision; register a new revision")
    m = json.loads(manifest_path.read_text())
    results: list[StageResult] = []

    async def s_register():
        return {"fingerprint": fp}, {}

    async def s_validate():
        report = validate_manifest(manifest_path)
        await session.execute(update(AssetRevision).where(AssetRevision.id == revision_id).values(state="validating" if not report.passed else "review"))
        if not report.passed:
            raise IngestError("; ".join(f"{c.name}: {c.detail}" for c in report.checks if not c.passed)[:2000])
        return report.to_json(), {"measurements": report.measurements}

    async def s_approvals():
        rows = (await session.execute(select(Approval).where(Approval.revision_id == revision_id, Approval.input_sha256 == fp))).scalars().all()
        kinds = {a.kind for a in rows if a.approved}
        rejected = {a.kind for a in rows if not a.approved}
        if rejected:
            await session.execute(update(AssetRevision).where(AssetRevision.id == revision_id).values(state="rejected"))
            raise IngestError(f"rejected: {sorted(rejected)}")
        missing = {"provenance", "visual_dimensions"} - kinds
        if missing:
            raise IngestError(f"awaiting approvals: {sorted(missing)}")
        await session.execute(update(AssetRevision).where(AssetRevision.id == revision_id).values(state="approved"))
        return {"approvals": sorted(kinds)}, {}

    async def s_publish():
        await session.execute(update(AssetRevision).where(AssetRevision.id == revision_id).values(state="publishing"))
        written = []
        for r in m["renditions"]:
            key = public_key(rev.asset_id, rev.revision, r)
            public.put_if_absent(key, manifest_path.parent / r["path"], r["sha256"])
            info = public.head(key)
            if info is None or info.size != r["size_bytes"] or (info.sha256 and info.sha256 != r["sha256"]):
                raise IngestError(f"public object {key} failed verification")
            existing = (await session.execute(select(Rendition).where(Rendition.object_key == key))).scalar_one_or_none()
            if existing is None:
                measured = validate_manifest(manifest_path).measurements.get(f"lod{r['lod']}.{r['format']}.{r['variant_key']}", {})
                session.add(Rendition(revision_id=revision_id, lod=r["lod"], format=r["format"], variant_key=r["variant_key"], object_key=key,
                                      sha256=r["sha256"], size_bytes=r["size_bytes"], triangles=measured.get("triangles", 0),
                                      max_texture_edge=measured.get("max_texture_edge", 0)))
            written.append(key)
        await session.execute(update(AssetRevision).where(AssetRevision.id == revision_id)
                              .values(state="published", published_at=dt.datetime.now(dt.UTC)))
        return {"objects": written}, {"public_keys": written}

    for name, work in (("register", s_register), ("validate", s_validate), ("approvals", s_approvals), ("publish", s_publish)):
        result = await _stage(session, revision_id, name, fp, work)
        results.append(result)
        if result.state != "passed":
            break
    return results


async def revoke(session: AsyncSession, revision_id: uuid.UUID, public: Storage, purger: CdnPurger) -> dict:
    """Rights revocation: hide immediately (state + delta), delete origin objects, purge CDN, verify absence, record
    evidence. Partial failure leaves the revision `revoking` with timestamps unset; re-running retries safely."""
    await _lock(session, revision_id)
    rev = await session.get(AssetRevision, revision_id)
    if rev is None:
        raise IngestError("unknown revision")
    if rev.state not in ("published", "revoking"):
        raise IngestError(f"cannot revoke a revision in state {rev.state}")
    rev.state = "revoking"
    tomb = (await session.execute(select(Revocation).where(Revocation.revision_id == revision_id))).scalar_one_or_none()
    if tomb is None:
        tomb = Revocation(revision_id=revision_id, reason="rights")
        session.add(tomb)
    await session.commit()  # hidden from the API and visible in deltas before any deletion work
    keys = [r.object_key for r in (await session.execute(select(Rendition).where(Rendition.revision_id == revision_id))).scalars()]
    errors = []
    for k in keys:
        try:
            public.delete(k)
        except OSError as e:
            errors.append(str(e))
    if not errors and all(public.head(k) is None for k in keys):
        tomb.removal_verified_at = tomb.removal_verified_at or dt.datetime.now(dt.UTC)
    try:
        purger.purge(keys)
        tomb.purge_verified_at = dt.datetime.now(dt.UTC)
    except OSError as e:
        errors.append(str(e))
    if tomb.removal_verified_at and tomb.purge_verified_at:
        rev.state = "revoked"
    await session.commit()
    return {"state": rev.state, "errors": errors, "objects": keys}


async def delist(session: AsyncSession, asset_id: uuid.UUID, market: str | None = None) -> int:
    """Commercial delisting: mark offers unavailable. Geometry stays published and pinned client copies keep working,
    unlike rights revocation. Returns the number of offers changed."""
    from ..db.models import Offer
    stmt = update(Offer).where(Offer.asset_id == asset_id)
    if market:
        stmt = stmt.where(Offer.market == market)
    result = await session.execute(stmt.values(available=False))
    await session.commit()
    return result.rowcount or 0
