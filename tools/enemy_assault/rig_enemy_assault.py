#!/usr/bin/env python3
"""Transfer the proven 28-bone Meshy Mixamo skin weights onto the Assault HQ body.
Run: blender -b --python tools/enemy_assault/rig_enemy_assault.py -- [source.glb] [output.glb]
The source GLB is read only. Weight sampling uses the 47k-vertex player skin as a spatial proxy.
"""
import bpy, sys, os, math, json, hashlib
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
SRC_ENEMY = os.path.join(ROOT,'source_assets/enemy_assault/export_Meshy_AI_2026-11-02_d5efc0.glb')
SRC_PLAYER = os.path.join(ROOT,'assets/meshy_jungle_commando.glb')
OUT = os.path.join(ROOT,'source_assets/enemy_assault/rig_test/enemy_assault_rigged_test.glb')
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if args: SRC_ENEMY=os.path.abspath(args[0])
if len(args)>1: OUT=os.path.abspath(args[1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC_ENEMY)
enemy_meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
if len(enemy_meshes)!=1: raise RuntimeError(f'Expected one enemy mesh, got {len(enemy_meshes)}')
enemy=enemy_meshes[0]
# Meshy exports this body as thousands of disconnected surface islands inside one object.
# Split them temporarily so small hard-surface equipment islands can receive one stable bone influence.
bpy.context.view_layer.objects.active=enemy; enemy.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.separate(type='LOOSE'); bpy.ops.object.mode_set(mode='OBJECT')
enemy_parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('Mesh_0')]
if len(enemy_parts)<2: raise RuntimeError('Expected disconnected Meshy body islands for component-aware binding')
enemy=max(enemy_parts,key=lambda o:len(o.data.vertices)); enemy.name='Mesh_0'
# Preserve enemy object geometry/materials as imported. Keep an untouched copy of mesh data in memory.
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.import_scene.gltf(filepath=SRC_PLAYER)
player_arm=next((o for o in bpy.context.scene.objects if o.type=='ARMATURE' and len(o.data.bones)==28),None)
player_mesh=next((o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.vertices)>10000 and len(o.vertex_groups)>=28),None)
if player_arm is None or player_mesh is None: raise RuntimeError('Could not find existing 28-bone armature and skinned mesh')
if len(player_arm.data.bones)!=28: raise RuntimeError('Unexpected rig bone count')
# Reuse only armature data; hide and remove all visible player geometry and its scene nodes.
arm_data=player_arm.data.copy(); arm_data.name='Assault_Mixamo28'
for ob in list(bpy.context.scene.objects):
    if ob not in enemy_parts and ob is not player_mesh:
        bpy.data.objects.remove(ob,do_unlink=True)
player_mesh.hide_viewport=True; player_mesh.hide_render=True
arm=bpy.data.objects.new('target_character',arm_data); bpy.context.collection.objects.link(arm)
# Build a KD tree from the player skin, with coordinates remapped to the enemy dimensions.
# The source skeleton spans Z=0..1.70m. Enemy feet/head span approximately -0.95..0.95m.
verts=player_mesh.data.vertices
bounds=[(min(v.co[i] for part in enemy_parts for v in part.data.vertices),max(v.co[i] for part in enemy_parts for v in part.data.vertices)) for i in range(3)]
e_lo=Vector([pair[0] for pair in bounds]); e_hi=Vector([pair[1] for pair in bounds])
p_bounds=[(min(v.co[i] for v in verts),max(v.co[i] for v in verts)) for i in range(3)]
# Fit proxy axes to source body bounds, and map enemy ground to player ground.
scales=[(p_bounds[i][1]-p_bounds[i][0])/max(1e-6,e_hi[i]-e_lo[i]) for i in range(3)]
# keep anatomical axis proportions rather than forcing width/depth to a single scale
scale=1.0
# Map target vertex positions into the source skin's coordinate frame, via axis-aligned body bounds.
def proxy(v):
    return Vector([p_bounds[i][0]+((v.co[i]-e_lo[i])/(e_hi[i]-e_lo[i]))*(p_bounds[i][1]-p_bounds[i][0]) for i in range(3)])
tree=KDTree(len(verts))
for i,v in enumerate(verts): tree.insert(v.co,i)
tree.balance()
# Map source group names to the existing 28-bone armature by exact name.
valid={b.name for b in arm.data.bones}
source_groups={g.name:g.index for g in player_mesh.vertex_groups if g.name in valid}
group_names=list(source_groups)
if len(group_names)<20: raise RuntimeError(f'Only {len(group_names)} matching bone groups found')
groups_by_part={part:{} for part in enemy_parts}
# Cache player influences, then transfer interpolated, normalized weights to every body vertex.
idx_to_name={g.index:g.name for g in player_mesh.vertex_groups if g.name in valid}
source_weights=[]
for sv in verts:
    source_weights.append([(idx_to_name[g.group],g.weight) for g in sv.groups if g.group in idx_to_name and g.weight>0.001])
smooth_vertices=0
weapon_hand_islands=0
weapon_parts=[]
for part in enemy_parts:
    verts_part=part.data.vertices
    center=Vector([sum(v.co[i] for v in verts_part)/len(verts_part) for i in range(3)])
    # Preview separation candidate: collect the disconnected front rifle region as a removable part set.
    if center.y < -0.22 and -0.25 < center.z < 0.16:
        weapon_parts.append(part)
        weapon_hand_islands += 1
        continue
    # Keep small disconnected straps, gloves, and armor details smoothly bound.
    # A single center-sampled rigid influence caused visible shoulder/arm islands
    # to detach when IK posed the arms.
    assigned={}
    for vi,v in enumerate(verts_part):
        neighbors=tree.find_n(proxy(v),4)
        if not neighbors: continue
        merged={}
        if neighbors[0][2] < 0.001:
            samples=[(neighbors[0][1],1.0)]
        else:
            samples=[(idx,1.0/max(dist*dist,1e-6)) for _co,idx,dist in neighbors]
        sample_total=sum(weight for _idx,weight in samples)
        for idx,sample_weight in samples:
            for name,weight in source_weights[idx]:
                merged[name]=merged.get(name,0.0)+weight*sample_weight/sample_total
        ws=sorted(((name,weight) for name,weight in merged.items() if weight > 0.015),key=lambda item:item[1],reverse=True)[:4]
        total=sum(w for _,w in ws)
        if total<=0: continue
        normalized=[(name,w/total) for name,w in ws]
        exact=[w*32.0 for _name,w in normalized]
        units=[int(math.floor(w)) for w in exact]
        remainder=32-sum(units)
        for idx in sorted(range(len(exact)),key=lambda j:exact[j]-units[j],reverse=True)[:remainder]: units[idx]+=1
        for (name,_weight),unit_weight in zip(normalized,units):
            if unit_weight <= 0: continue
            assigned.setdefault(name,[[] for _ in range(33)])[unit_weight].append(vi)
    for name,bins in assigned.items():
        group=groups_by_part[part].get(name)
        if group is None:
            group=part.vertex_groups.new(name=name)
            groups_by_part[part][name]=group
        for qw,indices in enumerate(bins):
            if indices: group.add(indices,qw/32.0,'REPLACE')
    smooth_vertices+=len(verts_part)
# Keep the source Meshy rifle as a separate rigid prop. Its geometry stays out of
# the skinned body so arm IK cannot bend the gun; both retain the source material.
if not weapon_parts: raise RuntimeError('Could not isolate the Meshy rifle components')
bpy.ops.object.select_all(action='DESELECT')
for part in weapon_parts: part.select_set(True)
bpy.context.view_layer.objects.active=weapon_parts[0]
bpy.ops.object.join()
weapon_mesh=bpy.context.view_layer.objects.active
weapon_mesh.name='Assault_Meshy_Weapon_Mesh'
weapon_root=bpy.data.objects.new('Assault_Meshy_Weapon',None)
bpy.context.collection.objects.link(weapon_root)
weapon_root.parent=arm
weapon_root.location=(0.0,0.0,-float(e_lo[2]))
weapon_mesh.parent=weapon_root
weapon_mesh.location=(0,0,0); weapon_mesh.rotation_euler=(0,0,0); weapon_mesh.scale=(1,1,1)
# These source-space anchors match the original two-hand hold and muzzle direction.
# They are kept in the GLB so the Godot adapter can use the authored Meshy weapon.
weapon_anchors={
    'Assault_RightHandGrip':(-0.015,-0.292,0.050),
    'Assault_LeftHandGrip':(0.205,-0.300,-0.090),
    'Assault_Muzzle':(0.345,-0.285,-0.220),
    'Assault_CasingEject':(0.030,-0.285,0.120),
    'Assault_Magazine':(0.105,-0.300,-0.105),
    'Assault_Sight':(0.185,-0.290,0.075),
}
anchor_objects=[]
for name,position in weapon_anchors.items():
    marker=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(marker)
    marker.parent=weapon_root
    marker.location=position
    marker.empty_display_type='SPHERE'
    marker.empty_display_size=0.025
    anchor_objects.append(marker)
# The source soldier holds this Meshy rifle in a low-ready, cross-body orientation.
# Keep the authored right-hand grip fixed, but rotate and scale the detached prop
# so the muzzle points forward along the Mixamo character's -Y facing axis. This
# preserves the chosen Meshy silhouette while making the grip, sight and muzzle
# agree with the game's forward-facing rifle fire.
right_grip_local=Vector(weapon_anchors['Assault_RightHandGrip'])
muzzle_local=Vector(weapon_anchors['Assault_Muzzle'])
weapon_axis=muzzle_local-right_grip_local
if weapon_axis.length < 1e-4: raise RuntimeError('Meshy rifle muzzle and right-hand grip overlap')
weapon_forward=Vector((0.0,-1.0,0.0))
weapon_rotation=weapon_axis.normalized().rotation_difference(weapon_forward)
weapon_scale=1.4
# Refresh parenting before reading world coordinates; Blender otherwise returns
# the just-created Empty's stale identity matrix and drops the ground offset.
bpy.context.view_layer.update()
right_grip_world=weapon_root.matrix_world @ right_grip_local
parent_world=weapon_root.parent.matrix_world.copy() if weapon_root.parent else None
right_grip_parent=parent_world.inverted() @ right_grip_world if parent_world else right_grip_world
weapon_root.rotation_mode='QUATERNION'
weapon_root.rotation_quaternion=weapon_rotation
weapon_root.scale=(weapon_scale,weapon_scale,weapon_scale)
weapon_root.location=right_grip_parent-(weapon_rotation@(right_grip_local*weapon_scale))
bpy.context.view_layer.update()
remaining_parts=[p for p in enemy_parts if p not in weapon_parts and p.name in bpy.data.objects]
bpy.ops.object.select_all(action='DESELECT')
for part in remaining_parts: part.select_set(True)
bpy.context.view_layer.objects.active=enemy
bpy.ops.object.join()
enemy=bpy.context.view_layer.objects.active
enemy.name='Assault_Body_Meshy'
# Attach original enemy mesh to the copied rig; no player mesh/materials are included.
mod=enemy.modifiers.new('Assault_28Bone_Skin','ARMATURE'); mod.object=arm; mod.use_vertex_groups=True
enemy.parent=arm
enemy.name='Assault_Body_Meshy'
# Enemy GLB is centered at origin; Mixamo rig is foot-rooted. Lift body so soles align at z=0.
enemy.location=(0.0,0.0,-float(e_lo[2]))
arm.location=(0,0,0)
# Use the same source material/textures for both body and separate weapon.
bpy.ops.object.select_all(action='DESELECT')
for ob in [arm,enemy,weapon_root,weapon_mesh]+anchor_objects: ob.select_set(True)
bpy.context.view_layer.objects.active=arm
os.makedirs(os.path.dirname(OUT),exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=True,export_apply=False,export_animations=False,export_skins=True,export_materials='EXPORT',export_image_format='AUTO')
# Blender-side validation and machine-readable report.
report={'source':SRC_ENEMY,'player_rig_source':SRC_PLAYER,'output':OUT,'bones':len(arm.data.bones),'bone_names':[b.name for b in arm.data.bones],'mesh_vertices':len(enemy.data.vertices),'mesh_triangles':sum(len(p.vertices)-2 for p in enemy.data.polygons),'weapon_vertices':len(weapon_mesh.data.vertices),'weapon_triangles':sum(len(p.vertices)-2 for p in weapon_mesh.data.polygons),'weapon_anchors':weapon_anchors,'weapon_forward_local':[float(x) for x in weapon_forward],'weapon_scale':weapon_scale,'weapon_right_grip_world_before':[float(x) for x in right_grip_world],'weapon_rotation_quaternion':[float(x) for x in weapon_rotation],'vertex_groups':len(enemy.vertex_groups),'weight_vertices':sum(1 for v in enemy.data.vertices if v.groups),'textures':[{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.source=='FILE'],'enemy_bounds':[[float(x) for x in pair] for pair in bounds],'proxy_scales':[float(x) for x in scales],'source_islands':len(enemy_parts),'smooth_weight_vertices':smooth_vertices,'weapon_islands_extracted':weapon_hand_islands}
with open(os.path.splitext(OUT)[0]+'.json','w') as f: json.dump(report,f,indent=2)
print('ASSAULT_RIG_REPORT='+json.dumps(report))
