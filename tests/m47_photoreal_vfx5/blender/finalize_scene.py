"""Idempotent final framing, volume, glow and core tweaks for the baked V5 scene.
Run after build_cinematic.py --build and --bake, before still or video renders.
"""
import bpy, sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import build_cinematic as cin
scene=bpy.context.scene
cam=scene.camera
views=[
 (1,(-3.5,-6.0,3.4),(-1.0,0.0,1.05),42),
 (49,(-3.5,-6.0,3.4),(-1.0,0.0,1.05),42),
 (73,(-0.55,-5.8,2.45),(0.40,0.0,1.25),28),
 (109,(-4.5,-6.5,3.5),(0.95,0.0,1.40),28),
 (145,(-4.0,-7.5,3.35),(3.35,0.0,1.20),32),
]
for frame,pos,target,focal in views:
 cam.location=pos
 cam.rotation_euler=(cin.Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
 cam.data.lens=focal
 cam.keyframe_insert(data_path='location',frame=frame)
 cam.keyframe_insert(data_path='rotation_euler',frame=frame)
 cam.data.keyframe_insert(data_path='lens',frame=frame)
for anim in (cam.animation_data,cam.data.animation_data):
 if anim and anim.action:
  for fc in anim.action.fcurves:
   for kp in fc.keyframe_points: kp.interpolation='CONSTANT'
# Remove only the additional close tree instances; approved Poly Haven trees remain linked.
for obj in list(scene.objects):
 if obj.name.startswith('Photogrammetry jungle canopy | framing'):
  bpy.data.objects.remove(obj,do_unlink=True)
for name,strength in [('M-47 plasma | blue cyan emission',3.0),('M-47 plasma | white blue-hot emission',2.3)]:
 mat=bpy.data.materials.get(name)
 if mat and mat.use_nodes:
  bs=mat.node_tree.nodes.get('Principled BSDF')
  if bs and bs.inputs.get('Emission Strength'):
   bs.inputs['Emission Strength'].default_value=strength
filament=bpy.data.materials.get('Cinematic ion filaments | saturated blue')
if not filament:
 filament=cin.principled('Cinematic ion filaments | saturated blue',(0.008,.12,.68),.14,.12,(.01,.16,1.0),1.25)
for obj in scene.objects:
 if obj.name=='Plasma heart | white-hot center': obj.scale=(0.64,0.70,0.70)
 if obj.type=='CURVE' and obj.name.startswith(('Liquid electric filament','Long helicoidal plasma vapor filament')):
  mat=obj.data.materials[0] if obj.data.materials else None
  is_blue=bool(mat and ('blue cyan emission' in mat.name or 'Cinematic ion filaments' in mat.name))
  if is_blue and obj.data.materials: obj.data.materials[0]=filament
  obj.data.bevel_depth=0.012 if is_blue else 0.006
# A broad, fast expanding pressure front; explicit key values make this pass repeatable.
center=bpy.data.objects.get('Impact center | hexagonal pressure front')
scale_by_frame={1:0.001,108:0.001,114:0.88,122:1.95,126:2.184,142:0.001,192:0.001}
if center and center.animation_data and center.animation_data.action:
 for fc in center.animation_data.action.fcurves:
  if fc.data_path=='scale':
   for kp in fc.keyframe_points:
    frame=round(kp.co.x)
    if frame in scale_by_frame:
     value=scale_by_frame[frame]
     kp.co.y=value; kp.handle_left.y=value; kp.handle_right.y=value
# Rebuild only the separate supplemental core. The imported M-47 GLB geometry is unchanged.
core_root=bpy.data.objects.get('Cinematic VFX | rotating blue-white weapon core')
if core_root:
 for child in list(core_root.children_recursive): bpy.data.objects.remove(child,do_unlink=True)
 bpy.data.objects.remove(core_root,do_unlink=True)
gun=bpy.data.objects.get('Approved M-47 | cinematic mount only')
energy=bpy.data.materials.get('M-47 plasma | blue cyan emission')
metal=bpy.data.materials.get('Parkerized forged steel')
if gun and energy and metal: cin.weapon_core_ornament((-2.25,.12,1.35),gun,energy,metal)
# Adjust the actual baked Mantaflow material fields for a cool flight wake and warm breach dust.
for name,color,keys in [
 ('Volumetric simulation | blue-grey projectile smoke',None,((72,.24),(91,.34),(104,.25),(116,.20))),
 ('Volumetric simulation | warm concrete dust',(0.56,.32,.18),((136,.30),(150,.72),(171,1.0),(188,.40),(192,.25))),
]:
 domain=bpy.data.objects.get(name)
 if not domain: continue
 material=next((m for m in domain.data.materials if m and m.use_nodes),None)
 if not material: continue
 volume=next((n for n in material.node_tree.nodes if n.type=='PRINCIPLED_VOLUME'),None)
 if volume and color: volume.inputs['Color'].default_value=(*color,1.0)
 density=next((n for n in material.node_tree.nodes if n.type=='MATH' and n.operation=='MULTIPLY'),None)
 if density:
  socket=density.inputs[1]
  for frame,value in keys:
   socket.default_value=value
   socket.keyframe_insert(data_path='default_value',frame=frame,group='Cinematic volume density')
bpy.ops.wm.save_as_mainfile(filepath=str(cin.BLEND_DIR/'M47_Photoreal_Cinematic_5_0.blend'))
print('[M47-CIN5] FINAL SCENE SAVED',flush=True)
