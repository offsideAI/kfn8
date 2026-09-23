"""Asset contract v1 validator. Fails closed: every check that cannot run is a failure, never a pass."""
from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass, field
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

from .geometry import GeometryError, Measurement, measure

CONTRACT_DIR = Path(__file__).resolve().parents[3] / "contracts" / "v1"
SCHEMA_PATH = CONTRACT_DIR / "asset.schema.json"
DIMENSION_TOLERANCE = 0.01
PIVOT_TOLERANCE = 0.005
PIVOT_MIN_ABS = 0.002
TRIANGLE_BUDGET = {0: 150_000, 1: 50_000, 2: 15_000}
TEXTURE_BUDGET = {0: 2048, 1: 1024, 2: 1024}
AXES = ("x", "y", "z")


@dataclass
class Check:
    name: str
    passed: bool
    detail: str
    rendition: str | None = None


@dataclass
class Report:
    manifest: str
    checks: list[Check] = field(default_factory=list)
    measurements: dict[str, dict] = field(default_factory=dict)

    @property
    def passed(self) -> bool:
        return bool(self.checks) and all(c.passed for c in self.checks)

    def add(self, name: str, passed: bool, detail: str, rendition: str | None = None) -> None:
        self.checks.append(Check(name, bool(passed), detail, rendition))

    def to_json(self) -> dict:
        return {"manifest": self.manifest, "passed": self.passed, "checks": [asdict(c) for c in self.checks],
                "measurements": self.measurements}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text())


def validate_manifest(manifest_path: Path, *, require_approvals: bool = False) -> Report:
    report = Report(str(manifest_path))
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        report.add("manifest.readable", False, f"cannot read manifest: {error}")
        return report

    schema_errors = sorted(Draft202012Validator(load_schema(), format_checker=FormatChecker()).iter_errors(manifest),
                           key=lambda e: list(e.path))
    if schema_errors:
        for e in schema_errors:
            report.add("manifest.schema", False, f"{'/'.join(map(str, e.path)) or '<root>'}: {e.message}")
        return report
    report.add("manifest.schema", True, "manifest matches contract v1 schema")

    approvals = {a["kind"]: a for a in manifest["approvals"] if a["approved"]}
    for kind in ("provenance", "visual_dimensions"):
        present = kind in approvals
        if require_approvals or present:
            report.add(f"approval.{kind}", present, "approved with evidence" if present else "missing approval")

    spec = manifest["dimension_spec"]
    target = (spec["width_m"], spec["height_m"], spec["depth_m"])  # X, Y, Z
    base = manifest_path.parent
    measured: list[tuple[str, Measurement]] = []
    seen = set()
    for r in manifest["renditions"]:
        key = f"lod{r['lod']}.{r['format']}.{r['variant_key']}"
        if key in seen:
            report.add("rendition.unique", False, f"duplicate rendition {key}", key)
            continue
        seen.add(key)
        path = (base / r["path"]).resolve()
        if not path.is_file():
            report.add("rendition.exists", False, f"missing file {r['path']}", key)
            continue
        size = path.stat().st_size
        report.add("rendition.size", size == r["size_bytes"], f"declared {r['size_bytes']} actual {size}", key)
        digest = sha256_file(path)
        report.add("rendition.sha256", digest == r["sha256"], "hash matches" if digest == r["sha256"] else f"actual {digest}", key)
        try:
            m = measure(path, r["format"])
        except (GeometryError, Exception) as error:  # noqa: BLE001 - any parse failure is a contract failure
            report.add("rendition.parse", False, f"{type(error).__name__}: {error}", key)
            continue
        measured.append((key, m))
        report.measurements[key] = {"min": [float(v) for v in m.min], "max": [float(v) for v in m.max],
                                    "size": [float(v) for v in m.size], "triangles": int(m.triangles),
                                    "max_texture_edge": int(m.max_texture_edge)}
        _check_rendition(report, key, r, m, target)

    formats = {k.split(".")[1] for k, _ in measured}
    report.add("renditions.formats", {"glb", "usdz"} <= formats, f"formats present: {sorted(formats)}")
    for i, (ka, ma) in enumerate(measured):
        for kb, mb in measured[i + 1:]:
            for axis in range(3):
                a, b = ma.size[axis], mb.size[axis]
                drift = abs(a - b) / max(a, b) if max(a, b) > 0 else 0
                if drift > DIMENSION_TOLERANCE:
                    report.add("dimensions.cross", False, f"{ka} vs {kb} {AXES[axis]} differ {drift:.2%}")
    if len(measured) >= 2 and not any(c.name == "dimensions.cross" for c in report.checks):
        report.add("dimensions.cross", True, "all representations agree within ±1 %")
    return report


def _check_rendition(report: Report, key: str, r: dict, m: Measurement, target: tuple[float, float, float]) -> None:
    if m.format == "usdz":
        report.add("units.metres", abs(m.meters_per_unit - 1.0) < 1e-9, f"metersPerUnit {m.meters_per_unit}", key)
        report.add("axis.up_y", m.up_axis == "Y", f"upAxis {m.up_axis}", key)
    for axis in range(3):
        size, want = m.size[axis], target[axis]
        drift = abs(size - want) / want
        report.add(f"dimensions.{AXES[axis]}", drift <= DIMENSION_TOLERANCE,
                   f"measured {size:.4f} m, spec {want:.4f} m, drift {drift:.2%}", key)
    height = m.size[1]
    base_tol = max(PIVOT_MIN_ABS, PIVOT_TOLERANCE * height)
    report.add("pivot.base", abs(m.min[1]) <= base_tol, f"min.y {m.min[1]:.4f} m (tolerance {base_tol:.4f})", key)
    for axis in (0, 2):
        tol = max(PIVOT_MIN_ABS, PIVOT_TOLERANCE * m.size[axis])
        report.add(f"pivot.centre_{AXES[axis]}", abs(m.centre[axis]) <= tol,
                   f"centre.{AXES[axis]} {m.centre[axis]:.4f} m (tolerance {tol:.4f})", key)
    report.add("materials.metallic_roughness", m.metallic_roughness,
               "PBR metallic-roughness" if m.metallic_roughness else "; ".join(m.material_issues), key)
    lod = r["lod"]
    report.add("budget.triangles", m.triangles <= TRIANGLE_BUDGET[lod], f"{m.triangles} ≤ {TRIANGLE_BUDGET[lod]}", key)
    report.add("budget.texture_edge", m.max_texture_edge <= TEXTURE_BUDGET[lod], f"{m.max_texture_edge} ≤ {TEXTURE_BUDGET[lod]}", key)
    if "triangles" in r:
        report.add("declared.triangles", r["triangles"] == m.triangles, f"declared {r['triangles']} measured {m.triangles}", key)


def validate_bundle_item(directory: Path) -> Report:
    """Client bundle check: the bundled files are byte-identical to manifest renditions and still meet the contract."""
    manifest_path = directory / "manifest.json"
    report = Report(str(manifest_path))
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        report.add("manifest.readable", False, f"cannot read manifest: {error}")
        return report
    errors = list(Draft202012Validator(load_schema(), format_checker=FormatChecker()).iter_errors(manifest))
    report.add("manifest.schema", not errors, "; ".join(e.message for e in errors[:3]) or "matches contract v1 schema")
    if errors:
        return report
    spec = manifest["dimension_spec"]
    target = (spec["width_m"], spec["height_m"], spec["depth_m"])
    by_name = {Path(r["path"]).name: r for r in manifest["renditions"]}
    bundled = [f for f in directory.iterdir() if f.suffix in (".usdz", ".glb")]
    report.add("bundle.nonempty", bool(bundled), f"{len(bundled)} rendition file(s) bundled")
    for f in bundled:
        r = by_name.get(f.name)
        if r is None:
            report.add("bundle.declared", False, f"{f.name} is not a manifest rendition", f.name)
            continue
        digest = sha256_file(f)
        report.add("bundle.sha256", digest == r["sha256"], "identical to manifest" if digest == r["sha256"] else f"actual {digest}", f.name)
        report.add("bundle.size", f.stat().st_size == r["size_bytes"], f"{f.stat().st_size} bytes", f.name)
        try:
            m = measure(f, r["format"])
        except Exception as error:  # noqa: BLE001
            report.add("rendition.parse", False, str(error), f.name)
            continue
        _check_rendition(report, f.name, r, m, target)
    return report
