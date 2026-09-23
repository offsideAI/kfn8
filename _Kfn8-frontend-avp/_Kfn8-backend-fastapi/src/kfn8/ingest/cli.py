"""kfn8-ingest: private operator commands. Credentials come from KFN8_* environment variables; never from arguments.

  kfn8-ingest register MANIFEST
  kfn8-ingest run REVISION_ID MANIFEST
  kfn8-ingest approve REVISION_ID MANIFEST --kind provenance|visual_dimensions --actor NAME --evidence FILE [--reject]
  kfn8-ingest revoke REVISION_ID
  kfn8-ingest delist ASSET_ID [--market US]
  kfn8-ingest status REVISION_ID
Add --local-storage DIR to use filesystem storage instead of Spaces (tests, dry runs)."""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
import uuid
from pathlib import Path

from sqlalchemy import select

from ..db.models import AssetRevision, IngestionStage
from ..db.session import make_engine, make_sessionmaker
from ..settings import get_settings
from . import pipeline
from .storage import DigitalOceanPurger, LocalStorage, RecordingPurger, S3Storage


def storages(args, settings):
    if args.local_storage:
        root = Path(args.local_storage)
        return LocalStorage(root / "private"), LocalStorage(root / "public"), RecordingPurger()
    if not (settings.spaces_key and settings.spaces_secret):
        sys.exit("Spaces credentials missing (KFN8_SPACES_KEY / KFN8_SPACES_SECRET). Use --local-storage for a dry run.")
    common = dict(endpoint=settings.spaces_endpoint, region=settings.spaces_region, key=settings.spaces_key, secret=settings.spaces_secret)
    purger = DigitalOceanPurger(settings.cdn_purge_token, settings.cdn_endpoint_id) if settings.cdn_purge_token and settings.cdn_endpoint_id else None
    if purger is None:
        sys.exit("CDN purge credentials missing (KFN8_CDN_PURGE_TOKEN / KFN8_CDN_ENDPOINT_ID).")
    return S3Storage(settings.private_bucket, public=False, **common), S3Storage(settings.public_bucket, public=True, **common), purger


async def main_async(args) -> int:
    settings = get_settings()
    engine = make_engine(settings.database_url)
    sessions = make_sessionmaker(engine)
    private, public, purger = storages(args, settings)
    try:
        async with sessions() as s:
            if args.cmd == "register":
                print(await pipeline.register(s, Path(args.manifest), private))
            elif args.cmd == "run":
                for r in await pipeline.run(s, uuid.UUID(args.revision), Path(args.manifest), public):
                    print(f"{r.stage:10s} {r.state}{' (already passed)' if r.skipped else ''}  {json.dumps(r.report)[:300]}")
            elif args.cmd == "approve":
                await pipeline.approve(s, uuid.UUID(args.revision), Path(args.manifest), kind=args.kind, actor=args.actor,
                                       evidence=Path(args.evidence), approved=not args.reject)
                print("recorded")
            elif args.cmd == "revoke":
                print(json.dumps(await pipeline.revoke(s, uuid.UUID(args.revision), public, purger), indent=2))
            elif args.cmd == "delist":
                print(await pipeline.delist(s, uuid.UUID(args.asset), args.market), "offer(s) delisted")
            elif args.cmd == "status":
                rev = await s.get(AssetRevision, uuid.UUID(args.revision))
                print("state", rev.state if rev else "unknown")
                for st in (await s.execute(select(IngestionStage).where(IngestionStage.revision_id == uuid.UUID(args.revision)))).scalars():
                    print(f"{st.stage:10s} {st.state:8s} {st.tool_version} {st.input_fingerprint[:12]} {json.dumps(st.report)[:200]}")
    except pipeline.IngestError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    finally:
        await engine.dispose()
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--local-storage")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("register").add_argument("manifest")
    r = sub.add_parser("run"); r.add_argument("revision"); r.add_argument("manifest")
    a = sub.add_parser("approve"); a.add_argument("revision"); a.add_argument("manifest")
    a.add_argument("--kind", required=True, choices=["provenance", "visual_dimensions"]); a.add_argument("--actor", required=True)
    a.add_argument("--evidence", required=True); a.add_argument("--reject", action="store_true")
    sub.add_parser("revoke").add_argument("revision")
    d = sub.add_parser("delist"); d.add_argument("asset"); d.add_argument("--market")
    sub.add_parser("status").add_argument("revision")
    return asyncio.run(main_async(p.parse_args(argv)))


if __name__ == "__main__":
    sys.exit(main())
