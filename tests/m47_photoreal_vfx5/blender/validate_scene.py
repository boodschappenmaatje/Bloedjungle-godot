"""Inspect saved V5 .blend data without rendering."""
import bpy, hashlib, json
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]
ROOT=Path(__file__).resolve().parents[3]
GLB=ROOT/'docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb'
scene=bpy.context.scene
names=('Idle','Equip','Aim','Fire','Reload')
actions=[]
for label in names:
 action=next((a for a in bpy.data.actions if a.name.startswith(label+'_M47_Mechanism_Rig')),None)
 if not action:
  actions.append({'name':label,'found':False}); continue
 curves=list(action.fcurves)
 points=sum(len(fc.keyframe_points) for fc in curves)
 varying=sum(1 for fc in curves if len({round(k.co.y,6) for k in fc.keyframe_points})>1)
 actions.append({'name':label,'action':action.name,'found':True,'frame_range':[float(action.frame_range[0]),float(action.frame_range[1])],
                 'fcurves':len(curves),'keyframes':points,'curves_with_motion':varying})
triangles={}
for name in ('M47_LOD0','M47_LOD1','M47_LOD2'):
 ob=bpy.data.objects.get(name)
 triangles[name]=sum(max(0,len(p.vertices)-2) for p in ob.data.polygons) if ob and ob.type=='MESH' else None
m47=[o for o in scene.objects if o.name.startswith(('M47_LOD','M47_')) and o.type=='MESH']
materials={}
for ob in m47:
 for mat in ob.data.materials:
  if not mat: continue
  nodes=mat.node_tree.nodes if mat.use_nodes else []
  image_nodes=[n for n in nodes if n.type=='TEX_IMAGE' and n.image]
  materials[mat.name]={'shader_nodes':len(nodes),'image_textures':[n.image.name for n in image_nodes],
                       'packed_images':[n.image.name for n in image_nodes if n.image.packed_file]}
volumes=[]
for name in ('Volumetric simulation | blue-grey projectile smoke','Volumetric simulation | warm concrete dust'):
 ob=bpy.data.objects.get(name)
 mod=next((m for m in ob.modifiers if m.type=='FLUID'),None) if ob else None
 ds=mod.domain_settings if mod else None
 cache=Path(bpy.path.abspath(ds.cache_directory)) if ds else None
 vdb_count=len(list(cache.rglob('*.vdb'))) if cache and cache.exists() else 0
 volumes.append({'name':name,'found':bool(ds),'cache_directory':str(cache) if cache else None,
                 'data_baked':bool(ds and ds.has_cache_baked_data),'noise_enabled':bool(ds and ds.use_noise),
                 'noise_baked':bool(ds and ds.has_cache_baked_noise),'vdb_files':vdb_count,
                 'resolution':int(ds.resolution_max) if ds else None,'noise_scale':int(ds.noise_scale) if ds else None})
def connected_components(obj):
 if not obj or obj.type!='MESH': return 0
 n=len(obj.data.vertices); parent=list(range(n)); used=set()
 def find(i):
  while parent[i]!=i:
   parent[i]=parent[parent[i]]; i=parent[i]
  return i
 for edge in obj.data.edges:
  a,b=edge.vertices; used.add(a); used.add(b)
  ra,rb=find(a),find(b)
  if ra!=rb: parent[rb]=ra
 return len({find(i) for i in used})
static_wall=bpy.data.objects.get('Rough cast concrete wall | intact outer field')
static_stones=connected_components(static_wall)
animated_stones=sum(1 for o in scene.objects if o.name.startswith('Fracture stone '))
metrics={
 'blender_version':bpy.app.version_string,'render_engine':scene.render.engine,'frame_range':[scene.frame_start,scene.frame_end],
 'fps':scene.render.fps,'duration_seconds':(scene.frame_end-scene.frame_start+1)/scene.render.fps,
 'source_glb':GLB.relative_to(ROOT).as_posix(),'source_glb_sha256':hashlib.sha256(GLB.read_bytes()).hexdigest(),
 'm47_lod_triangles':triangles,'lod0_render_visible':not bpy.data.objects['M47_LOD0'].hide_render,
 'lod1_lod2_render_hidden':all(bpy.data.objects[n].hide_render for n in ('M47_LOD1','M47_LOD2')),
 'm47_actions':actions,'m47_materials':materials,'mantaflow_domains':volumes,
 'photogrammetry_tree_instances':sum(1 for o in scene.objects if o.name.startswith('Photogrammetry jungle canopy | ')),
 'fern_patches':sum(1 for o in scene.objects if o.name.startswith('Island fern patch ')),
 'grass_clumps':sum(1 for o in scene.objects if o.name.startswith('PBR broadleaf grass clump ')),
 'leaf_litter_mesh_faces':sum(len(o.data.polygons) for o in scene.objects if o.name.startswith('Damp fallen broadleaf litter | dense scatter') and o.type=='MESH'),
 'masonry_stones':static_stones+animated_stones,'static_wall_stone_components':static_stones,
 'animated_fracture_stones':animated_stones,
 'large_concrete_debris':sum(1 for o in scene.objects if o.name.startswith('Large fractured concrete rubble ')),
 'cycles_still_settings':{'resolution':[960,540],'samples':8},
 'cycles_video_settings':{'resolution':[960,540],'fps':24,'frames':192,'samples':8,'duration_seconds':8.0},
}
(OUT/'build_metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
print('[M47-CIN5] VALIDATION',json.dumps(metrics,ensure_ascii=False),flush=True)
