"""Create the versioned Airfield HQ 2.1 source from the preserved 2.0 asset.

Uses licensed, 2K Poly Haven PBR maps and adds architectural details while
keeping the existing gameplay geometry, node contracts and animations intact.
Run: Blender 4.5.15 --background --python tools/airfield_hq/refine_airfield_hq_v21.py
"""
import bpy, os, json, math, shutil
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
IN=os.path.join(ROOT,'assets/airfield_hq/high_quality/Bloedjungle_Airfield_HQ_Source.blend')
OUT=os.path.join(ROOT,'assets/airfield_hq_v21/high_quality')
TEX=os.path.join(ROOT,'source_assets/airfield_hq/polyhaven')
os.makedirs(OUT,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=IN)
scene=bpy.context.scene
scene['ASSET_ID']='bloedjungle_airfield_hq_21'
scene['ASSET_NAME']='Bloedjungle Airfield HQ 2.1'
scene['SOURCE_STANDARD']='Bunker HQ Replacement + Airfield HQ 2.1 four visual references'

def img(filename, noncolor=False):
    path=os.path.join(TEX,filename)
    if not os.path.isfile(path): raise FileNotFoundError(path)
    image=bpy.data.images.load(path,check_existing=True)
    image.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    return image

def connect_pbr(mat, prefix, tint=None, roughness_floor=None, uv_scale=2.0):
    nt=mat.node_tree; bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
    for node in list(nt.nodes):
        if node not in (bs,output):nt.nodes.remove(node)
    uv=next((n for n in nt.nodes if n.type=='TEX_COORD'),None)
    if uv is None: uv=nt.nodes.new('ShaderNodeTexCoord')
    mapping=next((n for n in nt.nodes if n.type=='MAPPING'),None)
    if mapping is None:
        mapping=nt.nodes.new('ShaderNodeMapping'); nt.links.new(uv.outputs['UV'],mapping.inputs['Vector'])
    mapping.inputs['Scale'].default_value=(uv_scale,uv_scale,uv_scale)  # UVs are quarter-scale; 2 maps them to real-world 2 m sources.
    def tex(suffix, name, noncolor=False):
        node=nt.nodes.new('ShaderNodeTexImage');node.image=img(f'{prefix}_{suffix}_2k.jpg',noncolor);node.label=f'Poly Haven CC0 · {name} · 2K';node.location=(-620,200 if suffix=='diff' else (-80 if suffix=='nor_gl' else -360));node.interpolation='Linear';nt.links.new(mapping.outputs['Vector'],node.inputs['Vector']);return node
    diffuse=tex('diff','photographic surface')
    normal=tex('nor_gl','OpenGL tangent normal',True)
    arm=tex('arm','AO / roughness / metallic',True)
    if tint:
        mult=nt.nodes.new('ShaderNodeMixRGB');mult.blend_type='MULTIPLY';mult.inputs[0].default_value=1.0;mult.inputs[2].default_value=(*tint,1);mult.location=(-100,260);nt.links.new(diffuse.outputs['Color'],mult.inputs[1]);color_out=mult.outputs['Color']
    else: color_out=diffuse.outputs['Color']
    separate=nt.nodes.new('ShaderNodeSeparateColor');separate.mode='RGB';separate.location=(-100,-320);nt.links.new(arm.outputs['Color'],separate.inputs['Color'])
    nt.links.new(separate.outputs['Green'],bs.inputs['Roughness']);nt.links.new(separate.outputs['Blue'],bs.inputs['Metallic'])
    ao=nt.nodes.new('ShaderNodeMixRGB');ao.blend_type='MULTIPLY';ao.inputs[0].default_value=.35;ao.location=(100,230);nt.links.new(color_out,ao.inputs[1]);nt.links.new(separate.outputs['Red'],ao.inputs[2]);nt.links.new(ao.outputs['Color'],bs.inputs['Base Color'])
    nm=nt.nodes.new('ShaderNodeNormalMap');nm.location=(-100,-90);nm.inputs['Strength'].default_value=.65;nt.links.new(normal.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    bs.inputs['Metallic'].default_value=0.0 if prefix!='corrugated_iron_02' else .0 # map controls dielectric/metal response.
    mat['PBR_source']='Poly Haven CC0 2K maps: '+prefix
    mat['PBR_texture_resolution']='2048x2048'
    mat['PBR_texture_files']=json.dumps({k:os.path.relpath(os.path.join(TEX,f'{prefix}_{s}_2k.jpg'),ROOT) for k,s in [('BaseColor','diff'),('Normal','nor_gl'),('ORM','arm')]})

connect_pbr(bpy.data.materials['USAAF olive drab painted steel'],'corrugated_iron_02',(.53,.62,.43))
connect_pbr(bpy.data.materials['Weathered galvanized steel'],'corrugated_iron_02')
connect_pbr(bpy.data.materials['Aged airfield concrete'],'concrete_floor_01',(.76,.74,.67))
connect_pbr(bpy.data.materials['Runway concrete oil and tire wear'],'concrete_floor_01',(.63,.64,.61))
connect_pbr(bpy.data.materials['Compacted wet earth'],'dirt',(.80,.73,.58))

# Keep source maps relocatable with the Blender project and record CC0 origins.
for image in bpy.data.images:
    if image.source=='FILE' and image.filepath:
        path=bpy.path.abspath(image.filepath)
        if path.startswith(TEX+os.sep): image.filepath='//'+os.path.relpath(path,OUT)
# Separate textured floor material for the hangar interior. The old concrete
# remains as apron material; this distinct surface is confined to the hangar.
base=bpy.data.materials['Aged airfield concrete']
floor=base.copy();floor.name='Hangar Interior Pitted Concrete';connect_pbr(floor,'hangar_concrete_floor',(.74,.71,.63))
for ob in bpy.data.objects:
    if ob.name=='Continuous hangar reinforced concrete floor':
        ob.data.materials.clear();ob.data.materials.append(floor)

# Modular edge-of-bay maintenance furnishings. The centreline stays clear for
# the future licensed aircraft asset; these benches, cabinets, drums and parts
# are real low-poly meshes rather than painted-on silhouettes.
def collection(name):
    c=bpy.data.collections.get(name)
    if c is None:c=bpy.data.collections.new(name);scene.collection.children.link(c)
    return c
HC=collection('07_Hangar_Service_Props')
dark=bpy.data.materials['Deep shadowed structural steel'];steel=bpy.data.materials['Weathered galvanized steel']
toolpaint=bpy.data.materials.get('USAAF olive drab painted steel')
def hcube(name,loc,scale,mat,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    for c in list(o.users_collection):c.objects.unlink(o)
    HC.objects.link(o)
    if bevel:m=o.modifiers.new('Worn rounded metal edges','BEVEL');m.width=bevel;m.segments=2;o.modifiers.new('Workshop weighted normals','WEIGHTED_NORMAL')
    return o
def hbar(name,a,b,r,mat):
    a=Vector(a);b=Vector(b);delta=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=delta.length,location=(a+b)/2);o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=delta.to_track_quat('Z','Y');o.data.materials.append(mat)
    for c in list(o.users_collection):c.objects.unlink(o)
    HC.objects.link(o);return o
for side in (-1,1):
    x=side*13.5
    # Heavy maintenance bench, cross-braced legs, top, drawers and vise.
    hcube('Maintenance bench butcher-block top',(x,-5,.98),(3.5,1.25,.20),floor,.07)
    for dx in (-1.48,1.48):
        for dy in (-.45,.45):
            hcube('Bench steel leg',(x+dx,-5+dy,.48),(.12,.12,.86),dark,.018)
        hbar('Bench diagonal brace',(x+dx,-5-.42,.18),(x+dx,-5+.42,.72),.035,steel)
    hcube('Bench drawer bank',(x,-5, .76),(1.4,.88,.30),toolpaint,.035)
    for dx in (-.45,0,.45):
        hcube('Steel drawer pull',(x+dx,-5-.455,.77),(.20,.04,.035),steel,.012)
    hcube('Bench vise base',(x-1.2,-5,.13),(.42,.32,.12),dark,.02)
    hcube('Bench vise jaw',(x-1.2,-5,.28),(.42,.13,.15),steel,.025)
    # Two-height parts rack and stacked aircraft-maintenance crates.
    for dx in (-1.8,1.8):
        hcube('Parts shelf upright',(x+dx,6,1.35),(.10,.12,2.5),dark,.012)
    for z in (.35,1.35,2.35):
        hcube('Steel parts shelf',(x,6,z),(3.7,.62,.10),steel,.02)
    for iy in (-.2,.12):
        for dx in (-1.1,0,1.1):
            hcube('Wartime aircraft parts crate',(x+dx,6+iy,.64),( .78,.48,.48),toolpaint,.025)
    # Fuel drums have rolled rims and two raised hoops.
    for dx,yy in ((-1.7,-11),(-.5,-11)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.38,depth=.96,location=(x+dx,yy,.50));dr=bpy.context.object;dr.name='Riveted 55-gallon fuel drum';dr.data.materials.append(toolpaint)
        for c in list(dr.users_collection):c.objects.unlink(dr)
        HC.objects.link(dr)
        for z in (.13,.85):
            bpy.ops.mesh.primitive_torus_add(major_radius=.382,minor_radius=.025,major_segments=24,minor_segments=6,location=(x+dx,yy,z));rim=bpy.context.object;rim.name='Fuel drum rolled seam';rim.data.materials.append(steel)
            for c in list(rim.users_collection):c.objects.unlink(rim)
            HC.objects.link(rim)
# Practical overhead incandescent fixtures make the opened service bay legible
# in the real-time preview. Six non-shadowing punctual lamps are included only
# in LOD0; their period housings remain ordinary geometry in all LODs.
for x in (-12,0,12):
    for y in (-9,7):
        light_data=bpy.data.lights.new('Wartime hangar incandescent lamp','POINT');light_data.energy=6000;light_data.shadow_soft_size=.45
        lamp=bpy.data.objects.new('Wartime hangar incandescent point light',light_data);lamp.location=(x,y,11.35);HC.objects.link(lamp)

# Tower masonry. Replace the formerly solid lower service block with masonry
# piers and lintel/sill bands around actual openings; the 2.0 cube had only
# glass-like overlays and read as opaque when viewed from oblique angles.
base=bpy.data.materials['Aged airfield concrete']
for ob in bpy.data.objects:
    if ob.name=='Tower service block':
        bpy.data.objects.remove(ob,do_unlink=True)
glass=bpy.data.materials['Smoky wartime tower glass']
glass.diffuse_color=(.19,.25,.25,.42)
glass.use_nodes=True
gbs=glass.node_tree.nodes.get('Principled BSDF')
gbs.inputs['Base Color'].default_value=(.30,.40,.40,1)
gbs.inputs['Roughness'].default_value=.19
gbs.inputs['Metallic'].default_value=.08
gbs.inputs['Transmission Weight'].default_value=.65
gbs.inputs['IOR'].default_value=1.46
gbs.inputs['Alpha'].default_value=.42
if hasattr(glass,'surface_render_method'): glass.surface_render_method='DITHERED'
glass['transparency']='Smoky single-glazed wartime cab glazing'

# The blinking bulb mesh includes 12/16-sided cylinder caps. Fan-triangulate
# its polygons while carrying UVs, material indices and both morph shapes so
# tangent generation stays deterministic in glTF engines.
def triangulate_morph_object(obj):
    old=obj.data;old_keys=old.shape_keys
    if not old_keys:return
    source_shapes=[(kb.name,[v.co.copy() for v in kb.data],kb.slider_min,kb.slider_max) for kb in old_keys.key_blocks]
    source_action=old_keys.animation_data.action if old_keys.animation_data else None
    source_slot=old_keys.animation_data.action_slot if old_keys.animation_data else None
    verts=[];faces=[];uv_sets={layer.name:[] for layer in old.uv_layers};mat_indices=[]
    for poly in old.polygons:
        loops=list(poly.loop_indices);indices=[old.loops[li].vertex_index for li in loops]
        uv_by_vertex={old.loops[li].vertex_index:{layer.name:layer.data[li].uv.copy() for layer in old.uv_layers} for li in loops}
        for i in range(1,len(indices)-1):
            tri=(indices[0],indices[i],indices[i+1]);face=[]
            for vi in tri:face.append(len(verts));verts.append(old.vertices[vi].co.copy())
            faces.append(tuple(face));mat_indices.append(poly.material_index)
            for v in tri:
                for layer in old.uv_layers:uv_sets[layer.name].append(uv_by_vertex[v][layer.name])
    mesh=bpy.data.meshes.new(old.name+'_triangulated');mesh.from_pydata(verts,[],faces);mesh.update()
    for material in old.materials:mesh.materials.append(material)
    for poly,index in zip(mesh.polygons,mat_indices):poly.material_index=index
    for name,coords in uv_sets.items():
        layer=mesh.uv_layers.new(name=name)
        for datum,coord in zip(layer.data,coords):datum.uv=coord
    obj.data=mesh
    for name,coords,lo,hi in source_shapes:
        kb=obj.shape_key_add(name=name);kb.slider_min=lo;kb.slider_max=hi
        for datum,coord in zip(kb.data,coords):datum.co=coord
    if source_action:
        mesh.shape_keys.animation_data_create();mesh.shape_keys.animation_data.action=source_action
        if source_slot:mesh.shape_keys.animation_data.action_slot=source_slot
    mesh.update()
blink=bpy.data.objects.get('Blinking red runway and tower markers')
if blink:triangulate_morph_object(blink)

# Useful tower details: lower-floor windows with lintels/sills, electrical
# service equipment, exterior pipework, stair rails, landings and radio aerials.
TC=collection('03_Control_Tower');steel=bpy.data.materials['Weathered galvanized steel'];dark=bpy.data.materials['Deep shadowed structural steel'];concrete=bpy.data.materials['Aged airfield concrete'];olive=bpy.data.materials['USAAF olive drab painted steel'];glass=bpy.data.materials['Smoky wartime tower glass']
def cube(name,loc,scale,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    for c in list(o.users_collection):c.objects.unlink(o)
    TC.objects.link(o)
    if bevel: m=o.modifiers.new('Cast and weathered edge radius','BEVEL');m.width=bevel;m.segments=2;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o
def beam(name,a,b,width,mat,roundbar=False):
    a=Vector(a);b=Vector(b);d=b-a
    if roundbar:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=width/2,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    else:
        o=cube(name,(a+b)/2,(width,width,d.length),mat,min(width*.1,.02));o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    o.name=name
    if roundbar:o.data.materials.append(mat)
    for c in list(o.users_collection):c.objects.unlink(o)
    TC.objects.link(o);return o
tx,ty=72,20
# Four façades, each with three recessed 1.35 x 1.5 m service-room windows.
# The openings are true voids between wall sections, with fitted frames and
# cross bars; they let daylight and the interior control room read through.
for face in ('west','east','north','south'):
    width_axis='y' if face in ('west','east') else 'x'
    sign=-1 if face in ('west','south') else 1
    thickness=.42; wall_offset=sign*4.49
    for lo,hi,z0,z1 in [(-4.7,-3.75,.35,9.65),(3.75,4.7,.35,9.65),
                        (-3.75,-.675,.35,3.05),(.675,3.75,.35,3.05),
                        (-3.75,-.675,4.55,9.65),(.675,3.75,4.55,9.65),
                        (-.675,.675,.35,3.05),(-.675,.675,4.55,9.65)]:
        if width_axis=='y':
            loc=(tx+wall_offset,ty+(lo+hi)/2,(z0+z1)/2); dims=(thickness,hi-lo,z1-z0)
        else:
            loc=(tx+(lo+hi)/2,ty+wall_offset,(z0+z1)/2); dims=(hi-lo,thickness,z1-z0)
        cube(f'Tower {face} masonry around window openings',loc,dims,base,.04)
    for coord in (-3,0,3):
        if width_axis=='y': c=(tx+wall_offset,ty+coord,3.8);dims=(.08,1.35,1.5)
        else:c=(tx+coord,ty+wall_offset,3.8);dims=(1.35,.08,1.5)
        cube(f'Tower {face} recessed window glass',c,dims,glass,.012)
        # Concrete sill, lintel and steel muntins fitted in the opening plane.
        if width_axis=='y':
            cube('Tower window stone sill',(c[0],c[1],3.0),(.62,1.62,.18),concrete,.025)
            cube('Tower window stone lintel',(c[0],c[1],4.61),(.55,1.55,.18),concrete,.025)
            beam('Tower window vertical mullion',(c[0]-.06,c[1],3.08),(c[0]-.06,c[1],4.52),.045,dark)
            beam('Tower window crossbar',(c[0]-.06,c[1]-.65,3.8),(c[0]-.06,c[1]+.65,3.8),.045,dark)
        else:
            cube('Tower window stone sill',(c[0],c[1],3.0),(1.62,.62,.18),concrete,.025)
            cube('Tower window stone lintel',(c[0],c[1],4.61),(1.55,.55,.18),concrete,.025)
            beam('Tower window vertical mullion',(c[0],c[1]-.06,3.08),(c[0],c[1]-.06,4.52),.045,dark)
            beam('Tower window crossbar',(c[0]-.65,c[1]-.06,3.8),(c[0]+.65,c[1]-.06,3.8),.045,dark)
for run in range(4):
    z0=1+run*2.05;x0=tx+(-1 if run%2==0 else 1)*5.5;x1=x0+(3.7 if run%2==0 else -3.7);z1=z0+1.62
    for yoff in (-.78,.78):
        beam('Tower exterior stair handrail',(x0,ty-5.45+yoff,z0+.88),(x1,ty-5.45+yoff,z1+.88),.065,steel,True)
        beam('Tower stair lower guardrail',(x0,ty-5.45+yoff,z0+.42),(x1,ty-5.45+yoff,z1+.42),.05,dark,True)
        for k in range(6):
            t=k/5;xx=x0+(x1-x0)*t;zz=z0+.65+(z1-z0)*t
            beam('Stair guardrail upright',(xx,ty-5.45+yoff,zz-.18),(xx,ty-5.45+yoff,zz+.40),.05,steel,True)
    cube('Tower stair intermediate steel landing',((x0+x1)/2,ty-5.45,z1),(2.1,2.0,.14),steel,.035)
# Pipe runs and armored junction cabinet at building corners.
for sx in (-1,1):
    beam('Tower rainwater pipe',(tx+sx*4.82,ty-3.9,8.8),(tx+sx*4.82,ty-3.9,.6),.13,steel,True)
    for z in (1.1,3.2,5.3,7.4):beam('Rainpipe wall anchor',(tx+sx*4.7,ty-3.9,z),(tx+sx*4.95,ty-3.9,z),.08,dark)
cube('Tower electrical junction cabinet',(tx+4.92,ty+1.9,2.1),(.28,1.25,1.6),olive,.06)
for z in (1.5,1.85,2.2,2.55,2.9):beam('Tower visible conduit',(tx+5.08,ty+1.2,z),(tx+5.08,ty+5.2,z),.035,steel,True)
# Cab roof guardrails/aerial stays and roof access ladder.
for x in (tx-7.5,tx+7.5):
    for y in (ty-7.5,ty+7.5):beam('Control cab roof guardrail post',(x,y,16.05),(x,y,17.25),.08,steel,True)
for z in (16.2,17.2):
    for y in (ty-7.5,ty+7.5):beam('Roof guardrail long rail',(tx-7.5,y,z),(tx+7.5,y,z),.06,steel,True)
    for x in (tx-7.5,tx+7.5):beam('Roof guardrail side rail',(x,ty-7.5,z),(x,ty+7.5,z),.06,steel,True)
for j in range(8):
    z=15.9+j*.38;beam('Radio mast ladder rung',(tx+2.55,ty+2.55,z),(tx+3.35,ty+2.55,z),.045,steel,True)
for side in (-1,1):
    for y in (ty-8,ty+8):beam('Tower radio guy wire',(tx+3,ty+3,20.8),(tx+side*10,y,16.5),.025,dark,True)

# Add a raised apron shoulder with irregular dirt/grass margins so large slabs
# transition into field terrain rather than terminating into a black void.
green=bpy.data.materials.new('Airfield sparse grass and worn verge');green.use_nodes=True;green.diffuse_color=(.19,.22,.12,1)
connect_pbr(green,'sparse_grass',(.82,.85,.62),uv_scale=1.0)
GC=collection('09_Grass_Ver ges_and_Terrain')
def verge(name,cx,cy,w,d,seed):
    import random
    r=random.Random(seed);nx=max(8,int(w/8));ny=max(20,int(d/12));verts=[];faces=[]
    for j in range(ny+1):
        y=cy-d/2+d*j/ny
        for i in range(nx+1):
            x=cx-w/2+w*i/nx;edge=(i in (0,nx) or j in (0,ny));z=-.065+r.uniform(-.075,.045)
            if edge:z+=r.uniform(-.23,.12)
            verts.append((x,y,z))
    for j in range(ny):
        for i in range(nx):
            k=j*(nx+1)+i;faces.append((k,k+1,k+nx+2,k+nx+1))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(green);me.update();o=bpy.data.objects.new(name,me);GC.objects.link(o)
    uv=me.uv_layers.new(name='UV0_worldscale');
    for p in me.polygons:
        for li in p.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(v.x*.5,v.y*.5)
for args in [('North runway grass verge',-73,330,110,760,194401),('South runway grass verge',73,330,110,760,194402),('Taxiway west field',45,180,42,360,194403),('Apron east scrub verge',104,20,42,96,194404),('Apron west scrub verge',-104,20,42,96,194405)]:verge(*args)

scene['P47_status']='No correctly licensed, repository-available P-47 model was found; no substitute aircraft fabricated.'
scene['PBR_source_license']='Poly Haven CC0 1.0 Universal; provenance in source_assets/airfield_hq/polyhaven/ATTRIBUTION.md'
scene.render.resolution_x=1920;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.view_settings.exposure=.25
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.72
dst=os.path.join(OUT,'Bloedjungle_Airfield_HQ_2_1_Source.blend')
bpy.ops.wm.save_as_mainfile(filepath=dst)
deps=bpy.context.evaluated_depsgraph_get();tri=0;mesh_objects=[o for o in scene.objects if o.type=='MESH' and not o.name.startswith('COL_')]
for o in mesh_objects:
    ev=o.evaluated_get(deps);me=ev.to_mesh();tri+=sum(max(0,len(p.vertices)-2) for p in me.polygons);ev.to_mesh_clear()
report={'asset':'Bloedjungle Airfield HQ 2.1','source':'Preserved Airfield HQ 2.0 Blender source, refined and versioned','blender':bpy.app.version_string,'units':'metres','source_mesh_objects':len(mesh_objects),'source_evaluated_triangles':tri,'animations':['Open_Left_Door','Open_Right_Door','Blink_Red_Markers'],'external_texture_sets':['corrugated_iron_02','hangar_concrete_floor','concrete_floor_01','dirt','sparse_grass'],'texture_resolution':'2048x2048','pbr_license':'Poly Haven CC0 1.0','P47':'NOT AVAILABLE in project; no fake plane substituted','source_blend':os.path.relpath(dst,ROOT)}
with open(os.path.join(OUT,'source_metrics.json'),'w') as f:json.dump(report,f,indent=2)
print('AIRFIELD_21_SOURCE',json.dumps(report))
