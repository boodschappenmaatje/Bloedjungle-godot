"""Rebuild the Blender source and mobile GLB from the Meshy master GLB.
Run from repository root with Blender 4.3+: blender -b --python assets/apache_showcase/build_showcase.py
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "apache_showcase_meshy.glb"
BLEND = ROOT / "Apache_Showcase_Source.blend"
MOBILE = ROOT / "Apache_Showcase_Mobile.glb"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and len(obj.data.polygons) > 100)
mesh.name = "Apache_Showcase"
mesh.data.name = "Apache_Showcase_Mesh"
for obj in list(bpy.context.scene.objects):
    if obj != mesh:
        bpy.data.objects.remove(obj, do_unlink=True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh

# Keep the high-detail source editable; create a mobile copy with decimation.
source_copy = mesh.copy()
source_copy.data = mesh.data.copy()
source_copy.name = "Apache_Showcase_Mobile"
bpy.context.collection.objects.link(source_copy)
mod = source_copy.modifiers.new("Mobile_Triangle_Budget", "DECIMATE")
mod.ratio = min(1.0, 50000 / max(1, len(source_copy.data.polygons)))
bpy.context.view_layer.objects.active = source_copy
bpy.ops.object.modifier_apply(modifier=mod.name)

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

bpy.ops.object.select_all(action="DESELECT")
source_copy.select_set(True)
bpy.context.view_layer.objects.active = source_copy
bpy.ops.export_scene.gltf(filepath=str(MOBILE), export_format="GLB", use_selection=True, export_animations=False)
print(f"source triangles={len(mesh.data.polygons)} mobile triangles={len(source_copy.data.polygons)}")
