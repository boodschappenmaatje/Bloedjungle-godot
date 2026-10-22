"""render.py <blend> <actie> <frames,komma> <uitmap> [zij|voor]  ->  PNG per frame en een contactblad (vergt Pillow)"""
import sys, os, math, bpy
from mathutils import Vector
src, actname, frames, out = sys.argv[1], sys.argv[2], [float(x) for x in sys.argv[3].split(",")], sys.argv[4]
view = sys.argv[5] if len(sys.argv) > 5 else "zij"
os.makedirs(out, exist_ok=True)
if src.endswith(".glb"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
else:
    bpy.ops.wm.open_mainfile(filepath=src)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
act = bpy.data.actions[actname]
# voorbeeldgeweer: vast aan de rechterhand, in de "stil"-houding recht vooruit (zoals de montage in soldier_model.gd)
arm.animation_data_create()
st = bpy.data.actions.get("stil") or bpy.data.actions["basis_stil"]
arm.animation_data.action = st
if st.slots: arm.animation_data.action_slot = st.slots[0]
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()
hand = arm.pose.bones["DEF-handR"]
hp = hand.matrix.translation.copy()
bpy.ops.mesh.primitive_cube_add(size=1)
gun = bpy.context.active_object
gun.scale = (0.05, 0.85, 0.09)
gun.location = hp + Vector((0.0, -0.28, 0.0))
gun.parent = arm; gun.parent_type = 'BONE'; gun.parent_bone = "DEF-handR"
gun.matrix_parent_inverse = (arm.matrix_world @ hand.matrix).inverted()
mat = bpy.data.materials.new("gun"); mat.diffuse_color = (0.15, 0.15, 0.17, 1); gun.data.materials.append(mat)
arm.animation_data_create()
arm.animation_data.action = act
if hasattr(arm.animation_data, "action_slot") and act.slots:
    arm.animation_data.action_slot = act.slots[0]
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'CYCLES'
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 16
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.7, 0.72, 0.75)
sun = bpy.data.objects.new("zon", bpy.data.lights.new("zon", 'SUN')); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(55), 0, math.radians(35)); sc.collection.objects.link(sun)
# grondvlak + hulplijn op heuphoogte
bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
sc.render.resolution_x, sc.render.resolution_y = 360, 420
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 2.6
tgt = Vector((0, 0, 0.95))
off = {"zij": Vector((6, 0, 0)), "voor": Vector((0, -6, 0))}[view]
cam.location = tgt + off
cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name == 'Icosphere':
        o.hide_render = True
files = []
for fr in frames:
    sc.frame_set(int(fr), subframe=fr - int(fr))
    p = os.path.join(out, f"{actname}_{view}_{int(fr):03d}.png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    files.append(p)
from PIL import Image
ims = [Image.open(f) for f in files]
w, h = ims[0].size
sheet = Image.new("RGB", (w * len(ims), h), (255, 255, 255))
for i, im in enumerate(ims):
    sheet.paste(im, (i * w, 0))
sheet.save(os.path.join(out, f"blad_{actname}_{view}.png"))
print("BLAD", os.path.join(out, f"blad_{actname}_{view}.png"))
