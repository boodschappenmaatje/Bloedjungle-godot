"""Plaatjes van de brug: render.py uit/brug.blend uit/ (boven en schuin)"""
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
blk("oever1", (0, -12, -0.5), (30, 12, 1.0), (0.18, 0.13, 0.07))
blk("oever2", (0, 12, -0.5), (30, 12, 1.0), (0.18, 0.13, 0.07))
blk("water", (0, 0, -1.3), (30, 12, 0.2), (0.03, 0.12, 0.11))
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 35
for name, loc in (("schuin", (9, -11, 6)), ("boven", (0.5, -3, 16))):
    tgt = Vector((0, 0, 0.5))
    cam.location = Vector(loc)
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, f"b_{name}.png")
    bpy.ops.render.render(write_still=True)
