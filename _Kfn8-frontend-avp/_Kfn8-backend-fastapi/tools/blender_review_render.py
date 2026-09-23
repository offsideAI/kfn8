"""blender -b --python tools/blender_review_render.py -- LOD0.glb OUT_PREFIX : front (from −Z, the contract front) and side renders."""
import sys, bpy, mathutils
src, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
lo = mathutils.Vector([min(p[i] for p in pts) for i in range(3)]); hi = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
centre, size = (lo + hi) / 2, max(hi - lo)
scene = bpy.context.scene
scene.render.resolution_x = scene.render.resolution_y = 520
world = bpy.data.worlds.new("w"); world.use_nodes = True; world.node_tree.nodes["Background"].inputs[1].default_value = 3.0; scene.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 3; sun.rotation_euler = (0.8, 0.2, 0.6); scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scene.collection.objects.link(cam); scene.camera = cam
# glTF −Z maps to Blender +Y, so the contract front is seen from Blender +Y.
for label, d in (("front", mathutils.Vector((0, 1, 0))), ("side", mathutils.Vector((1, 0, 0)))):
    cam.location = centre + d * size * 2.3 + mathutils.Vector((0, 0, size * 0.25))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{out}_{label}.png"
    bpy.ops.render.render(write_still=True)
