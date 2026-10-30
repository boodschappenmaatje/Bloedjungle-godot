"""Vergelijkingsbeeld (Cycles CPU): oude Kist_Munitie uit assets/props.glb, Meshy-bron op maat, Meshy game-glb.
Gebruik: python3 render.py <meshy-volle-resolutie.glb> <munitiekist_meshy.glb> <uitmap>"""
import bpy, sys, os, math, bmesh
from mathutils import Vector
from pathlib import Path
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
vol, game, out = ARGS[0], ARGS[1], ARGS[2]
ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.device = "CPU"
sc.render.resolution_x, sc.render.resolution_y = 1500, 700
w = bpy.data.worlds.new("w"); w.use_nodes = True; sc.world = w
w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN")); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(40), 0, math.radians(-35)); sc.collection.objects.link(sun)
ground = bpy.data.objects.new("grond", bpy.data.meshes.new("g")); sc.collection.objects.link(ground)
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=10); bm.to_mesh(ground.data)
gm = bpy.data.materials.new("gm"); gm.diffuse_color = (0.16, 0.17, 0.11, 1); ground.data.materials.append(gm)

def load(path, x, keep=None):
    before = set(sc.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in sc.objects if o not in before]
    for o in new:
        if keep and o.type == "MESH" and o.name not in keep and (not o.parent or o.parent.name not in keep):
            bpy.data.objects.remove(o)
    for o in [o for o in sc.objects if o not in before and o.parent is None]:
        o.location.x += x

load(ROOT / "assets/props.glb", -0.95, keep={"Kist_Munitie"})
for o in list(sc.objects):     # props.glb zet alles naast elkaar: haal de oude kist naar het eerste vak
    if o.name == "Kist_Munitie":
        o.matrix_world.translation = Vector((-0.95, 0, 0))
load(vol, 0.0)
load(game, 0.95)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
def shot(name, loc, target, lens=50):
    cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
shot("munitiekist-dichtbij", (0.9, -3.4, 1.6), (0, 0, 0.2))
# spelcamera: 58 graden schuin, 28 m afstand, 45 graden beeldhoek (zoals de VQ2-viewer)
a = math.radians(58)
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
shot("munitiekist-spelcamera", (0, -math.cos(a) * 28, math.sin(a) * 28), (0, 0, 0), lens=43.5)
