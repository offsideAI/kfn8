#!/usr/bin/env python3
"""Fetch Poly Haven CC0 model sources with their provenance evidence.

For each slug: saves the API responses as ledger/evidence/<slug>.info.json and <slug>.files.json (the licence and
author record the manifests cite), then downloads the 1k glTF, its .bin and textures into assets-source/<slug>/,
checking each file's size and MD5 against the API. Nothing is approved here; approvals are the founder's.

Usage: venv/bin/python tools/fetch_polyhaven.py SLUG [SLUG ...]
"""
import hashlib, json, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = "https://api.polyhaven.com"


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "kfn8-asset-ingest/1.0 (operator tooling)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def download(entry: dict, dest: Path) -> None:
    data = get(entry["url"])
    if len(data) != entry["size"] or hashlib.md5(data).hexdigest() != entry["md5"]:
        raise SystemExit(f"integrity check failed for {entry['url']}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)


def fetch(slug: str) -> None:
    info = json.loads(get(f"{API}/info/{slug}"))
    files = json.loads(get(f"{API}/files/{slug}"))
    evidence = ROOT / "ledger" / "evidence"
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / f"{slug}.info.json").write_text(json.dumps(info))
    (evidence / f"{slug}.files.json").write_text(json.dumps(files, indent=1))
    gltf = files["gltf"]["1k"]["gltf"]
    out = ROOT / "assets-source" / slug
    download(gltf, out / f"{slug}_1k.gltf")
    for rel, entry in gltf.get("include", {}).items():
        download(entry, out / rel)
    print(f"FETCHED {slug}: {info['name']} by {', '.join(info['authors'])} -> {out.relative_to(ROOT)} ({1 + len(gltf.get('include', {}))} files)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for s in sys.argv[1:]:
        fetch(s)
