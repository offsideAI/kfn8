"""Build real GLB/USDZ box assets and manifests for tests."""
from __future__ import annotations

import io
import json
import uuid
from pathlib import Path

import numpy as np
from PIL import Image
from pygltflib import (GLTF2, Accessor, Asset, Buffer, BufferView, Image as GImage, Material, Mesh, Node,
                       PbrMetallicRoughness, Primitive, Attributes, Scene, Texture, TextureInfo)

from kfn8.contract.validator import sha256_file

EVIDENCE = "a" * 64


def box_arrays(w: float, h: float, d: float, offset=(0.0, 0.0, 0.0)):
    x0, x1 = -w / 2 + offset[0], w / 2 + offset[0]
    y0, y1 = 0.0 + offset[1], h + offset[1]
    z0, z1 = -d / 2 + offset[2], d / 2 + offset[2]
    v = np.array([[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0],
                  [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]], dtype=np.float32)
    quads = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 3, 7, 4)]
    tris = np.array([[a, b, c] for q in quads for a, b, c in ((q[0], q[1], q[2]), (q[0], q[2], q[3]))], dtype=np.uint16)
    return v, tris, quads


def write_glb(path: Path, w: float, h: float, d: float, *, offset=(0, 0, 0), scale=1.0, texture_edge=0,
              spec_gloss=False, node_rotation=None) -> Path:
    v, tris, _ = box_arrays(w, h, d, offset)
    vb, ib = v.tobytes(), tris.flatten().tobytes()
    blob = bytearray(vb + ib)
    views = [BufferView(buffer=0, byteOffset=0, byteLength=len(vb), target=34962),
             BufferView(buffer=0, byteOffset=len(vb), byteLength=len(ib), target=34963)]
    material = Material(pbrMetallicRoughness=PbrMetallicRoughness(baseColorFactor=[0.6, 0.4, 0.3, 1], metallicFactor=0, roughnessFactor=0.8))
    images, textures = [], []
    if texture_edge:
        png = io.BytesIO()
        Image.new("RGB", (texture_edge, texture_edge), (200, 180, 150)).save(png, "PNG")
        while len(blob) % 4:
            blob += b"\0"
        views.append(BufferView(buffer=0, byteOffset=len(blob), byteLength=len(png.getvalue())))
        blob += png.getvalue()
        images = [GImage(bufferView=2, mimeType="image/png")]
        textures = [Texture(source=0)]
        material.pbrMetallicRoughness.baseColorTexture = TextureInfo(index=0)
    if spec_gloss:
        material.extensions = {"KHR_materials_pbrSpecularGlossiness": {"diffuseFactor": [1, 1, 1, 1]}}
    node = Node(mesh=0, scale=[scale] * 3)
    if node_rotation:
        node.rotation = node_rotation
    gltf = GLTF2(
        asset=Asset(version="2.0"), scene=0, scenes=[Scene(nodes=[0])], nodes=[node],
        meshes=[Mesh(primitives=[Primitive(attributes=Attributes(POSITION=0), indices=1, material=0)])],
        materials=[material], images=images, textures=textures,
        accessors=[Accessor(bufferView=0, componentType=5126, count=len(v), type="VEC3",
                            min=v.min(axis=0).tolist(), max=v.max(axis=0).tolist()),
                   Accessor(bufferView=1, componentType=5123, count=tris.size, type="SCALAR")],
        bufferViews=views, buffers=[Buffer(byteLength=len(blob))])
    gltf.set_binary_blob(bytes(blob))
    gltf.save_binary(str(path))
    return path


def write_usdz(path: Path, w: float, h: float, d: float, *, offset=(0, 0, 0), meters_per_unit=1.0, up="Y") -> Path:
    from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils

    usdc = path.with_suffix(".usdc")
    stage = Usd.Stage.CreateNew(str(usdc))
    UsdGeom.SetStageMetersPerUnit(stage, meters_per_unit)
    UsdGeom.SetStageUpAxis(stage, up)
    root = UsdGeom.Xform.Define(stage, "/Asset")
    stage.SetDefaultPrim(root.GetPrim())
    v, _, quads = box_arrays(w, h, d, offset)
    mesh = UsdGeom.Mesh.Define(stage, "/Asset/Box")
    mesh.CreatePointsAttr([Gf.Vec3f(*map(float, p)) for p in v])
    mesh.CreateFaceVertexCountsAttr([4] * len(quads))
    mesh.CreateFaceVertexIndicesAttr([i for q in quads for i in q])
    mat = UsdShade.Material.Define(stage, "/Asset/Mat")
    shader = UsdShade.Shader.Define(stage, "/Asset/Mat/Surface")
    shader.CreateIdAttr("UsdPreviewSurface")
    shader.CreateInput("metallic", Sdf.ValueTypeNames.Float).Set(0.0)
    shader.CreateInput("roughness", Sdf.ValueTypeNames.Float).Set(0.8)
    mat.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "surface")
    UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(mat)
    stage.GetRootLayer().Save()
    UsdUtils.CreateNewUsdzPackage(str(usdc), str(path))
    usdc.unlink()
    return path


def rendition(base: Path, path: Path, lod: int, fmt: str) -> dict:
    return {"lod": lod, "format": fmt, "variant_key": "default", "path": str(path.relative_to(base)),
            "sha256": sha256_file(path), "size_bytes": path.stat().st_size}


def write_manifest(base: Path, renditions: list[dict], *, w=0.8, h=0.9, d=0.7, approvals=True, **overrides) -> Path:
    manifest = {
        "contract_version": "1.0.0",
        "asset": {"id": str(uuid.uuid4()), "name": "Test chair", "category": "seating", "affinity": "floor",
                  "provenance": "licensed", "delivery_mode": "public"},
        "revision": 1,
        "front_axis": "-Z",
        "dimension_spec": {"width_m": w, "depth_m": d, "height_m": h, "authority_kind": "operator", "source": "test",
                           "approved_by": "tester", "approved_at": "2026-09-23T00:00:00Z", "evidence_sha256": EVIDENCE},
        "licence": {"source_url": "https://example.com/a", "author": "A", "licence_id": "CC0-1.0", "attribution_required": False,
                    "evidence_reference": "ledger/test.md", "evidence_sha256": EVIDENCE, "recorded_at": "2026-09-23T00:00:00Z"},
        "approvals": [{"kind": k, "actor": "founder", "decided_at": "2026-09-23T00:00:00Z", "evidence_reference": "x",
                       "evidence_sha256": EVIDENCE, "approved": True} for k in ("provenance", "visual_dimensions")] if approvals else [],
        "renditions": renditions,
    }
    manifest.update(overrides)
    path = base / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2))
    return path


def good_asset(base: Path, w=0.8, h=0.9, d=0.7, **manifest_overrides) -> Path:
    glb = write_glb(base / "lod0.glb", w, h, d, texture_edge=256)
    usdz = write_usdz(base / "lod0.usdz", w, h, d)
    return write_manifest(base, [rendition(base, glb, 0, "glb"), rendition(base, usdz, 0, "usdz")], w=w, h=h, d=d, **manifest_overrides)
