"""Write contract-v1 manifests for the bundled fixtures from conformed files and licence evidence.

Approvals are intentionally empty: provenance and visual/dimension approvals belong to the founder and are added with
`tools/approve_manifest.py`. Dimension spec authority is operator: source geometry measured after the scale sanity check.
Existing manifests are left untouched (they may carry approvals) unless `--force` is given.

Usage: venv/bin/python tools/make_manifests.py [--force]
"""
import datetime, json, uuid
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from kfn8.contract.geometry import measure_glb  # noqa: E402
from kfn8.contract.validator import sha256_file  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
NS = uuid.UUID("6f1d2c1e-5a8e-4a0f-9b0e-6b6b8d3f0a11")
FIXTURES = {
    "modern_arm_chair_01": dict(name="Modern arm chair", category="seating", affinity="floor", tags=["mid-century", "walnut"], colour="walnut", weight="medium"),
    "industrial_wall_sconce": dict(name="Industrial wall sconce", category="lighting", affinity="wall", tags=["industrial", "brass"], colour="brass", weight="light"),
    "hanging_industrial_lamp": dict(name="Hanging industrial lamp", category="lighting", affinity="ceiling", tags=["industrial"], colour="olive", weight="light"),
    "ceramic_vase_02": dict(name="Ceramic vase", category="decor", affinity="tabletop", tags=["ceramic"], colour="bone", weight="light"),
    # Batch 2 (2026-09-26): five generic floor pieces, conform turn noted per item in the batch-2 review sheet.
    "sofa_02": dict(name="Tufted leather sofa", category="seating", affinity="floor", tags=["vintage", "leather"], colour="ink", weight="heavy"),
    "modern_coffee_table_01": dict(name="Stone-top coffee table", category="table", affinity="floor", tags=["modern", "stone", "walnut"], colour="walnut", weight="medium"),
    "side_table_01": dict(name="Oak side table", category="table", affinity="floor", tags=["minimalist", "oak"], colour="walnut", weight="light"),
    "wooden_display_shelves_01": dict(name="Cube display shelves", category="storage", affinity="floor", tags=["modern", "pine"], colour="clay", weight="medium"),
    "Ottoman_01": dict(name="Leather ottoman", category="seating", affinity="floor", tags=["leather", "tufted"], colour="walnut", weight="medium"),
}
now = datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
force = "--force" in sys.argv
for slug, meta in FIXTURES.items():
    d = ROOT / "assets-conformed" / slug
    if (d / "manifest.json").exists() and not force:
        print(slug, "manifest exists; left unchanged")
        continue
    info_path = ROOT / "ledger" / "evidence" / f"{slug}.info.json"
    info = json.loads(info_path.read_text())
    lod0 = measure_glb(d / "lod0.glb")
    w, h, dep = lod0.size
    mount = None
    if meta["affinity"] == "wall":
        mount = {"mount_point_m": [0.0, round(h / 2, 4), round(dep / 2, 4)], "mount_normal": [0.0, 0.0, 1.0]}
    if meta["affinity"] == "ceiling":
        mount = {"mount_point_m": [0.0, round(h, 4), 0.0], "mount_normal": [0.0, 1.0, 0.0]}
    renditions = []
    for lod in (0, 1, 2):
        p = d / f"lod{lod}.glb"
        renditions.append({"lod": lod, "format": "glb", "variant_key": "default", "path": p.name, "sha256": sha256_file(p),
                           "size_bytes": p.stat().st_size, "triangles": measure_glb(p).triangles})
    u = d / "lod0.usdz"
    renditions.append({"lod": 0, "format": "usdz", "variant_key": "default", "path": u.name, "sha256": sha256_file(u), "size_bytes": u.stat().st_size})
    manifest = {
        "contract_version": "1.0.0",
        "asset": {"id": str(uuid.uuid5(NS, slug)), "name": meta["name"], "sku": None, "category": meta["category"],
                  "affinity": meta["affinity"], "provenance": "licensed", "delivery_mode": "public",
                  "style_tags": meta["tags"], "dominant_colour": meta["colour"], "weight_class": meta["weight"],
                  "is_floor_covering": False},
        "revision": 1,
        "front_axis": "-Z",
        "dimension_spec": {"width_m": round(w, 4), "depth_m": round(dep, 4), "height_m": round(h, 4), "authority_kind": "operator",
                           "source": f"Poly Haven {slug} 1k glTF, conformed geometry measured after furniture-scale sanity check",
                           "approved_by": "measured by agent; founder sign-off is the visual_dimensions approval", "approved_at": now, "evidence_sha256": sha256_file(info_path)},
        "licence": {"source_url": f"https://polyhaven.com/a/{slug}", "author": ", ".join(info["authors"]), "licence_id": "CC0-1.0",
                    "attribution_required": False, "attribution_text": None,
                    "evidence_reference": f"ledger/evidence/{slug}.info.json + ledger/evidence/polyhaven-license.html",
                    "evidence_sha256": sha256_file(info_path), "recorded_at": now},
        "approvals": [],
        "renditions": renditions,
    }
    if mount:
        manifest["attachment"] = mount
    (d / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(slug, manifest["asset"]["id"], f"{w:.3f}x{h:.3f}x{dep:.3f}")
