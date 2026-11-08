"""Validate the saved 5.2 Blender scene after reopening it in batch mode."""
import hashlib
import json
from pathlib import Path

import bpy

root = Path(__file__).resolve().parents[3]
asset = root / "docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb"
scene = bpy.context.scene
lod0 = bpy.data.objects["M47_LOD0"]
triangles = sum(max(0, len(poly.vertices) - 2) for poly in lod0.data.polygons)
actions = sorted(action.name for action in bpy.data.actions if action.name.startswith((
    "Idle_M47_", "Equip_M47_", "Aim_M47_", "Fire_M47_", "Reload_M47_")))
m47_materials = sorted({slot.material.name for obj in scene.objects
                        if obj.name.startswith("M47_") and obj.type == "MESH"
                        for slot in obj.material_slots if slot.material})
packed_images = sorted(image.name for image in bpy.data.images if image.packed_file)
source_sha = hashlib.sha256(asset.read_bytes()).hexdigest()
result = {
    "blender": bpy.app.version_string,
    "engine": scene.render.engine,
    "resolution": [scene.render.resolution_x, scene.render.resolution_y],
    "samples": scene.cycles.samples,
    "frame": scene.frame_current,
    "m47_lod0_triangles": triangles,
    "m47_lod1_hidden_from_render": bpy.data.objects["M47_LOD1"].hide_render,
    "m47_lod2_hidden_from_render": bpy.data.objects["M47_LOD2"].hide_render,
    "m47_materials": m47_materials,
    "m47_actions": actions,
    "packed_image_count": len(packed_images),
    "approved_glb_sha256": source_sha,
    "5_2_smoke_and_dust_objects": sum(1 for o in scene.objects if o.name.startswith((
        "5.2 smoke", "5.2 impact plume", "5.2 dust", "5.2 energy haze"))),
    "5_2_concrete_fragments": sum(1 for o in scene.objects if o.name.startswith((
        "Crater lip |", "Impact apron |", "Crater rim |", "5.2 wall | large chipped crater lip"))),
    "5_2_facade_present": "5.2 wall | weathered aggregate face around jagged breach" in scene.objects,
}
expected_actions = {"Idle_M47_Mechanism_Rig", "Equip_M47_Mechanism_Rig", "Aim_M47_Mechanism_Rig",
                    "Fire_M47_Mechanism_Rig", "Reload_M47_Mechanism_Rig"}
assert scene.render.engine == "CYCLES"
assert result["resolution"] == [1920, 1080] and result["samples"] == 80
assert triangles == 50000
assert result["m47_lod1_hidden_from_render"] and result["m47_lod2_hidden_from_render"]
assert {"M47_Mechanism_Steel", "Material_0"}.issubset(set(m47_materials))
assert set(actions) == expected_actions, actions
assert result["packed_image_count"] >= 40
assert source_sha == "4031e935c5ef19a96a10257334a3cc99db92410a01389ef708259d887cf89872"
assert result["5_2_concrete_fragments"] == 302
assert result["5_2_facade_present"]
print("SCENE_5_2_VALIDATION " + json.dumps(result, sort_keys=True))
