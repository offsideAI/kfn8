import json

from builders import good_asset, rendition, write_glb, write_manifest, write_usdz

from kfn8.contract.cli import main
from kfn8.contract.validator import validate_manifest


def failed(report):
    return {c.name for c in report.checks if not c.passed}


def test_conforming_asset_passes(tmp_path):
    report = validate_manifest(good_asset(tmp_path), require_approvals=True)
    assert report.passed, failed(report)
    assert report.measurements["lod0.glb.default"]["triangles"] == 12


def test_missing_evidence_hash_rejected_by_schema(tmp_path):
    m = good_asset(tmp_path)
    data = json.loads(m.read_text())
    data["licence"]["evidence_sha256"] = "not-a-hash"
    m.write_text(json.dumps(data))
    assert "manifest.schema" in failed(validate_manifest(m))


def test_missing_approvals_fail_publication_gate(tmp_path):
    m = good_asset(tmp_path, approvals=False)
    assert validate_manifest(m).passed
    assert {"approval.provenance", "approval.visual_dimensions"} <= failed(validate_manifest(m, require_approvals=True))


def test_centimetre_units_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 80, 90, 70)
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "dimensions.x" in failed(validate_manifest(m))


def test_usdz_wrong_meters_per_unit_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8, 0.9, 0.7)
    usdz = write_usdz(tmp_path / "a.usdz", 80, 90, 70, meters_per_unit=0.01)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "units.metres" in failed(validate_manifest(m))


def test_z_up_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8, 0.9, 0.7)
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7, up="Z")
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "axis.up_y" in failed(validate_manifest(m))


def test_rotated_orientation_rejected(tmp_path):
    # 90° about X swaps height and depth: a lying-down chair.
    glb = write_glb(tmp_path / "a.glb", 0.8, 0.9, 0.7, node_rotation=[0.7071068, 0, 0, 0.7071068])
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert {"dimensions.y", "dimensions.z"} <= failed(validate_manifest(m))


def test_off_centre_pivot_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8, 0.9, 0.7, offset=(0.2, 0.0, 0.0))
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "pivot.centre_x" in failed(validate_manifest(m))


def test_centre_pivot_instead_of_base_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8, 0.9, 0.7, offset=(0, -0.45, 0))
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "pivot.base" in failed(validate_manifest(m))


def test_dimension_drift_over_one_percent_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8 * 1.015, 0.9, 0.7)
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "dimensions.x" in failed(validate_manifest(m))


def test_opposite_direction_drift_caught_by_cross_check(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8 * 1.008, 0.9, 0.7)
    usdz = write_usdz(tmp_path / "a.usdz", 0.8 * 0.992, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    f = failed(validate_manifest(m))
    assert "dimensions.x" not in f and "dimensions.cross" in f


def test_texture_over_budget_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8, 0.9, 0.7, texture_edge=4096)
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "budget.texture_edge" in failed(validate_manifest(m))


def test_lod_texture_budget_is_tighter(tmp_path):
    glb0 = write_glb(tmp_path / "a0.glb", 0.8, 0.9, 0.7, texture_edge=2048)
    glb1 = write_glb(tmp_path / "a1.glb", 0.8, 0.9, 0.7, texture_edge=2048)
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb0, 0, "glb"), rendition(tmp_path, glb1, 1, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    bad = [c for c in validate_manifest(m).checks if not c.passed]
    assert [(c.name, c.rendition) for c in bad] == [("budget.texture_edge", "lod1.glb.default")]


def test_spec_gloss_material_rejected(tmp_path):
    glb = write_glb(tmp_path / "a.glb", 0.8, 0.9, 0.7, spec_gloss=True)
    usdz = write_usdz(tmp_path / "a.usdz", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb, 0, "glb"), rendition(tmp_path, usdz, 0, "usdz")])
    assert "materials.metallic_roughness" in failed(validate_manifest(m))


def test_corrupted_file_rejected_by_hash(tmp_path):
    m = good_asset(tmp_path)
    glb = tmp_path / "lod0.glb"
    data = bytearray(glb.read_bytes())
    data[-10] ^= 0xFF
    glb.write_bytes(bytes(data))
    assert "rendition.sha256" in failed(validate_manifest(m))


def test_malformed_glb_is_failure_not_crash(tmp_path):
    m = good_asset(tmp_path)
    (tmp_path / "lod0.glb").write_bytes(b"not a glb at all")
    data = json.loads(m.read_text())
    from kfn8.contract.validator import sha256_file
    data["renditions"][0]["sha256"] = sha256_file(tmp_path / "lod0.glb")
    data["renditions"][0]["size_bytes"] = 16
    m.write_text(json.dumps(data))
    assert "rendition.parse" in failed(validate_manifest(m))


def test_single_format_rejected(tmp_path):
    glb0 = write_glb(tmp_path / "a0.glb", 0.8, 0.9, 0.7)
    glb1 = write_glb(tmp_path / "a1.glb", 0.8, 0.9, 0.7)
    m = write_manifest(tmp_path, [rendition(tmp_path, glb0, 0, "glb"), rendition(tmp_path, glb1, 1, "glb")])
    assert "renditions.formats" in failed(validate_manifest(m))


def test_cli_exit_codes(tmp_path, capsys):
    ok = good_asset(tmp_path)
    assert main([str(ok), "--require-approvals"]) == 0
    bad_dir = tmp_path / "bad"
    bad_dir.mkdir()
    bad = good_asset(bad_dir, approvals=False)
    assert main([str(bad), "--require-approvals", "--json", str(tmp_path / "r.json")]) == 1
    assert json.loads((tmp_path / "r.json").read_text())[0]["passed"] is False


def test_bundle_item_detects_tampering(tmp_path):
    import shutil
    from kfn8.contract.validator import validate_bundle_item
    good_asset(tmp_path)
    bundle = tmp_path / "bundle"
    bundle.mkdir()
    shutil.copy(tmp_path / "manifest.json", bundle / "manifest.json")
    shutil.copy(tmp_path / "lod0.usdz", bundle / "lod0.usdz")
    assert validate_bundle_item(bundle).passed
    write_usdz(bundle / "lod0.usdz", 0.9, 0.9, 0.7)
    assert "bundle.sha256" in failed(validate_bundle_item(bundle))
