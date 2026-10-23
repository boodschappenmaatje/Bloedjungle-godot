"""Voorbeeldplaatje van de kerk: python3 render.py uit/kerk.blend uit.png "x,y,z" [lens] [--doel=z] [--geendak] [--toren=N]
[--kapot] [--sloop] [--ruine] [--torenruine] [--schipruine]
--geendak: dak van het schip weg, --toren=N: torenlagen boven N weg (N = 0..3), --kapot: alles kapot, --sloop: een deel
kapot met puin, --ruine: alles ingestort, --torenruine / --schipruine: alleen de toren of alleen het schip ingestort."""
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


def toon(o):
    o.hide_render = False
    for c in o.children_recursive:
        if not c.name.endswith("_kapot"):
            c.hide_render = False


for o in bpy.data.objects:
    if o.name.endswith("_kapot"):
        o.hide_render = True
verberg(bpy.data.objects["Puin"])
verberg(bpy.data.objects["Ruine"])
toren = next((int(a.split("=")[1]) for a in args if a.startswith("--toren=")), 3)
for k in range(toren + 1, 4):
    verberg(bpy.data.objects[f"Toren{k}"])
if "--geendak" in args:
    verberg(bpy.data.objects["Dak"])
if "--ruine" in args or "--torenruine" in args:
    for nm in ("TorenVoet", "Toren1", "Toren2", "Toren3"):
        verberg(bpy.data.objects[nm])
    toon(bpy.data.objects["RuineToren"])
if "--ruine" in args or "--schipruine" in args:
    for nm in ("Schip", "Dak"):
        verberg(bpy.data.objects[nm])
    toon(bpy.data.objects["RuineSchip"])
if "--kapot" in args:
    for o in bpy.data.objects:
        if o.name.endswith("_kapot") and not bpy.data.objects[o.name[:-6] + "_heel"].hide_render:
            o.hide_render = False
            bpy.data.objects[o.name[:-6] + "_heel"].hide_render = True
if "--sloop" in args:
    random.seed(4)
    segs = [o for o in bpy.data.objects if o.name.endswith("_heel") and (o.name[0] in "MSP" or o.name.startswith("Dak"))]
    for o in segs:
        if o.hide_render:
            continue
        r = random.random()
        k = bpy.data.objects[o.name[:-5] + "_kapot"]
        if o.name.startswith("Dak") or r < 0.35:
            o.hide_render = True
            k.hide_render = False
        elif r < 0.45 and o.name[0] == "S":
            o.hide_render = True
    for nm, loc in (("PuinGroot", (-5.6, 1.0, 0)), ("PuinKlein", (5.4, -1.5, 0))):
        src = bpy.data.objects[nm]
        src.hide_render = False
        src.parent = None
        src.location = loc

bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, 0))
g = bpy.context.active_object
m = bpy.data.materials.new("Grond"); m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.3 ** 2.2, 0.32 ** 2.2, 0.18 ** 2.2, 1)
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
doel = [float(v) for v in next((a.split("=")[1] for a in args if a.startswith("--doel=")), "0,0,4").split(",")]
target = Vector(doel)
cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1200, 800
scene.view_settings.view_transform = "AgX"
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
