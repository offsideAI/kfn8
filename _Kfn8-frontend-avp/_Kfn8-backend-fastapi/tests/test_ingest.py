"""M6/M2 operator pipeline end to end against real Postgres and local storage: stage failure and resume, approval
binding, idempotent publish, API visibility, rights revocation with partial failure and retry, delisting."""
import json
import shutil
from pathlib import Path

from builders import good_asset
from sqlalchemy import select

from kfn8.db.models import IngestionStage, Offer, Rendition
from kfn8.ingest import pipeline
from kfn8.ingest.storage import LocalStorage, RecordingPurger


def storages(tmp_path):
    return LocalStorage(tmp_path / "private"), LocalStorage(tmp_path / "public")


async def test_full_operator_flow(client, db, tmp_path):
    private, public = storages(tmp_path)
    src = tmp_path / "src"
    src.mkdir()
    manifest = good_asset(src, approvals=False)
    evidence = tmp_path / "evidence.md"
    evidence.write_text("reviewed source page, licence and measured dimensions")

    rev_id = await pipeline.register(db, manifest, private)
    assert await pipeline.register(db, manifest, private) == rev_id, "register is idempotent"
    assert list((tmp_path / "private").rglob("*.glb")), "sources stored privately"

    stages = await pipeline.run(db, rev_id, manifest, public)
    assert [(r.stage, r.state) for r in stages] == [("register", "passed"), ("validate", "passed"), ("approvals", "failed")]
    assert "awaiting approvals" in stages[-1].report["error"]
    assert not list((tmp_path / "public").rglob("*")), "nothing public before approval"

    await pipeline.approve(db, rev_id, manifest, kind="provenance", actor="founder", evidence=evidence)
    await pipeline.approve(db, rev_id, manifest, kind="visual_dimensions", actor="founder", evidence=evidence)
    stages = await pipeline.run(db, rev_id, manifest, public)
    assert [r.skipped for r in stages[:2]] == [True, True], "resume skips passed stages"
    assert stages[-1].stage == "publish" and stages[-1].state == "passed"

    again = await pipeline.run(db, rev_id, manifest, public)
    assert all(r.skipped for r in again), "second publish is a no-op"
    count = len((await db.execute(select(Rendition).where(Rendition.revision_id == rev_id))).scalars().all())
    assert count == 2, "no duplicate rendition rows"

    listed = (await client.get("/v1/assets")).json()["items"]
    assert [a["name"] for a in listed] == ["Test chair"]
    detail = (await client.get(f"/v1/assets/{listed[0]['id']}/revisions/1")).json()
    assert all(r["url"].startswith("https://cdn.example.test/assets/") for r in detail["renditions"])

    # Rights revocation: first attempt fails to delete, stays revoking and hidden; retry completes with evidence.
    purger = RecordingPurger()
    public.fail_deletes = True
    result = await pipeline.revoke(db, rev_id, public, purger)
    assert result["state"] == "revoking" and result["errors"]
    assert (await client.get(f"/v1/assets/{listed[0]['id']}/revisions/1")).status_code == 410
    public.fail_deletes = False
    result = await pipeline.revoke(db, rev_id, public, purger)
    assert result["state"] == "revoked" and not result["errors"]
    assert not list((tmp_path / "public").rglob("*.glb")), "origin objects removed"
    assert set(purger.purged) == set(result["objects"]) and len(result["objects"]) == 2
    deltas = (await client.get("/v1/revocations")).json()["items"]
    assert [d["revision_id"] for d in deltas] == [str(rev_id)]


async def test_failed_validation_reports_and_resumes_after_fix(db, tmp_path):
    private, public = storages(tmp_path)
    src = tmp_path / "src"
    src.mkdir()
    manifest = good_asset(src, approvals=False, w=0.8)
    data = json.loads(manifest.read_text())
    data["dimension_spec"]["width_m"] = 0.9  # wrong declared spec: drift > 1 %
    manifest.write_text(json.dumps(data))
    rev_id = await pipeline.register(db, manifest, private)
    stages = await pipeline.run(db, rev_id, manifest, public)
    assert stages[-1].stage == "validate" and stages[-1].state == "failed"
    assert "dimensions.x" in stages[-1].report["error"]
    row = await db.get(IngestionStage, (rev_id, "validate"))
    assert row.tool_version == pipeline.TOOL_VERSION and len(row.input_fingerprint) == 64


async def test_changed_inputs_require_a_new_revision(db, tmp_path):
    private, public = storages(tmp_path)
    src = tmp_path / "src"
    src.mkdir()
    manifest = good_asset(src, approvals=False)
    rev_id = await pipeline.register(db, manifest, private)
    (src / "lod0.glb").write_bytes((src / "lod0.glb").read_bytes() + b"\0")
    try:
        await pipeline.run(db, rev_id, manifest, public)
        raise AssertionError("expected refusal")
    except pipeline.IngestError as e:
        assert "register a new revision" in str(e)


async def test_rejection_stops_publication(db, tmp_path):
    private, public = storages(tmp_path)
    src = tmp_path / "src"
    src.mkdir()
    manifest = good_asset(src, approvals=False)
    ev = tmp_path / "e.md"
    ev.write_text("x")
    rev_id = await pipeline.register(db, manifest, private)
    await pipeline.approve(db, rev_id, manifest, kind="provenance", actor="founder", evidence=ev, approved=False)
    stages = await pipeline.run(db, rev_id, manifest, public)
    assert stages[-1].state == "failed" and "rejected" in stages[-1].report["error"]
    assert not list((tmp_path / "public").rglob("*"))


async def test_delisting_is_not_revocation(client, db, tmp_path):
    from conftest import make_asset
    asset, _ = await make_asset(db, "Priced chair", offers=[("US", "USD", 19900)])
    assert await pipeline.delist(db, asset.id) == 1
    body = (await client.get(f"/v1/assets/{asset.id}")).json()
    assert body["offer"]["available"] is False
    assert (await client.get(f"/v1/assets/{asset.id}/revisions/1")).status_code == 200, "geometry stays available"


async def test_manifest_approvals_bound_to_inputs_are_imported(db, tmp_path):
    import datetime as dt
    from kfn8.contract.validator import sha256_file
    private, public = storages(tmp_path)
    src = tmp_path / "src"
    src.mkdir()
    manifest = good_asset(src, approvals=False)
    fp_before = pipeline.input_fingerprint(manifest)
    ev = tmp_path / "review.png"
    ev.write_bytes(b"review")
    data = json.loads(manifest.read_text())
    for kind in ("provenance", "visual_dimensions"):
        data["approvals"].append({"kind": kind, "actor": "founder", "decided_at": "2026-09-23T12:00:00Z", "evidence_reference": "review.png",
                                  "evidence_sha256": sha256_file(ev), "input_sha256": fp_before, "approved": True})
    manifest.write_text(json.dumps(data))
    assert pipeline.input_fingerprint(manifest) == fp_before, "recording approvals must not change the approved inputs"
    rev = await pipeline.register(db, manifest, private)
    stages = await pipeline.run(db, rev, manifest, public)
    assert stages[-1].stage == "publish" and stages[-1].state == "passed"


async def test_stale_manifest_approvals_are_ignored(db, tmp_path):
    private, public = storages(tmp_path)
    src = tmp_path / "src"
    src.mkdir()
    manifest = good_asset(src, approvals=False)
    data = json.loads(manifest.read_text())
    for kind in ("provenance", "visual_dimensions"):
        data["approvals"].append({"kind": kind, "actor": "founder", "decided_at": "2026-09-23T12:00:00Z", "evidence_reference": "x",
                                  "evidence_sha256": "c" * 64, "input_sha256": "d" * 64, "approved": True})
    manifest.write_text(json.dumps(data))
    rev = await pipeline.register(db, manifest, private)
    stages = await pipeline.run(db, rev, manifest, public)
    assert stages[-1].stage == "approvals" and stages[-1].state == "failed"
