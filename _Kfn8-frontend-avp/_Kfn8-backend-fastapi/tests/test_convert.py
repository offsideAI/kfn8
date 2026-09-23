import sys

import pytest

from kfn8.ingest.convert import conform_gltf, run_constrained
from kfn8.ingest.pipeline import IngestError


def test_timeout_is_a_failure_not_a_pass():
    with pytest.raises(IngestError, match="timed out"):
        run_constrained([sys.executable, "-c", "import time; time.sleep(5)"], timeout=1)


def test_nonzero_exit_is_a_failure():
    with pytest.raises(IngestError, match="exited 3"):
        run_constrained([sys.executable, "-c", "import sys; sys.exit(3)"])


def test_output_size_limit_is_enforced(tmp_path):
    code = f"open({str(tmp_path / 'big')!r}, 'wb').write(b'x' * (8 << 20))"
    with pytest.raises(IngestError):
        run_constrained([sys.executable, "-c", code], max_file_bytes=1 << 20)


def test_remote_urls_are_refused():
    with pytest.raises(IngestError, match="local files"):
        run_constrained(["blender", "-b", "https://example.com/model.gltf"])


def test_environment_is_scrubbed(monkeypatch):
    monkeypatch.setenv("KFN8_SPACES_SECRET", "must-not-leak")
    out = run_constrained([sys.executable, "-c", "import os; print(os.environ.get('KFN8_SPACES_SECRET'))"])
    assert out.stdout.strip() == "None"


def test_malformed_source_fails_conform(tmp_path):
    bad = tmp_path / "bad.gltf"
    bad.write_text("{ not gltf")
    with pytest.raises(IngestError):
        conform_gltf(bad, tmp_path / "out", timeout=120)
