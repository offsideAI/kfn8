"""kfn8-validate MANIFEST [MANIFEST...] [--require-approvals] [--json OUT]. Exit 1 if any manifest fails."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .validator import validate_bundle_item, validate_manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifests", nargs="+", type=Path)
    parser.add_argument("--require-approvals", action="store_true", help="publication gate: both approvals required")
    parser.add_argument("--json", type=Path, help="write the full report here")
    parser.add_argument("--bundle", action="store_true", help="arguments are client bundle item directories")
    args = parser.parse_args(argv)
    if args.bundle:
        reports = [validate_bundle_item(d) for d in args.manifests]
    else:
        reports = [validate_manifest(m, require_approvals=args.require_approvals) for m in args.manifests]
    for r in reports:
        print(f"{'PASS' if r.passed else 'FAIL'}  {r.manifest}")
        for c in r.checks:
            if not c.passed:
                print(f"   ✗ {c.name}{' [' + c.rendition + ']' if c.rendition else ''}: {c.detail}")
    if args.json:
        args.json.write_text(json.dumps([r.to_json() for r in reports], indent=2))
    return 0 if all(r.passed for r in reports) else 1


if __name__ == "__main__":
    sys.exit(main())
