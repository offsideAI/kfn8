"""Batch readiness dry run: register + run every conformed manifest against a throwaway Postgres and local storage.
Records per-stage timing, pass/fail counts and idempotency (a second run must skip everything already passed).
Stops at the approval gate: approvals are the founder's, never simulated here."""
import asyncio, json, subprocess, sys, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
from kfn8.db.ephemeral import ephemeral_postgres  # noqa: E402
from kfn8.db.session import make_engine, make_sessionmaker  # noqa: E402
from kfn8.ingest import pipeline  # noqa: E402
from kfn8.ingest.storage import LocalStorage  # noqa: E402


async def main(url: str, out: Path) -> dict:
    engine = make_engine(url)
    sessions = make_sessionmaker(engine)
    work = Path(tempfile.mkdtemp(prefix="kfn8-batch-"))
    private, public = LocalStorage(work / "private"), LocalStorage(work / "public")
    report = {"assets": [], "totals": {}}
    for manifest in sorted((ROOT / "assets-conformed").glob("*/manifest.json")):
        entry = {"asset": manifest.parent.name, "stages": []}
        async with sessions() as s:
            t0 = time.perf_counter()
            rev = await pipeline.register(s, manifest, private)
            entry["register_ms"] = round((time.perf_counter() - t0) * 1000, 1)
            entry["revision_id"] = str(rev)
            for attempt in (1, 2):
                t0 = time.perf_counter()
                results = await pipeline.run(s, rev, manifest, public)
                entry["stages"].append({"attempt": attempt, "ms": round((time.perf_counter() - t0) * 1000, 1),
                                        "results": [(r.stage, r.state, r.skipped) for r in results]})
        report["assets"].append(entry)
    await engine.dispose()
    flat = [r for a in report["assets"] for r in a["stages"][0]["results"]]
    report["totals"] = {
        "assets": len(report["assets"]),
        "validate_passed": sum(1 for st, state, _ in flat if st == "validate" and state == "passed"),
        "awaiting_approvals": sum(1 for st, state, _ in flat if st == "approvals" and state == "failed"),
        "public_objects_before_approval": sum(1 for _ in (work / "public").rglob("*") if _.is_file()),
        "second_run_skipped_passed_stages": all(r[2] for a in report["assets"] for r in a["stages"][1]["results"] if r[1] == "passed"),
    }
    out.write_text(json.dumps(report, indent=2))
    return report


if __name__ == "__main__":
    out = ROOT / "ledger" / "batch-dry-run-2026-09-23.json"
    with ephemeral_postgres() as url:
        subprocess.run([str(ROOT / "venv/bin/alembic"), "-x", f"url={url}", "upgrade", "head"], cwd=ROOT, check=True, capture_output=True)
        r = asyncio.run(main(url, out))
    print(json.dumps(r["totals"], indent=2))
    for a in r["assets"]:
        print(a["asset"], [(st, state) for st, state, _ in a["stages"][0]["results"]], f'{a["stages"][0]["ms"]} ms')
