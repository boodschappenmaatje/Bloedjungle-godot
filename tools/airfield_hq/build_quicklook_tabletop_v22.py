"""Prepare compact, static tabletop Blender sources for iPhone Quick Look.

The full-size 840 x 1140 m airfield USDZ is too large to frame sensibly in
Quick Look. These are review-only derivatives: game/source geometry stays at
true metre scale. Run Blender with: --python this_file -- --asset hangar|tower
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
SOURCE = os.path.join(ROOT, 'assets/airfield_hq_v22/high_quality/Bloedjungle_Airfield_HQ_2_2_Source.blend')
OUT = os.path.join(ROOT, 'previews/usdz/airfield_hq/2.2/tabletop_sources')
COLLECTIONS = {
    'hangar': {'01_Hangar_HQ_22', '02_Hangar_Sliding_Doors', '07_Hangar_Service_Props_22'},
    'tower': {'03_Control_Tower_22'},
}

raw = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument('--asset', choices=COLLECTIONS, required=True)
asset = parser.parse_args(raw).asset

bpy.ops.wm.open_mainfile(filepath=SOURCE)
scene = bpy.context.scene
scene.frame_set(1)
depsgraph = bpy.context.evaluated_depsgraph_get()
preview = bpy.data.collections.new('Quick Look tabletop | ' + asset)
scene.collection.children.link(preview)
keep = [
    obj for obj in list(bpy.data.objects)
    if obj.type == 'MESH' and any(c.name in COLLECTIONS[asset] for c in obj.users_collection)
]
assert keep, f'No source meshes for {asset}'

# Duplicate evaluated geometry so bevels, modifiers and shape keys are baked
# at a known frame. This is a static review asset, not an animation export.
copies = []
for obj in keep:
    evaluated = obj.evaluated_get(depsgraph)
    data = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
    copy = bpy.data.objects.new(obj.name, data)
    preview.objects.link(copy)
    copy.matrix_world = obj.matrix_world.copy()
    copies.append(copy)

points = [copy.matrix_world @ Vector(corner) for copy in copies for corner in copy.bound_box]
minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
centre = Vector(((minimum.x + maximum.x) / 2, (minimum.y + maximum.y) / 2, minimum.z))
source_span = maximum - minimum
scale = 0.90 / max(source_span)

for obj in list(bpy.data.objects):
    if obj not in copies:
        bpy.data.objects.remove(obj, do_unlink=True)
for copy in copies:
    matrix = copy.matrix_world.copy()
    for vert in copy.data.vertices:
        vert.co = (matrix @ vert.co - centre) * scale
    copy.matrix_world.identity()
    copy.data.update()

# One mesh and a small material set are easier for Quick Look to load than
# hundreds of architectural object transforms.
bpy.ops.object.select_all(action='DESELECT')
for copy in copies:
    copy.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
model = bpy.context.object
model.name = f'Airfield HQ 2.2 {asset} | 0.9 m tabletop model'
scene['asset_version'] = 'Airfield HQ 2.2'
scene['quicklook_preview_only'] = True
scene['source_scale_metres'] = list(source_span)
scene['tabletop_scale_factor'] = scale

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, f'Airfield_HQ_2_2_{asset}_tabletop.blend')
for image in bpy.data.images:
    if image.source == 'FILE' and image.filepath:
        absolute = bpy.path.abspath(image.filepath)
        if os.path.isfile(absolute):
            image.filepath = '//' + os.path.relpath(absolute, OUT)
bpy.ops.wm.save_as_mainfile(filepath=path, relative_remap=False)
receipt = {
    'asset': asset,
    'source': os.path.relpath(SOURCE, ROOT),
    'preview_blend': os.path.relpath(path, ROOT),
    'source_span_m': [round(x, 3) for x in source_span],
    'tabletop_span_m': [round(x * scale, 3) for x in source_span],
    'scale_factor': scale,
    'source_meshes': len(keep),
    'preview_meshes': 1,
    'animation': 'static frame 1 only',
}
with open(os.path.join(OUT, f'Airfield_HQ_2_2_{asset}_tabletop.json'), 'w') as f:
    json.dump(receipt, f, indent=2)
print('AIRFIELD_QUICKLOOK_TABLETOP', json.dumps(receipt), flush=True)
