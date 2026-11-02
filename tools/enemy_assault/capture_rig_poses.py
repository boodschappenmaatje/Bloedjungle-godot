import bpy, os, sys
from mathutils import Vector
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
glb=os.path.abspath(args[0]) if args else os.path.join(root,'source_assets/enemy_assault/rig_test/enemy_assault_rigged_test.glb')
out=os.path.dirname(os.path.abspath(args[1])) if len(args)>1 else os.path.join(root,'source_assets/enemy_assault/rig_test')
capture_name=os.path.basename(args[1]) if len(args)>1 else 'capture_aim_test.png'
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=glb)
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
# camera + soft studio lighting
bpy.ops.object.camera_add(location=(3.4,-6.7,2.6)); cam=bpy.context.object; cam.name='Assault_Capture_Camera'; cam.data.type='ORTHO'; cam.data.ortho_scale=2.65; cam.rotation_euler=(Vector((0,0,0.95))-cam.location).to_track_quat('-Z','Y').to_euler(); bpy.context.scene.camera=cam
for name,loc,power,size in [('Key',(2,-4,4),850,4),('Fill',(-3,-2,2.2),500,3),('Rim',(0,3,3),900,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object; l.name=name; l.data.energy=power; l.data.shape='DISK'; l.data.size=size; l.rotation_euler=(Vector((0,0,1))-l.location).to_track_quat('-Z','Y').to_euler()
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.render.resolution_x=600; sc.render.resolution_y=800; sc.render.resolution_percentage=100; sc.render.image_settings.file_format='PNG'; sc.render.film_transparent=True; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='MATERIAL'; sc.display.shading.show_shadows=True
poses={'aim_test':{'mixamorig:RightArm':(0.0,0.0,-0.35),'mixamorig:RightForeArm':(0.0,0.0,-0.7),'mixamorig:LeftArm':(0.0,0.0,0.3),'mixamorig:LeftForeArm':(0.0,0.0,0.55)}}
for pose,rots in poses.items():
 for b in arm.pose.bones: b.rotation_mode='XYZ'; b.rotation_euler=(0,0,0)
 for n,r in rots.items(): arm.pose.bones[n].rotation_euler=r
 sc.render.filepath=os.path.join(out,capture_name if len(poses)==1 else 'capture_'+pose+'.png'); bpy.ops.render.render(write_still=True)
