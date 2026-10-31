"""Ensure every small USAAF stencil and sign mesh has an explicit UV0."""
import bpy
import os
import json

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
source = os.path.join(root, "assets/airfield_hq/high_quality/Bloedjungle_Airfield_HQ_Source.blend")
metrics_path = os.path.join(root, "assets/airfield_hq/high_quality/source_metrics.json")
bpy.ops.wm.open_mainfile(filepath=source)
names = (
    "USAAF blue insignia roundel",
    "USAAF white star and bar stencil",
    "Hangar fascia identification board",
    "USAAF hangar sign lettering",
)
fixed = []
for obj in bpy.data.objects:
    if obj.type != "MESH" or not any(obj.name.startswith(name) for name in names):
        continue
    if obj.data.uv_layers:
        continue
    layer = obj.data.uv_layers.new(name="UV0_4m_tile")
    for polygon in obj.data.polygons:
        normal = polygon.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[axis]
        for loop_index in polygon.loop_indices:
            coord = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            layer.data[loop_index].uv = (coord[axes[0]] * 0.25, coord[axes[1]] * 0.25)
    fixed.append(obj.name)
bpy.ops.wm.save_as_mainfile(filepath=source)
with open(metrics_path) as stream:
    metrics = json.load(stream)
metrics["uv_repair_objects"] = fixed
with open(metrics_path, "w") as stream:
    json.dump(metrics, stream, indent=2)
print("AIRFIELD_DECAL_UV_REPAIR", fixed)
