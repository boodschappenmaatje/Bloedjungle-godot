import bpy,os,math
from mathutils import Vector
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
source=os.path.join(root,'assets/airfield_hq/high_quality/Bloedjungle_Airfield_HQ_Source.blend')
out=os.path.join(root,'previews/airfield_hq/v2');os.makedirs(out,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=source)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=False
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.65
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.42,.48,.55,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.8
sun=bpy.data.objects.get('Late morning sun')
if sun is None:
    sun_data=bpy.data.lights.new('Late morning sun','SUN');sun_data.energy=2.0;sun_data.angle=math.radians(.12);sun_data.color=(1.0,.91,.78)
    sun=bpy.data.objects.new('Late morning sun',sun_data);scene.collection.objects.link(sun);sun.location=(-80,-100,150)
sun.rotation_euler=(Vector((0,180,0))-sun.location).to_track_quat('-Z','Y').to_euler()
def render(name,camloc,target,lens,frame=1):
    scene.frame_set(frame)
    bpy.ops.object.camera_add(location=camloc);cam=bpy.context.object;cam.name='Review_'+name
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=lens;scene.camera=cam
    scene.render.filepath=os.path.join(out,name+'.png');bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam,do_unlink=True)
render('01_hangar_exterior',(86,-88,52),(4,5,8),50,1)
render('02_hangar_interior_doors_open',(5,-46,11),(0,3,9),34,90)
render('03_control_tower',(112,-8,42),(72,20,9),52,1)
render('04_runway_approach',(34,-170,41),(0,270,2),40,1)
print('AIRFIELD_PREVIEWS',out)
