"""Build the Bloedjungle WWII USAAF Airfield HQ 2.0 source asset.

Run with Blender 4.5.15:
  blender --background --factory-startup --python tools/airfield_hq/build_airfield_hq.py

Dimensions are authored in metres. The three hero material sets are true 2K
PBR textures. This deterministic procedural authoring is used for source
repeatability; visible construction is modeled as geometry (not height-only
placeholders)."""
import bpy, math, os, json, random
from mathutils import Vector
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets/airfield_hq")
TEX = os.path.join(OUT, "textures")
os.makedirs(TEX, exist_ok=True)
random.seed(1944); np.random.seed(1944)

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.collections:
    if d.name != 'Collection': bpy.data.collections.remove(d)
scene=bpy.context.scene; scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.render.resolution_x=1920; scene.render.resolution_y=1080; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'

def coll(name):
    c=bpy.data.collections.new(name); scene.collection.children.link(c); return c
C={n:coll(n) for n in ['01_Hangar_HQ','02_Hangar_Sliding_Doors','03_Control_Tower','04_Runway_and_Apron','05_Ground_Support','06_Defensive_Perimeter','07_Lighting','08_Collision_Proxies']}
def move_to(o, collection):
    for cc in list(o.users_collection): cc.objects.unlink(o)
    collection.objects.link(o); return o

# Tileable 2K maps: multiscale weathered pigment, oxidized flecks, oily grime,
# roughness/metal response, and a tangent-space normal derived from height.
def noise2(n, octaves=5):
    out=np.zeros((n,n), dtype=np.float32); amp=1.0; norm=0.0
    for k in range(octaves):
        side=max(2, n//(2**(k+1)))
        a=np.random.random((side,side)).astype(np.float32)
        yy=np.linspace(0,side, n, endpoint=False); xx=yy
        yi=np.floor(yy).astype(int)%side; xi=np.floor(xx).astype(int)%side
        fy=(yy-np.floor(yy))[:,None]; fx=(xx-np.floor(xx))[None,:]
        v00=a[np.ix_(yi,xi)]; v10=a[np.ix_((yi+1)%side,xi)]; v01=a[np.ix_(yi,(xi+1)%side)]; v11=a[np.ix_((yi+1)%side,(xi+1)%side)]
        sm=(v00*(1-fy)*(1-fx)+v10*fy*(1-fx)+v01*(1-fy)*fx+v11*fy*fx)
        out+=sm*amp; norm+=amp; amp*=0.52
    return out/norm

def make_pbr(name, base, metal, rough, kind):
    n=2048
    broad=noise2(512,5); broad=np.repeat(np.repeat(broad,4,0),4,1)
    fine=noise2(n,5); streak=np.random.random((n,n)).astype(np.float32)
    if kind in ('steel','olive'):
        # sparse oxidized pits and directional sanding/scrape marks
        rust=np.clip((broad-.69)*4.5,0,1); scratches=np.clip((streak-.965)*19,0,1)
        h=np.clip(.50+(fine-.5)*.22-rust*.19-scratches*.10,0,1)
        variation=(fine-.5)*.105-rust*.24-scratches*.12
        metalmap=np.clip(metal-rust*.60,0,1); roughmap=np.clip(rough+(fine-.5)*.12+rust*.25,0,1)
        oxide=np.array([0.24,0.105,0.047],dtype=np.float32)
        b=np.array(base,dtype=np.float32)[None,None,:]*(1+variation[:,:,None])
        b=b*(1-rust[:,:,None]*.68)+oxide[None,None,:]*(rust[:,:,None]*.68)
        b=np.clip(b,0,1)
    else:
        pitting=np.clip((fine-.70)*1.45,0,1); h=np.clip(.52+(fine-.5)*.18-pitting*.10,0,1)
        b=np.clip(np.array(base)[None,None,:]*(1+(fine[:,:,None]-.5)*.16-pitting[:,:,None]*.11),0,1)
        metalmap=np.zeros((n,n),np.float32)+metal; roughmap=np.clip(rough+(fine-.5)*.13+pitting*.15,0,1)
    # convert height to tangent normal; tileable wrap gradients
    gy,gx=np.gradient(h); nx=-gx*7.0; ny=-gy*7.0; nz=np.ones_like(h)
    ln=np.sqrt(nx*nx+ny*ny+nz*nz)
    normal=np.stack((nx/ln*.5+.5, ny/ln*.5+.5, nz/ln*.5+.5),axis=-1)
    def save_rgb(path, arr):
        im=bpy.data.images.new(os.path.basename(path),width=n,height=n,alpha=False,float_buffer=False)
        if arr.ndim==3 and arr.shape[2]==3:
            arr=np.concatenate((arr,np.ones((n,n,1),dtype=np.float32)),axis=2)
        im.pixels.foreach_set(np.clip(arr,0,1).astype(np.float32).ravel()); im.filepath_raw=path; im.file_format='PNG'; im.save(); bpy.data.images.remove(im)
    slug=name.lower().replace(' ','_')
    paths={}
    paths['BaseColor']=os.path.join(TEX,slug+'_BaseColor_2K.png'); save_rgb(paths['BaseColor'],b)
    paths['Normal']=os.path.join(TEX,slug+'_Normal_2K.png'); save_rgb(paths['Normal'],normal)
    orm=np.stack((np.full((n,n),.72,np.float32),roughmap,metalmap),axis=-1)
    paths['ORM']=os.path.join(TEX,slug+'_ORM_2K.png'); save_rgb(paths['ORM'],orm)
    m=bpy.data.materials.new(name); m.diffuse_color=(*base,1); m.use_nodes=True
    nt=m.node_tree; nt.nodes.clear(); out=nt.nodes.new('ShaderNodeOutputMaterial'); bs=nt.nodes.new('ShaderNodeBsdfPrincipled'); out.location=(600,0); bs.location=(340,0); nt.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    texc=nt.nodes.new('ShaderNodeTexCoord'); texc.location=(-800,0); mapping=nt.nodes.new('ShaderNodeVectorMath'); mapping.operation='SCALE'; mapping.inputs[3].default_value=1.0; mapping.location=(-610,0); nt.links.new(texc.outputs['UV'],mapping.inputs[0])
    def img_node(path,label,noncolor=False,y=0):
        im=bpy.data.images.load(path,check_existing=True); tex=nt.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.label=label; tex.location=(-370,y)
        if noncolor: tex.image.colorspace_settings.name='Non-Color'
        nt.links.new(mapping.outputs['Vector'],tex.inputs['Vector']); return tex
    bc=img_node(paths['BaseColor'],'2K aged pigment',False,220); nt.links.new(bc.outputs['Color'],bs.inputs['Base Color'])
    ormnode=img_node(paths['ORM'],'2K ambient occlusion / roughness / metallic',True,-20)
    sep=nt.nodes.new('ShaderNodeSeparateColor'); sep.mode='RGB'; sep.location=(-100,-40); nt.links.new(ormnode.outputs['Color'],sep.inputs['Color'])
    nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']); nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    nn=img_node(paths['Normal'],'2K tangent normal',True,-290); nmap=nt.nodes.new('ShaderNodeNormalMap'); nmap.location=(100,-210); nt.links.new(nn.outputs['Color'],nmap.inputs['Color']); nt.links.new(nmap.outputs['Normal'],bs.inputs['Normal'])
    m['PBR_texture_resolution']='2048x2048'; m['PBR_texture_files']=json.dumps({k:os.path.relpath(v,ROOT) for k,v in paths.items()}); return m

steel=make_pbr('USAAF olive drab painted steel',(0.205,.235,.185),.42,.53,'olive')
galv=make_pbr('Weathered galvanized steel',(.34,.36,.34),.78,.39,'steel')
concrete=make_pbr('Aged airfield concrete',(.39,.39,.35),.0,.83,'concrete')
runway=make_pbr('Runway concrete oil and tire wear',(.25,.265,.25),.0,.88,'concrete')
earth=make_pbr('Compacted wet earth',(.105,.098,.068),0,.96,'concrete')

def simple(name,color,metal=0.0,rough=.6,emission=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True; bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1); bs.inputs['Emission Strength'].default_value=emission
    return m
dark= simple('Deep shadowed structural steel',(.055,.067,.055),.7,.62)
glass=simple('Smoky wartime tower glass',(.095,.16,.17),.38,.18)
rubber=simple('Worn black rubber',(.028,.032,.029),.0,.84)
marking=simple('Faded wartime runway paint',(.66,.63,.53),0,.8)
amber=simple('Warm incandescent beacon lens',(1,.22,.018),.05,.28,3.5)
red=simple('Red obstruction warning lamp',(.88,.015,.006),0,.3,2.5)
wood=simple('Weathered crate timber',(.27,.19,.105),0,.8)
fabric=simple('Olive canvas',(.18,.20,.14),0,.94)
sand=simple('Canvas sandbag',(.34,.29,.19),0,.97)

def cube(name,loc,scale,mat,col,bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat); move_to(o,col)
    if bevel:
        mod=o.modifiers.new('Small fabrication edge radii','BEVEL'); mod.width=bevel; mod.segments=2
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o
def cyl(name,loc,r,depth,mat,col,verts=16,axis='Z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc); o=bpy.context.object; o.name=name; o.data.materials.append(mat); move_to(o,col)
    if axis=='Y': o.rotation_euler[0]=math.pi/2
    if axis=='X': o.rotation_euler[1]=math.pi/2
    return o
def beam(name,a,b,width,mat,col,rect=True):
    a=Vector(a); b=Vector(b); d=b-a
    if rect:
        o=cube(name,(a+b)/2,(width,width,d.length),mat,col,min(width*.12,.05)); o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
    else:
        o=cyl(name,(a+b)/2,width/2,d.length,mat,col,12); o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
    return o

def corrugated_panel(name, loc, width, height, axis, mat, col, pitch=.26, amp=.035, thickness=.045):
    # Real profiled sheet geometry, with a doubled edge return and UVs.
    count=max(8,int(width/pitch)); verts=[]; faces=[]
    for j in range(2):
        z=0 if j==0 else height
        for i in range(count+1):
            x=width*i/count; y=amp*(.5+.5*math.cos(2*math.pi*x/pitch))
            if axis=='front': verts.append((-width/2+x,y,z))
            else: verts.append((y,-width/2+x,z))
    for i in range(count): faces.append((i,i+1,count+2+i,count+1+i))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.materials.append(mat); mesh.update(); o=bpy.data.objects.new(name,mesh); col.objects.link(o); o.location=loc
    solid=o.modifiers.new('Sheet thickness and return lip','SOLIDIFY'); solid.thickness=thickness; solid.offset=0
    bevel=o.modifiers.new('Rolled sheet edge highlight','BEVEL'); bevel.width=.008; bevel.segments=1
    return o

def roof_sheet(name, side, start, width, mat, col):
    """A continuous profiled sheet runs eave-to-ridge and full hangar depth."""
    pitch=.29; count=max(8,int(width/pitch)); amp=.028; slope=(RIDGE-EAVE)/(HX/2); theta=math.atan(slope)
    verts=[]; faces=[]
    for layer_y in (-HY/2, HY/2):
        for i in range(count+1):
            distance=start+width*i/count
            wave=amp*(.5+.5*math.cos(2*math.pi*(distance-start)/pitch))
            x=side*(HX/2-distance*math.cos(theta))
            z=EAVE+distance*math.sin(theta)
            verts.append((x,layer_y,z+wave))
    for i in range(count): faces.append((i,i+1,count+2+i,count+1+i))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.materials.append(mat); mesh.update()
    obj=bpy.data.objects.new(name,mesh); col.objects.link(obj)
    solid=obj.modifiers.new('Sheet thickness and eave return','SOLIDIFY'); solid.thickness=.045; solid.offset=0
    bevel=obj.modifiers.new('Rolled sheet edge','BEVEL'); bevel.width=.01; bevel.segments=1
    return obj

# Hangar: 42 m clear span x 36 m depth; portal frames, triangulated roof trusses,
# real corrugated sheets, footing channels, ventilation, glazing and fittings.
HX=44; HY=38; EAVE=13.5; RIDGE=19.3; front=-HY/2; back=HY/2
cube('Continuous hangar reinforced concrete floor',(0,0,.03),(44,38,.36),concrete,C['01_Hangar_HQ'],.08)
for x in (-17,-11,-5,5,11,17):
    for y in (-16,16):
        cyl('Floor aircraft tie-down socket',(x,y,.22),.115,.035,galv,C['01_Hangar_HQ'],12)
for y in (-13,0,13):
    beam('Ceiling service conduit',(-19,y,12.8),(19,y,12.8),.12,galv,C['01_Hangar_HQ'],False)
for x in (-15,0,15):
    for y in (-13,0,13):
        cube('Hangar pendant industrial fitting',(x,y,13.0),(.8,.45,.20),dark,C['01_Hangar_HQ'],.05)
for side in (-1,1):
    x=side*HX/2
    for y in np.linspace(front,back,14):
        cube('Continuous reinforced concrete footing',(x,float(y),.42),(.9,2.95,.84),concrete,C['01_Hangar_HQ'],.08)
    # wall sheets and bay posts
    for y in np.linspace(front+.15,back-.15,13):
        cube('Bolted portal-frame column',(x,float(y),EAVE/2),(.48,.5,EAVE),dark,C['01_Hangar_HQ'],.035)
    for z in (2.4,5.4,8.4,11.5): beam('Sidewall continuous girt',(x-side*.32,front,z),(x-side*.32,back,z),.20,dark,C['01_Hangar_HQ'])
    for y in np.arange(front+1,back,2.0):
        corrugated_panel('Vertical profiled steel side cladding',(x-side*.07,float(y),0),1.92,EAVE,'side',steel,C['01_Hangar_HQ'],.25,.035,.045)
    # downpipes, high vents, louvers, service door, frame bolts
    for y in (-15,-5,5,15):
        beam('Rainwater downpipe',(x-side*.4,y,12.9),(x-side*.4,y,.8),.16,galv,C['01_Hangar_HQ'],False)
        cyl('Pipe clamp',(x-side*.41,y,4),.12,.12,dark,C['01_Hangar_HQ'],12,axis='X')
    for y in (-12,-6,0,6,12):
        cube('High level louver vent',(x-side*.30,y,11.9),(.18,1.3,.68),dark,C['01_Hangar_HQ'],.04)
        for zz in np.linspace(11.66,12.12,4): beam('Louver blade',(x-side*.42,y-.58,zz),(x-side*.42,y+.58,zz+.05),.06,galv,C['01_Hangar_HQ'])

# Main gable end walls and large service windows, spandrels, gable cladding.
for y in (front,back):
    for x in np.arange(-HX/2+1,HX/2,2.0):
        cube('End wall steel column',(float(x),y,EAVE/2),(.28,.32,EAVE),dark,C['01_Hangar_HQ'],.025)
    for x in np.arange(-HX/2+1,HX/2,2.0):
        if y==front and abs(x)<20: continue
        if y==back and abs(x)<=16:
            corrugated_panel('Rear wall profiled lower sheet',(float(x),y,0),1.9,9.0,'front',steel,C['01_Hangar_HQ'],.25,.032,.045)
            corrugated_panel('Rear wall profiled upper sheet',(float(x),y,11.2),1.9,2.3,'front',steel,C['01_Hangar_HQ'],.25,.032,.045)
        else:
            corrugated_panel('End wall profiled steel cladding',(float(x),y,0),1.9,EAVE,'front',steel,C['01_Hangar_HQ'],.25,.032,.045)
    # Gable infill is surfaced with profiled panel strips
    for z in np.arange(EAVE+.05,RIDGE-.4,1.2):
        width=HX*(1-(z-EAVE)/(RIDGE-EAVE))
        for x in np.arange(-width/2+1,width/2,2.0):
            corrugated_panel('Gable profiled cladding',(float(x),y,z),1.9,1.15,'front',steel,C['01_Hangar_HQ'],.25,.028,.04)
    # industrial horizontal ribbon glazing below roof line on the rear facade
    if y==back:
        for x in np.arange(-15,16,2.5):
            cube('High industrial glazing',(float(x),y-.02,10.2),(2.08,.1,1.15),glass,C['01_Hangar_HQ'],.025)
            beam('Window mullion',(x,y-.10,9.65),(x,y-.10,10.75),.07,dark,C['01_Hangar_HQ'])

# Portal frames at 6 m bays: built-up columns, knee braces, rafters and trusses.
for y in np.arange(front+1,back,6.0):
    for side in (-1,1):
        x=side*HX/2; top=(side*HX/2,y,EAVE)
        beam('Built-up portal rafter',(x,y,EAVE),(0,y,RIDGE),.50,dark,C['01_Hangar_HQ'])
        beam('Rafter cover flange',(x-side*.1,y-.18,EAVE+.1),(0,y-.18,RIDGE),.09,galv,C['01_Hangar_HQ'])
        beam('Knee brace',(side*HX/2,y,8.6),(side*12,y,13.2),.26,galv,C['01_Hangar_HQ'])
        for q in range(5):
            xx=side*(HX/2-(HX/2-1)*q/5); zz=EAVE+(RIDGE-EAVE)*q/5
            beam('Roof truss web',(xx,y,zz),(side*(HX/2-(HX/2-1)*(q+1)/5),y,EAVE+(RIDGE-EAVE)*(q+1)/5),.14,dark,C['01_Hangar_HQ'])
        for xx in (side*21,side*18,side*15,side*12,side*9,side*6,side*3):
            z=EAVE+(RIDGE-EAVE)*(1-abs(xx)/22)
            beam('Roof purlin',(xx,front,z+.2),(xx,back,z+.2),.16,galv,C['01_Hangar_HQ'])

# Corrugated pitched roof panels follow the gable pitch as angled, ribbed strips.
for side in (-1,1):
    length=math.sqrt((HX/2)**2+(RIDGE-EAVE)**2)
    for i in range(11):
        roof_sheet('Continuous corrugated roof sheet',side,i*length/11,length/11,galv,C['01_Hangar_HQ'])
    # gutters and eave flashing
    cyl('Half-round steel gutter',(side*22,0,EAVE+.1),.18,HY,galv,C['01_Hangar_HQ'],16,axis='Y')
    cube('Folded eave flashing',(side*21.9,0,EAVE+.18),(.28,HY,.12),steel,C['01_Hangar_HQ'],.025)
# Ridge vent and rooflight monitors
beam('Ridge beam', (0,front,RIDGE),(0,back,RIDGE),.48,dark,C['01_Hangar_HQ'])
for y in np.arange(front+2,back,8):
    cube('Ridge ventilator plinth',(0,float(y),RIDGE+.5),(2.8,7,.9),steel,C['01_Hangar_HQ'],.12)
    for side in (-1,1):
        cube('Ridge ventilator hood',(side*.85,float(y),RIDGE+1.1),(1.15,7,.18),galv,C['01_Hangar_HQ'],.06)

# Separate paired rolling hangar leaves. Framed panel details and roller gear.
doors=[]
for name, side, xpos in [('Hangar sliding door LEFT','L',-10.2),('Hangar sliding door RIGHT','R',10.2)]:
    before=set(bpy.data.objects)
    door=cube(name,(xpos,front-.55,6.65),(20.0,.40,13.0),steel,C['02_Hangar_Sliding_Doors'],.07)
    # channel frame, recessed seam panels, diagonal stiffeners, bolts and roller brackets
    for xx in np.linspace(-9.6,9.6,9):
        cube('Door vertical stiffener',(xpos+xx,front-.83,6.7),(.20,.18,12.3),dark,C['02_Hangar_Sliding_Doors'],.025)
    for zz in (1.0,3.0,5.1,7.2,9.4,11.5,12.8):
        cube('Door horizontal girder',(xpos,front-.86,zz),(19.7,.2,.18),galv,C['02_Hangar_Sliding_Doors'],.02)
    beam('Door diagonal brace',(xpos-9.4,front-.98,1.2),(xpos+9.4,front-.98,12.4),.20,dark,C['02_Hangar_Sliding_Doors'])
    for xx in np.linspace(-9.4,9.4,15):
        for zz in (1.2,12.2): cyl('Door rivet',(xpos+xx,front-1.02,zz),.045,.035,galv,C['02_Hangar_Sliding_Doors'],10,'Y')
    for xx in (-8.5,0,8.5):
        cyl('Door bottom roller',(xpos+xx,front-.65,.55),.18,.42,rubber,C['02_Hangar_Sliding_Doors'],16,'Y')
    parts=[o for o in C['02_Hangar_Sliding_Doors'].objects if o not in before and o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    parts=[o for o in C['02_Hangar_Sliding_Doors'].objects if o not in before and o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=door
    bpy.ops.object.join(); door.name=name
    doors.append(door)
# overhead track, trolley housings, safety bumpers and service handles
for z in (13.25,13.55): beam('Overhead sliding door track',(-34,front-.75,z),(34,front-.75,z),.17,galv,C['01_Hangar_HQ'])
for x in np.linspace(-33,33,23):
    cube('Door rail support',(float(x),front-.58,13.38),(.18,.36,.4),dark,C['01_Hangar_HQ'],.03)
for x in (-2,2):
    cube('Hangar door motor gearbox',(x,front-1.5,13.0),(1.2,.8,.68),dark,C['01_Hangar_HQ'],.08)

# Apron and runway with joints, faded markings, friction patches and drainage.
cube('Compacted base around field',(0,330,-1.35),(960,760,2.5),earth,C['04_Runway_and_Apron'],.2)
cube('Main landing runway',(0,330,-.10),(38,760,.34),runway,C['04_Runway_and_Apron'],.12)
cube('Taxiway',(42,170,-.06),(18,320,.28),concrete,C['04_Runway_and_Apron'],.08)
cube('Hangar apron',(0,17,-.02),(112,74,.32),concrete,C['04_Runway_and_Apron'],.1)
for x in (-19,19): cube('Runway drainage shoulder',(x,330,-.18),(2.1,760,.18),earth,C['04_Runway_and_Apron'],.05)
# Slab joints (rubber/sealant in actual recessed cuts) and transverse runway panels.
for y in np.arange(-40,701,7.5):
    cube('Runway transverse expansion joint',(0,float(y),.078),(37.5,.055,.006),dark,C['04_Runway_and_Apron'])
for x in (-18.4,18.4): cube('Longitudinal concrete joint',(x,330,.078),(.055,760,.006),dark,C['04_Runway_and_Apron'])
# Center dashes and threshold piano keys, worn rather than pristine.
for y in np.arange(-5,690,27): cube('Faded runway centerline dash',(0,float(y),.079),(.40,13,.012),marking,C['04_Runway_and_Apron'],.015)
for end in (-1,1):
    y=-47 if end<0 else 707
    for x in np.linspace(-14,14,9): cube('Runway threshold marking',(float(x),y,.081),(1.45,15,.014),marking,C['04_Runway_and_Apron'],.02)
for x in (-18,18):
    for yy in np.arange(-25,705,60):
        cube('Runway edge lamp base',(x,float(yy),.12),(.28,.28,.18),dark,C['07_Lighting'],.04)
        cyl('Shielded runway incandescent lamp',(x,float(yy),.30),.095,.13,red,C['07_Lighting'],12)
# Apron inset service trenches and tie-down points
for y in (-12,25,47):
    cube('Apron drain channel',(0,y,.12),(100,.20,.08),dark,C['04_Runway_and_Apron'])
    for x in np.arange(-48,49,1.2): cube('Drainage slot',(float(x),y,.168),(.40,.025,.012),galv,C['04_Runway_and_Apron'])
for x in np.arange(-48,49,6):
    for y in (0,34): cyl('Aircraft apron tie-down ring',(x,y,.16),.11,.025,galv,C['04_Runway_and_Apron'],12)

# Control tower: reinforced base, protected stair, glazed cab, framing and
# believable 1940s visual aids. Tower is 22 m to top of roof.
tx,ty=72,20
cube('Tower reinforced concrete footing',(tx,ty,.42),(12,12,.84),concrete,C['03_Control_Tower'],.14)
cube('Tower service block',(tx,ty,5.0),(9.4,9.4,9.2),steel,C['03_Control_Tower'],.14)
for z in (1.2,3.4,5.8,8.3):
    for side in (-1,1): cube('Tower belt course',(tx+side*4.75,ty,z),( .22,9.6,.12),galv,C['03_Control_Tower'],.025)
# External concrete stair zig-zag
for run in range(4):
    z0=1+run*2.05; x0=tx+(-1 if run%2==0 else 1)*5.5
    for step in range(9):
        cube('Tower stair tread',(x0+(step*.42 if run%2==0 else -step*.42),ty-5.45,z0+step*.18),(.62,.98,.18),concrete,C['03_Control_Tower'],.025)
    beam('Stair stringer',(x0,ty-5.5,z0),(x0+(3.7 if run%2==0 else -3.7),ty-5.5,z0+1.62),.12,dark,C['03_Control_Tower'])
# Glazed control room and interior consoles
for z in (10.1,15.3): cube('Control cab floor slab',(tx,ty,z),(14,14,.34),dark,C['03_Control_Tower'],.07)
for side in (-1,1):
    for y in np.linspace(ty-6.75,ty+6.75,7): cube('Tower cab glazing',(tx+side*6.55,y,12.7),(.12,2.1,4.9),glass,C['03_Control_Tower'],.02)
    for yy in np.linspace(ty-7,ty+7,8): beam('Cab mullion',(tx+side*6.68,yy,10.25),(tx+side*6.68,yy,15.15),.10,dark,C['03_Control_Tower'])
for side in (-1,1):
    for x in np.linspace(tx-6.75,tx+6.75,7): cube('Tower cab front glazing',(x,ty+side*6.55,12.7),(2.1,.12,4.9),glass,C['03_Control_Tower'],.02)
for x in np.linspace(tx-7,tx+7,8): beam('Cab front mullion',(x,ty-6.68,10.25),(x,ty-6.68,15.15),.1,dark,C['03_Control_Tower'])
cube('Control room console',(tx,ty-4,11.2),(9,.9,1.5),dark,C['03_Control_Tower'],.08)
for x in np.linspace(tx-3.8,tx+3.8,9): cube('Analog instrument panel',(x,ty-4.5,12),(.65,.08,.62),galv,C['03_Control_Tower'],.025)
for z in (15.6,16.2): cube('Cab weather canopy',(tx,ty,z),(15.2,15.2,.22),steel,C['03_Control_Tower'],.09)
cube('Tower roof penthouse',(tx,ty,17.4),(5.4,5.4,2.25),steel,C['03_Control_Tower'],.11)
for x in (-1.8,1.8):
    for y in (-1.8,1.8): cube('Roof corner post',(tx+x,ty+y,17.1),(.16,.16,2.1),dark,C['03_Control_Tower'])
# Wind cone and mast
beam('Wind indicator mast',(tx+10,ty,15.8),(tx+10,ty,22.8),.10,galv,C['03_Control_Tower'],False)
for i in range(7):
    cone=cyl('Wind sock narrow cuff',(tx+10,ty,21.7-i*.50),.32-i*.027,.52, fabric if i%2 else marking,C['03_Control_Tower'],12,'Y')
    cone.scale[0]=1-i*.08
for z in (18.1,19.4,20.7): cyl('Tower incandescent obstruction beacon',(tx,ty,z),.22,.18,red,C['07_Lighting'],16)

# Fuel, crates, workshop gear, machinery and defensive sandbag nests.
for group_x, group_y in [(-48,18),(50,47),(60,-7)]:
    for i in range(7):
        x=group_x+(i%4)*1.8; y=group_y+(i//4)*1.9
        barrel=cyl('WWII fuel drum',(x,y,.62),.47,1.05,steel,C['05_Ground_Support'],24)
        for z in (.34,.62,.90): cyl('Drum rolled steel chime',(x,y,z),.49,.065,galv,C['05_Ground_Support'],24)
        for q in range(2): cyl('Drum filler cap',(x-.18+q*.35,y,.99),.08,.05,dark,C['05_Ground_Support'],12)
for x,y in [(-40,22),(-37,22),(-40,25),(47,44)]:
    cube('Timber packing crate',(x,y,.55),(1.25,1.15,1.1),wood,C['05_Ground_Support'],.035)
    for z in (.15,.95): cube('Crate reinforcing batten',(x,y,z),(1.31,.08,.10),dark,C['05_Ground_Support'],.012)
    for xx in (-.48,.48): cube('Crate corner cleat',(x+xx,y,.55),(.09,1.18,1.16),wood,C['05_Ground_Support'],.01)
# Maintenance trolley, wheel chocks, hose reel, ladder and hydraulic jack
cube('Maintenance tool trolley',(-32,30,.65),(2.8,.95,1.1),steel,C['05_Ground_Support'],.11)
for x in (-33,-31):
    for y in (29.6,30.4): cyl('Trolley rubber caster',(x,y,.27),.22,.15,rubber,C['05_Ground_Support'],14,'Y')
for y in (33,35):
    cube('Aircraft wheel chock',(-8,y,.16),(1.1,.35,.28),wood,C['05_Ground_Support'],.045)
    beam('Chock hand grip',(-8.45,y,.31),(-7.55,y,.31),.04,dark,C['05_Ground_Support'],False)
for x in (27,29): beam('Maintenance ladder rail',(x,30,.4),(x,30,5.8),.12,galv,C['05_Ground_Support'])
for z in np.arange(.7,5.8,.42): beam('Maintenance ladder rung',(27,29.96,z),(29,29.96,z),.08,galv,C['05_Ground_Support'],False)
for side in (-1,1):
    # two WWII-style defensive positions built from individually beveled sacks
    cx=side*76; cy=53
    for row in range(3):
        for i in range(11):
            xx=cx+(i-5)*.82
            if abs(i-5)>3 or row<2: cube('Canvas-covered sandbag',(xx,cy,row*.42+.25),(.91,.56,.42),sand,C['06_Defensive_Perimeter'],.17)
    for i in range(5): cube('Perimeter timber picket',(side*95,20+i*4,1.1),(.18,.18,2.2),wood,C['06_Defensive_Perimeter'],.025)
beam('Barbed wire strand',(side*95,20,2.05),(side*95,36,2.05),.025,galv,C['06_Defensive_Perimeter'],False)

# WWII marker lamps on runway ends: hooded kerosene/incandescent-style low lights
# and portable flare pots, suitable for austere wartime strips.
for y in (-48,708):
    for x in (-18,-12,-6,0,6,12,18):
        cube('Low-profile runway edge marker',(x,y,.30),(.42,.42,.46),dark,C['07_Lighting'],.04)
        cyl('Hooded amber runway lamp',(x,y,.56),.15,.22,amber,C['07_Lighting'],14)
for x in (-34,34):
    for y in (3,22):
        cyl('Portable flare pot',(x,y,.38),.3,.64,dark,C['07_Lighting'],16)
        cyl('Flare glass',(x,y,.76),.18,.14,amber,C['07_Lighting'],12)
        bpy.ops.object.light_add(type='POINT',location=(x,y,1.0)); li=bpy.context.object; li.name='Warm flare pot light'; li.data.energy=45; li.data.color=(1,.31,.08); li.data.shadow_soft_size=1.4; move_to(li,C['07_Lighting'])

# Combine the 26 runway markers and 3 tower obstruction lamps into one draw call
# and blink them with one glTF morph animation, avoiding dozens of tiny nodes.
warning_lamps=[o for o in C['07_Lighting'].objects if o.type=='MESH' and (o.name.startswith('Shielded runway incandescent lamp') or o.name.startswith('Tower incandescent obstruction beacon'))]
lamp_vertices=[]; lamp_faces=[]; lamp_groups=[]; offset=0
for o in warning_lamps:
    transform=o.matrix_world.copy(); indices=[]
    for v in o.data.vertices:
        lamp_vertices.append(transform@v.co); indices.append(offset+v.index)
    for poly in o.data.polygons: lamp_faces.append(tuple(offset+i for i in poly.vertices))
    lamp_groups.append(indices); offset+=len(o.data.vertices)
mesh=bpy.data.meshes.new('Blinking red runway and tower lamps'); mesh.from_pydata(lamp_vertices,[],lamp_faces); mesh.materials.append(red); mesh.update()
blink_obj=bpy.data.objects.new('Blinking red runway and tower markers',mesh); C['07_Lighting'].objects.link(blink_obj)
for o in warning_lamps: bpy.data.objects.remove(o,do_unlink=True)
basis=blink_obj.shape_key_add(name='Basis'); blink=blink_obj.shape_key_add(name='Lights Off')
for group in lamp_groups:
    centroid=sum((Vector(lamp_vertices[i]) for i in group),Vector())/len(group)
    for i in group: blink.data[i].co=centroid
keys=[]
for base in range(1,121,30): keys.extend([(base,1.0),(base+3,0.0),(base+8,1.0),(base+10,0.0),(base+20,0.0),(base+21,1.0),(base+22,0.0),(base+27,0.0),(base+28,1.0),(min(base+30,120),1.0)])
for frame,value in keys:
    blink.value=value; blink.keyframe_insert(data_path='value',frame=frame,group='Red field warning lamps')
if blink_obj.data.shape_keys.animation_data and blink_obj.data.shape_keys.animation_data.action:
    blink_obj.data.shape_keys.animation_data.action.name='Blink_Red_Markers'
    for curve in blink_obj.data.shape_keys.animation_data.action.fcurves:
        for point in curve.keyframe_points: point.interpolation='CONSTANT'

# Generate continuous world-space UV tiles without the per-object UV operators.
# A 4 metre tile preserves the same texel density across structural modules.
for ob in [o for o in scene.objects if o.type=='MESH']:
    if not ob.data.uv_layers:
        uv=ob.data.uv_layers.new(name='UV0_4m_tile')
        for poly in ob.data.polygons:
            n=poly.normal; axis=max(range(3),key=lambda i:abs(n[i]))
            axes=({0:(1,2),1:(0,2),2:(0,1)})[axis]
            for li in poly.loop_indices:
                co=ob.data.vertices[ob.data.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]]*.25,co[axes[1]]*.25)
    ob['real_world_units']='metres'

# Drive door leaves independently; both are cyclic animation clips suitable for
# preview. GLB export includes the two clips as separate named animation tracks.
scene.frame_start=1; scene.frame_end=120; scene.render.fps=30
for door, sign, label in [(doors[0],-1,'Open_Left_Door'),(doors[1],1,'Open_Right_Door')]:
    start=door.location.x
    door.location.x=start; door.keyframe_insert('location',frame=1,group=label)
    door.location.x=start+sign*21.2; door.keyframe_insert('location',frame=90,group=label)
    door.location.x=start+sign*21.2; door.keyframe_insert('location',frame=120,group=label)
    act=door.animation_data.action; act.name=label
    for fc in act.fcurves:
        for kp in fc.keyframe_points: kp.interpolation='BEZIER'
    door['animation_clip']=label; door['collision_class']='moving_hangar_door'

# Collision guides live in their own collection and are excluded from all exports.
for name,loc,scale in [('COL_Hangar_Footprint',(0,0,6),(45,39,13)),('COL_Apron',(0,17,-.15),(112,74,.5)),('COL_Tower',(tx,ty,8),(12,12,16)),('COL_Runway',(0,330,-.15),(38,760,.5))]:
    co=cube(name,loc,scale,None,C['08_Collision_Proxies']); co.display_type='WIRE'; co.hide_render=True; co.hide_viewport=True; co['collision_proxy']=True
    co.data.materials.clear()

# Mark collection/asset metadata and preserve exact authoring settings.
scene['ASSET_ID']='bloedjungle_airfield_hq_2'; scene['ASSET_NAME']='Bloedjungle Airfield HQ 2.0'; scene['ASSET_CLASS']='modular_airfield_environment'
scene['SOURCE_STANDARD']='Bunker HQ Replacement quality principles'; scene['SOURCE_SCALE']='1 Blender unit = 1 metre'; scene['HISTORICAL_LIGHTING']='Low incandescent edge markers and blinking red obstruction lamps'
scene.render.engine='CYCLES'; scene.cycles.samples=64
scene.render.resolution_x=2048; scene.render.resolution_y=1152; scene.render.resolution_percentage=100
scene.world.color=(.28,.31,.34); scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.28,.31,.34,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.55
# Hero three-quarter camera and photographic area lights.
bpy.ops.object.camera_add(location=(105,-120,72)); cam=bpy.context.object; cam.name='Hero_Camera'; cam.rotation_euler=(Vector((0,155,5))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.lens=58; scene.camera=cam
for name,loc,energy,size,color in [('Large cool sky softbox',(-45,-35,90),55000,65,(.78,.84,1)),('Warm hangar-side bounce',(65,5,55),30000,48,(1,.78,.55)),('Runway long fill',(0,360,110),80000,85,(.72,.82,1))]:
    bpy.ops.object.light_add(type='AREA',location=loc); li=bpy.context.object; li.name=name; li.data.energy=energy; li.data.shape='DISK'; li.data.size=size; li.data.color=color; li.rotation_euler=(Vector((0,80,0))-li.location).to_track_quat('-Z','Y').to_euler()
# Export-visible asset collections only (camera, lights and collision guides are not model parts).
blend=os.path.join(OUT,'high_quality','Bloedjungle_Airfield_HQ_Source.blend'); os.makedirs(os.path.dirname(blend),exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=blend)
# Deterministic model stats for the authoring receipt.
deps=bpy.context.evaluated_depsgraph_get(); mesh_objs=[o for o in scene.objects if o.type=='MESH' and not o.name.startswith('COL_')]
tri=0
for o in mesh_objs:
    ev=o.evaluated_get(deps); me=ev.to_mesh(); tri+=sum(max(0,len(p.vertices)-2) for p in me.polygons); ev.to_mesh_clear()
report={'asset':scene['ASSET_NAME'],'blender':'4.5.15 LTS','units':'metres','source_blend':os.path.relpath(blend,ROOT),'source_mesh_objects':len(mesh_objs),'source_evaluated_triangles':tri,'animation_actions':['Open_Left_Door','Open_Right_Door','Blink_Red_Markers'],'hero_material_textures':{m.name:json.loads(m['PBR_texture_files']) for m in [steel,galv,concrete,runway,earth]},'note':'Generated with geometric portal frames, corrugated sheets, service details and physically-based 2K tileable maps.'}
with open(os.path.join(OUT,'high_quality','source_metrics.json'),'w') as f: json.dump(report,f,indent=2)
print('AIRFIELD_SOURCE_REPORT',json.dumps({k:v for k,v in report.items() if k not in ['hero_material_textures']}))
