"""Plaatjes van de poort met een stuk muur erbij: render.py uit/poort.blend uit/ (dicht, half, open)"""
import sys, os, math, bpy
from mathutils import Vector
blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 32
sc.render.resolution_x, sc.render.resolution_y = 900, 520
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.55, 0.6, 0.62)
sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", 'SUN'))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
sc.collection.objects.link(sun)
def blk(name, loc, size, col):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*col, 1)
    o.data.materials.append(m)
# muur (dikte 0,4) met een opening van 4,8 m, poortpalen en grond
blk("muurL", (-2.4 - 5, 0, 0.775), (10, 0.4, 1.55), (0.35, 0.35, 0.33))
blk("muurR", (2.4 + 5, 0, 0.775), (10, 0.4, 1.55), (0.35, 0.35, 0.33))
for sx in (-1, 1):
    blk("paal", (sx * 2.7, 0, 1.05), (0.7, 0.7, 2.1), (0.2, 0.2, 0.19))
blk("grond", (0, 0, -0.05), (40, 30, 0.1), (0.22, 0.17, 0.1))
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 35
tgt = Vector((1.5, 0, 0.8))
cam.location = Vector((-3.5, 9.5, 4.5))
cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
for fr in (0, 38, 75):
    sc.frame_set(fr)
    sc.render.filepath = os.path.join(out, f"p_{fr}.png")
    bpy.ops.render.render(write_still=True)
