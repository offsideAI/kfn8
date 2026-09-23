#!/usr/bin/env python3
"""Founder approval of asset revisions, recorded in each manifest (no database needed).

Run it yourself; it asks before recording anything. For each asset you confirm two separate approvals:
  provenance         — the source and licence are what the ledger says (CC0, author, source page)
  visual_dimensions  — the model looks right, faces the right way, and its dimensions are plausible
Each approval stores your name, the time, the hash of the evidence file you reviewed, and the fingerprint of the exact
model files, so a later change to the model invalidates it. The app's bundled copy of the manifest is updated too.

Usage: python3 tools/approve_manifest.py --actor "Your Name" --evidence ledger/review-sheet.png [--reject]
"""
import argparse, datetime, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from kfn8.contract.validator import sha256_file, validate_manifest  # noqa: E402
from kfn8.ingest.pipeline import input_fingerprint  # noqa: E402

BUNDLE = ROOT.parent / "_Kfn8-frontend-avp-src" / "Kfn8" / "Resources" / "Catalogue"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--actor", required=True)
    ap.add_argument("--evidence", required=True, type=Path)
    ap.add_argument("--reject", action="store_true", help="record rejections instead of approvals")
    a = ap.parse_args()
    if not a.evidence.is_file():
        sys.exit(f"evidence file not found: {a.evidence}")
    evidence_hash = sha256_file(a.evidence)
    now = datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    changed = 0
    for manifest in sorted((ROOT / "assets-conformed").glob("*/manifest.json")):
        m = json.loads(manifest.read_text())
        spec, lic = m["dimension_spec"], m["licence"]
        print(f"\n{m['asset']['name']}  ({manifest.parent.name})")
        print(f"  source   {lic['source_url']}  ·  {lic['licence_id']}  ·  author {lic['author']}")
        print(f"  size     W {spec['width_m']*100:.0f} × D {spec['depth_m']*100:.0f} × H {spec['height_m']*100:.0f} cm  ·  mounts on: {m['asset']['affinity']}")
        report = validate_manifest(manifest)
        if not report.passed:
            print("  contract check FAILED; skipping (fix the model first)")
            continue
        fp = input_fingerprint(manifest)
        for kind in ("provenance", "visual_dimensions"):
            if any(x["kind"] == kind and x.get("input_sha256") == fp for x in m["approvals"]):
                print(f"  {kind}: already recorded")
                continue
            verb = "REJECT" if a.reject else "approve"
            if input(f"  {verb} {kind}? [y/N] ").strip().lower() != "y":
                continue
            m["approvals"].append({"kind": kind, "actor": a.actor, "decided_at": now, "evidence_reference": str(a.evidence),
                                   "evidence_sha256": evidence_hash, "input_sha256": fp, "approved": not a.reject})
            changed += 1
        manifest.write_text(json.dumps(m, indent=2) + "\n")
        bundled = BUNDLE / manifest.parent.name / "manifest.json"
        if bundled.parent.is_dir():
            bundled.write_text(manifest.read_text())
    print(f"\nRecorded {changed} decision(s). Check: venv/bin/kfn8-validate --require-approvals assets-conformed/*/manifest.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
