"""Export one static USDZ Quick Look preview per weapon from the HQ Blender scene.

Usage: Blender --background --python export_usdz.py -- wapens_hq.blend <output-dir>
The animated GLB remains the authoritative game/viewer asset; USDZ previews are static.
"""
import os
import sys

import bpy


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
source, output = args[:2]
os.makedirs(output, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(source))
names = ("M1911", "Thompson", "Garand", "Trench", "MG42", "Bazooka")
roots = {obj.name: obj for obj in bpy.context.scene.objects if obj.type == "EMPTY" and obj.parent is None}
for name in names:
    root = roots[name]
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    target = os.path.join(output, name + ".usdz")
    bpy.ops.wm.usd_export(
        filepath=target,
        selected_objects_only=True,
        visible_objects_only=True,
        export_animation=False,
        export_meshes=True,
        export_lights=False,
        export_cameras=False,
        export_materials=True,
        export_textures=True,
        export_uvmaps=True,
        export_normals=True,
        convert_scene_units="METERS",
        meters_per_unit=1.0,
    )
    print("USDZ_EXPORTED", name, os.path.getsize(target))
