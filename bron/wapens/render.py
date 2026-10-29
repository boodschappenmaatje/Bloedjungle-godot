"""Voorbeeldplaatje van elk wapen van opzij (loop naar rechts). Gebruik: python3 render.py uit/wapens.blend uit/ [naam ...]"""
import sys, math, bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
draft = "--draft" in args
args = [arg for arg in args if arg != "--draft"]
blend, out = args[0], args[1]
names = args[2:]
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
roots = {o.name: o for o in bpy.data.objects if o.type == "EMPTY" and o.parent is None}
names = names or [n for n in roots if n not in ("Huls", "Raket")]
sun = bpy.data.objects.new("Zon", bpy.data.lights.new("Zon", "SUN"))
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(110))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.65, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "CYCLES"; scene.cycles.device = "CPU"; scene.cycles.samples = 32 if draft else 128; scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = (1280, 720) if draft else (1920, 1080)
scene.view_settings.view_transform = "AgX"
for n in names:
    for k, o in roots.items():
        o.hide_render = k != n
        for c in o.children_recursive:
            c.hide_render = k != n
    bpy.context.view_layer.update()
    root = roots[n]
    points = [obj.matrix_world @ Vector(corner) for obj in root.children_recursive if obj.type == "MESH" for corner in obj.bound_box]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    mid = (lo + hi) * 0.5
    cam.data.ortho_scale = max(0.35, (hi - lo).length * 1.35)
    cam.location = mid + Vector((2.6, -1.9, 1.4))
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{out}/w_{n}.png"
    bpy.ops.render.render(write_still=True)
