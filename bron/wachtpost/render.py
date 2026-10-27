"""Studiobeeld van wachtpost.blend met Cycles (CPU): python3 render.py uit/wachtpost.blend uit/"""
import bpy, sys, os, math
from mathutils import Vector
src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=src)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.device = "CPU"
sc.render.resolution_x, sc.render.resolution_y = 1400, 800
w = bpy.data.worlds.new("w"); w.use_nodes = True; sc.world = w
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN")); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(35)); sc.collection.objects.link(sun)
ground = bpy.data.objects.new("grond", bpy.data.meshes.new("g")); sc.collection.objects.link(ground)
import bmesh
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=14); bm.to_mesh(ground.data)
gm = bpy.data.materials.new("gm"); gm.diffuse_color = (0.18, 0.16, 0.1, 1); ground.data.materials.append(gm)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
def shot(name, loc, target):
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
shot("w_totaal", (0, 15, 9), (0, -2, 1))
bpy.data.objects["Boom"].rotation_euler = (0, 0, 0)
shot("w_huis", (3.5, -0.5, 2.6), (0, -4.5, 1.2))
shot("w_boom", (-6.5, 3.2, 2.0), (-3, 0, 1))
bpy.data.objects["Boom"].rotation_euler = (0, -math.radians(82), 0)
shot("w_open", (0, 15, 9), (0, -2, 1))
