import sys, math, bpy
from mathutils import Vector

blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
for o in bpy.data.objects:
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:
            tr.mute = True
scene = bpy.context.scene

# grondvlak, zandkleur
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
g = bpy.context.active_object
m = bpy.data.materials.new("Grond"); m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42 ** 2.2, 0.34 ** 2.2, 0.22 ** 2.2, 1)
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
g.data.materials.append(m)

# zon + lucht
sun = bpy.data.objects.new("Zon", bpy.data.lights.new("Zon", "SUN"))
sun.data.energy = 4.5; sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7

# de NLA-sporen staan uit: zet de rusthouding met de hand (klep dicht, zeil opgerold)
O = bpy.data.objects
bpy.context.view_layer.update()
O["Klep"].rotation_euler = (0, 0, 0)
O["Trap"].rotation_euler = (math.pi, 0, 0)
O["ZeilDak"].scale = (1, 0.02, 1)
O["RolDak"].location.y = 0.35
for k in "LR":
    O["Zeil" + k].scale = (1, 1, 0.02)
    O["Rol" + k].location.z = 3.04
if "--dicht" in sys.argv:  # zeil helemaal dicht (eindstand van ZeilDicht)
    O["ZeilDak"].scale = (1, 1, 1)
    O["RolDak"].location.y = 0.35 - 4.12
    for k in "LR":
        O["Zeil" + k].scale = (1, 1, 1)
        O["Rol" + k].location.z = 3.04 - 1.39
if "--open" in sys.argv:  # klep open, trapje uit
    O["Klep"].rotation_euler.x = math.pi
    O["Trap"].rotation_euler.x = 0
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
pos = Vector([float(v) for v in sys.argv[3].split(",")])
cam.location = pos
cam.data.lens = float(sys.argv[4]) if len(sys.argv) > 4 and not sys.argv[4].startswith("--") else 50
target = Vector((0, -0.2, 1.4))
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
