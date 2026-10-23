"""Plaatjes van de klim-animatie: render.py uit/klimmen.blend uit/  (voor- en zijaanzicht op vier momenten)"""
import sys, os, math, bpy
from mathutils import Vector
blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 24
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.6, 0.62, 0.65)
sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", 'SUN'))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
sc.collection.objects.link(sun)
sc.render.resolution_x, sc.render.resolution_y = 300, 420
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.3
tgt = Vector((0, 0, 0.95))
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name == 'Icosphere':
        o.hide_render = True
views = {"voor": Vector((0, -6, 0)), "zij": Vector((6, 0, 0))}
for vn, off in views.items():
    cam.location = tgt + off
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    for fr in (0, 5, 10, 15):
        sc.frame_set(fr)
        sc.render.filepath = os.path.join(out, f"k_{vn}_{fr}.png")
        bpy.ops.render.render(write_still=True)
