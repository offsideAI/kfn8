"""Measure real geometry from GLB and USDZ files: world bounds, triangles, materials, textures, stage metadata."""
from __future__ import annotations

import io
import struct
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image
from pygltflib import GLTF2

COMPONENT_DTYPE = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
TYPE_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


@dataclass
class Measurement:
    format: str
    min: tuple[float, float, float]
    max: tuple[float, float, float]
    triangles: int
    max_texture_edge: int
    metallic_roughness: bool
    material_issues: list[str] = field(default_factory=list)
    meters_per_unit: float = 1.0
    up_axis: str = "Y"

    @property
    def size(self) -> tuple[float, float, float]:
        return tuple(self.max[i] - self.min[i] for i in range(3))  # type: ignore[return-value]

    @property
    def centre(self) -> tuple[float, float, float]:
        return tuple((self.max[i] + self.min[i]) / 2 for i in range(3))  # type: ignore[return-value]


class GeometryError(Exception):
    pass


# ---------------------------------------------------------------------------- GLB

def _node_matrix(node) -> np.ndarray:
    if node.matrix:
        return np.array(node.matrix, dtype=np.float64).reshape(4, 4).T
    t = np.array(node.translation or [0, 0, 0], dtype=np.float64)
    x, y, z, w = node.rotation or [0, 0, 0, 1]
    s = np.array(node.scale or [1, 1, 1], dtype=np.float64)
    r = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    m = np.eye(4)
    m[:3, :3] = r * s
    m[:3, 3] = t
    return m


def _accessor_array(gltf: GLTF2, blob: bytes, index: int) -> np.ndarray:
    acc = gltf.accessors[index]
    view = gltf.bufferViews[acc.bufferView]
    dtype = np.dtype(COMPONENT_DTYPE[acc.componentType])
    count = TYPE_COUNT[acc.type]
    offset = (view.byteOffset or 0) + (acc.byteOffset or 0)
    stride = view.byteStride or dtype.itemsize * count
    if stride == dtype.itemsize * count:
        data = np.frombuffer(blob, dtype=dtype, count=acc.count * count, offset=offset)
        return data.reshape(acc.count, count) if count > 1 else data
    rows = [np.frombuffer(blob, dtype=dtype, count=count, offset=offset + i * stride) for i in range(acc.count)]
    return np.stack(rows)


def measure_glb(path: Path) -> Measurement:
    gltf = GLTF2().load(str(path))
    blob = gltf.binary_blob()
    if blob is None:
        raise GeometryError("GLB has no embedded binary buffer")
    mins = np.full(3, np.inf)
    maxs = np.full(3, -np.inf)
    triangles = 0

    def visit(node_index: int, parent: np.ndarray) -> None:
        nonlocal triangles
        node = gltf.nodes[node_index]
        world = parent @ _node_matrix(node)
        if node.mesh is not None:
            for prim in gltf.meshes[node.mesh].primitives:
                positions = _accessor_array(gltf, blob, prim.attributes.POSITION).astype(np.float64)
                homo = np.c_[positions, np.ones(len(positions))] @ world.T
                mins[:] = np.minimum(mins, homo[:, :3].min(axis=0))
                maxs[:] = np.maximum(maxs, homo[:, :3].max(axis=0))
                mode = 4 if prim.mode is None else prim.mode
                if mode == 4:
                    n = gltf.accessors[prim.indices].count if prim.indices is not None else len(positions)
                    triangles += n // 3
        for child in node.children or []:
            visit(child, world)

    scene = gltf.scenes[gltf.scene or 0]
    for root in scene.nodes:
        visit(root, np.eye(4))
    if not np.isfinite(mins).all():
        raise GeometryError("GLB contains no mesh geometry")

    issues: list[str] = []
    mr = True
    for i, mat in enumerate(gltf.materials or []):
        ext = mat.extensions or {}
        if "KHR_materials_pbrSpecularGlossiness" in ext:
            mr = False
            issues.append(f"material {i} uses specular-glossiness")
        if mat.pbrMetallicRoughness is None:
            mr = False
            issues.append(f"material {i} has no pbrMetallicRoughness")
    if not gltf.materials:
        mr = False
        issues.append("no materials")

    edge = 0
    for image in gltf.images or []:
        if image.bufferView is None:
            issues.append("external image reference (textures must be embedded)")
            continue
        view = gltf.bufferViews[image.bufferView]
        start = view.byteOffset or 0
        with Image.open(io.BytesIO(blob[start:start + view.byteLength])) as im:
            edge = max(edge, *im.size)
    return Measurement("glb", tuple(mins), tuple(maxs), triangles, edge, mr, issues)


# ---------------------------------------------------------------------------- USDZ

def measure_usdz(path: Path) -> Measurement:
    from pxr import Usd, UsdGeom, UsdShade

    stage = Usd.Stage.Open(str(path))
    if stage is None:
        raise GeometryError("USDZ could not be opened")
    mpu = UsdGeom.GetStageMetersPerUnit(stage)
    up = UsdGeom.GetStageUpAxis(stage)
    cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), [UsdGeom.Tokens.default_, UsdGeom.Tokens.render])
    root = stage.GetPseudoRoot()
    box = cache.ComputeWorldBound(root).ComputeAlignedRange()
    if box.IsEmpty():
        raise GeometryError("USDZ contains no geometry")
    lo, hi = box.GetMin(), box.GetMax()
    triangles = 0
    issues: list[str] = []
    has_surface = False
    for prim in stage.Traverse():
        if prim.IsA(UsdGeom.Mesh):
            counts = UsdGeom.Mesh(prim).GetFaceVertexCountsAttr().Get() or []
            triangles += sum(max(c - 2, 0) for c in counts)
        if prim.IsA(UsdShade.Shader):
            shader_id = UsdShade.Shader(prim).GetIdAttr().Get()
            if shader_id == "UsdPreviewSurface":
                has_surface = True
                shader = UsdShade.Shader(prim)
                if shader.GetInput("useSpecularWorkflow") and shader.GetInput("useSpecularWorkflow").Get() == 1:
                    issues.append(f"{prim.GetPath()} uses specular workflow")
    if not has_surface:
        issues.append("no UsdPreviewSurface material")
    edge = 0
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if name.lower().endswith((".png", ".jpg", ".jpeg")):
                with Image.open(io.BytesIO(z.read(name))) as im:
                    edge = max(edge, *im.size)
    scale = mpu if mpu else 1.0
    return Measurement("usdz", tuple(v * scale for v in lo), tuple(v * scale for v in hi), triangles, edge,
                       has_surface and not issues, issues, mpu, up)


def measure(path: Path, fmt: str) -> Measurement:
    if fmt == "glb":
        return measure_glb(path)
    if fmt == "usdz":
        return measure_usdz(path)
    raise GeometryError(f"unsupported format {fmt}")


def glb_header_ok(path: Path) -> bool:
    with path.open("rb") as f:
        magic, version, _ = struct.unpack("<4sII", f.read(12))
    return magic == b"glTF" and version == 2
