"""Voorbeeldplaatje van de winkel: python3 render.py uit/winkel.blend uit.png "x,y,z" [lens] [--geendak] [--flat1] [--open] [--kapot] [--sloop] [--ruine]
--geendak: dak weg, --flat1: ook flat 2 weg, --open: alleen de winkel, --kapot: alles kapot, --sloop: een deel kapot met puin,
--ruine: helemaal ingestort."""
import sys, math, bpy, random
from mathutils import Vector

blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
args = sys.argv[3:]


def verberg(o, ook_kinderen=True):
    o.hide_render = True
    if ook_kinderen:
        for c in o.children_recursive:
            c.hide_render = True


for o in bpy.data.objects:
    if o.name.endswith("_kapot"):
        o.hide_render = True
verberg(bpy.data.objects["Puin"])
verberg(bpy.data.objects["Ruine"])
if "--ruine" in args:
    for nm in ("Begane", "Verdieping", "Verdieping2", "Dak"):
        verberg(bpy.data.objects[nm])
    for o in bpy.data.objects["Ruine"].children_recursive:
        o.hide_render = False
if "--geendak" in args or "--open" in args or "--flat1" in args:
    verberg(bpy.data.objects["Dak"])
if "--open" in args or "--flat1" in args:
    verberg(bpy.data.objects["Verdieping2"])
if "--open" in args:
    verberg(bpy.data.objects["Verdieping"])
if "--kapot" in args:
    for o in bpy.data.objects:
        if o.name.endswith("_kapot"):
            o.hide_render = False
            bpy.data.objects[o.name[:-6] + "_heel"].hide_render = True
if "--sloop" in args:
    random.seed(3)
    segs = [o for o in bpy.data.objects if o.name.endswith("_heel") and (o.name.startswith("M") or o.name.startswith("Dak"))]
    for o in segs:
        r = random.random()
        k = bpy.data.objects[o.name[:-5] + "_kapot"]
        if o.name.startswith("Dak") or r < 0.35:
            o.hide_render = True
            k.hide_render = False
        elif r < 0.5 and (o.name.startswith("M1") or o.name.startswith("M2")):
            o.hide_render = True
    # puin voor de gevel
    for nm, loc in (("PuinGroot", (-2.6, -4.6, 0)), ("PuinKlein", (3.4, -4.4, 0))):
        src = bpy.data.objects[nm]
        src.hide_render = False
        src.parent = None
        src.location = loc

bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
g = bpy.context.active_object
m = bpy.data.materials.new("Grond"); m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.36 ** 2.2, 0.3 ** 2.2, 0.2 ** 2.2, 1)
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
g.data.materials.append(m)
sun = bpy.data.objects.new("Zon", bpy.data.lights.new("Zon", "SUN"))
sun.data.energy = 4.0; sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(45), math.radians(12), math.radians(150))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
pos = Vector([float(v) for v in args[0].split(",")])
cam.location = pos
cam.data.lens = float(args[1]) if len(args) > 1 and not args[1].startswith("--") else 35
target = Vector((0, 0.5, float(next((a.split("=")[1] for a in args if a.startswith("--doel=")), "3.5"))))
cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1200, 800
scene.view_settings.view_transform = "AgX"
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
