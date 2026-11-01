"""Voorbeeldrenders van de verzamelvlag (Cycles CPU, weinig samples). Gebruik: python render.py <blend> <uitmap>"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

blend, outdir = sys.argv[1], Path(sys.argv[2])
outdir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 900, 900
# grond + zon + lucht
bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 0, 0))
gr = bpy.context.active_object
m = bpy.data.materials.new("Grond")
m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.20, 0.11, 0.06, 1)
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
gr.data.materials.append(m)
sun = bpy.data.lights.new("Zon", "SUN")
sun.energy = 4.0
sun.angle = math.radians(4)
so = bpy.data.objects.new("Zon", sun)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
w = bpy.data.worlds.new("W")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.55, 0.62, 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sc.world = w
sc.view_settings.view_transform = "AgX"
cam_d = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam


def shot(name, loc, target, lens, frame=12):
    sc.frame_set(frame)
    cam.location = loc
    cam_d.lens = lens
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = str(outdir / name)
    bpy.ops.render.render(write_still=True)


shot("gamecamera.png", (0.0, -5.2, 6.2), (0.3, 0, 1.3), 40)       # schuin van boven, zoals de spelcamera
shot("zijkant.png", (0.4, -4.6, 1.8), (0.4, 0, 1.6), 45)
shot("detail_doek.png", (0.7, -1.9, 2.5), (0.6, 0, 2.5), 55, frame=8)
shot("detail_voet.png", (1.1, -1.7, 0.7), (0, 0, 0.3), 45)
shot("detail_lamp.png", (0.5, -0.9, 3.1), (0, 0, 3.1), 60)
