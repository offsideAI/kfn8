"""Conform a source glTF to the Kfn8 contract and export GLB LOD0-2 + USDZ LOD0.

blender -b --python tools/blender_conform.py -- SRC.gltf OUT_DIR [--keep NAME,NAME] [--turn-degrees 180]

Steps: import, keep selected meshes, apply transforms, turn about the up axis so the front faces glTF -Z,
move to a base-centre pivot, export LOD0 GLB, decimate for LOD1 (<=45 %) and LOD2 (<=15 %), export USDZ
(Y-up, metersPerUnit 1). Prints CONFORM lines with measured sizes; the contract validator is the judge.
"""
import math, sys, bpy, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
keep = None
turn = 180.0
if "--keep" in args:
    keep = set(args[args.index("--keep") + 1].split(","))
if "--turn-degrees" in args:
    turn = float(args[args.index("--turn-degrees") + 1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
# Bake every parent transform into the meshes BEFORE removing empties; removing a parent otherwise drops its rotation
# (this silently cancelled the front turn in the first conform run; caught by the founder review renders).
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
for o in list(bpy.context.scene.objects):
    if o.type != "MESH" or (keep and o.name not in keep):
        bpy.data.objects.remove(o, do_unlink=True)
meshes = list(bpy.context.scene.objects)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Blender up is +Z; turning about it is turning about glTF +Y. Rotate the mesh data itself: the glTF importer uses
# quaternion rotation mode, so setting rotation_euler was silently ignored in the first conform run.
obj.data.transform(mathutils.Matrix.Rotation(math.radians(turn), 4, "Z"))
obj.data.update()
bpy.context.view_layer.update()
# Bounds from the vertices themselves: the cached bound_box can be stale after a data transform.
pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
lo = mathutils.Vector([min(p[i] for p in pts) for i in range(3)])
hi = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
obj.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
size = hi - lo
print(f"CONFORM size_m width={size.x:.4f} height={size.z:.4f} depth={size.y:.4f}")


def export_glb(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_image_format="AUTO")


bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
base_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
export_glb(f"{out}/lod0.glb")
bpy.ops.wm.usd_export(filepath=f"{out}/lod0.usdz", selected_objects_only=True, export_materials=True,
                      convert_orientation=True, export_global_forward_selection="NEGATIVE_Z",
                      export_global_up_selection="Y", convert_scene_units="METERS", export_textures_mode="NEW",
                      usdz_downscale_size="1024")
def bounds(o):
    pts = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    return (mathutils.Vector([min(p[i] for p in pts) for i in range(3)]), mathutils.Vector([max(p[i] for p in pts) for i in range(3)]))


ref_lo, ref_hi = bounds(obj)
ref_size = ref_hi - ref_lo
for lod, target in ((1, 0.45), (2, 0.15)):
    # Collapse decimation can push silhouettes outward. Relax the ratio until every axis stays within 0.5 % of LOD0
    # (half the contract tolerance) and the base stays on y=0; never rescale geometry to hide drift.
    ratio = target
    while True:
        dup = obj.copy()
        dup.data = obj.data.copy()
        bpy.context.scene.collection.objects.link(dup)
        mod = dup.modifiers.new("decimate", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.select_all(action="DESELECT")
        dup.select_set(True)
        bpy.context.view_layer.objects.active = dup
        bpy.ops.object.modifier_apply(modifier=mod.name)
        lo, hi = bounds(dup)
        size = hi - lo
        worst = max(abs(size[i] - ref_size[i]) / ref_size[i] for i in range(3))
        base_off = abs(lo.z - ref_lo.z)
        if (worst <= 0.005 and base_off <= 0.001) or ratio >= 0.95:
            break
        bpy.data.objects.remove(dup, do_unlink=True)
        ratio = min(0.95, ratio * 1.35)
    tris = sum(len(p.vertices) - 2 for p in dup.data.polygons)
    print(f"CONFORM lod{lod} ratio={ratio:.3f} tris={tris} (lod0 {base_tris}) worst_axis_drift={worst:.4%}")
    export_glb(f"{out}/lod{lod}.glb")
    bpy.data.objects.remove(dup, do_unlink=True)
print("CONFORM done")
