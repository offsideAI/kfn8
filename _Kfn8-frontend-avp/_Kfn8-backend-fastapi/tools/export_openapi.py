"""Write the pinned OpenAPI document for API v1. CI runs this with --check and fails on any drift."""
import argparse, json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from kfn8.api.app import create_app  # noqa: E402
from kfn8.settings import Settings  # noqa: E402

OUT = Path(__file__).resolve().parents[1] / "contracts" / "v1" / "openapi.json"


def build() -> str:
    doc = create_app(Settings(), sessions=None).openapi()  # type: ignore[arg-type]
    return json.dumps(doc, indent=2, sort_keys=True) + "\n"


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true")
    a = p.parse_args()
    text = build()
    if a.check:
        if not OUT.exists() or OUT.read_text() != text:
            print("openapi.json is out of date; run tools/export_openapi.py", file=sys.stderr)
            sys.exit(1)
        print("openapi.json up to date")
    else:
        OUT.write_text(text)
        print("wrote", OUT)
