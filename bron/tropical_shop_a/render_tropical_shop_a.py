"""Render review views from the saved Blender source with temporary cutaways."""
import bpy, bmesh, os
from mathutils import Vector
HERE=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.abspath(os.path.join(HERE,'../..'))
blend=os.path.join(HERE,'Tropical_Shop_A.blend')
out=os.path.join(HERE,'previews'); os.makedirs(out,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
s=bpy.context.scene
s.render.engine='BLENDER_EEVEE_NEXT'; s.eevee.taa_render_samples=8
s.render.resolution_x=800; s.render.resolution_y=600; s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG'; s.view_settings.view_transform='AgX'
s.world=bpy.data.worlds.new('Tropical daylight review'); s.world.color=(.19,.22,.19)

def look(cam,target): cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
def setup_scene():
 bpy.ops.mesh.primitive_plane_add(size=70,location=(0,0,-.04)); ground=bpy.context.object; ground.name='Render ground'; ground.data.materials.append(bpy.data.materials.get('Damp stone ground'))
 bpy.ops.object.light_add(type='AREA',location=(-8,-10,18)); key=bpy.context.object;key.data.energy=3200;key.data.shape='DISK';key.data.size=12;look(key,(0,0,4))
 bpy.ops.object.light_add(type='AREA',location=(8,8,11)); fill=bpy.context.object;fill.data.energy=1300;fill.data.size=10;look(fill,(0,0,5))
def camera(pos,target,scale):
 bpy.ops.object.camera_add(location=pos);cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=scale;look(cam,target);s.camera=cam;return cam
def render(name,cam):s.camera=cam;s.render.filepath=os.path.join(out,name+'.png');bpy.ops.render.render(write_still=True)
def wall_cut(obj_names, zmin=-999,zmax=999):
 for name in obj_names:
  o=bpy.data.objects.get(name)
  if not o:continue
  bm=bmesh.new();bm.from_mesh(o.data);fs=[]
  for f in bm.faces:
   c=o.matrix_world@f.calc_center_median()
   if -4.85<c.x<4.85 and -4.52<c.y<-3.98 and zmin<=c.z<=zmax:fs.append(f)
  bmesh.ops.delete(bm,geom=fs,context='FACES');bm.to_mesh(o.data);bm.free();o.data.update()
def z_cut(names,low=-999,high=999,keep_above=True):
 for name in names:
  o=bpy.data.objects.get(name)
  if not o:continue
  bm=bmesh.new();bm.from_mesh(o.data);fs=[]
  for f in bm.faces:
   z=(o.matrix_world@f.calc_center_median()).z
   if (z<low or z>high):fs.append(f)
  bmesh.ops.delete(bm,geom=fs,context='FACES');bm.to_mesh(o.data);bm.free();o.data.update()
setup_scene()
cam=camera((15,-21,14),(0,0,5),19);render('01_street_exterior',cam)
cam.location=(-15,21,12);look(cam,(0,0,5));render('02_rear_exterior',cam)
cam.location=(0,-.3,28);cam.data.ortho_scale=18;look(cam,(0,0,5));render('03_build_camera_roof',cam)
# Ground floor only: remove the second storey modules and expose a full front cutaway.
for n in ('Roof_Meshy','Upper_Floor','Exterior_Walls_Upper','Exterior_Details_Upper','Interior_Walls_Upper','Residence_Furniture','Accessible_Balcony'):
 if bpy.data.objects.get(n):bpy.data.objects[n].hide_render=True
wall_cut(('Exterior_Walls_Ground',),.2,3.45)
cam.location=(0,-19,5.3);cam.data.ortho_scale=13;look(cam,(0,0,1.8));render('04_ground_floor_open',cam)
# Reopen clean file for the upper floor-only camera.
bpy.ops.wm.open_mainfile(filepath=blend);s=bpy.context.scene;s.render.engine='BLENDER_EEVEE_NEXT';s.eevee.taa_render_samples=8;s.render.resolution_x=800;s.render.resolution_y=600;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX';s.world=bpy.data.worlds.new('Tropical daylight review');s.world.color=(.19,.22,.19);setup_scene()
for n in ('Roof_Meshy','Ground_Floor','Exterior_Walls_Ground','Exterior_Details_Ground','Interior_Walls_Ground','Shop_Furniture','Walkable_Staircase'):
 if bpy.data.objects.get(n):bpy.data.objects[n].hide_render=True
wall_cut(('Exterior_Walls_Upper',),3.4,7.0)
cam=camera((0,-19,8.3),(0,0,5.0),13);render('05_upper_floor_without_roof',cam)
# Balcony and stair inspection with the complete front elevation opened.
wall_cut(('Exterior_Walls_Upper',),3.4,7.0)
# Re-enable the balcony and stairs; open the lower shell too.
for n in ('Accessible_Balcony','Walkable_Staircase'):
 if bpy.data.objects.get(n):bpy.data.objects[n].hide_render=False
wall_cut(('Exterior_Walls_Ground',),.2,3.45)
cam.location=(13,-17,9);cam.data.ortho_scale=17;look(cam,(0,0,4.5));render('07_balcony_and_stair',cam)
# Third-person interior view with the project's actual soldier model.
bpy.ops.wm.open_mainfile(filepath=blend);s=bpy.context.scene;s.render.engine='BLENDER_EEVEE_NEXT';s.eevee.taa_render_samples=8;s.render.resolution_x=800;s.render.resolution_y=600;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX';s.world=bpy.data.worlds.new('Tropical daylight review');s.world.color=(.19,.22,.19);setup_scene()
for n in ('Roof_Meshy','Upper_Floor','Exterior_Walls_Upper','Exterior_Details_Upper','Interior_Walls_Upper','Residence_Furniture','Accessible_Balcony'):
 if bpy.data.objects.get(n):bpy.data.objects[n].hide_render=True
wall_cut(('Exterior_Walls_Ground',),.2,3.45)
# Hide only the front door assembly for this cutaway camera so the actual
# soldier GLB remains visible through the doorway; gameplay doors stay intact.
for obj in bpy.context.scene.objects:
 if obj.name.startswith('Front door '): obj.hide_render=True
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT,'assets/soldaat_vq2.glb'))
added=[o for o in bpy.context.scene.objects if o not in before]
soldier_roots=[o for o in added if o.parent not in added]
soldier_root=next((o for o in soldier_roots if o.type=='EMPTY'),None)
for soldier in soldier_roots:
 if soldier is soldier_root:
  # Place the sample soldier in the open central aisle, aligned with the front doorway.
  soldier.location=(0,-2.2,.22);soldier.rotation_euler.z=0
 else:
  soldier.hide_render=True
cam=camera((0,-6.8,1.7),(0,-2.2,1.0),1)
cam.data.type='PERSP';cam.data.lens=55
render('06_third_person_soldier_inside',cam)
# Reuse the actual model for the city editor's cached palette card.
bpy.ops.wm.open_mainfile(filepath=blend);s=bpy.context.scene
s.render.engine='BLENDER_EEVEE_NEXT';s.eevee.taa_render_samples=8
s.render.resolution_x=256;s.render.resolution_y=256;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX'
s.world=bpy.data.worlds.new('Tropical daylight palette icon');s.world.color=(.19,.22,.19)
setup_scene()
ground=bpy.data.objects.get('Render ground')
if ground: ground.hide_render=True
s.render.film_transparent=True;s.render.resolution_x=256;s.render.resolution_y=256
cam=camera((15,-21,14),(0,0,5),17)
icon_dir=os.path.join(ROOT,'assets','stad_icons');os.makedirs(icon_dir,exist_ok=True)
s.render.filepath=os.path.join(icon_dir,'tropical_shop_a.png');bpy.ops.render.render(write_still=True)
print('RENDERS',out)
