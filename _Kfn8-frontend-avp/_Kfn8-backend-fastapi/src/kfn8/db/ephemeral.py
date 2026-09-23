"""Throwaway PostgreSQL cluster for tests and migration generation: initdb in a temp dir, start on a free port, stop and
delete on exit. Short-lived by construction; never a long-running service."""
from __future__ import annotations

import contextlib
import shutil
import socket
import subprocess
import tempfile
from collections.abc import Iterator
from pathlib import Path


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@contextlib.contextmanager
def ephemeral_postgres() -> Iterator[str]:
    root = Path(tempfile.mkdtemp(prefix="kfn8-pg-"))
    data, port = root / "data", _free_port()
    subprocess.run(["initdb", "-D", str(data), "-U", "kfn8", "--auth=trust", "-E", "UTF8", "--no-instructions"],
                   check=True, capture_output=True)
    subprocess.run(["pg_ctl", "-D", str(data), "-o", f"-p {port} -k {root} -c listen_addresses=127.0.0.1", "-l", str(root / "log"),
                    "-w", "start"], check=True, capture_output=True)
    try:
        subprocess.run(["createdb", "-h", "127.0.0.1", "-p", str(port), "-U", "kfn8", "kfn8"], check=True, capture_output=True)
        yield f"postgresql+asyncpg://kfn8@127.0.0.1:{port}/kfn8"
    finally:
        subprocess.run(["pg_ctl", "-D", str(data), "-m", "fast", "-w", "stop"], capture_output=True)
        shutil.rmtree(root, ignore_errors=True)
