import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.dirname(__file__))
SRC=ROOT+'/M47_Muurbreker_original.glb'
SHOT=ROOT+'/screenshots'
os.makedirs(SHOT,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
scene=bpy.context.scene
src=next(o for o in scene.objects if o.type=='MESH' and o.name=='Mesh_0')
# Source reference remains unchanged and is excluded from exports.
refcol=bpy.data.collections.new('REFERENCE_ORIGINAL_DO_NOT_EDIT'); scene.collection.children.link(refcol)
refcol.objects.link(src); src.name='M47_Original_Reference'; src.hide_render=True
src.hide_set(True)
# Per-LOD duplicate from immutable imported geometry; evaluated decimation applied to duplicate.
assets=bpy.data.collections.new('M47_OPTIMIZED_LODS'); scene.collection.children.link(assets)
levels=[('LOD0',50000),('LOD1',25000),('LOD2',10000)]
lods=[]
for name,target in levels:
 ob=src.copy(); ob.data=src.data.copy(); ob.name='M47_'+name; assets.objects.link(ob); ob.hide_set(False); ob.hide_render=False
 dec=ob.modifiers.new('Decimate_'+name,'DECIMATE'); dec.decimate_type='COLLAPSE'; dec.ratio=target/len(ob.data.polygons); dec.use_collapse_triangulate=True
 bpy.context.view_layer.objects.active=ob; ob.select_set(True); bpy.ops.object.modifier_apply(modifier=dec.name); ob.select_set(False)
 ob.data.calc_loop_triangles(); lods.append(ob); print('LOD_RESULT',name,'polys',len(ob.data.polygons),'triangles',len(ob.data.loop_triangles),'uv_layers',len(ob.data.uv_layers),'materials',len(ob.data.materials))
# Keep LOD0 visible in authoring scene; hide other LODs.
for ob in lods[1:]: ob.hide_render=True; ob.hide_set(True)
lod0=lods[0]; lod0.hide_render=False; lod0.hide_set(False)
# PBR render camera and lighting: neutral studio setup, shared unchanged for comparison.
pts=[lod0.matrix_world @ Vector(c) for c in lod0.bound_box]; mn=Vector(tuple(min(p[i] for p in pts) for i in range(3))); mx=Vector(tuple(max(p[i] for p in pts) for i in range(3))); center=(mn+mx)*.5; size=(mx-mn).length
camd=bpy.data.cameras.new('M47_Studio_Camera'); cam=bpy.data.objects.new('M47_Studio_Camera',camd); scene.collection.objects.link(cam); scene.camera=cam; cam.location=center+Vector((size*1.05,-size*2.5,size*1.15)); cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=size*1.30
world=bpy.data.worlds.new('M47_Neutral_Studio'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.20,.23,1); world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35; scene.world=world
for name,offset,power,sz in [('Key',(0,-1,1.7),1800,1.0),('Fill',(-1,-.5,.5),1000,1.5),('Rim',(0,.8,1),2100,1.0)]:
 d=bpy.data.lights.new(name,'AREA'); o=bpy.data.objects.new(name,d); scene.collection.objects.link(o); o.location=center+Vector(offset)*size; d.energy=power; d.shape='DISK'; d.size=size*sz; o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES'; scene.cycles.samples=8; scene.cycles.use_denoising=False
scene.render.resolution_x=1000; scene.render.resolution_y=700; scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
# Original render: reference shown, LOD hidden.
lod0.hide_render=True; src.hide_render=False
scene.render.filepath=SHOT+'/pbr-original.png'; bpy.ops.render.render(write_still=True)
# LOD0 render under identical camera and lights.
src.hide_render=True; lod0.hide_render=False
scene.render.filepath=SHOT+'/pbr-lod0.png'; bpy.ops.render.render(write_still=True)
# Mechanical insert and bolt as separate, non-destructive test pieces attached to moving parent.
mat=bpy.data.materials.new('M47_Mechanism_Steel'); mat.diffuse_color=(.16,.20,.22,1); mat.use_nodes=True; bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(.12,.16,.18,1); bs.inputs['Metallic'].default_value=.88; bs.inputs['Roughness'].default_value=.27
rig=bpy.data.objects.new('M47_AnimationRoot',None); scene.collection.objects.link(rig); lod0.parent=rig
# center accessible on near side surface; separate core and sliding chamber are auxiliary test geometry.
def add_cylinder(name,loc,radius,depth):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth, location=loc, rotation=(0,math.pi/2,0)); ob=bpy.context.object; ob.name=name; ob.data.materials.append(mat); ob.parent=rig; return ob
core=add_cylinder('M47_Rotating_Core',(.05,-.205,.10),.105,.22)
# add a visible concentric retaining ring
bpy.ops.mesh.primitive_torus_add(major_radius=.13,minor_radius=.018,major_segments=32,minor_segments=8,location=(-.02,-.215,.10),rotation=(0,math.pi/2,0)); ring=bpy.context.object; ring.name='M47_Core_Retaining_Ring'; ring.data.materials.append(mat); ring.parent=rig
bolt=add_cylinder('M47_Moving_Loading_Chamber',(.22,-.215,-.05),.075,.13)
# Dedicated animation actions. Each is keyed on root recoil, core spin, bolt slide.
clip_frames={'Idle':(1,48),'Equip':(1,36),'Aim':(1,30),'Fire':(1,18),'Reload':(1,60)}
def insert_action(ob,clip,start,end,kind):
 bpy.context.view_layer.objects.active=ob; ob.animation_data_create(); act=bpy.data.actions.new(clip+'_'+ob.name); ob.animation_data.action=act
 ob.location=ob.location.copy(); ob.rotation_euler=ob.rotation_euler.copy()
 if kind=='root':
  keys={start:(0,0,0),end:(0,0,0)}
  if clip=='Equip': keys.update({start:(0,0,-.18),start+8:(0,0,0)})
  elif clip=='Aim': keys.update({start:(0,0,-.05),start+8:(0,0,0),end:(0,0,0)})
  elif clip=='Fire': keys.update({start:(0,0,0),start+2:(.09,0,0),start+5:(-.035,0,0),start+12:(0,0,0),end:(0,0,0)})
  elif clip=='Reload': keys.update({start+14:(0,0,.025),start+18:(.06,0,.025),start+25:(.06,0,.025),start+29:(0,0,0)})
  for f,v in keys.items(): ob.location=v; ob.keyframe_insert(data_path='location',frame=f,group=clip)
 elif kind=='core':
  for f,angle in [(start,0),(end,2*math.pi if clip in ('Idle','Equip','Aim','Reload') else math.pi*1.5)]: ob.rotation_euler[0]=angle; ob.keyframe_insert(data_path='rotation_euler',frame=f,group=clip)
 elif kind=='bolt':
  delta=.02 if clip=='Idle' else (.12 if clip=='Reload' else .075 if clip=='Fire' else 0)
  for f,x in [(start,0),(start+8,delta),(start+18,0),(end,0)]: ob.location.x=(.22 if ob==bolt else 0)+x; ob.keyframe_insert(data_path='location',frame=f,group=clip)
 # linear keys ensure actual movement and predictable GLB tracks
 for fc in act.fcurves:
  for kp in fc.keyframe_points: kp.interpolation='LINEAR'
 track=ob.animation_data.nla_tracks.new(); track.name=clip; strip=track.strips.new(clip,start,act); strip.action=act; ob.animation_data.action=None
 return act
for clip,(st,en) in clip_frames.items():
 insert_action(rig,clip,st,en,'root'); insert_action(core,clip,st,en,'core'); insert_action(bolt,clip,st,en,'bolt')
# Save Blender authoring source and export animated GLB with NLA clips.
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/M47_Muurbreker_Blender_1.0.blend')
scene.frame_start=1; scene.frame_end=60
out=ROOT+'/M47_Muurbreker_1.0_animated.glb'
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_animations=True,export_nla_strips=True,export_skins=False,export_morph=False,export_cameras=False,export_lights=False,export_apply=False,export_materials='EXPORT',export_image_format='AUTO',use_selection=False)
print('EXPORTED',out)
