"""blender -b --python tools/blender_inspect.py -- SRC.gltf OUT_PREFIX : print world bounds (glTF axes) and render two views."""
import sys, bpy, mathutils
src, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
# Blender (x, y, z) == glTF (x, -z, y)
print(f"INSPECT meshes={len(meshes)} tris={sum(len(o.data.loop_triangles) or (o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in meshes)}")
print(f"INSPECT gltf_size_m width_x={hi.x-lo.x:.4f} height_y={hi.z-lo.z:.4f} depth_z={hi.y-lo.y:.4f}")
print(f"INSPECT gltf_min x={lo.x:.4f} y={lo.z:.4f} z={-hi.y:.4f}  names={[o.name for o in meshes][:8]}")
centre = (lo + hi) / 2; size = max(hi - lo)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 480
world = bpy.data.worlds.new("w"); world.use_nodes = True; world.node_tree.nodes["Background"].inputs[1].default_value = 1.5; scene.world = world
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scene.collection.objects.link(cam); scene.camera = cam
for label, direction in (("from_gltf_minusZ", mathutils.Vector((0, 1, 0))), ("from_gltf_plusZ", mathutils.Vector((0, -1, 0)))):
    cam.location = centre + direction * size * 2.2 + mathutils.Vector((0, 0, size * 0.3))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{out}_{label}.png"
    bpy.ops.render.render(write_still=True)
