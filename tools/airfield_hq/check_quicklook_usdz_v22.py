"""Re-import tabletop USDZ in Blender, assert physical bounds, render proof PNG."""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
raw = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument('--asset', choices=('Hangar', 'Tower'), required=True)
asset = parser.parse_args(raw).asset
base = os.path.join(ROOT, 'previews/usdz/airfield_hq/2.2')
source = os.path.join(base, f'Bloedjungle_Airfield_HQ_2_2_{asset}_QuickLook.usdz')
output = os.path.join(base, f'Bloedjungle_Airfield_HQ_2_2_{asset}_QuickLook_check.png')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=source)
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
assert len(meshes) == 1, f'Expected one batched mesh, got {len(meshes)}'
points = [obj.matrix_world @ Vector(v) for obj in meshes for v in obj.bound_box]
minimum = Vector(tuple(min(p[i] for p in points) for i in range(3)))
maximum = Vector(tuple(max(p[i] for p in points) for i in range(3)))
span = maximum - minimum
assert 0.7 <= max(span) <= 1.0, f'Not tabletop sized: {span}'
assert minimum.z >= -0.01, f'Model below floor: {minimum.z}'
materials = {mat for obj in meshes for mat in obj.data.materials if mat}
assert len(materials) >= 3, f'Missing USDZ materials: {len(materials)}'
texnodes = sum(
    node.type == 'TEX_IMAGE' and node.image is not None
    for mat in materials if mat.use_nodes for node in mat.node_tree.nodes
)
assert texnodes >= 3, f'Missing re-imported textures: {texnodes}'

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 20
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new('Soft studio sky')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.72, .77, .82, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .7

def area(position, power, size):
    data = bpy.data.lights.new('USDZ inspection softbox', 'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((0, 0, .15)) - obj.location).to_track_quat('-Z', 'Y').to_euler()

area((1.1, -1.2, 1.7), 150, 2.0)
area((-.9, .8, 1.3), 90, 1.5)
camera_data = bpy.data.cameras.new('USDZ inspection camera')
camera = bpy.data.objects.new(camera_data.name, camera_data)
scene.collection.objects.link(camera)
target = Vector((0, 0, span.z * .42))
camera.location = (1.15, -1.28, .75 if asset == 'Hangar' else 1.15)
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 1.48 if asset == 'Hangar' else 1.75
scene.camera = camera
scene.render.filepath = output
bpy.ops.render.render(write_still=True)
print('AIRFIELD_USDZ_REIMPORT_PASS', json.dumps({
    'asset': asset,
    'mesh_count': len(meshes),
    'materials': len(materials),
    'texture_nodes': texnodes,
    'span_m': [round(x, 3) for x in span],
    'render': os.path.relpath(output, ROOT),
}), flush=True)
