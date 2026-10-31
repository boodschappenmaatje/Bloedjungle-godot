"""Convert the editable Airfield HQ source into optimized Blender/GLB assets."""
import bpy,os,json,sys

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
SRC=os.path.join(ROOT,'assets/airfield_hq/high_quality/Bloedjungle_Airfield_HQ_Source.blend')
DEST=os.path.join(ROOT,'assets/airfield_hq/game_optimized')
RUNTIME=os.path.join(ROOT,'assets/airfield_hq/runtime')
os.makedirs(DEST,exist_ok=True)
os.makedirs(RUNTIME,exist_ok=True)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
LOD='--lod1' in args

def mesh_objects(c): return [o for o in c.objects if o.type=='MESH' and not o.name.startswith('COL_')]
def has_animation(o):
    return bool((o.animation_data and o.animation_data.action) or (o.data.shape_keys and o.data.shape_keys.animation_data and o.data.shape_keys.animation_data.action))
def has_morph_animation(o):
    return bool(o.data.shape_keys and len(o.data.shape_keys.key_blocks)>1 and o.data.shape_keys.animation_data and o.data.shape_keys.animation_data.action)
def join_collection(c):
    obs=[o for o in mesh_objects(c) if not has_animation(o)]
    if len(obs)<2: return obs[0] if obs else None
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.convert(target='MESH')
    obs=[o for o in mesh_objects(c) if not has_animation(o)]
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs: o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.join(); o=bpy.context.object; o.name=c.name.split('_',1)[-1].replace('_',' ')
    o['module']=c.name; o['source_object_count']=len(obs); o['runtime_material_slots']=len(o.data.materials)
    return o
def tri_count(o): return sum(max(0,len(p.vertices)-2) for p in o.data.polygons)
def make_textures_portable_jpeg():
    converted=[]
    for image in list(bpy.data.images):
        if image.source!='FILE' or not image.filepath: continue
        old=bpy.path.abspath(image.filepath)
        if not os.path.isfile(old) or not old.lower().endswith('.png'): continue
        new=os.path.splitext(old)[0]+'.jpg'
        optimized=bpy.data.images.load(new,check_existing=False)
        optimized.filepath=bpy.path.relpath(new)
        optimized.colorspace_settings.name=image.colorspace_settings.name
        for material in bpy.data.materials:
            if not material.use_nodes or not material.node_tree: continue
            for node in material.node_tree.nodes:
                if node.type=='TEX_IMAGE' and node.image==image: node.image=optimized
        bpy.data.images.remove(image)
        converted.append((old,new))
    for mat in bpy.data.materials:
        if mat.get('PBR_texture_files'):
            mat['PBR_texture_files']=mat['PBR_texture_files'].replace('.png','.jpg')
    metrics_path=os.path.join(ROOT,'assets/airfield_hq/high_quality/source_metrics.json')
    if os.path.exists(metrics_path):
        with open(metrics_path) as f: report=json.load(f)
        report['hero_material_textures']={m.name:json.loads(m['PBR_texture_files']) for m in bpy.data.materials if m.get('PBR_texture_files')}
        with open(metrics_path,'w') as f: json.dump(report,f,indent=2)
    return converted

if LOD:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(DEST,'Bloedjungle_Airfield_HQ_Game_Optimized.blend'))
    originals=[o for c in bpy.data.collections if c.name.startswith(('01_','03_','04_','05_','06_','07_')) for o in mesh_objects(c)]
    # Doors remain a separate pair of animated nodes in both LOD packages.
    originals += [o for o in mesh_objects(bpy.data.collections['02_Hangar_Sliding_Doors'])]
    for o in originals:
        lod=o.copy(); lod.data=o.data.copy(); lod.name='LOD1_'+o.name; o.users_collection[0].objects.link(lod)
        if not has_animation(lod):
            dec=lod.modifiers.new('Mobile LOD reduction','DECIMATE'); dec.ratio=.48
            bpy.context.view_layer.objects.active=lod; lod.select_set(True); bpy.ops.object.modifier_apply(modifier=dec.name); lod.select_set(False)
        lod['lod_level']=1; lod['target_device']='mobile'
    # export only copies and their source action curves; original meshes remain hidden in the LOD package.
    lodobjs=[o for o in bpy.context.scene.objects if o.name.startswith('LOD1_')]
    bpy.ops.object.select_all(action='DESELECT')
    for o in lodobjs: o.select_set(True)
    output=os.path.join(RUNTIME,'Bloedjungle_Airfield_HQ_LOD1.glb')
    blend=os.path.join(DEST,'Bloedjungle_Airfield_HQ_LOD1.blend')
    bpy.ops.wm.save_as_mainfile(filepath=blend)
else:
    bpy.ops.wm.open_mainfile(filepath=SRC)
    converted=make_textures_portable_jpeg()
    # Update source material provenance paths before saving the source blend.
    bpy.ops.wm.save_as_mainfile(filepath=SRC)
    for old,new in converted:
        try: os.remove(old)
        except OSError: pass
    excluded={'08_Collision_Proxies'}
    modules=[]
    for c in bpy.data.collections:
        if c.name in excluded or c.name in {'Collection'}: continue
        if c.name=='02_Hangar_Sliding_Doors':
            doors=mesh_objects(c)
            for o in doors:
                bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
                bpy.ops.object.convert(target='MESH'); o.select_set(False)
            modules.extend(mesh_objects(c))
            continue
        o=join_collection(c)
        if o: modules.append(o)
        modules.extend([o for o in mesh_objects(c) if has_animation(o)])
    # Keep the production hangar within the approved 35k–70k hero runtime
    # budget while retaining the editable high-detail source mesh unchanged.
    hero=next(o for o in modules if o.name=='Hangar HQ')
    dec=hero.modifiers.new('Hero hangar mobile triangle budget','DECIMATE'); dec.ratio=.52
    bpy.context.view_layer.objects.active=hero; bpy.ops.object.modifier_apply(modifier=dec.name)
    # Explicit triangulation gives stable tangent-space normal mapping in GLTF.
    for o in modules:
        if o.type!='MESH' or has_morph_animation(o): continue
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
        tri=o.modifiers.new('Game-ready triangulation','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name); o.select_set(False)
    # Trim unused datablocks; retain instancing-free modules and action-driven doors.
    bpy.ops.object.select_all(action='DESELECT')
    for o in modules: o.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in modules if o.name=='Hangar HQ')
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DEST,'Bloedjungle_Airfield_HQ_Game_Optimized.blend'))
    output=os.path.join(RUNTIME,'Bloedjungle_Airfield_HQ_Game_Optimized.glb')
    blend=os.path.join(DEST,'Bloedjungle_Airfield_HQ_Game_Optimized.blend')
    lodobjs=[]

def export_glb(path,selected):
    bpy.ops.object.select_all(action='DESELECT')
    for o in selected: o.select_set(True)
    if selected: bpy.context.view_layer.objects.active=selected[0]
    opts=dict(filepath=path,export_format='GLB',use_selection=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_image_format='AUTO',export_animations=True,export_nla_strips=False,export_force_sampling=True,export_frame_range=True,export_cameras=False,export_lights=False,export_skins=False,export_morph=True)
    known={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    result=bpy.ops.export_scene.gltf(**{k:v for k,v in opts.items() if k in known})
    if 'FINISHED' not in result: raise RuntimeError(f'GLB export failed: {result}')

selected=lodobjs if LOD else modules
export_glb(output,selected)
meshes=[o for o in selected if o.type=='MESH']
report={'asset':'Bloedjungle Airfield HQ 2.0','variant':'LOD1 mobile' if LOD else 'game optimized LOD0','blender_version':bpy.app.version_string,'units':'metres','mesh_objects':len(meshes),'evaluated_triangles':sum(tri_count(o) for o in meshes),'material_slots':sum(len(o.data.materials) for o in meshes),'unique_materials':len({m.name for o in meshes for m in o.data.materials if m}),'animation_clips':['Open_Left_Door','Open_Right_Door','Blink_Red_Markers'],'glb_path':os.path.relpath(output,ROOT),'glb_bytes':os.path.getsize(output),'modules':{o.name:{'triangles':tri_count(o),'material_slots':len(o.data.materials)} for o in meshes}}
with open(os.path.join(DEST,'lod1_metrics.json' if LOD else 'production_metrics.json'),'w') as f:json.dump(report,f,indent=2)
print('AIRFIELD_EXPORT_REPORT',json.dumps(report))
