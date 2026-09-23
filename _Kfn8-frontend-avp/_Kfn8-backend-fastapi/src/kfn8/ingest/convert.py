"""Constrained converter subprocesses. Untrusted source files are parsed by external tools (Blender), so every run gets
CPU-time, output-file-size and wall-clock limits, a scrubbed environment, and local file paths only (no URL fetching).
Timeouts and non-zero exits are stage failures, never placeholder passes."""
from __future__ import annotations

import os
import resource
import shutil
import subprocess
from pathlib import Path

from .pipeline import IngestError

ROOT = Path(__file__).resolve().parents[3]
CONFORM_SCRIPT = ROOT / "tools" / "blender_conform.py"


def _limits(cpu_seconds: int, max_file_bytes: int):
    def apply():
        resource.setrlimit(resource.RLIMIT_CPU, (cpu_seconds, cpu_seconds))
        resource.setrlimit(resource.RLIMIT_FSIZE, (max_file_bytes, max_file_bytes))
    return apply


def run_constrained(argv: list[str], *, timeout: int = 600, cpu_seconds: int = 900, max_file_bytes: int = 512 << 20,
                    cwd: Path | None = None) -> subprocess.CompletedProcess:
    if any(a.startswith(("http://", "https://", "ftp://")) for a in argv):
        raise IngestError("converters may only read local files")
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": str(cwd or Path.cwd()), "LANG": "C"}
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, cwd=cwd, env=env,
                                preexec_fn=_limits(cpu_seconds, max_file_bytes))
    except subprocess.TimeoutExpired as e:
        raise IngestError(f"{Path(argv[0]).name} timed out after {timeout}s") from e
    if result.returncode != 0:
        raise IngestError(f"{Path(argv[0]).name} exited {result.returncode}: {result.stderr[-500:]}")
    return result


def conform_gltf(source: Path, out_dir: Path, *, keep: list[str] | None = None, timeout: int = 900) -> dict:
    """Run the Blender conform step (turn to −Z front, base-centre pivot, LODs, USDZ) in a constrained subprocess."""
    blender = shutil.which("blender")
    if blender is None:
        raise IngestError("Blender is not installed on this operator machine")
    if not source.is_file():
        raise IngestError(f"source {source} not found")
    out_dir.mkdir(parents=True, exist_ok=True)
    argv = [blender, "-b", "--factory-startup", "--python", str(CONFORM_SCRIPT), "--", str(source), str(out_dir)]
    if keep:
        argv += ["--keep", ",".join(keep)]
    result = run_constrained(argv, timeout=timeout, cwd=out_dir)
    lines = [l for l in result.stdout.splitlines() if l.startswith("CONFORM")]
    if not any("done" in l for l in lines):
        raise IngestError("conform did not complete: " + " | ".join(lines[-3:]))
    missing = [n for n in ("lod0.glb", "lod1.glb", "lod2.glb", "lod0.usdz") if not (out_dir / n).is_file()]
    if missing:
        raise IngestError(f"conform produced no {missing}")
    return {"log": lines}
