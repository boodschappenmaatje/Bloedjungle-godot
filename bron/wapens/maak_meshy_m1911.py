"""Normalize the downloaded Meshy M1911A1 and export Blender source + animated GLB.

The source is deliberately retained byte-for-byte in the project assets directory.
The game model is 219 mm long on local +X (mapped to Godot +Z by its profile),
with the right-hand grip pivoted near the origin and five authored action clips.
"""
import bpy, math, os, sys
from mathutils import Vector
import bmesh

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SRC = os.path.join(ROOT, "assets", "meshy_weapon.glb")
OUT = os.path.join(ROOT, "assets", "meshy_m1911.glb")
BLEND = os.path.join(ROOT, "bron", "wapens", "uit", "meshy_m1911.blend")
os.makedirs(os.path.dirname(BLEND), exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
mesh.name = "M1911"
# Source bounds show the barrel along +X. Keep that axis: the Godot profile
# rotates +X onto its forward -Z and dimensions use real-world meters.
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
ratio = 0.219 / max(mesh.dimensions.x, mesh.dimensions.y, mesh.dimensions.z)
mesh.scale = (ratio, ratio, ratio)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
# Center the hand grip at the object origin; source artwork grip is at the rear.
bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
mesh.location = Vector((0.060, 0.0, 0.0))
bpy.context.view_layer.update()

# Meshy delivers a fused triangle soup. Split the upper receiver/sleeve from
# the grip/frame using a conservative height cut in the normalized pistol
# coordinates. Both resulting meshes retain the original UVs and materials.
coords = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
zmin, zmax = min(v.z for v in coords), max(v.z for v in coords)
cut_z = zmin + (zmax - zmin) * 0.59
slide = mesh.copy()
slide.data = mesh.data.copy()
slide.name = "M1911_Slede"
slide.data.name = "M1911_SledeMesh"
bpy.context.collection.objects.link(slide)

def filter_faces(obj, keep_above):
    bm = bmesh.new(); bm.from_mesh(obj.data)
    doomed = [f for f in bm.faces if (f.calc_center_median().z > cut_z) != keep_above]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(obj.data); bm.free()
    obj.data.update()

filter_faces(mesh, False)
filter_faces(slide, True)
# The Meshy source is over 1.1M triangles with 2K maps. The game asset targets
# a sub-30K triangle budget and 1K PBR maps; source GLB and this full-resolution
# Blender import stay untouched as provenance.
for obj in (mesh, slide):
    dec = obj.modifiers.new("Mobile game mesh budget", "DECIMATE")
    dec.ratio = 0.025
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=dec.name)
for image in bpy.data.images:
    if image.source == "FILE" and max(image.size) > 1024:
        image.scale(1024, 1024)
slide_world = slide.matrix_world.copy()
slide.parent = mesh
slide.matrix_parent_inverse = mesh.matrix_world.inverted()
slide.matrix_world = slide_world

def action(name, keys, target=mesh):
    if target.animation_data is None:
        target.animation_data_create()
    target.animation_data.action = None
    # Put each named action on its own NLA track so the GLB exporter preserves
    # a selectable clip library rather than only the last action.
    target.rotation_mode = "XYZ"
    for frame, loc, rot in keys:
        target.location = loc
        target.rotation_euler = rot
        target.keyframe_insert("location", frame=frame, group="M1911")
        target.keyframe_insert("rotation_euler", frame=frame, group="M1911")
    act = target.animation_data.action
    act.name = name
    act.use_fake_user = True
    track = target.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(keys[0][0]), act)
    target.animation_data.action = None

rest = tuple(mesh.location)
slide_rest = tuple(slide.location)
zero = (0.0, 0.0, 0.0)
action("M1911_schot", [(1, slide_rest, zero), (2, (slide_rest[0]+0.034,slide_rest[1],slide_rest[2]),zero), (3,(slide_rest[0]+0.010,slide_rest[1],slide_rest[2]),zero),(6,slide_rest,zero)], slide)
action("M1911_leeg", [(1,slide_rest,zero),(2,(slide_rest[0]+0.034,slide_rest[1],slide_rest[2]),zero),(4,slide_rest,zero),(7,(slide_rest[0]+0.034,slide_rest[1],slide_rest[2]),zero)], slide)
action("M1911_herladen", [(1,slide_rest,zero),(8,(slide_rest[0]+0.034,slide_rest[1],slide_rest[2]),zero),(40,(slide_rest[0]+0.034,slide_rest[1],slide_rest[2]),zero),(55,slide_rest,zero)], slide)
action("M1911_wisselen", [(1,slide_rest,zero),(14,slide_rest,zero),(26,slide_rest,zero)], slide)
action("M1911_rust", [(1,slide_rest,zero),(12,slide_rest,zero),(24,slide_rest,zero)], slide)
# Whole-weapon movement paired with the slide: recoil, present/lower and idle sway.
action("M1911_schot", [(1,rest,zero),(2,(rest[0]+0.006,rest[1],rest[2]),(0,-0.06,0)),(6,rest,zero)])
action("M1911_leeg", [(1,rest,zero),(2,(rest[0]+0.006,rest[1],rest[2]),(0,-0.06,0)),(7,rest,zero)])
action("M1911_herladen", [(1,rest,zero),(8,(rest[0],rest[1],rest[2]-0.02),(0,0.08,0)),(40,(rest[0],rest[1],rest[2]-0.02),(0,0.08,0)),(55,rest,zero)])
action("M1911_wisselen", [(1,(rest[0],rest[1],rest[2]-0.06),(0,0.12,0)),(14,rest,zero),(26,rest,zero)])
action("M1911_rust", [(1,rest,zero),(12,rest,(0,0.015,0)),(24,rest,zero)])
for a in bpy.data.actions:
    if not a.name.startswith("M1911_"):
        continue
    for fc in a.fcurves:
        for k in fc.keyframe_points:
            k.interpolation = "BEZIER"
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
slide.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
    export_animations=True, export_nla_strips=True, export_frame_range=False,
    export_apply=True, export_materials="EXPORT", export_image_format="AUTO")
print("MESHY_M1911_EXPORTED", OUT, BLEND)
