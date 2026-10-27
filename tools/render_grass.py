"""Real Cycles old/new renders of the exported GLBs under matched light/camera."""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/grass/renders'


def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=48;s.cycles.use_denoising=False
    s.render.resolution_x=1200;s.render.resolution_y=800;s.render.resolution_percentage=100
    s.world=bpy.data.worlds.new('Neutral photographic studio');s.world.use_nodes=True
    s.world.node_tree.nodes['Background'].inputs[0].default_value=(.36,.43,.50,1)
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.006));floor=bpy.context.object
    mat=bpy.data.materials.new('Quiet soil');mat.diffuse_color=(.095,.075,.04,1);mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.095,.075,.04,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.92;floor.data.materials.append(mat)
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,7));light=bpy.context.object
    light.data.energy=1050;light.data.shape='DISK';light.data.size=4
    light.rotation_euler=(Vector((0,0,.4))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(3.4,-5.2,3.2));camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,.50))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=48;s.camera=camera
    s.view_settings.view_transform='AgX'
    s.render.image_settings.file_format='PNG'
    return s


for family in ['short','medium','tall']:
    for revision in (['new'] if '--new-only' in sys.argv else ['old','new']):
        s=scene()
        path=ROOT/'assets/grass'/('grass_baseline.glb' if revision=='old' else f'grass_{family}_lod0.glb')
        bpy.ops.import_scene.gltf(filepath=str(path))
        s.render.filepath=str(OUT/f'blender-{family}-{revision}.png')
        bpy.ops.render.render(write_still=True)
print('GRASS CYCLES RENDERS COMPLETE: six matched old/new GLB images')
