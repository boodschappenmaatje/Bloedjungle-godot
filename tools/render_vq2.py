"""blender -b -t 4 --python tools/render_vq2.py -- [optional asset]

Matched before/after studio renders from the actual GLBs. The Godot showcase
supplies separate actual-game-camera captures with runtime V1 material skins.
"""
from pathlib import Path
import sys, math
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/vq2/renders'
OUT.mkdir(parents=True,exist_ok=True)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
names=args or ['kazerne','wachttoren','legerjeep']
for name in names:
    paths=[ROOT/'assets/vq2_baseline'/f'{name}.glb',ROOT/'assets'/f'{name}.glb']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    groups=[]
    points=[]
    for path in paths:
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(path))
        group=list(set(bpy.data.objects)-before)
        groups.append(group)
        for o in group:
            if o.type=='MESH':
                points.extend(o.matrix_world@Vector(p) for p in o.bound_box)
    low=Vector(tuple(min(p[a] for p in points) for a in range(3)))
    high=Vector(tuple(max(p[a] for p in points) for a in range(3)))
    target=(low+high)/2
    span=high-low
    scene=bpy.context.scene
    world=bpy.data.worlds.new('VQ2 neutral daylight');scene.world=world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.56,.62,.69,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
    def area(pos,energy,size):
        data=bpy.data.lights.new('Studio area','AREA');data.energy=energy;data.size=size
        obj=bpy.data.objects.new('Studio area',data);scene.collection.objects.link(obj);obj.location=pos
        obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
    area(target+Vector((-4,-6,10)),1400,7)
    area(target+Vector((5,3,7)),1100,5)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,min(low.z,0)-.012))
    floor=bpy.context.object
    mat=bpy.data.materials.new('Studio floor');mat.diffuse_color=(.14,.17,.13,1);mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.14,.17,.13,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    floor.data.materials.append(mat)
    data=bpy.data.cameras.new('Matched camera');cam=bpy.data.objects.new('Matched camera',data)
    scene.collection.objects.link(cam);cam.location=target+Vector((8,-12,8)).normalized()*max(span)*3
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=max(span.z*1.45,max(span.x,span.y)*1.55)
    scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False
    scene.render.resolution_x=1024;scene.render.resolution_y=768;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
    for i,group in enumerate(groups):
        for j,other in enumerate(groups):
            for obj in other: obj.hide_render=j!=i
        scene.render.filepath=str(OUT/f'{name}-studio-v{i+1}.png')
        bpy.ops.render.render(write_still=True)
        print('MATCHED_RENDER',scene.render.filepath,flush=True)
