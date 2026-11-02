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
# Preserve enemy object geometry/materials as imported. Keep an untouched copy of mesh data in memory.
bpy.ops.import_scene.gltf(filepath=SRC_PLAYER)
player_arm=next((o for o in bpy.context.scene.objects if o.type=='ARMATURE' and len(o.data.bones)==28),None)
player_mesh=next((o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.vertices)>10000 and len(o.vertex_groups)>=28),None)
if player_arm is None or player_mesh is None: raise RuntimeError('Could not find existing 28-bone armature and skinned mesh')
if len(player_arm.data.bones)!=28: raise RuntimeError('Unexpected rig bone count')
# Reuse only armature data; hide and remove all visible player geometry and its scene nodes.
arm_data=player_arm.data.copy(); arm_data.name='Assault_Mixamo28'
for ob in list(bpy.context.scene.objects):
    if ob is not enemy and ob is not player_mesh:
        bpy.data.objects.remove(ob,do_unlink=True)
player_mesh.hide_viewport=True; player_mesh.hide_render=True
arm=bpy.data.objects.new('target_character',arm_data); bpy.context.collection.objects.link(arm)
# Build a KD tree from the player skin, with coordinates remapped to the enemy dimensions.
# The source skeleton spans Z=0..1.70m. Enemy feet/head span approximately -0.95..0.95m.
verts=player_mesh.data.vertices
bounds=[(min(v.co[i] for v in enemy.data.vertices),max(v.co[i] for v in enemy.data.vertices)) for i in range(3)]
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
# Map source group names to armature groups by exact name; retain only groups backed by the 28-bone rig.
valid={b.name for b in arm.data.bones}
source_groups={g.name:g.index for g in player_mesh.vertex_groups if g.name in valid}
group_names=list(source_groups)
if len(group_names)<20: raise RuntimeError(f'Only {len(group_names)} matching bone groups found')
groups={n:enemy.vertex_groups.new(name=n) for n in group_names}
# Nearest-surface transfer: cache source vertex influences once, then bulk-assign by bone.
idx_to_name={g.index:g.name for g in player_mesh.vertex_groups if g.name in valid}
source_weights=[]
for sv in verts:
    source_weights.append([(idx_to_name[g.group],g.weight) for g in sv.groups if g.group in idx_to_name and g.weight>0.001])
assigned={name:[[] for _ in range(33)] for name in group_names}
for vi,v in enumerate(enemy.data.vertices):
    _co,idx,_dist=tree.find(proxy(v))
    ws=source_weights[idx]
    total=sum(w for _,w in ws)
    if total<=0: continue
    for name,w in ws:
        qw=max(1,min(32,round(w/total*32)))
        assigned[name][qw].append(vi)
for name,bins in assigned.items():
    for qw,indices in enumerate(bins):
        if indices: groups[name].add(indices,qw/32.0,'REPLACE')
# Attach original enemy mesh to the copied rig; no player mesh/materials are included.
mod=enemy.modifiers.new('Assault_28Bone_Skin','ARMATURE'); mod.object=arm; mod.use_vertex_groups=True
enemy.parent=arm
enemy.name='Assault_Body_Meshy'
# Enemy GLB is centered at origin; Mixamo rig is foot-rooted. Lift body so soles align at z=0.
enemy.location=(0.0,0.0,-float(e_lo[2]))
arm.location=(0,0,0)
# Use original textures/materials from enemy mesh; export only assault armature and body.
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); enemy.select_set(True); bpy.context.view_layer.objects.active=arm
os.makedirs(os.path.dirname(OUT),exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',use_selection=True,export_apply=False,export_animations=False,export_skins=True,export_materials='EXPORT',export_image_format='AUTO')
# Blender-side validation and machine-readable report.
report={'source':SRC_ENEMY,'player_rig_source':SRC_PLAYER,'output':OUT,'bones':len(arm.data.bones),'bone_names':[b.name for b in arm.data.bones],'mesh_vertices':len(enemy.data.vertices),'mesh_triangles':sum(len(p.vertices)-2 for p in enemy.data.polygons),'vertex_groups':len(enemy.vertex_groups),'weight_vertices':sum(1 for v in enemy.data.vertices if v.groups),'textures':[{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.source=='FILE'],'enemy_bounds':[[float(x) for x in pair] for pair in bounds],'proxy_scales':[float(x) for x in scales]}
with open(os.path.splitext(OUT)[0]+'.json','w') as f: json.dump(report,f,indent=2)
print('ASSAULT_RIG_REPORT='+json.dumps(report))
