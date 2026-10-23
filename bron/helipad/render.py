"""Rendert een beeld van helipad_show.blend op tijdstip t (seconden van Show-loop).
Gebruik: python3 render.py uit/helipad_show.blend uit.png t camx,camy,camz [lens] [doel z]"""
import sys, math, bpy
from mathutils import Vector
blend, out, t = sys.argv[1], sys.argv[2], float(sys.argv[3])
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
for o in bpy.data.objects:
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:
            tr.mute = tr.name != "Show-loop"
scene.frame_set(int(round(t * 30)))
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, -0.31))
g = bpy.context.active_object
m = bpy.data.materials.new("Grond"); m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.3 ** 2.2, 0.27 ** 2.2, 0.15 ** 2.2, 1)
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
g.data.materials.append(m)
sun = bpy.data.objects.new("Zon", bpy.data.lights.new("Zon", "SUN"))
sun.data.energy = 4.0; sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
pos = Vector([float(v) for v in sys.argv[4].split(",")])
cam.location = pos
cam.data.lens = float(sys.argv[5]) if len(sys.argv) > 5 else 35
target = Vector((0, 0, float(sys.argv[6]) if len(sys.argv) > 6 else 0.5))
cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1100, 720
scene.view_settings.view_transform = "AgX"
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
