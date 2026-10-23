"""Voorbeeldplaatje van de straatmeubilair: python3 render.py uit/straat.blend uit.png "x,y,z" "doel x,y,z" [lens]
Zet de dingen op een rij op een zandvlakte en rendert met Cycles."""
import sys, bpy
from mathutils import Vector

blend, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
pos = Vector([float(v) for v in sys.argv[3].split(",")])
doel = Vector([float(v) for v in sys.argv[4].split(",")])
lens = float(sys.argv[5]) if len(sys.argv) > 5 else 35

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.002))
grond = bpy.context.object
m = bpy.data.materials.new("Grond")
m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.13, 0.08, 1)
m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
grond.data.materials.append(m)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
cam.location = pos
cam.rotation_euler = (doel - pos).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = lens
scene.camera = cam
zon = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN"))
zon.data.energy = 4.0
zon.data.angle = 0.05
zon.rotation_euler = (0.75, 0.2, 0.9)
scene.collection.objects.link(zon)
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.72, 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
scene.world = w
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1400, 900
scene.view_settings.view_transform = "AgX"
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
