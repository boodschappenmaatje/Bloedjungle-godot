"""Plaatjes van de brug: render.py uit/brug.blend uit/ (boven en schuin)"""
import sys, os, math, bpy
from mathutils import Vector
blend, out = sys.argv[1], sys.argv[2]
frame = int(sys.argv[3]) if len(sys.argv) > 3 else 108
suffix = sys.argv[4] if len(sys.argv) > 4 else ""
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.frame_set(frame)
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
for name, loc, tg in (("schuin", (11, -13, 7), (0, -1, 1.5)), ("boven", (0.5, -3, 18), (0, 0, 0.5)), ("kastje", (-1.2, -13.8, 2.6), (3.8, -8.6, 1.1))):
    tgt = Vector(tg)
    cam.location = Vector(loc)
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, f"b_{name}{suffix}.png")
    bpy.ops.render.render(write_still=True)
