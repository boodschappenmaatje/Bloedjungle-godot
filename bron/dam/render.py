"""Eenvoudige Cycles-voorbeeldrender van dam.blend (CPU, weinig samples): python3 render.py uit/dam.blend uit/prev_ [hoek...]"""
import bpy, sys, math, os
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(a[0]))
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = int(os.environ.get("S", 24)); sc.cycles.device = "CPU"
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.cycles.use_denoising = False
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 4.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-35)); sc.collection.objects.link(sun)
g = bpy.data.objects.new("g", bpy.data.meshes.new("g")); 
import bmesh
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=200); bm.to_mesh(g.data); sc.collection.objects.link(g)
gm = bpy.data.materials.new("gm"); gm.diffuse_color = (0.2, 0.3, 0.12, 1); gm.use_nodes = True; gm.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.12, 0.18, 0.06, 1); g.data.materials.append(gm)
g.location.z = -0.3
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
views = {"achter": ((-4, -52, 20), (0, 0, 7)), "voor": ((10, 55, 22), (0, 0, 7)), "schuin": ((45, -38, 24), (0, 0, 6)),
         "dichtbij": ((12, -26, 12), (0, 0, 9)), "kroon": ((-10, 18, 24), (0, 0, 15))}
for name in (a[2:] or views):
    p, t = views[name]
    cam.location = Vector(p)
    cam.rotation_euler = (Vector(t) - Vector(p)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 28
    sc.render.filepath = os.path.abspath(a[1] + name + ".png")
    bpy.ops.render.render(write_still=True)
