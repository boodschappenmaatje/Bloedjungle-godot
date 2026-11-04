#!/usr/bin/env python3
"""Create shared-material mobile LOD meshes from the rigged Meshy Assault GLB.

Usage: blender -b --python tools/enemy_assault/build_assault_mobile_lods.py -- INPUT.glb OUTPUT.glb
The high-poly input and original Meshy source are read-only.
"""
import bpy
import json
import math
import os
import shutil
import sys
import hashlib


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SOURCE = os.path.abspath(ARGS[0]) if ARGS else os.path.join(ROOT, "source_assets/enemy_assault/rig_test/enemy_assault_meshy_weapon_rigged_test.glb")
OUT = os.path.abspath(ARGS[1]) if len(ARGS) > 1 else os.path.join(ROOT, "assets/enemies/assault/assault_meshy_hq2_runtime.glb")
TARGETS = [("LOD0", 12000, 1800), ("LOD1", 3500, 700), ("LOD2", 1400, 300)]


def tris(mesh):
    return sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons)


def decimated_copy(source, name, target_tris):
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    source.users_collection[0].objects.link(obj)
    original_tris = tris(obj.data)
    modifier = obj.modifiers.new("Mobile LOD reduction", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = min(1.0, max(0.0001, target_tris / max(1, original_tris)))
    if len(obj.modifiers) > 1:
        obj.modifiers.move(len(obj.modifiers) - 1, 0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)
    return obj, original_tris, tris(obj.data)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SOURCE)
arm = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE" and len(obj.data.bones) == 28), None)
body = next((obj for obj in bpy.context.scene.objects if obj.type == "MESH" and len(obj.data.vertices) > 500000 and any(m.type == "ARMATURE" for m in obj.modifiers)), None)
weapon_root = next((obj for obj in bpy.context.scene.objects if obj.name == "Assault_Meshy_Weapon"), None)
weapon = next((obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name == "Assault_Meshy_Weapon_Mesh"), None)
if arm is None or body is None or weapon_root is None or weapon is None:
    raise RuntimeError("Expected 28-bone armature, skinned Meshy body, detached rifle, and authored weapon root")

# Preserve the source's packed PBR set, including its detail normal map, while
# scaling the largest images for the close gameplay LOD on mobile hardware.
texture_dir = os.path.join(os.path.dirname(OUT), ".assault_texture_work")
os.makedirs(texture_dir, exist_ok=True)
texture_report = []
for image in list(bpy.data.images):
    if image.source != "FILE" or image.size[0] <= 0 or image.size[1] <= 0:
        continue
    old_size = tuple(image.size)
    limit = 1024 if "Image_1" in image.name else 2048
    factor = min(1.0, limit / max(old_size))
    new_size = (max(1, round(old_size[0] * factor)), max(1, round(old_size[1] * factor)))
    if new_size != old_size:
        image.scale(*new_size)
    path = os.path.join(texture_dir, image.name.replace("/", "_") + ".jpg")
    image.filepath_raw = path
    image.file_format = "JPEG"
    image.save()
    image.pack()
    texture_report.append({"name": image.name, "source_resolution": old_size, "runtime_resolution": tuple(image.size), "temp_bytes": os.path.getsize(path)})

lod_objects = []
lod_report = []
body_lod0 = None
weapon_lod0 = None
for level, body_target, weapon_target in TARGETS:
    body_source = body if body_lod0 is None else body_lod0
    weapon_source = weapon if weapon_lod0 is None else weapon_lod0
    body_lod, body_before, body_after = decimated_copy(body_source, "Assault_Body_" + level, body_target)
    body_lod.parent = arm
    body_lod.matrix_parent_inverse = body.matrix_parent_inverse.copy()
    body_lod.matrix_basis = body.matrix_basis.copy()
    weapon_lod, weapon_before, weapon_after = decimated_copy(weapon_source, "Assault_Meshy_Weapon_Mesh_" + level, weapon_target)
    weapon_lod.parent = weapon_root
    weapon_lod.matrix_parent_inverse = weapon.matrix_parent_inverse.copy()
    weapon_lod.matrix_basis = weapon.matrix_basis.copy()
    lod_objects.extend([body_lod, weapon_lod])
    if body_lod0 is None:
        body_lod0 = body_lod
        weapon_lod0 = weapon_lod
    lod_report.append({"level": level, "body_triangles": body_after, "weapon_triangles": weapon_after, "combined_triangles": body_after + weapon_after,
                       "body_source_triangles": body_before, "weapon_source_triangles": weapon_before})

# Discard only the heavyweight preview meshes; retain their source on disk.
bpy.data.objects.remove(body, do_unlink=True)
bpy.data.objects.remove(weapon, do_unlink=True)
lod_report_by_name = {item["level"]: item for item in lod_report}

for obj in lod_objects:
    obj["assault_lod_level"] = obj.name.rsplit("_", 1)[-1]
    obj["assault_lod_body_or_weapon"] = "weapon" if "Weapon" in obj.name else "body"

os.makedirs(os.path.dirname(OUT), exist_ok=True)
export_objects = [arm, weapon_root] + lod_objects
export_objects += [obj for obj in bpy.context.scene.objects if obj.name.startswith("Assault_") and obj.type == "EMPTY"]
bpy.ops.object.select_all(action="DESELECT")
for obj in export_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=False,
                          export_animations=False, export_skins=True, export_materials="EXPORT",
                          export_image_format="JPEG", export_image_quality=82)

report = {"source": SOURCE, "output": OUT, "bones": len(arm.data.bones), "lods": lod_report, "textures": texture_report,
          "source_materials": len({mat.name for obj in lod_objects for mat in obj.data.materials if mat is not None}),
          "runtime_body_vertices_total": sum(len(item.data.vertices) for item in lod_objects if "Weapon" not in item.name),
          "runtime_weapon_vertices_total": sum(len(item.data.vertices) for item in lod_objects if "Weapon" in item.name),
          "runtime_bytes": os.path.getsize(OUT)}
with open(OUT, "rb") as stream:
    report["sha256"] = hashlib.sha256(stream.read()).hexdigest()
with open(os.path.splitext(OUT)[0] + ".json", "w") as stream:
    json.dump(report, stream, indent=2)
shutil.rmtree(texture_dir, ignore_errors=True)
print("ASSAULT_MOBILE_LOD_REPORT=" + json.dumps(report))
