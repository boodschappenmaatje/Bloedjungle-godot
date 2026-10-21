"""Voorbeeldplaatje van elk wapen van opzij (loop naar rechts). Gebruik: python3 render.py uit/wapens.blend uit/ [naam ...]"""
import sys, math, bpy
from mathutils import Vector

blend, out = sys.argv[1], sys.argv[2]
names = sys.argv[3:]
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
roots = {o.name: o for o in bpy.data.objects if o.type == "EMPTY"}
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
scene.render.engine = "CYCLES"; scene.cycles.device = "CPU"; scene.cycles.samples = 32; scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 900, 450
scene.view_settings.view_transform = "AgX"
for n in names:
    for k, o in roots.items():
        for c in [o] + list(o.children):
            c.hide_render = k != n
    mid = Vector((0, 0.33 if n != "M1911" else 0.06, 0.08))
    cam.data.ortho_scale = {"M1911": 0.5, "Thompson": 1.2, "Garand": 1.9, "Trench": 1.8, "MG42": 1.9, "Bazooka": 2.1}.get(n, 1.0)
    cam.location = mid + Vector((2.6, -1.9, 1.4))
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{out}/w_{n}.png"
    bpy.ops.render.render(write_still=True)
