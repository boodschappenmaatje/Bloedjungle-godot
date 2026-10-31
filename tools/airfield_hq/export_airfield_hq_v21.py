"""Export the versioned Airfield HQ 2.1 source to mobile GLB LOD packages.

Run Blender 4.5.15 with --python this file -- [--lod 0|1|2]. LOD0 preserves
the existing door and light clips. LOD1/2 are static distance variants.
"""
import bpy,os,sys,json,math
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
SOURCE=os.path.join(ROOT,'assets/airfield_hq_v21/high_quality/Bloedjungle_Airfield_HQ_2_1_Source.blend')
GAME=os.path.join(ROOT,'assets/airfield_hq_v21/game_optimized');RUNTIME=os.path.join(ROOT,'assets/airfield_hq_v21/runtime')
os.makedirs(GAME,exist_ok=True);os.makedirs(RUNTIME,exist_ok=True)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
try: level=int(args[args.index('--lod')+1]) if '--lod' in args else 0
except: level=0
if level not in (0,1,2):raise ValueError('LOD must be 0, 1, or 2')
bpy.ops.wm.open_mainfile(filepath=SOURCE)

# Keep the 2K hero maps at LOD0, and make genuine lower-resolution mobile maps
# for the distance packages. They are downsampled from licensed 2K source maps.
if level in (0,1,2):
    from pathlib import Path
    texout=os.path.join(ROOT,'assets/airfield_hq_v21/textures',f'lod{level}');os.makedirs(texout,exist_ok=True)
    replacements={}
    for image in list(bpy.data.images):
        if image.source!='FILE':continue
        image.filepath=bpy.path.abspath(image.filepath)
        if os.path.join('source_assets','airfield_hq','polyhaven') not in image.filepath:continue
        terrain_map=any(name in image.filepath for name in ('/dirt_','/sparse_grass_'))
        if level==0 and not terrain_map:continue
        target=1024 if level==0 or level==1 else 512
        key=image.filepath
        if key not in replacements:
            smaller=image.copy();smaller.name=f'{Path(image.name).stem}_{target}';smaller.scale(target,target)
            dest=os.path.join(texout,Path(image.filepath).stem.replace('_2k',f'_{target}')+'.jpg')
            smaller.filepath_raw=dest;smaller.file_format='JPEG';smaller.save();smaller.filepath=dest
            replacements[key]=smaller
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image:
                src=bpy.path.abspath(node.image.filepath)
                if src in replacements:node.image=replacements[src]

def mesh_objects(c):return [o for o in c.objects if o.type=='MESH' and not o.name.startswith('COL_')]
def animated(o):return bool((o.animation_data and o.animation_data.action) or (o.data.shape_keys and o.data.shape_keys.animation_data and o.data.shape_keys.animation_data.action))
def tri_count(o):return sum(max(0,len(p.vertices)-2) for p in o.data.polygons)
def join_collection(c):
    obs=[o for o in mesh_objects(c) if not animated(o)]
    if len(obs)<2:return obs[0] if obs else None
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.convert(target='MESH')
    obs=[o for o in mesh_objects(c) if not animated(o)]
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object
    o.name=c.name.split('_',1)[-1].replace('_',' ');o['module']=c.name;o['source_object_count']=len(obs)
    return o

if level==0:
    modules=[]
    for c in list(bpy.data.collections):
        if c.name.startswith('08_') or c.name=='Collection':continue
        if c.name=='02_Hangar_Sliding_Doors':
            for o in mesh_objects(c):
                if not animated(o):
                    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');o.select_set(False)
            modules.extend(mesh_objects(c));continue
        merged=join_collection(c)
        if merged:modules.append(merged)
        modules.extend([o for o in mesh_objects(c) if animated(o)])
    hero=next(o for o in modules if o.get('module')=='01_Hangar_HQ' or o.name=='Hangar HQ')
    d=hero.modifiers.new('LOD0 hangar mobile geometry budget','DECIMATE');d.ratio=.52;bpy.context.view_layer.objects.active=hero;bpy.ops.object.modifier_apply(modifier=d.name)
    for o in modules:
        if o.type!='MESH' or (o.data.shape_keys and len(o.data.shape_keys.key_blocks)>1):continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        m=o.modifiers.new('Stable GLB triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=m.name);o.select_set(False)
    selected=modules+[o for o in bpy.data.collections['07_Hangar_Service_Props'].objects if o.type=='LIGHT']
    name='Bloedjungle_Airfield_HQ_2_1_LOD0'
else:
    # Rebuild independently per distance tier. Preserve high-level module
    # boundaries but merge tiny objects before the reduction to keep draw calls low.
    modules=[]
    for c in list(bpy.data.collections):
        if c.name.startswith('08_') or c.name=='Collection':continue
        if c.name=='02_Hangar_Sliding_Doors':
            # Distance copies are static and intentionally use the final open or closed pose.
            bpy.context.scene.frame_set(1)
        merged=join_collection(c)
        if merged:modules.append(merged)
        modules.extend([o for o in mesh_objects(c) if animated(o)])
    ratio=.30 if level==1 else .12
    for o in modules:
        if o.type!='MESH' or (o.data.shape_keys and len(o.data.shape_keys.key_blocks)>1):continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        d=o.modifiers.new(f'LOD{level} mobile decimation','DECIMATE');d.ratio=ratio;bpy.ops.object.modifier_apply(modifier=d.name);o['lod_level']=level;o.select_set(False)
        o.data.validate(verbose=False,clean_customdata=True)
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);tri=o.modifiers.new('Stable GLB triangulation','TRIANGULATE');bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=tri.name);o.select_set(False)
        o.data.validate(verbose=False,clean_customdata=True)
    selected=modules
    name=f'Bloedjungle_Airfield_HQ_2_1_LOD{level}'

# Remove cameras and lights; keep module objects only. Every PBR image is embedded.
bpy.ops.object.select_all(action='DESELECT')
for o in selected:o.select_set(True)
bpy.context.view_layer.objects.active=selected[0]
blend=os.path.join(GAME,name+'.blend');bpy.ops.wm.save_as_mainfile(filepath=blend)
glb=os.path.join(RUNTIME,name+'.glb')
opts=dict(filepath=glb,export_format='GLB',use_selection=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_image_format='AUTO',export_animations=(level==0),export_nla_strips=False,export_force_sampling=True,export_frame_range=True,export_cameras=False,export_lights=(level==0),export_skins=False,export_morph=True)
known={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties};r=bpy.ops.export_scene.gltf(**{k:v for k,v in opts.items() if k in known})
if 'FINISHED' not in r:raise RuntimeError('glTF export failed: '+str(r))
meshes=[o for o in selected if o.type=='MESH'];clips=['Open_Left_Door','Open_Right_Door','Blink_Red_Markers'] if level==0 else []
map_policy='2K concrete/steel hero maps; 1K dirt and grass' if level==0 else f'{1024 if level==1 else 512}px mobile maps'
report={'asset':'Bloedjungle Airfield HQ 2.1','variant':f'LOD{level}','blender':bpy.app.version_string,'units':'metres','mesh_objects':len(meshes),'triangles':sum(tri_count(o) for o in meshes),'material_slots':sum(len(o.data.materials) for o in meshes),'unique_materials':len({m.name for o in meshes for m in o.data.materials if m}),'animation_clips':clips,'glb':os.path.relpath(glb,ROOT),'bytes':os.path.getsize(glb),'texture_source':f'Poly Haven CC0 maps; {map_policy}; embedded in GLB','p47':'not available; no substitute fabricated'}
path=os.path.join(GAME,f'{name}_metrics.json')
with open(path,'w') as f:json.dump(report,f,indent=2)
print('AIRFIELD_21_GLTF_REPORT',json.dumps(report))
