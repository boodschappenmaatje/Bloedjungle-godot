"""Bloedjungle Airfield 3.0. Procedural Blender scene; no external assets."""
import bpy, math, json, pathlib, hashlib, struct, time, traceback
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'previews'
EXPORTS = ROOT / 'exports'
LOGS = ROOT / 'logs'
VALID = ROOT / 'validation'
ANIMATIONS = ROOT / 'animations'
ASSETS = ROOT / 'assets'
for p in (OUT, EXPORTS, LOGS, VALID, ANIMATIONS, ASSETS): p.mkdir(parents=True, exist_ok=True)
RUN = time.strftime('%Y%m%d_%H%M%S') + f'_{time.time_ns() % 1000000:06d}'
STAMP = RUN
SCENE = bpy.context.scene
SCENE.unit_settings.system = 'METRIC'
SCENE.unit_settings.scale_length = 1.0
SCENE.render.engine = 'CYCLES'
SCENE.cycles.device = 'CPU'
SCENE.cycles.samples = 12
SCENE.render.resolution_x, SCENE.render.resolution_y = 1280, 768
SCENE.render.resolution_percentage = 100
SCENE.render.image_settings.file_format = 'PNG'

def collection(name):
    c = bpy.data.collections.new(name); SCENE.collection.children.link(c); return c

COL = {n: collection(n) for n in (
    '00 Terrain', '01 Airfield', '02 Hangar Structure', '03 Hangar Interior',
    '04 Animated Doors', '05 Warning Beacons', '06 Jet Placeholder - REPLACE',
    '07 Roof - Toggle for interior', '08 Preview Rig')}
ACTIVE = COL['00 Terrain']

def put(o, col=None, mat=None):
    col = col or ACTIVE
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o)
    if mat: o.data.materials.append(mat)
    return o

def mat(name, color, metallic=0.0, rough=.65, noise_scale=24, bump=.08, emission=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    nt=m.node_tree; bs=nt.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metallic; bs.inputs['Roughness'].default_value=rough
    if noise_scale:
        tex=nt.nodes.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=noise_scale; tex.inputs['Detail'].default_value=3
        ramp=nt.nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.24; ramp.color_ramp.elements[0].color=(*[v*.70 for v in color],1)
        ramp.color_ramp.elements[1].position=.78; ramp.color_ramp.elements[1].color=(*[min(v*1.22,1) for v in color],1)
        nt.links.new(tex.outputs['Fac'],ramp.inputs['Fac']); nt.links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
        if bump:
            b=nt.nodes.new('ShaderNodeBump'); b.inputs['Strength'].default_value=bump; b.inputs['Distance'].default_value=.025
            nt.links.new(tex.outputs['Fac'],b.inputs['Height']); nt.links.new(b.outputs['Normal'],bs.inputs['Normal'])
    if emission:
        col,strength=emission
        inp=bs.inputs.get('Emission Color') or bs.inputs.get('Emission')
        if inp: inp.default_value=(*col,1)
        if bs.inputs.get('Emission Strength'): bs.inputs['Emission Strength'].default_value=strength
    return m

CONCRETE=mat('Concrete | weathered military apron',(.30,.32,.31),0,.88,42,.11)
ASPHALT=mat('Asphalt | runway aggregate',(.075,.085,.086),0,.92,80,.12)
STEEL=mat('Hangar | olive structural steel',(.17,.20,.17),.58,.58,36,.09)
PANEL=mat('Hangar | galvanized wall panels',(.29,.32,.30),.72,.43,64,.055)
ROOF=mat('Hangar | roof panels and grime',(.19,.23,.22),.66,.56,30,.1)
INTERIOR=mat('Interior | coated concrete',(.33,.34,.31),.08,.84,28,.09)
YELLOW=mat('Safety paint | worn yellow',(.92,.60,.12),.08,.7,18,.05)
WHITE=mat('Runway paint | worn white',(.76,.77,.72),0,.78,26,.03)
RED=mat('Beacon | animated emissive red',(1,.008,.002),0,.2,0,0,((1,.002,.0005),5.0))
GLASS=mat('Cockpit glass placeholder',(.06,.18,.22),.65,.19,4,.015)
JET=mat('Jet placeholder | olive gray',(.22,.25,.23),.65,.43,18,.04)
RUBBER=mat('Tires and rubber deposits',(.018,.021,.02),0,.92,12,.025)
RUST=mat('Oxidized seams',(.24,.105,.045),.34,.84,20,.04)

def box(name, loc, dims, material, col=None, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); put(o,col,material)
    if bevel:
        mod=o.modifiers.new('Manufactured edge radius','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def beam(name,a,b,w,material,depth=None,col=None):
    a,b=Vector(a),Vector(b); o=box(name,(a+b)*.5,(w,depth or w,(b-a).length),material,col)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o

def cylinder(name,loc,r,depth,material,col=None,vertices=12,rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc)
    o=put(bpy.context.object,col,material); o.name=name
    if rot: o.rotation_euler=rot
    return o

def curve_line(name, points, bevel_depth, material, col=None, cyclic=False):
    cv=bpy.data.curves.new(name,'CURVE'); cv.dimensions='3D'; cv.bevel_depth=bevel_depth; cv.bevel_resolution=1
    sp=cv.splines.new('POLY'); sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points): p.co=(*co,1)
    sp.use_cyclic_u=cyclic; ob=bpy.data.objects.new(name,cv); (col or ACTIVE).objects.link(ob); ob.data.materials.append(material); return ob

def label(name,text,loc,size,material,rot=(math.pi/2,0,0),col=None):
    cv=bpy.data.curves.new(name,'FONT'); cv.body=text; cv.size=size; cv.extrude=.006; cv.align_x='CENTER'; cv.align_y='CENTER'
    o=bpy.data.objects.new(name,cv); o.location=loc; o.rotation_euler=rot; (col or ACTIVE).objects.link(o); cv.materials.append(material); return o

def save_phase(num,name):
    ACTIVE=COL['08 Preview Rig']
    path=OUT/f'preview_{num:02d}_{name}_{STAMP}.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    temp=OUT/'latest.json.tmp'; temp.write_text(json.dumps({'file':path.name,'phase':num,'status':SCENE.get('phase_status','')})); temp.replace(OUT/'latest.json')
    return path

# STAGE 2: compact test ground, long apron and runway footprint.
ACTIVE=COL['00 Terrain']
box('Terrain slab',(0,-82,-.62),(150,188,1.2),ASPHALT,ACTIVE)
ACTIVE=COL['01 Airfield']
box('Runway 09/27',(0,-112,-.025),(17,105,.25),ASPHALT,ACTIVE,.04)
box('Runway left threshold',(0,-62,.11),(15.8,2.2,.025),WHITE,ACTIVE)
box('Runway far threshold',(0,-162,.11),(15.8,2.2,.025),WHITE,ACTIVE)
for y in range(-68,-158,-8): box('Runway center dash',(0,y,.125),(.42,4.1,.025),WHITE,ACTIVE)
for x in (-6.7,6.7):
    box('Runway edge stripe',(x,-112,.12),(.18,100,.025),WHITE,ACTIVE)
    for y in range(-64,-162,-6): box('Runway side bar',(x+(.5 if x<0 else -.5),y,.12),(.6,2.1,.025),WHITE,ACTIVE)
for y in (-165,-59):
    for i in range(8):
        x=-5.8+i*1.65; box('Threshold piano key',(x,y,.13),(.72,2.6,.025),WHITE,ACTIVE)
box('Concrete apron',(0,-27,.04),(62,42,.28),CONCRETE,ACTIVE,.08)
for x in range(-29,31,8):
    curve_line('Apron control joint',[(x,-47,.19),(x,-7,.19)],.018,RUST,ACTIVE)
for y in range(-43,-7,7): curve_line('Apron control joint',[(-30,y,.19),(30,y,.19)],.018,RUST,ACTIVE)
# Spalled seams and oil patches are low-poly, flat tonal overlays.
for i,(x,y,r) in enumerate(((-21,-35,1.2),(16,-41,1.7),(24,-18,.8),(-12,-15,.7),(7,-30,.9))):
    bpy.ops.mesh.primitive_circle_add(vertices=14,radius=r,fill_type='NGON',location=(x,y,.205)); put(bpy.context.object,ACTIVE,RUBBER); bpy.context.object.name='Oil spill / tire scuff'
# Taxi route represented as modular pavement slabs following a legible S turn.
taxi_pts=[(-1,-41,.22),(-1,-48,.22),(0,-55,.22),(1,-62,.22),(0,-69,.22),(0,-76,.22)]
for i in range(len(taxi_pts)-1):
    a,b=Vector(taxi_pts[i]),Vector(taxi_pts[i+1]); mid=(a+b)*.5; d=b-a
    slab=box('Taxiway slab',mid,(13,d.length+.35,.3),CONCRETE,ACTIVE,.06); slab.rotation_euler.z=math.atan2(d.x,-d.y)
    # centerline and broken guidance marks
    curve_line('Taxiway yellow guidance line',[(a.x,a.y,.385),(b.x,b.y,.385)],.09,YELLOW,ACTIVE)
    box('Taxiway edge yellow',(-6.2,mid.y,.38),(.13,d.length,.025),YELLOW,ACTIVE)
    box('Taxiway edge yellow',(6.2,mid.y,.38),(.13,d.length,.025),YELLOW,ACTIVE)
for x in (-33,33):
    for y in range(-47,-6,7): box('Apron boundary warning dash',(x,y,.205),(.22,3.1,.025),YELLOW,ACTIVE)
label('Taxiway identifier','A',(-4,-52,.4),2.1,YELLOW,(0,0,0),ACTIVE)
label('Runway designation','09',(0,-61,.42),3.0,WHITE,(0,0,0),ACTIVE)
# Runway approach and edge lamps: emissive mesh, sparse real point sources.
for x in (-8.3,8.3):
    for y in range(-61,-164,-8):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.22,location=(x,y,.48)); put(bpy.context.object,ACTIVE,WHITE); bpy.context.object.name='Runway edge marker'

SCENE['phase_status']='Fase 2 — terrein, platformvoetprint, taxibaan en startbaan'
save_phase(2,'basisscene')

# STAGE 2/3: hangar base and structure, opening faces south (-Y).
ACTIVE=COL['02 Hangar Structure']
box('Hangar foundation',(0,0,.23),(27,21,.46),CONCRETE,ACTIVE,.09)
box('Hangar interior floor',(0,0,.49),(25.8,19.8,.12),INTERIOR,ACTIVE,.025)
# Wall panel grid; front lintel and side walls frame a 20m wide, 9m tall opening.
for x in range(-12,13,2):
    beam('Front portal steel post',(x,-10,0),(x, -10,11.5),.24,STEEL,.28,ACTIVE) if abs(x)>10 else None
    if abs(x)>10:
        box('Front cladding panel',(x,-10.02,5.55),(1.88,.19,10.8),PANEL,ACTIVE,.025)
    box('Rear cladding panel',(x,10,5.55),(1.88,.2,10.8),PANEL,ACTIVE,.025)
for y in range(-8,10,2):
    for x in (-13,13): box('Side cladding panel',(x,y,5.55),(.2,1.88,10.8),PANEL,ACTIVE,.025)
for x in (-12.8,12.8):
    for y in (-9.7,9.7): beam('Primary portal column',(x,y,.5),(x,y,11.5),.38,STEEL,.4,ACTIVE)
for y in (-9.5,9.5): beam('Side wall girder',(-12.8,y,10.8),(12.8,y,10.8),.26,STEEL,.3,ACTIVE)
beam('Front door header',(-13,-10,10.1),(13,-10,10.1),.42,STEEL,.5,ACTIVE)
beam('Rear roof truss',(-12.8,9.6,10.7),(12.8,9.6,10.7),.22,STEEL,.25,ACTIVE)
# Roof supports and rafters. Separate roof collection allows toggling for gameplay/interior view.
ACTIVE=COL['07 Roof - Toggle for interior']
for y in (-9,-4,1,6,9):
    for x in (-12,0,12): beam('Roof truss rafter',(x,y,10.9),(x,y,12.2),.13,STEEL,.17,ACTIVE)
    beam('Roof cross member',(-12.5,y,12.1),(12.5,y,12.1),.17,STEEL,.2,ACTIVE)
for x in range(-12,13,3):
    box('Roof standing seam panel',(x,0,12.23),(2.85,20.4,.16),ROOF,ACTIVE,.035)
    beam('Roof raised seam',(x,-10,12.34),(x,10,12.34),.06,STEEL,.07,ACTIVE)
for x in (-13.65,13.65): box('Roof gutter',(x,0,11.65),(.3,20,.2),STEEL,ACTIVE,.045)
for x in (-13.6,13.6):
    for y in (-9,9): beam('Downpipe',(x,y,0),(x,y,11.6),.12,STEEL,.14,ACTIVE)
# Gutters, vents, electrical boxes and external warning striping.
ACTIVE=COL['02 Hangar Structure']
for x in range(-11,12,2):
    box('Front safety stripe',(x,-10.18,.72),(1.65,.035,.13),YELLOW,ACTIVE)
for z in (8.4,8.9,9.4):
    box('Portal safety stripe',(-12.1,-10.19,z),(1.3,.04,.13),YELLOW,ACTIVE)
    box('Portal safety stripe',(12.1,-10.19,z),(1.3,.04,.13),YELLOW,ACTIVE)
for x in (-11,11):
    box('External service cabinet',(x,-10.7,1.5),(1.2,.8,2.2),STEEL,ACTIVE,.05)
    for i in range(4): box('Cabinet vent',(x,-11.11,1+i*.18),(.72,.025,.055),RUBBER,ACTIVE)
for x in (-8,-4,0,4,8):
    box('High wall louver',(x,10.13,8.7),(2.1,.1,.85),STEEL,ACTIVE,.04)
    for z in range(8): box('Louver blade',(x,10.2,8.4+z*.095),(1.85,.05,.04),PANEL,ACTIVE)
label('Hangar signage','AIR WING  /  H-01',(0,-10.22,9.7),.56,WHITE,(math.pi/2,0,0),ACTIVE)
for x in (-11.8,11.8):
    box('Exterior wall lamp',(x,-10.4,8.1),(.65,.3,.28),STEEL,ACTIVE)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.18,location=(x,-10.6,7.88)); put(bpy.context.object,ACTIVE,WHITE); bpy.context.object.name='Warm exterior lamp lens'

# STAGE 3: two full-height sliding leaves with rails and animated travel.
ACTIVE=COL['04 Animated Doors']
door_objects=[]
for side,center in (('L',-5.3),('R',5.3)):
    root=bpy.data.objects.new('DOOR_'+side+'_SLIDING',None); ACTIVE.objects.link(root); root.location=(center,-10.15,0); door_objects.append(root)
    root['mechanism']='horizontal outward sliding door leaf'; root['slide_side']=side
    panel=box('Door '+side+' | insulated steel leaf',(0,0,5.05),(10.55,.42,9.75),PANEL,ACTIVE,.07); panel.parent=root; panel.location=(0,0,5.05)
    for xx in (-4.8,-3.2,-1.6,0,1.6,3.2,4.8):
        rib=box('Door '+side+' | vertical rib',(0,0,5.05),(.075,.09,9.35),STEEL,ACTIVE,.018); rib.parent=root; rib.location=(xx,-.255,5.05)
    for z in (.48,9.58):
        rail=box('Door '+side+' | edge frame',(0,0,0),(10.2,.12,.18),STEEL,ACTIVE); rail.parent=root; rail.location=(0,-.27,z)
    for x in (-4.6,4.6):
        wheel=cylinder('Door '+side+' | roller',(0,0,0),.2,.2,RUBBER,ACTIVE,12,(0,math.pi/2,0)); wheel.parent=root; wheel.location=(x,-.32,.32)
    # opening motion from closed to parked outside; separate actions are exported as NLA clips.
    def action_for(obj,name,frames):
        act=bpy.data.actions.new(name); obj.animation_data_create(); obj.animation_data.action=act
        for frame,xpos in frames:
            obj.location.x=xpos; obj.keyframe_insert(data_path='location',index=0,frame=frame,group='Door travel')
        obj.animation_data.action=None; tr=obj.animation_data_create().nla_tracks.new(); tr.name=name
        st=tr.strips.new(name,frames[0][0],act); st.blend_type='REPLACE'
    end=center + (-11.0 if side=='L' else 11.0)
    action_for(root,'hangar_open',[(1,center),(49,end)])
    action_for(root,'hangar_close',[(1,end),(49,center)])
    action_for(root,'hangar_'+('left' if side=='L' else 'right')+'_open',[(1,center),(49,end)])
    action_for(root,'hangar_'+('left' if side=='L' else 'right')+'_close',[(1,end),(49,center)])
    root.location.x=center
    # Keep the independent clips in the scene timeline after the combined taxi demo.
    for track in root.animation_data.nla_tracks:
        for strip in track.strips:
            if strip.name == 'hangar_open':
                strip.frame_start=70; strip.extrapolation='HOLD_FORWARD'
            elif strip.name == 'hangar_close':
                strip.frame_start=280
            elif strip.name.endswith('_open'):
                strip.frame_start=340 if side=='L' else 400
                strip.extrapolation='HOLD_FORWARD'
            elif strip.name.endswith('_close'):
                strip.frame_start=460 if side=='L' else 500
SCENE.frame_end=560
for y in (-10.6,-10.85): box('Door ground track',(0,y,.56),(28,.13,.12),STEEL,ACTIVE,.02)
for x in range(-13,14,2): cylinder('Track fixing bolt',(x,-10.86,.56),.07,.04,RUST,ACTIVE,8)
SCENE['phase_status']='Fase 3 — twee afzonderlijke schuifdeuren met open-, sluit- en zijdeurclips'
save_phase(3,'deuren')

# STAGE 4: interior work areas, floor markings, machinery, lighting.
ACTIVE=COL['03 Hangar Interior']
for x in range(-11,12,4): curve_line('Interior floor expansion joint',[(x,-9,.57),(x,9,.57)],.018,RUST,ACTIVE)
for y in range(-8,10,4): curve_line('Interior floor expansion joint',[(-12,y,.57),(12,y,.57)],.018,RUST,ACTIVE)
for x in (-10,10):
    box('Maintenance bay yellow boundary',(x,0,.59),(.11,16,.035),YELLOW,ACTIVE)
for y in (-7,7): box('Maintenance bay transverse line',(0,y,.59),(20,.11,.035),YELLOW,ACTIVE)
for x in (-8,8):
    box('Tool cabinet',(x,7.8,1.65),(3.1,1.2,2.2),STEEL,ACTIVE,.07)
    for i in range(5): box('Tool drawer',(x,7.16,.85+i*.32),(2.55,.1,.23),PANEL,ACTIVE,.025)
    box('Bench top',(x,5.9,1.32),(3.8,1.1,.16),RUST,ACTIVE,.03)
    for dx in (-1.55,1.55): beam('Workbench leg',(x+dx,5.9,.62),(x+dx,5.9,1.27),.1,STEEL,.12,ACTIVE)
for x in (-9,-5,5,9):
    box('Hangar cable tray',(x,0,10.35),(.32,17,.18),STEEL,ACTIVE)
for y in (-6,0,6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.32,location=(0,y,10.55)); put(bpy.context.object,ACTIVE,WHITE); bpy.context.object.name='Interior high-bay LED diffuser'
    bpy.ops.object.light_add(type='AREA',location=(0,y,10.35)); lamp=put(bpy.context.object,COL['08 Preview Rig']); lamp.name='Preview only | hangar high-bay'; lamp.data.energy=950; lamp.data.shape='RECTANGLE'; lamp.data.size=5; lamp.data.size_y=1.2
for x in (-12,12):
    for y in (-8,8): box('Corner safety bollard',(x,y,1.05),(.26,.26,1.05),YELLOW,ACTIVE,.07)
# Roof underside purlins are separated from exterior panels to reveal architecture when roof hidden.
ACTIVE=COL['07 Roof - Toggle for interior']
for y in range(-9,10,3): beam('Visible roof purlin',(-12,y,11.82),(12,y,11.82),.11,STEEL,.15,ACTIVE)
SCENE['phase_status']='Fase 4 — hangarconstructie, interieur, onderhoudszones en vliegveld'
save_phase(4,'vliegveld_interieur')

# STAGE 5: red blinking beacons; material keyframes for Blender and companion Godot behavior.
ACTIVE=COL['05 Warning Beacons']
beacons=[]
for x,y,z in ((-13.8,-9.5,11.9),(13.8,-9.5,11.9),(-13.8,9.5,11.9),(13.8,9.5,11.9),(-35,-46,.7),(35,-46,.7),(-8.3,-62,.68),(8.3,-62,.68),(-8.3,-162,.68),(8.3,-162,.68)):
    base=cylinder('Beacon base',(x,y,z-.25),.28,.5,STEEL,ACTIVE,10)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=.3,location=(x,y,z)); ob=put(bpy.context.object,ACTIVE,RED); ob.name='RED_BLINK_BEACON'; ob['blink_rate_hz']=1.0; beacons.append(ob)
    # Animated scale gives an unmistakable Blender viewport preview; Godot script animates material emission.
    for f in range(1,321,10):
        s=1 if ((f-1)//10)%2 else .12
        ob.scale=(s,s,s); ob.keyframe_insert(data_path='scale',frame=f)
SCENE.frame_start=1; SCENE.frame_end=560; SCENE.render.fps=30
SCENE['phase_status']='Fase 5 — rode geanimeerde waarschuwingslampen'
save_phase(5,'waarschuwingslichten')

# STAGE 6: existing jet absent in searched project folders/repository view. Build unmistakable temporary proxy.
ACTIVE=COL['06 Jet Placeholder - REPLACE']
root=bpy.data.objects.new('TEMPORARY_JET_PLACEHOLDER_REPLACE_WITH_PROJECT_MODEL',None); ACTIVE.objects.link(root)
root['asset_status']='TEMPORARY PLACEHOLDER: existing Bloedjungle jet source not found locally or publicly accessible'
root['replace_with']='Existing Bloedjungle project jet before game integration'
def mesh_obj(name,verts,faces,material):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.materials.append(material); me.update(); ob=bpy.data.objects.new(name,me); ACTIVE.objects.link(ob); ob.parent=root; return ob
# Axis: nose points toward -Y. Fuselage loft; broad swept wings and twin tail fins.
sections=[(7.5,.08,.08),(6.2,.28,.28),(3,.48,.43),(-1,.62,.52),(-5,.52,.47),(-7.5,.12,.16)]
verts=[]
for y,rx,rz in sections:
    for i in range(10):
        a=2*math.pi*i/10; verts.append((rx*math.cos(a),y,2.05+rz*math.sin(a)))
faces=[]
for j in range(len(sections)-1):
    for i in range(10): faces.append((j*10+i,j*10+(i+1)%10,(j+1)*10+(i+1)%10,(j+1)*10+i))
faces.extend([tuple(range(9,-1,-1)),tuple((len(sections)-1)*10+i for i in range(10))]); mesh_obj('Placeholder jet | fuselage',verts,faces,JET)
mesh_obj('Placeholder jet | main wings',[(-8,-2,1.95),(-4,1,1.95),(4,1,1.95),(8,-2,1.95),(6,-4.7,1.95),(-6,-4.7,1.95)],[(0,1,2,3,4,5)],JET)
mesh_obj('Placeholder jet | tailplane',[(-4,4.2,2.15),(-2,5.6,2.15),(2,5.6,2.15),(4,4.2,2.15),(3.2,3,2.15),(-3.2,3,2.15)],[(0,1,2,3,4,5)],JET)
mesh_obj('Placeholder jet | fin L',[(-1.1,4.8,2.4),(-.1,5.8,4.5),(-.1,3.2,2.4)],[(0,1,2)],JET)
mesh_obj('Placeholder jet | fin R',[(.1,3.2,2.4),(.1,5.8,4.5),(1.1,4.8,2.4)],[(0,1,2)],JET)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=(0,2.2,2.55)); canopy=put(bpy.context.object,ACTIVE,GLASS); canopy.name='Placeholder cockpit canopy'; canopy.scale=(.42,1.5,.48); canopy.parent=root
for x in (-3,3):
    cylinder('Placeholder engine nacelle',(x,4.25,1.85),.36,3.1,JET,ACTIVE,12,(math.pi/2,0,0)).parent=root
    cylinder('Placeholder dark exhaust',(x,5.84,1.85),.25,.05,RUBBER,ACTIVE,12,(math.pi/2,0,0)).parent=root
for x,y in ((0,3),(-3,-3),(3,-3)):
    cylinder('Placeholder tire',(x,y,.42),.43,.23,RUBBER,ACTIVE,12,(0,math.pi/2,0)).parent=root
    beam('Placeholder landing gear',(x,y,1.75),(x,y,.58),.1,STEEL,.12,ACTIVE).parent=root
label('Placeholder warning','PLACEHOLDER JET',(0,0,0),.1,YELLOW,(0,0,0),ACTIVE)
root.location=(0,-2,0)
def jet_clip(name, keys):
    act=bpy.data.actions.new(name); root.animation_data_create(); root.animation_data.action=act
    for frame,loc,yaw in keys:
        root.location=loc; root.keyframe_insert(data_path='location',frame=frame,group='Taxi demonstration')
        root.rotation_euler.z=yaw; root.keyframe_insert(data_path='rotation_euler',index=2,frame=frame,group='Taxi demonstration')
    root.animation_data.action=None
    track=root.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,keys[0][0],act); strip.blend_type='REPLACE'; strip.extrapolation='HOLD_FORWARD'

jet_clip('jet_idle | PLACEHOLDER',[(1,(0,-2,0),0),(149,(0,-2,0),0)])
jet_clip('jet_taxi_out | PLACEHOLDER',[(150,(0,-2,0),0),(180,(0,-16,0),0),(220,(0,-39,0),math.radians(5)),(250,(0,-55,0),0),(280,(0,-70,0),0)])
jet_clip('jet_stop | PLACEHOLDER',[(280,(0,-70,0),0),(320,(0,-70,0),0)])
root.location=(0,-2,0); root.rotation_euler.z=0
SCENE.frame_set(1)

# Configure viewport/camera for inspectable full-scene view.
ACTIVE=COL['08 Preview Rig']
bpy.ops.object.camera_add(location=(76,-125,110)); cam=put(bpy.context.object,ACTIVE); cam.name='Preview camera | overview'
cam.rotation_euler=(Vector((0,-78,2))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=188; SCENE.camera=cam
bpy.ops.object.light_add(type='AREA',location=(20,-45,82)); key=put(bpy.context.object,ACTIVE); key.name='Preview key light'; key.data.energy=15000; key.data.shape='DISK'; key.data.size=55
bpy.ops.object.light_add(type='AREA',location=(-65,-100,45)); fill=put(bpy.context.object,ACTIVE); fill.name='Preview fill light'; fill.data.energy=7000; fill.data.size=45
interior_cam=bpy.data.objects.new('Preview camera | hangar interior',bpy.data.cameras.new('Interior camera data')); ACTIVE.objects.link(interior_cam)
interior_cam.location=(0,-36,16); interior_cam.rotation_euler=(Vector((0,0,5))-interior_cam.location).to_track_quat('-Z','Y').to_euler()
interior_cam.data.type='ORTHO'; interior_cam.data.ortho_scale=31
SCENE.world.color=(.16,.18,.20); SCENE.render.image_settings.color_mode='RGBA'; SCENE.view_settings.view_transform='AgX'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=190; area.spaces.active.region_3d.view_location=(0,-76,0); area.spaces.active.region_3d.view_perspective='PERSP'
SCENE['project']='BLOEDJUNGLE — MILITARY AIRFIELD 3.0'
SCENE['jet_source_status']='Placeholder only; existing project model unavailable in local/repository search'
SCENE['phase_status']='06 jet placeholder and animation built; visual finishing and export validation pending'

SCENE['phase_status']='Fase 6 — demonstratieanimatie met duidelijk gemarkeerde tijdelijke jet-placeholder'
phase_path=save_phase(6,'demo_compleet')

# Preview variants and final editable scene; views are deliberately composed for gameplay readability.
def render_png(path, roof_hidden=False, frame=1, resolution=1.0, camera=None):
    roof=COL['07 Roof - Toggle for interior']; prev=roof.hide_render; roof.hide_render=roof_hidden
    old_camera=SCENE.camera
    if camera: SCENE.camera=camera
    SCENE.frame_set(frame); SCENE.render.resolution_percentage=int(100*resolution); SCENE.render.filepath=str(path)
    bpy.ops.render.render(write_still=True); roof.hide_render=prev; SCENE.render.resolution_percentage=100
    SCENE.camera=old_camera

final_blend=ROOT/'Bloedjungle-Airfield.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(final_blend))
try:
    render_png(ROOT/'preview_overview.png',False,150,.75)
    render_png(ROOT/'preview_interior.png',True,150,.75,interior_cam)
    render_png(ROOT/'preview_doors_open.png',True,49,.75)
except Exception:
    (LOGS/'preview_error.txt').write_text(traceback.format_exc())

# GLB export helpers, using object selection by collection membership.
def export_glb(path, cols, animations=True):
    bpy.ops.object.select_all(action='DESELECT'); objs=[]
    for c in cols:
        objs.extend(o for o in c.objects if o.type in {'MESH','EMPTY','LIGHT'})
        for child in c.children: objs.extend(o for o in child.objects if o.type in {'MESH','EMPTY','LIGHT'})
    # Avoid preview camera/lights and never export them to game assets.
    objs=[o for o in objs if o.type in {'MESH','EMPTY'}]
    for o in objs: o.select_set(True)
    if objs: bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,
        export_animations=animations,export_nla_strips=True,
        export_frame_range=True,export_force_sampling=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    return objs

exports=[]
try:
    export_glb(EXPORTS/'Bloedjungle-Airfield.glb',[c for c in COL.values() if c.name!='08 Preview Rig'],True)
    exports.append(EXPORTS/'Bloedjungle-Airfield.glb')
    export_glb(EXPORTS/'Hangar.glb',[COL['02 Hangar Structure'],COL['03 Hangar Interior'],COL['04 Animated Doors'],COL['07 Roof - Toggle for interior'],COL['05 Warning Beacons']],True)
    exports.append(EXPORTS/'Hangar.glb')
    export_glb(EXPORTS/'Airfield.glb',[COL['00 Terrain'],COL['01 Airfield']],False)
    exports.append(EXPORTS/'Airfield.glb')
except Exception:
    (LOGS/'export_error.txt').write_text(traceback.format_exc())

def triangle_count(objs):
    total=0
    for o in objs:
        if o.type=='MESH': total+=sum(max(0,len(p.vertices)-2) for p in o.data.polygons)
    return total

report={'blender':bpy.app.version_string,'run_id':RUN,'scene':'Bloedjungle-Airfield-3.0',
 'jet_source':'NOT FOUND in accessible local paths; GitHub page unavailable/private from session; temporary procedural placeholder used',
 'phase_blends':[p.name for p in sorted(OUT.glob(f'preview_*_{STAMP}.blend'))],
 'exports':{},'collections':{},'glb_roundtrip':{},'godot_runtime_test':'NOT RUN','iphone_device_test':'NOT RUN',
 'blender_background':bpy.app.background,'warnings':['Jet is an explicitly marked temporary placeholder.','Live UI launch is supplied as a normal macOS Terminal command; sandboxed Blender startup crashes before bpy initialization.']}
for name,c in COL.items():
    objs=[o for o in c.objects if o.type=='MESH']; report['collections'][name]={'meshes':len(objs),'triangles':triangle_count(objs)}
for p in exports:
    if p.exists():
        raw=p.read_bytes(); magic,version,length=struct.unpack_from('<4sII',raw)
        report['exports'][p.name]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'glb_header':'PASS' if magic==b'glTF' and version==2 and length==len(raw) else 'FAIL'}
        before_objects=set(bpy.data.objects); before_actions=set(bpy.data.actions)
        try:
            bpy.ops.import_scene.gltf(filepath=str(p))
            imported=[o for o in bpy.data.objects if o not in before_objects]
            tris=triangle_count(imported)
            clips=set()
            for act in set(bpy.data.actions)-before_actions: clips.add(act.name)
            for ob in imported:
                ad=ob.animation_data
                if ad:
                    if ad.action: clips.add(ad.action.name)
                    for tr in ad.nla_tracks:
                        for strip in tr.strips: clips.add(strip.name)
            report['glb_roundtrip'][p.name]={'status':'PASS' if imported and tris>0 else 'FAIL',
                'imported_objects':len(imported),'triangles':tris,'animation_channels_or_clips':sorted(clips)}
            for ob in imported: bpy.data.objects.remove(ob,do_unlink=True)
        except Exception:
            report['glb_roundtrip'][p.name]={'status':'FAIL','error':traceback.format_exc()}
report['total_meshes']=sum(v['meshes'] for v in report['collections'].values())
report['total_triangles']=sum(v['triangles'] for v in report['collections'].values())
report['preview_files']=[p.name for p in (ROOT/'preview_overview.png',ROOT/'preview_interior.png',ROOT/'preview_doors_open.png') if p.exists()]
(VALID/'validation.json').write_text(json.dumps(report,indent=2))
try: (ANIMATIONS/'blink_beacons.gd').write_text((ROOT/'scripts'/'blink_beacons.gd').read_text())
except Exception: pass
(ROOT/'Rapport.md').write_text('# Bloedjungle Airfield 3.0 — productierapport\n\n'+
 'Blender-procedureel bronproject. Deze build gebruikt nog een duidelijk gemarkeerde jet-placeholder omdat het bestaande projectmodel niet beschikbaar was. Zie validation/validation.json voor gemeten gegevens en exportstatus.\n')
print('BLOEDJUNGLE_AIRFIELD_RESULT',json.dumps(report))
