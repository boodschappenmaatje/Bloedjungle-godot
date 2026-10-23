"""Plaatje van de zwaailamp: render.py uit/zwaailamp.blend uit/ (twee standen van de reflector)"""
import sys, os, math, bpy
from mathutils import Vector
blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 48
sc.render.resolution_x, sc.render.resolution_y = 500, 420
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.3, 0.32, 0.3)
sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", 'SUN')); sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30)); sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
tgt = Vector((0, 0, 0.13)); cam.location = Vector((0.55, -0.55, 0.4))
cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
for fr in (0, 8):
    sc.frame_set(fr); sc.render.filepath = os.path.join(out, f"l_{fr}.png"); bpy.ops.render.render(write_still=True)
