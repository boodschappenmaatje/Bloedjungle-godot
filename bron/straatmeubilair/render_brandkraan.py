"""Stilstaand beeld van de brandkraan in uitbarsting: python3 render_brandkraan.py uit/straatmeubilair.blend uit.png <beeldje> "x,y,z" "doel" [lens]"""
import sys, bpy
from mathutils import Vector
blend, out, frame = sys.argv[1], sys.argv[2], int(sys.argv[3])
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
for o in bpy.data.objects:     # alleen de brandkraan
    if o.type == "MESH" and o.parent is None:
        o.hide_render = True
# de NLA-strook 'Spuit' wint van 'Spuiten-loop' als beide actief zijn: kies via mute
for o in bpy.data.objects:
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:
            tr.mute = (tr.name != ("Spuit" if frame >= 0 else "Spuiten-loop"))
scene.frame_set(abs(frame))
pos = Vector([float(v) for v in sys.argv[4].split(",")])
doel = Vector([float(v) for v in sys.argv[5].split(",")])
bpy.ops.mesh.primitive_plane_add(size=60, location=(33, 0, 0))
g = bpy.context.object
m = bpy.data.materials.new("Grond"); m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.1, 0.1, 1)
g.data.materials.append(m)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scene.collection.objects.link(cam)
cam.location = pos; cam.rotation_euler = (doel - pos).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = float(sys.argv[6]) if len(sys.argv) > 6 else 35
scene.camera = cam
zon = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN")); zon.data.energy = 4; zon.rotation_euler = (0.8, 0.2, 0.9)
scene.collection.objects.link(zon)
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.58, 0.7, 1)
scene.world = w
scene.render.engine = "CYCLES"; scene.cycles.samples = 32; scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 900, 1100
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
