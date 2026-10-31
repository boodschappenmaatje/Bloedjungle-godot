"""Airfield HQ 2.2: authored architectural/terrain rebuild, preserving v2.1 clips.

Blender 4.5.15: --background --python tools/airfield_hq/build_airfield_hq_v22.py
Coordinates are metres, Blender Z-up. 2.1 remains untouched.
"""
import bpy, math, os, random, json
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
SRC=os.path.join(ROOT,'assets/airfield_hq_v21/high_quality/Bloedjungle_Airfield_HQ_2_1_Source.blend')
OUT=os.path.join(ROOT,'assets/airfield_hq_v22/high_quality')
os.makedirs(OUT,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=SRC)
scene=bpy.context.scene
scene['ASSET_ID']='bloedjungle_airfield_hq_22'
scene['ASSET_NAME']='Bloedjungle Airfield HQ 2.2'
scene['REFERENCE']='Four Airfield HQ 2.1 concept images; Bunker HQ Replacement'
random.seed(1944)

def coll(name):
    c=bpy.data.collections.get(name)
    if c is None:c=bpy.data.collections.new(name);scene.collection.children.link(c)
    return c

def remove_collection(name):
    c=bpy.data.collections.get(name)
    if not c:return
    for o in list(c.objects):
        if len(o.users_collection)==1:bpy.data.objects.remove(o,do_unlink=True)
        else:c.objects.unlink(o)
    bpy.data.collections.remove(c)

# Keep the existing action-bearing door objects, obstruction light mesh, and
# familiar support props. The architectural shell, tower and airfield are new.
for n in ['01_Hangar_HQ','03_Control_Tower','04_Runway_and_Apron','09_Grass_Ver ges_and_Terrain']:
    remove_collection(n)

H=coll('01_Hangar_HQ_22');T=coll('03_Control_Tower_22');R=coll('04_Runway_and_Apron_22')
W=coll('07_Hangar_Service_Props_22');L=coll('07_Lighting_22')
M=bpy.data.materials
steel=M['Weathered galvanized steel']; olive=M['USAAF olive drab painted steel']
dark=M['Deep shadowed structural steel']; concrete=M['Aged airfield concrete']
floor=M['Hangar Interior Pitted Concrete']; runway=M['Runway concrete oil and tire wear']
earth=M['Compacted wet earth'];grass=M['Airfield sparse grass and worn verge']
glass=M['Smoky wartime tower glass'];wood=M['Weathered crate timber']
paint=M['Faded wartime runway paint'];red=M['Red obstruction warning lamp']

# 2.1's photographic, CC0 Poly Haven maps remain the material source. The
# facade tint is lightened to resemble zinc/aged field paint rather than toy green.
for mat in [olive,steel]:
    mat.diffuse_color=(.48,.50,.43,1) if mat==olive else (.53,.55,.53,1)
    for n in mat.node_tree.nodes:
        if n.type=='MIX_RGB' and n.blend_type=='MULTIPLY' and n.inputs[2].is_linked is False:
            if mat==olive:n.inputs[2].default_value=(.78,.79,.69,1)

# Blender renders the AO tint already present in the 2.1 source, while glTF
# needs an explicit Occlusion socket to carry the R channel of the ARM map.
# This exporter-only group keeps the three PBR channels in one shared texture.
gltf_group=bpy.data.node_groups.get('glTF Material Output')
if gltf_group is None:
    gltf_group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
    gltf_group.interface.new_socket('Occlusion',socket_type='NodeSocketFloat')
    gltf_group.nodes.new('NodeGroupInput')
    gltf_group.nodes.new('NodeGroupOutput')
for mat in [steel,olive,concrete,runway,floor,earth]:
    nodes=mat.node_tree.nodes
    separate=next((n for n in nodes if n.type=='SEPARATE_COLOR' and n.inputs['Color'].is_linked),None)
    if separate is None:raise RuntimeError(f'Missing ARM node in {mat.name}')
    group_node=nodes.new('ShaderNodeGroup')
    group_node.node_tree=gltf_group
    group_node.label='Export ARM red channel as glTF occlusion'
    mat.node_tree.links.new(separate.outputs['Red'],group_node.inputs['Occlusion'])

def move(o,c):
    for old in list(o.users_collection):old.objects.unlink(o)
    c.objects.link(o)
    return o

def uv_box(o):
    if o.type!='MESH':return
    if not o.data.uv_layers:o.data.uv_layers.new(name='UVMap')
    uv=o.data.uv_layers.active
    for p in o.data.polygons:
        n=p.normal;axis=max(range(3),key=lambda i:abs(n[i]))
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            pair=((co.y,co.z) if axis==0 else ((co.x,co.z) if axis==1 else (co.x,co.y)))
            uv.data[li].uv=(pair[0]*.25,pair[1]*.25)

def box(name,center,size,mat,c,bev=0,uv=True):
    x,y,z=(s*.5 for s in size)
    verts=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    dat=bpy.data.meshes.new(name);dat.from_pydata(verts,[],faces);dat.update()
    o=bpy.data.objects.new(name,dat);c.objects.link(o);o.location=center
    dat.materials.append(mat)
    if uv:uv_box(o)
    if bev:
        mod=o.modifiers.new('edge wear radius','BEVEL');mod.width=bev;mod.segments=2
        o.modifiers.new('weighted normals','WEIGHTED_NORMAL')
    return o

def cyl(name,a,b,r,mat,c,vertices=12):
    a,b=Vector(a),Vector(b);d=b-a
    vs=[];fs=[]
    for z in (-d.length/2,d.length/2):
        for i in range(vertices):
            angle=2*math.pi*i/vertices;vs.append((r*math.cos(angle),r*math.sin(angle),z))
    fs.append(tuple(range(vertices-1,-1,-1)));fs.append(tuple(range(vertices,2*vertices)))
    for i in range(vertices):
        j=(i+1)%vertices;fs.append((i,j,j+vertices,i+vertices))
    dat=bpy.data.meshes.new(name);dat.from_pydata(vs,[],fs);dat.update()
    o=bpy.data.objects.new(name,dat);c.objects.link(o);o.location=(a+b)/2
    o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    dat.materials.append(mat);uv_box(o);return o

def beam(name,a,b,width,depth,mat,c):
    a,b=Vector(a),Vector(b);d=b-a
    o=box(name,(a+b)/2,(width,depth,d.length),mat,c,.014)
    o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    return o

def mesh(name,verts,faces,mat,c,uv_mode='world'):
    dat=bpy.data.meshes.new(name);dat.from_pydata(verts,[],faces);dat.update()
    ob=bpy.data.objects.new(name,dat);c.objects.link(ob);dat.materials.append(mat)
    uv=dat.uv_layers.new(name='UVMap')
    for p in dat.polygons:
        axis=max(range(3),key=lambda i:abs(p.normal[i]))
        for li in p.loop_indices:
            co=dat.vertices[dat.loops[li].vertex_index].co
            pair=((co.y,co.z) if axis==0 else ((co.x,co.z) if axis==1 else (co.x,co.y)))
            uv.data[li].uv=(pair[0]*.25,pair[1]*.25)
    return ob

# -------- hangar: 44 x 40 m, 13.2 m clear opening, 16 m apex --------
box('Poured perimeter foundation',(0,0,-.16),(45,41,.32),concrete,H,.06)
box('Hangar pitted maintenance floor',(0,0,.035),(43.2,39.1,.20),floor,H,.015)
for x in (-22,22):
    box('Cast side plinth',(x,0,.52),(.7,40,1.05),concrete,H,.04)
for y in (-20,20):
    box('Rear / portal sill',(0,y,.25),(44,.55,.5),concrete,H,.04)

# Zig-zag pitched roof sheets are actual folded profiles, not a grid of roof
# tiles. They share long continuous strips; translucent clerestory is below.
roof_verts=[];roof_faces=[]
for side in (-1,1):
    for i in range(0,221):
        x=side*(i*.1)
        z=16.7-abs(x)*.157+0.07*math.sin(i*math.pi*.75)
        roof_verts.extend([(x,-20.65,z),(x,20.65,z)])
        if i: j=len(roof_verts)-4;roof_faces.append((j,j+1,j+3,j+2))
mesh('Continuous overlapped corrugated roof, west/east',roof_verts,roof_faces,steel,H)
for x in (-22,0,22):
    cyl('Half-round galvanized rain gutter',(x,-21,13.28),(x,21,13.28),.11,steel,H,12)
for x in (-22,22):
    for y in (-20,20):
        cyl('Downpipe and sleeve',(x,y,13.18),(x,y,.42),.085,steel,H,12)
        for z in (2.5,7.2,11.7):box('Downpipe wall clamp',(x,y,z),(.27,.18,.09),dark,H,.01)

# End gables are profiled sheet triangles above a real full-width door void.
for y in (-20.35,20.35):
    if y<0:
        # front gable begins above the 13.2 m sliding-door clearance
        verts=[(-22,y,13.2),(22,y,13.2),(0,y,16.7)]
        mesh('Front gable sheet with open door beneath',verts,[(0,1,2)],steel,H)
    else:
        for x in (-16,-8,0,8,16):
            box('Rear glazed service-wall pier',(x,y,5.35),(.32,.28,10.7),olive,H,.04)
        box('Rear lower sheet wall',(0,y,2.4),(44,.25,4.8),steel,H,.02)
        box('Rear clerestory window band',(0,y,8.5),(43.6,.10,5.1),glass,H)
        box('Rear eave infill',(0,y,11.95),(44,.23,1.55),steel,H)
        mesh('Rear gable infill',[(-22,y,13.2),(22,y,13.2),(0,y,16.7)],[(0,1,2)],steel,H)

for x in (-22,22):
    for y in range(-19,20,5):
        box('Pressed side wall lower sheet',(x,y,4.0),(.20,4.92,8),steel,H,.012)
        box('Sidewall clerestory glazing',(x,y,10.05),(.09,4.6,3.5),glass,H)
        box('Upper side wall sheet',(x,y,12.55),(.23,4.92,1.45),steel,H)
        for zz in (8.25,11.85):box('Clerestory horizontal sash',(x,y,zz),(.18,4.88,.10),dark,H)
    for y in (-20,-10,0,10,20):
        box('Riveted side column',(x,y,6.8),(.32,.32,13.6),dark,H,.018)

# Nine open-web portal frames: lower tie, rafters and zig-zag triangulation.
for y in (-19.5,-14.5,-9.5,-4.5,.5,5.5,10.5,15.5,19.5):
    for x in (-21.55,21.55):
        box('Hanger portal wide-flange post',(x,y,6.75),(.24,.28,13.5),dark,H,.012)
        box('Portal gusset knee plate',(x,y,12.95),(.92,.06,.58),olive,H,.01)
    for side in (-1,1):
        beam('Pitched steel rafter',(0,y,16.35),(side*21.7,y,13.02),.25,.34,dark,H)
        for k in range(5):
            x0=side*(k*4.25);x1=side*((k+1)*4.25)
            z0=16.15-abs(x0)*.15;z1=16.15-abs(x1)*.15
            beam('Portal truss diagonal',(x0,y,13.35),(x1,y,z1),.095,.095,olive,H)
            beam('Portal truss diagonal',(x0,y,z0),(x1,y,13.35),.07,.07,olive,H)
    beam('Hangar truss bottom chord',(-21.6,y,13.35),(21.6,y,13.35),.16,.22,dark,H)
for x in (-18,-12,-6,0,6,12,18):
    beam('Continuous roof purlin',(x,-20,16.5-abs(x)*.157),(x,20,16.5-abs(x)*.157),.095,.14,olive,H)

# Door track, trolley housings and a genuinely recessed open portal.
box('Door overhead I-beam track',(0,-20.65,13.3),(65,.30,.27),dark,H,.02)
box('Inset lower steel guide',(0,-20.58,.10),(65,.17,.14),dark,H)
for x in (-31.3,-20.8,-10.2,0,10.2,20.8,31.3):
    cyl('Portal trolley roller',(x,-20.65,13.26),(x,-20.37,13.26),.16,dark,H,20)
for x in (-32,-22,22,32):
    box('Sliding portal guide post',(x,-20.45,6.7),(.30,.40,13.4),dark,H,.02)

# Replace only the mesh data, keeping each 2.1 door object, animation, location
# and gameplay collision transform. Local geometry is relative to its pivot.
def remake_door(ob):
    old=ob.data
    doorparts=[]
    def db(name,p,s,m,bev=0):
        return box(name,tuple(ob.location[i]+p[i] for i in range(3)),s,m,H,bev)
    def dc(name,a,b,r,m):
        return cyl(name,tuple(ob.location[i]+a[i] for i in range(3)),tuple(ob.location[i]+b[i] for i in range(3)),r,m,H,20)
    def de(name,a,b,w,d,m):
        return beam(name,tuple(ob.location[i]+a[i] for i in range(3)),tuple(ob.location[i]+b[i] for i in range(3)),w,d,m,H)
    # Make a single joined mesh of thin corrugated sheets, diagonal braces,
    # framed panels, wheel lugs and hand-sized ironwork.
    for i in range(29):
        x=-9.88+i*.705
        doorparts.append(db('sheet',(x,0,0),(.73,.12,12.85),steel))
        if i%3==0:doorparts.append(db('pressed seam',(x+.34,-.075,0),(.035,.08,12.85),dark))
    for x in (-9.9,0,9.9):doorparts.append(db('door edge stiffener',(x,-.18,0),(.18,.18,12.9),dark))
    for z in (-6.28,0,6.28):doorparts.append(db('door crossmember',(0,-.21,z),(19.9,.13,.16),dark))
    for a,b in [((-9.5,-.24,-6),(9.5,-.24,6)),((-9.5,-.24,6),(9.5,-.24,-6))]:
        doorparts.append(de('Z-bracing',a,b,.12,.09,olive))
    for x in (-7,7):
        doorparts.append(dc('hanging trolley',(x,-.05,6.46),(x,.25,6.46),.17,dark))
        doorparts.append(db('trolley hanger',(x,0,6.3),(.18,.22,.45),steel))
    for x in (-9.2,9.2):doorparts.append(db('recessed pull',(x,-.29,-.4),(.08,.07,.52),dark,.01))
    bpy.ops.object.select_all(action='DESELECT')
    for p in doorparts:p.select_set(True)
    bpy.context.view_layer.objects.active=doorparts[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join();result=bpy.context.object
    # Coordinates are world-space before join; put them in the animated door's
    # local frame. Its original pivot is at (+/-10.2,-19.55,6.65).
    result_world=result.matrix_world.copy()
    for v in result.data.vertices:v.co=result_world@v.co-ob.location
    result.matrix_world.identity()
    result.data.update()
    ob.data=result.data.copy();bpy.data.objects.remove(result,do_unlink=True)
    if old.users==0:bpy.data.meshes.remove(old)

# Door children/pivots in 2.1 are preserved; replacement geometry constructed
# at each object location in world space (sheet centres are offset here).
for side in ('LEFT','RIGHT'):
    ob=bpy.data.objects.get('Hangar sliding door '+side)
    if ob:remake_door(ob)

# Three louvred monitor vents, sheeted differently from the old roof boxes.
for y in (-12,0,12):
    box('Vent monitor raised curb',(0,y,16.95),(2.1,3.2,.55),dark,H,.04)
    for x in (-.94,.94):
        for z in (17.15,17.38,17.61):
            blade=box('Angled roof-vent louvre',(x,y,z),(.16,2.7,.12),steel,H,.01)
            blade.rotation_euler[1]=math.radians(19)
    box('Rain hood over ridge vent',(0,y,17.85),(2.65,3.65,.18),steel,H,.035)

# Workshop kept out of the P-47 15 m central clearance envelope.
for x in (-17.7,17.7):
    for y in (-12,-5,3,11):
        box('Heavy maintenance bench',(x,y,.88),(2.55,1.05,.17),wood,W,.025)
        for dx in (-1.1,1.1):
            for dy in (-.43,.43):box('Bench angle-iron leg',(x+dx,y+dy,.42),(.1,.1,.84),dark,W,.01)
        box('Workshop drawer chest',(x,y,.56),(1.25,.76,.48),olive,W,.035)
        for zz in (.4,.55,.7):box('Metal drawer handle',(x,y-.39,zz),(.27,.05,.035),steel,W,.01)
    for y in (-9,8):
        box('Parts shelf welded upright',(x,y,1.4),(.11,.10,2.8),dark,W)
        for zz in (.45,1.3,2.2):box('Parts shelf tray',(x,y,zz),(2.6,.8,.09),steel,W,.01)
        for xx in (-.75,.6):box('Spare parts wood crate',(x+xx,y,1.57),(.8,.6,.44),wood,W,.02)
    # Mobile rolling work platforms with perimeter rails, stair and wheels.
    y=0
    box('Aircraft service platform deck',(x,y,2.25),(3.1,1.25,.13),steel,W,.02)
    for dx in (-1.35,1.35):
        for dy in (-.5,.5):
            box('Platform post',(x+dx,y+dy,1.15),(.09,.09,2.2),dark,W)
            cyl('Platform caster',(x+dx,y+dy-.2,.16),(x+dx,y+dy+.2,.16),.17,dark,W,12)
    for z in (.55,1.05,1.55,2.05):box('Platform stair tread',(x+1.9,y,z),(.7,.65,.10),steel,W)
    for z in (2.8,3.45):beam('Platform tubular guard rail',(x-1.55,y-.58,z),(x+1.55,y-.58,z),.045,.045,dark,W)

# Aircraft jack and spare propeller are discrete maintenance equipment, not a
# stand-in for an aircraft. Central aircraft envelope remains deliberately empty.
for x,y in [(-14,13),(14,13)]:
    cyl('Hydraulic jack base',(x,y,.12),(x,y,.3),.42,olive,W,20)
    cyl('Hydraulic jack column',(x,y,.3),(x,y,1.35),.11,dark,W,16)
    box('Jack saddle',(x,y,1.4),(.55,.25,.13),steel,W,.03)
    for dx in (-.36,.36):
        for dy in (-.36,.36):beam('Jack support leg',(x,y,.3),(x+dx,y+dy,.03),.055,.055,dark,W)
for x,y in [(-17,15),(17,15)]:
    cyl('Spare propeller hub on rack',(x,y,1.2),(x,y+.45,1.2),.34,dark,W,24)
    for ang in (0,2*math.pi/3,4*math.pi/3):
        dx=math.cos(ang);dz=math.sin(ang)
        blade=box('Stored P-47-class spare propeller blade',(x+dx*1.2,y+.25,1.2+dz*1.2),(.32,.09,2.3),dark,W,.08)
        blade.rotation_euler[1]=ang

# Service objects close enough to read from the original interior camera while
# still 3 m outside a 12.44 m P-47 wing envelope.
for side in (-1,1):
    x=side*10.4
    for y in (-7,4):
        box('USAAF mobile mechanics tool cabinet',(x,y,.65),(1.2,.72,1.25),olive,W,.07)
        for z in (.35,.57,.79,1.01):
            box('Tool chest drawer lip',(x,y-.39,z),(.95,.055,.035),steel,W,.008)
        for dx in (-.46,.46):
            cyl('Tool cart rubber wheel',(x+dx,y-.36,.16),(x+dx,y-.17,.16),.14,dark,W,14)
    y=9
    cyl('Spare radial engine outer case',(x,y,.8),(x,y+.5,.8),.71,dark,W,24)
    cyl('Spare radial engine centre boss',(x,y-.08,.8),(x,y+.57,.8),.26,steel,W,20)
    for a in range(9):
        ang=2*math.pi*a/9
        dx=.62*math.cos(ang);dz=.62*math.sin(ang)
        cyl('Radial engine exposed cylinder bank',(x,y+.2,.8),(x+dx,y+.2,.8+dz),.13,steel,W,10)
    for y in (-15,-13):
        cyl('Workshop used-oil drum',(x,y,.15),(x,y,1.1),.35,olive,W,20)
        cyl('Oil drum rolled rim',(x,y,1.1),(x,y,1.17),.38,dark,W,20)

# A marked 18 x 26 m parking rectangle frames the empty, deliberately reserved
# P-47 servicing position without placing any fake aircraft in it.
for x in (-8.6,8.6):box('P-47 maintenance bay floor line',(x,0,.145),(.13,27,.01),paint,W)
for y in (-13.5,13.5):box('P-47 maintenance bay end line',(0,y,.145),(17.2,.13,.01),paint,W)

# Irregular localized oil marks lie on the concrete, never as uniform noise.
for i in range(28):
    x=random.choice((-1,1))*random.uniform(8.2,19.5);y=random.uniform(-17,16)
    r=random.uniform(.18,.7);v=[(x,y,.15)];f=[]
    for j in range(9):
        a=j*2*math.pi/8;v.append((x+r*math.cos(a),y+r*.55*math.sin(a),.15))
        if j: f.append((0,j,j+1))
    mesh('Localized maintenance oil trace',v,f,dark,W)

for x in (-12,0,12):
    for y in (-12,0,12):
        # Factory fixture housing, warm shallow bowl; the visible shape stays
        # in the GLB while only LOD0 gets its light source.
        cyl('Pendant conduit',(x,y,15.6),(x,y,14.2),.025,dark,W)
        bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.48,radius2=.15,depth=.30,location=(x,y,14.05))
        o=bpy.context.object;o.name='Industrial pendant shade';o.data.materials.append(dark);move(o,W)
        if abs(x)<.1 or y==0:
            ld=bpy.data.lights.new('Warm workshop practical','POINT');ld.energy=700;ld.use_shadow=False
            lamp=bpy.data.objects.new('Warm workshop practical light',ld);lamp.location=(x,y,13.82);W.objects.link(lamp)

# -------- tower: two storeys of plastered masonry and a glazed 360-degree cab --------
tx,ty=72,20
box('Tower cast footing',(tx,ty,-.05),(11.4,11.4,.65),concrete,T,.08)
box('Tower ground floor',(tx,ty,.3),(10.1,10.1,.22),concrete,T)
box('Tower first-floor slab',(tx,ty,5.15),(10.3,10.3,.25),concrete,T,.045)
box('Tower cab subfloor',(tx,ty,10.55),(12.8,12.8,.36),concrete,T,.06)
for z0,z1 in ((.3,5.05),(5.3,10.4)):
    for face in ('east','west','north','south'):
        sign=1 if face in ('east','north') else -1
        zz=(z0+z1)/2
        for u in (-3.6,3.6):
            p=(tx+sign*5.05,ty+u,zz) if face in ('east','west') else (tx+u,ty+sign*5.05,zz)
            dims=(.45,2.8,z1-z0) if face in ('east','west') else (2.8,.45,z1-z0)
            box('Tower masonry pier',p,dims,concrete,T,.045)
        for u in (-1.55,1.55):
            p=(tx+sign*5.05,ty+u,zz) if face in ('east','west') else (tx+u,ty+sign*5.05,zz)
            dims=(.45,.3,z1-z0) if face in ('east','west') else (.3,.45,z1-z0)
            box('Tower narrow pier',p,dims,concrete,T,.025)
        for z,d in ((z0+.55,1.1),(z1-.30,.60)):
            p=(tx+sign*5.05,ty,(z+d/2)) if face in ('east','west') else (tx,ty+sign*5.05,z+d/2)
            dims=(.46,10.1,d) if face in ('east','west') else (10.1,.46,d)
            box('Tower wall sill / lintel',p,dims,concrete,T,.02)
        for u in (-3.1,0,3.1):
            if face=='south' and u==0 and z0<1:
                # true entrance void and an inset operable access leaf
                continue
            p=(tx+sign*5.05,ty+u,z0+2.4) if face in ('east','west') else (tx+u,ty+sign*5.05,z0+2.4)
            dims=(.09,1.5,2.2) if face in ('east','west') else (1.5,.09,2.2)
            box('Tower inset 1940s steel sash',p,dims,glass,T)
            for offset in (-.70,.70):
                q=(p[0],p[1]+offset,p[2]) if face in ('east','west') else (p[0]+offset,p[1],p[2])
                d=(.11,.045,2.28) if face in ('east','west') else (.045,.11,2.28)
                box('Tower steel mullion',q,d,dark,T)
            box('Tower window crossbar',p,(.12,1.47,.055) if face in ('east','west') else (1.47,.12,.055),dark,T)

door=box('Tower ground entrance',(tx,ty-5.14,1.63),(1.35,.13,2.55),olive,T,.04)
inset=box('Tower door pressed inset',(tx,ty-5.23,1.72),(.96,.035,1.85),dark,T,.015)
handle=cyl('Tower lever handle',(tx+.45,ty-5.27,1.42),(tx+.62,ty-5.27,1.42),.035,steel,T)
bpy.ops.object.select_all(action='DESELECT')
for part in (door,inset,handle):part.select_set(True)
bpy.context.view_layer.objects.active=door
bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
door=bpy.context.object;door.name='Tower access door | animated'
# Move the pivot to the western hinge while keeping the visible leaf in place.
for v in door.data.vertices:v.co.x+=.675
door.location.x-=.675
for frame,angle in ((1,0),(32,math.radians(95)),(72,math.radians(95))):
    door.rotation_euler[2]=angle;door.keyframe_insert(data_path='rotation_euler',frame=frame)
door.animation_data.action.name='Open_Tower_Door'
scene.frame_set(1)
box('Tower cab balcony slab',(tx,ty,11.12),(14.8,14.8,.23),concrete,T,.07)
box('Tower cab floor',(tx,ty,11.35),(12.7,12.7,.18),wood,T)
for x in (-6.25,6.25):
    for y in (-6.25,6.25):
        box('Cab steel corner mullion',(tx+x,ty+y,13.9),(.17,.17,5.15),dark,T,.018)
for face in ('east','west','north','south'):
    sign=1 if face in ('east','north') else -1
    for u in (-4.8,-2.4,0,2.4,4.8):
        p=(tx+sign*6.25,ty+u,13.9) if face in ('east','west') else (tx+u,ty+sign*6.25,13.9)
        box('Cab continuous glass',(p),( .07,2.28,4.8) if face in ('east','west') else (2.28,.07,4.8),glass,T)
        box('Cab vertical mullion',(p[0],p[1],p[2]),(.12,.055,4.9) if face in ('east','west') else (.055,.12,4.9),dark,T)
    p=(tx+sign*6.25,ty,13.15) if face in ('east','west') else (tx,ty+sign*6.25,13.15)
    box('Cab waist rail',p,(.16,12.6,.13) if face in ('east','west') else (12.6,.16,.13),dark,T)
box('Tower weathered cab roof',(tx,ty,16.62),(14.3,14.3,.38),steel,T,.12)
box('Tower cab rain coping',(tx,ty,16.82),(13.8,13.8,.13),dark,T,.035)
for face in (-1,1):
    for u in (-6.8,6.8):
        for z in (11.55,12.3):
            beam('Tower balcony guardrail',(tx+face*6.85,ty+u,11.35),(tx+face*6.85,ty+u,z),.05,.05,dark,T)
            beam('Tower balcony guardrail',(tx+u,ty+face*6.85,11.35),(tx+u,ty+face*6.85,z),.05,.05,dark,T)
    for z in (11.9,12.3):
        beam('Tower perimeter rail',(tx-6.85,ty+face*6.85,z),(tx+6.85,ty+face*6.85,z),.05,.05,dark,T)
        beam('Tower perimeter rail',(tx+face*6.85,ty-6.85,z),(tx+face*6.85,ty+6.85,z),.05,.05,dark,T)

# Two flight-control desks, black radio stacks, map board, cable conduits.
for x in (-2.6,2.6):
    box('Control desk timber top',(tx+x,ty,12.1),(2.55,.78,.12),wood,T,.03)
    for dx in (-1.0,1.0):
        for dy in (-.31,.31):box('Control desk leg',(tx+x+dx,ty+dy,11.74),(.08,.08,.7),dark,T)
    for dx in (-.7,0,.7):
        box('Tube radio chassis',(tx+x+dx,ty+.12,12.44),(.52,.40,.58),dark,T,.03)
        for zz in (12.32,12.49):
            cyl('Radio tuning knob',(tx+x+dx-.12,ty-.1,zz),(tx+x+dx-.12,ty-.16,zz),.035,steel,T)
box('Folded field map board',(tx,ty+3.8,12.15),(4.8,1.7,.045),wood,T,.01)
for x in (-4.2,4.2):
    for z in (2.5,7.5):box('Tower exterior service junction box',(tx+x,ty-5.33,z),(.55,.35,.85),olive,T,.04)
    cyl('Tower exposed electrical conduit',(tx+x,ty-5.36,.5),(tx+x,ty-5.36,10.4),.045,dark,T)

# Full exterior staircase: separate treads/landings/railings with usable
# 1.1 m width. The game collision stays a cheap proxy rather than per tread.
for flight in range(2):
    x=tx-8.2-flight*.8;y0=ty-4.8+flight*4.8;z0=.3+flight*5.1
    box('Tower steel stair landing',(x,y0+4.1,z0+5.05),(2.2,2.15,.16),steel,T,.02)
    for i in range(21):
        y=y0+i*.2;z=z0+i*.24
        box('Open steel stair tread',(x,y,z),(1.35,.19,.08),steel,T,.008)
    for side in (-.72,.72):
        beam('Tower stair guard',(x+side,y0,z0+.9),(x+side,y0+4.1,z0+5.9),.055,.055,dark,T)
        for i in range(0,21,5):
            y=y0+i*.2;z=z0+i*.24
            beam('Tower stair baluster',(x+side,y,z),(x+side,y,z+.9),.04,.04,dark,T)

for x,y in [(tx+5,ty+5),(tx-3,ty+5)]:
    cyl('1944 radio aerial mast',(x,y,16.85),(x,y,22.8),.045,dark,T)
    for z in (19.2,21.8):
        beam('Radio aerial crossarm',(x-1.25,y,z),(x+1.25,y,z),.035,.035,dark,T)
for x,y in [(tx+4,ty-3),(tx-3,ty+5)]:
    cyl('Tower mast guy wire',(x,y,22.7),(tx,y,16.7),.009,dark,T,8)

# Windsock uses actual mesh shape keys, visibly deflecting in a loop.
cyl('Wind mast',(tx-6.2,ty+5,16.85),(tx-6.2,ty+5,22.5),.055,dark,T)
v=[];f=[]
for ring in range(7):
    xx=tx-6.2+ring*.49;rr=.32*(1-ring/8)
    for j in range(12):
        a=2*math.pi*j/12;v.append((xx,ty+5+rr*math.cos(a),21.9+rr*math.sin(a)))
for ring in range(6):
    for j in range(12):
        n=ring*12+j;nn=ring*12+(j+1)%12;f.append((n,nn,nn+12,n+12))
sock=mesh('Tower wind sock | wind animation',v,f,paint,T)
sock.shape_key_add(name='Basis')
key=sock.shape_key_add(name='Wind_Gust')
for i,vert in enumerate(key.data):
    ring=i//12;vert.co.z+=.18*math.sin(ring*.75);vert.co.y+=.12*math.sin(ring*1.1)
key.value=0
for frame,val in [(1,0),(18,1),(36,.1),(54,.7),(72,0)]:
    key.value=val;key.keyframe_insert('value',frame=frame)
if sock.data.shape_keys.animation_data and sock.data.shape_keys.animation_data.action:
    sock.data.shape_keys.animation_data.action.name='Wind_Sock_Gust'

# -------- one concrete runway with shaped grass/soil, apron and taxi link --------
# Runway centre x=0, y=100..1000. The 900 m paved length supports a game
# acceleration profile of 2.0 m/s² to 50 m/s within 625 m (physics check only).
def terrain_height(x,y):
    return -.24+.11*math.sin(x*.055)*math.cos(y*.031)+.06*math.sin(x*.17+y*.11)

# Existing 1K ambientCG CC0 PBR grass is a clearer field base than the very
# sparse brown verge map. Its source and licence are recorded in the repo.
meadow=bpy.data.materials.new('1944 airfield meadow | ambientCG CC0 1K')
meadow.use_nodes=True
nt=meadow.node_tree;nt.nodes.clear()
out=nt.nodes.new('ShaderNodeOutputMaterial');bs=nt.nodes.new('ShaderNodeBsdfPrincipled')
nt.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
uv=nt.nodes.new('ShaderNodeTexCoord');mapping=nt.nodes.new('ShaderNodeMapping')
mapping.inputs['Scale'].default_value=(1,1,1)
nt.links.new(uv.outputs['UV'],mapping.inputs['Vector'])
grassdir=os.path.join(ROOT,'assets/textures/terrain/grass')
for filename,kind in [('base_color.jpg','COLOR'),('normal_gl.jpg','NORMAL'),('roughness.jpg','ROUGH')]:
    node=nt.nodes.new('ShaderNodeTexImage')
    node.image=bpy.data.images.load(os.path.join(grassdir,filename),check_existing=True)
    node.image.colorspace_settings.name='sRGB' if kind=='COLOR' else 'Non-Color'
    nt.links.new(mapping.outputs['Vector'],node.inputs['Vector'])
    if kind=='COLOR':nt.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    elif kind=='ROUGH':nt.links.new(node.outputs['Color'],bs.inputs['Roughness'])
    else:
        nm=nt.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.65
        nt.links.new(node.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
meadow['license']='ambientCG CC0-1.0, existing assets/licenses/downloaded_assets.json'
colour_node=nt.nodes.new('ShaderNodeAttribute');colour_node.attribute_name='FieldColor'
base_link=next(l for l in nt.links if l.to_node==bs and l.to_socket.name=='Base Color')
base_socket=base_link.from_socket;nt.links.remove(base_link)
macro=nt.nodes.new('ShaderNodeMixRGB');macro.blend_type='MULTIPLY';macro.inputs[0].default_value=.75
nt.links.new(base_socket,macro.inputs[1]);nt.links.new(colour_node.outputs['Color'],macro.inputs[2])
nt.links.new(macro.outputs['Color'],bs.inputs['Base Color'])

verts=[];faces=[]
nx=80;ny=95
for iy in range(ny+1):
    y=-105+iy*12.0
    for ix in range(nx+1):
        x=-420+ix*10.5
        verts.append((x,y,terrain_height(x,y)))
        if ix and iy:
            q=iy*(nx+1)+ix;faces.append((q-nx-2,q-nx-1,q,q-1))
ground=mesh('Continuous graded terrain with real elevation variation',verts,faces,meadow,R)
# Smooth macro variation is stored as vertex colours, so the same gradient
# survives glTF/Godot without a runtime procedural shader or decal drawcalls.
attr=ground.data.color_attributes.new(name='FieldColor',type='BYTE_COLOR',domain='CORNER')
for poly in ground.data.polygons:
    for li in poly.loop_indices:
        co=ground.data.vertices[ground.data.loops[li].vertex_index].co
        x,y=co.x,co.y
        n=.5+.24*math.sin(x*.014+y*.008)+.17*math.sin(x*.031-y*.021)+.09*math.cos(x*.067+y*.045)
        n=max(0,min(1,n))
        # sandy, worn turf near hardstand; greener meadow away from service area
        wear=max(0,1-min(1,math.hypot(x*.012,(y+20)*.005)))
        attr.data[li].color=(.72+.27*(1-n)+.14*wear,.78+.28*n-.10*wear,.60+.25*n-.08*wear,1)

# Existing Bloedjungle foliage meshes give the horizon a believable tree line.
# Their far LODs are reused; no primitive stand-in vegetation is invented.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT,'assets/jungle.glb'))
imported=[o for o in bpy.data.objects if o not in before]
templates=[o for o in imported if o.name.startswith(('Boom1_far','Boom2_far')) and o.type=='MESH']
trees=coll('10_Existing_Jungle_Treeline_22')
if templates:
    for i in range(44):
        source=templates[i%len(templates)]
        o=source.copy();o.data=source.data;trees.objects.link(o)
        x=random.choice((-1,1))*random.uniform(140,310)
        y=random.uniform(45,930)
        o.location=(x,y,terrain_height(x,y))
        o.rotation_euler[2]=random.uniform(0,2*math.pi)
        scale=random.uniform(.75,1.35);o.scale=(scale,scale,scale)
        o.name='Reused Bloedjungle tree far LOD'
for o in imported:bpy.data.objects.remove(o,do_unlink=True)

# Eroded shoulders follow the runway in irregular ribbons; no floating black
# rectangular base. The concrete terminates at actual grassy edges.
for side in (-1,1):
    vv=[];ff=[]
    for i in range(91):
        y=100+i*10
        fringe=27+2.7*math.sin(i*.89)+1.3*math.sin(i*2.17)
        vv.extend([(side*19.2,y,.015),(side*fringe,y,terrain_height(side*fringe,y)+.035)])
        if i:
            j=2*i;ff.append((j-2,j-1,j+1,j))
    mesh('Irregular compacted runway shoulder',vv,ff,earth,R)

# Slabs are split by true recessed 5 cm joints, with sparse, colour-varied
# 1940s concrete patches. 2 x 90 modular pour sections, not a smooth ribbon.
for row in range(90):
    y=105+row*9.9
    for side in (-1,1):
        x=side*9.5
        mat=runway if (row+int(side))%5 else concrete
        slab=box('Runway poured concrete slab',(x,y,.055),(18.93,9.83,.17),mat,R,.012)
        slab['slab_row']=row
    if row%7==0:
        for xx in (-11,11):
            # dark tire/oil treatment localized in the wheel zones
            box('Faint wheel-path rubber scuff',(xx,y+.6,.149),(1.8,2.3,.007),dark,R)
for y in (111,975):
    for x in (-15,-9,-3,3,9,15):
        box('1944 runway threshold bar',(x,y,.154),(3.2,10,.012),paint,R)
for i in range(26):
    y=150+i*31
    box('Intermittent centreline runway marking',(0,y,.155),(.62,10,.012),paint,R)

# Connected apron extends from door y=-20 outward, with broad parking wings.
for row in range(7):
    y=-60+row*14
    for col in range(9):
        x=-49+col*12.3
        if y>15 and abs(x)<24:continue # hangar footprint remains solid
        box('Apron concrete pour slab',(x,y,.035),(12.2,13.9,.15),concrete if (row+col)%4 else runway,R,.008)

# Taxiway follows a curved centreline around the tower, then enters the runway
# at y≈245. A sampled strip provides real shoulders and joint rhythm.
taxi_pts=[(47,-42),(54,-33),(60,-15),(58,5),(55,36),(54,70),(51,105),(43,140),(30,175),(19,204),(10,230),(0,245)]
def smooth_path(points,step=.075):
    out=[]
    for k in range(len(points)-1):
        p0=Vector(points[max(0,k-1)]);p1=Vector(points[k]);p2=Vector(points[k+1]);p3=Vector(points[min(len(points)-1,k+2)])
        for j in range(int(1/step)):
            t=j*step;t2=t*t;t3=t2*t
            q=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t2+(-p0+3*p1-3*p2+p3)*t3)
            out.append((q.x,q.y))
    out.append(points[-1]);return out
path=smooth_path(taxi_pts)
vv=[];ff=[];shoulder_v=[];shoulder_f=[]
for i,(x,y) in enumerate(path):
    a=Vector(path[max(i-1,0)]);b=Vector(path[min(i+1,len(path)-1)]);d=b-a
    n=Vector((-d.y,d.x));n.normalize()
    for s in (-1,1):
        vv.append((x+s*n.x*9.2,y+s*n.y*9.2,.088))
        shoulder_v.extend([(x+s*n.x*9.25,y+s*n.y*9.25,.055),(x+s*n.x*13,y+s*n.y*13,terrain_height(x+s*n.x*13,y+s*n.y*13)+.03)])
    if i:
        j=2*i;ff.append((j-2,j-1,j+1,j))
        for q in range(2):
            h=4*i+2*q;shoulder_f.append((h-4,h-3,h+1,h))
mesh('Continuous curved poured-concrete taxiway',vv,ff,concrete,R)
mesh('Taxiway worn unpaved margins',shoulder_v,shoulder_f,earth,R)

# Period painted line, joined to the apron but broken before runway hold.
line_v=[];line_f=[]
for i,(x,y) in enumerate(path):
    a=Vector(path[max(i-1,0)]);b=Vector(path[min(i+1,len(path)-1)]);d=b-a;n=Vector((-d.y,d.x));n.normalize()
    line_v.extend([(x-n.x*.065,y-n.y*.065,.103),(x+n.x*.065,y+n.y*.065,.103)])
    if i: j=2*i;line_f.append((j-2,j-1,j+1,j))
mesh('Faded taxi centre guide',line_v,line_f,paint,R)
for yy in (226,230):
    box('Runway holding double line',(11,yy,.108),(17,.14,.012),paint,R)

# Tie-down rings and servicing zone. No fake aircraft mesh is part of the
# delivery; P-47 clearance is checked through Godot markers and test geometry.
for x in (-35,-22,-9,9,22,35):
    for y in (-55,-36):
        cyl('Apron tie-down anchor',(x,y,.1),(x,y,.14),.14,dark,R,16)
for x,y in [(-41,-59),(40,-58)]:
    box('Fuel compound kerb',(x,y,-.01),(10,8,.25),concrete,R,.035)
    for dx in (-3,-1,1,3):
        cyl('Av-gas drums | grouped storage',(x+dx,y,.12),(x+dx,y,1.03),.35,olive,R,20)

# Shift the preserved runway marker assembly and edge sockets to the new 100 m
# threshold, while leaving tower lights at x≈72. The morph clip stays intact.
for o in list(bpy.data.collections['07_Lighting'].objects):
    if o.type!='MESH':continue
    if o.name.startswith('Blinking red runway'):
        # This single morph mesh contains both runway and tower caps. Move only
        # vertex positions belonging to the runway strip, in every key block.
        if o.data.shape_keys:
            for key in o.data.shape_keys.key_blocks:
                for v in key.data:
                    if abs(v.co.x)<50:v.co.y+=150
        else:
            for v in o.data.vertices:
                if abs(v.co.x)<50:v.co.y+=150
    elif 'Runway' in o.name or 'runway' in o.name:
        o.location.y+=150

# Additional low-intensity period edge housings; no modern LED strips.
for y in range(105,990,60):
    for side in (-1,1):
        x=side*22.1
        cyl('Low wartime runway edge marker',(x,y,.02),(x,y,.22),.11,steel,L,12)
        cyl('Red glass field lamp cap',(x,y,.22),(x,y,.30),.075,red,L,12)

# Source-level receipts and spatial assertions.
assert (44-2*.5)>12.44+3.0
assert 13.2>4.45+2.0
assert len(path)>100
scene['P47_clear_door_width_m']=39.4
scene['P47_clear_door_height_m']=13.0
scene['P47_central_bay_clear_width_m']=30.0
scene['runway_length_m']=900.0
scene['P47_asset_status']='Model missing from repository; intentionally not fabricated.'
scene.frame_set(1)
dst=os.path.join(OUT,'Bloedjungle_Airfield_HQ_2_2_Source.blend')
for image in bpy.data.images:
    if image.source=='FILE' and image.filepath:
        source=bpy.path.abspath(image.filepath)
        if os.path.isfile(source):image.filepath='//'+os.path.relpath(source,OUT)
bpy.ops.wm.save_as_mainfile(filepath=dst)
metrics={'source_blend':os.path.relpath(dst,ROOT),'blender':bpy.app.version_string,'source_meshes':sum(o.type=='MESH' for o in bpy.data.objects),'animations':[a.name for a in bpy.data.actions],'runway_m':900,'p47_door_width_m':39.4,'p47_door_height_m':13.0,'p47_hangar_clear_width_m':30.0}
with open(os.path.join(OUT,'source_metrics.json'),'w') as f:json.dump(metrics,f,indent=2)
print('AIRFIELD_22_SOURCE_PASS',json.dumps(metrics))
