"""Render 2.2 from 2.1's exact four cameras plus focused 2.2 review cameras."""
import bpy,os,math,sys
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
SRC=os.path.join(ROOT,'assets/airfield_hq_v22/high_quality/Bloedjungle_Airfield_HQ_2_2_Source.blend')
OUT=os.path.join(ROOT,'previews/airfield_hq/v22_review');os.makedirs(OUT,exist_ok=True)
SHOTS={
 '01_hangar_exterior':((78,-84,47),(0,0,8),52,1),
 '02_hangar_interior_doors_open':((8,-38,9),(0,1,7),40,90),
 '03_control_tower':((105,-10,31),(72,20,10),55,1),
 '04_runway_approach':((190,-130,145),(0,330,0),38,1),
 '05_roof_and_sliding_door_close':((32,-34,27),(3,-19,12),42,1),
 '06_workshop_detail':((17,-15,6),(15,2,3),38,90),
 '07_tower_street_level':((91,-8,6),(72,20,11),43,1),
 '08_runway_taxiway_aerial':((190,-120,270),(20,190,0),36,1),
 '09_gameplay_top_down':((35,-55,72),(0,0,0),40,1),
 '10_p47_parking_clearance':((44,-77,40),(0,-45,0),44,90),
}
only=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--shot=')),None)
if only:SHOTS={k:v for k,v in SHOTS.items() if k==only}
bpy.ops.wm.open_mainfile(filepath=SRC)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
for name,(pos,target,lens,frame) in SHOTS.items():
    camera=scene.camera
    if camera is None:
        bpy.ops.object.camera_add(location=pos);camera=bpy.context.object;scene.camera=camera
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens
    camera.data.dof.use_dof=False;scene.frame_set(frame)
    if name=='10_p47_parking_clearance':
        # Dimension-only render annotation. It is deliberately absent from
        # the source/game GLBs and must never be presented as a P-47 model.
        mark=bpy.data.materials.new('RENDER ONLY | P-47 clearance annotation')
        mark.diffuse_color=(1,.66,.08,1);mark.use_nodes=True
        mark.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(1,.66,.08,1)
        def line(label,points):
            cv=bpy.data.curves.new(label,'CURVE');cv.dimensions='3D';cv.bevel_depth=.055;cv.bevel_resolution=2
            s=cv.splines.new('POLY');s.points.add(len(points)-1)
            for point,co in zip(s.points,points):point.co=(*co,1)
            o=bpy.data.objects.new(label,cv);scene.collection.objects.link(o);cv.materials.append(mark)
        x0,x1=-6.22,6.22;y0,y1=-50.5,-39.5
        for z in (.25,4.7):line('P-47 dimensional envelope outline',[(x0,y0,z),(x1,y0,z),(x1,y1,z),(x0,y1,z),(x0,y0,z)])
        for x in (x0,x1):
            for y in (y0,y1):line('P-47 height 4.45 m',[(x,y,.25),(x,y,4.7)])
        font=bpy.data.curves.new('P-47 SIZE ONLY • NO AIRCRAFT MODEL','FONT');font.body='P-47 SIZE ONLY  |  12.44 m x 11 m x 4.45 m';font.size=1.2
        label=bpy.data.objects.new('P-47 dimensional label',font);scene.collection.objects.link(label)
        label.location=(-13,-55,.24);font.materials.append(mark)
    scene.render.filepath=os.path.join(OUT,'v22_'+name+'.png')
    bpy.ops.render.render(write_still=True)
    print('AIRFIELD_22_RENDER',name,scene.render.filepath,flush=True)
