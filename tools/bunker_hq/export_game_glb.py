"""Re-export the baked High Quality Showcase bunker from its game .blend.

Run from the repository root with Blender 4.5+:
  blender --background --factory-startup \
    assets/bunker/game_optimized/Bloedjungle_Bunker_Game_Optimized.blend \
    --python tools/bunker_hq/export_game_glb.py
"""
from pathlib import Path
import bpy


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/tests/bunker/bloedjungle_bunker_hq.glb"
COLLECTION_NAME = "Game Optimized — baked atlas"


collection = bpy.data.collections.get(COLLECTION_NAME)
if collection is None:
    raise RuntimeError(f"Missing optimized bunker collection: {COLLECTION_NAME}")

objects = [obj for obj in collection.all_objects if obj.type == "MESH"]
if len(objects) != 1:
    raise RuntimeError(f"Expected one baked mesh, found {len(objects)}")

bpy.ops.object.select_all(action="DESELECT")
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

properties = bpy.ops.export_scene.gltf.get_rna_type().properties
options = {
    "filepath": str(OUTPUT),
    "export_format": "GLB",
    "use_selection": True,
    "export_apply": True,
    "export_materials": "EXPORT",
}
for name, value in (("export_yup", True), ("export_cameras", False), ("export_lights", False)):
    if name in properties:
        options[name] = value

bpy.ops.export_scene.gltf(**options)
print(f"BUNKER_GLB_EXPORTED {OUTPUT}")
