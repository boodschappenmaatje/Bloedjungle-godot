import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.dirname(__file__)); SHOT=ROOT+'/screenshots'
bpy.ops.wm.open_mainfile(filepath=ROOT+'/M47_Muurbreker_Blender_1.0.blend'); scene=bpy.context.scene
# Remove prior non-destructive animation prototype; keep immutable reference and LOD copies.
for o in list(bpy.data.objects):
 if o.name.startswith(('M47_AnimationRoot','M47_Rotating_Core','M47_Core_Retaining_Ring','M47_Moving_Loading_Chamber')) or o.type=='ARMATURE': bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
mat=bpy.data.materials.get('M47_Mechanism_Steel') or bpy.data.materials.new('M47_Mechanism_Steel'); mat.diffuse_color=(.16,.20,.22,1); mat.use_nodes=True; bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(.12,.16,.18,1); bs.inputs['Metallic'].default_value=.88; bs.inputs['Roughness'].default_value=.27
# simple mechanical demonstration parts independent from pristine weapon body
bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.105,depth=.22,location=(.05,-.205,.10),rotation=(0,math.pi/2,0)); core=bpy.context.object; core.name='M47_Rotating_Core'; core.data.materials.append(mat)
bpy.ops.mesh.primitive_torus_add(major_radius=.13,minor_radius=.018,major_segments=32,minor_segments=8,location=(-.02,-.215,.10),rotation=(0,math.pi/2,0)); ring=bpy.context.object; ring.name='M47_Core_Retaining_Ring'; ring.data.materials.append(mat)
bpy.ops.mesh.primitive_cube_add(size=1,location=(.38,-.205,.08)); bolt=bpy.context.object; bolt.name='M47_Moving_Loading_Chamber'; bolt.dimensions=(.18,.055,.11); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); bolt.data.materials.append(mat)
# Armature bones: root recoil and two independently moving mechanical parts.
ad=bpy.data.armatures.new('M47_Mechanism_Rig'); arm=bpy.data.objects.new('M47_Mechanism_Rig',ad); scene.collection.objects.link(arm); bpy.context.view_layer.objects.active=arm; arm.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
b=ad.edit_bones.new('Root'); b.head=(0,0,0); b.tail=(0,0,.5)
c=ad.edit_bones.new('Core'); c.head=(.05,-.205,.10); c.tail=(.5,-.205,.10); c.parent=b; c.use_connect=False
ch=ad.edit_bones.new('Chamber'); ch.head=(.38,-.205,.08); ch.tail=(.7,-.205,.08); ch.parent=b; ch.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT'); arm.select_set(False)
# weight and armature-deform optimised and mechanism geometry; immutable original ref excluded
for obj,bone in [(bpy.data.objects['M47_LOD0'],'Root'),(bpy.data.objects['M47_LOD1'],'Root'),(bpy.data.objects['M47_LOD2'],'Root'),(core,'Core'),(ring,'Core'),(bolt,'Chamber')]:
 obj.hide_set(False); obj.hide_render=False; obj.parent=arm
 vg=obj.vertex_groups.new(name=bone); vg.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
 mod=obj.modifiers.new('M47_Mechanism_Rig','ARMATURE'); mod.object=arm
# Create five one-track actions on one armature so each GLB clip has all channels.
clips={'Idle':48,'Equip':36,'Aim':30,'Fire':18,'Reload':60}
for name,end in clips.items():
 bpy.context.view_layer.objects.active=arm; arm.select_set(True); bpy.ops.object.mode_set(mode='POSE')
 root=arm.pose.bones['Root']; cp=arm.pose.bones['Core']; chamber=arm.pose.bones['Chamber']
 for pb in (root,cp,chamber): pb.rotation_mode='XYZ'; pb.location=(0,0,0); pb.rotation_euler=(0,0,0)
 act=bpy.data.actions.new(name); arm.animation_data_create(); arm.animation_data.action=act
 def key(pb,frame):
  pb.keyframe_insert(data_path='location',frame=frame,group=pb.name); pb.keyframe_insert(data_path='rotation_euler',frame=frame,group=pb.name)
 key(root,1); key(cp,1); key(chamber,1)
 if name=='Idle':
  cp.rotation_euler[1]=2*math.pi; key(cp,end); chamber.location[1]=.02; key(chamber,end)
 elif name=='Equip':
  root.location[2]=-.18; key(root,1); root.location[2]=0; key(root,9); cp.rotation_euler[1]=2*math.pi; key(cp,end)
 elif name=='Aim':
  root.location[2]=-.05; key(root,1); root.location[2]=0; key(root,9); cp.rotation_euler[1]=math.pi; key(cp,end)
 elif name=='Fire':
  root.location[0]=.10; key(root,3); root.location[0]=-.035; key(root,6); root.location[0]=0; key(root,13); cp.rotation_euler[1]=math.pi*1.5; key(cp,end); chamber.location[1]=.075; key(chamber,3); chamber.location[1]=0; key(chamber,9)
 elif name=='Reload':
  root.location[2]=.025; key(root,15); chamber.location[1]=.12; key(chamber,19); key(chamber,27); chamber.location[1]=0; key(chamber,32); cp.rotation_euler[1]=2*math.pi; key(cp,end)
 for fc in act.fcurves:
  for kp in fc.keyframe_points: kp.interpolation='LINEAR'
 bpy.ops.object.mode_set(mode='OBJECT'); arm.select_set(False)
 track=arm.animation_data.nla_tracks.new(); track.name=name; strip=track.strips.new(name,1,act); strip.action=act; arm.animation_data.action=None
# render proof frames by evaluating actions in authoring scene
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=False
scene.render.resolution_x=900; scene.render.resolution_y=630; scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
for name,end in clips.items():
 track=next(t for t in arm.animation_data.nla_tracks if t.name==name); track.mute=False
 for t in arm.animation_data.nla_tracks:
  t.mute=(t!=track)
 frame=max(1,min(end, 3 if name=='Fire' else 20 if name=='Reload' else 12 if name=='Equip' else 10))
 scene.frame_set(frame); scene.render.filepath=SHOT+'/'+name.lower()+'.png'; bpy.ops.render.render(write_still=True)
 track.mute=True
for t in arm.animation_data.nla_tracks:t.mute=False
# save working project and export selection without original mesh
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/M47_Muurbreker_Blender_1.0.blend')
for obj in bpy.context.selected_objects: obj.select_set(False)
export_objects=[arm,bpy.data.objects['M47_LOD0'],bpy.data.objects['M47_LOD1'],bpy.data.objects['M47_LOD2'],core,ring,bolt]
for obj in export_objects: obj.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.ops.export_scene.gltf(filepath=ROOT+'/M47_Muurbreker_1.0_animated.glb',export_format='GLB',export_animations=True,export_nla_strips=True,export_skins=True,export_morph=False,export_cameras=False,export_lights=False,export_apply=False,export_materials='EXPORT',export_image_format='AUTO',use_selection=True)
print('ANIMATION_TRACKS',[(t.name,len(t.strips)) for t in arm.animation_data.nla_tracks]); print('EXPORT_DONE')
