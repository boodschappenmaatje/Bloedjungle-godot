"""Render identical Airfield HQ 2.0 / 2.1 review cameras with Blender 4.5."""
import bpy,os,math
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
VERSIONS=[('v2','assets/airfield_hq/high_quality/Bloedjungle_Airfield_HQ_Source.blend'),('v21','assets/airfield_hq_v21/high_quality/Bloedjungle_Airfield_HQ_2_1_Source.blend')]
if '--v21-only' in __import__('sys').argv:VERSIONS=VERSIONS[1:]
SHOTS={
 '01_hangar_exterior':((78,-84,47),(0,0,8),52,1),
 '02_hangar_interior_doors_open':((8,-38,9),(0,1,7),40,90),
 '03_control_tower':((105,-10,31),(72,20,10),55,1),
 '04_runway_approach':((190,-130,145),(0,330,0),38,1),
}
OUT=os.path.join(ROOT,'previews/airfield_hq/v21_review');os.makedirs(OUT,exist_ok=True)
only=next((arg.split('=',1)[1] for arg in __import__('sys').argv if arg.startswith('--shot=')),None)
if only:SHOTS={name:shot for name,shot in SHOTS.items() if name==only}
for version,path in VERSIONS:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,path));scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=20;scene.cycles.use_denoising=True
    scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.render.resolution_percentage=100
    for name,(pos,target,lens,frame) in SHOTS.items():
        camera=scene.camera
        if camera is None:
            bpy.ops.object.camera_add(location=pos);camera=bpy.context.object;scene.camera=camera
        camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens
        scene.frame_set(frame);scene.camera.data.dof.use_dof=False
        scene.render.filepath=os.path.join(OUT,f'{version}_{name}.png')
        bpy.ops.render.render(write_still=True)
        print('AIRFIELD_REVIEW_RENDER',version,name,scene.render.filepath)
