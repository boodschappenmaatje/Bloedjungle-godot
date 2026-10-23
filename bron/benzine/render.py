"""Voorbeeldplaatje van het benzinestation: python3 render.py uit/benzine.blend uit.png "x,y,z" [lens] [--open] [--kapot]
[--sloop] [--ruine] [--doel=z]. --open: dak en luifeldak weg, --kapot: alles kapot (pompen uitgebrand), --sloop: een deel
kapot met puin, --ruine: winkeltje en luifel ingestort."""
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
    for nm in ("Begane", "Dak", "Luifel"):
        verberg(bpy.data.objects[nm])
    for o in bpy.data.objects["Ruine"].children_recursive:
        o.hide_render = False
if "--open" in args:
    verberg(bpy.data.objects["Dak"])
    verberg(bpy.data.objects["LuifelDak"], False)
if "--kapot" in args or "--ruine" in args:
    for o in bpy.data.objects:
        if o.name.endswith("_kapot") and (o.name.startswith("X") or "--kapot" in args):
            o.hide_render = False
            bpy.data.objects[o.name[:-6] + "_heel"].hide_render = True
if "--sloop" in args:
    random.seed(3)
    for o in bpy.data.objects:
        if o.name.endswith("_heel") and (o.name.startswith("M") or o.name.startswith("K") or o.name.startswith("Dak")
                                         or o.name.startswith("XPomp0") or o.name.startswith("XPomp1")):
            k = bpy.data.objects[o.name[:-5] + "_kapot"]
            r = random.random()
            if o.name.startswith("Dak") or o.name.startswith("X") or r < 0.4:
                o.hide_render = True
                k.hide_render = False
    for nm, loc in (("PuinGroot", (-2.4, -0.8, 0)), ("PuinKlein", (2.8, -0.6, 0))):
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
target = Vector((0, -0.5, float(next((a.split("=")[1] for a in args if a.startswith("--doel=")), "2.0"))))
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
