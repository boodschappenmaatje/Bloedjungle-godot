"""Add realistic runway, ATC tower, aircraft shop, and flight/day-night animation."""
import bpy, math, pathlib
from mathutils import Vector
ROOT = pathlib.Path(__file__).resolve().parents[1]
SC = bpy.context.scene
SC.frame_start, SC.frame_end, SC.render.fps = 1, 600, 30
SC.unit_settings.system = 'METRIC'

# Clear the previous compact runway and terrain footprint while retaining the hangar.
def remove_obj(o): bpy.data.objects.remove(o, do_unlink=True)
for o in list(bpy.data.objects):
    n=o.name.lower()
    if o.name.startswith('Terrain slab') or any(k in n for k in ('runway 09/27','runway left threshold','runway far threshold','runway center dash','runway edge stripe','runway side bar','threshold piano key','runway edge marker','runway designation','oil spill / tire scuff')):
        remove_obj(o)
# Replace the temporary single aircraft with two display / flyable aircraft.
for o in list(bpy.data.collections.get('06 Jet Placeholder - REPLACE').objects): remove_obj(o)
COL_AIR=bpy.data.collections.get('01 Airfield')
COL_HANG=bpy.data.collections.get('02 Hangar Structure')
COL_INT=bpy.data.collections.get('03 Hangar Interior')
COL_ROOF=bpy.data.collections.get('07 Roof - Toggle for interior')
COL_LIGHT=bpy.data.collections.get('05 Warning Beacons')
COL_PREV=bpy.data.collections.get('08 Preview Rig')
COL_AIRF=bpy.data.collections.new('09 Aircraft Shop | purchase metadata'); SC.collection.children.link(COL_AIRF)
COL_TWR=bpy.data.collections.new('10 Control Tower'); SC.collection.children.link(COL_TWR)
COL_LUX=bpy.data.collections.new('11 VIP Lounge'); SC.collection.children.link(COL_LUX)

# Materials, with simple PBR noise and optional emissive shading.
def material(name, color, metal=0, rough=.55, emission=None):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    if emission:
        slot=bs.inputs.get('Emission Color') or bs.inputs.get('Emission')
        if slot: slot.default_value=(*emission[0],1)
        if bs.inputs.get('Emission Strength'): bs.inputs['Emission Strength'].default_value=emission[1]
    return m
ASPH=material('Runway | fine aggregate asphalt',(.055,.065,.068),0,.86)
CONC=material('Apron extension | brushed concrete',(.29,.31,.30),.04,.82)
MARK=material('Runway marking | reflective white',(.88,.88,.79),.0,.42)
YEL=material('Taxi guidance | safety yellow',(.96,.61,.08),.03,.48)
WHITE_L=material('Runway lamps | cool white',(.75,.85,1),.0,.2,((.63,.8,1),4))
GREEN_L=material('Runway threshold | green',(.025,.55,.09),.0,.18,((.015,.9,.12),6))
RED_L=material('Runway end | red',(.75,.008,.005),.0,.18,((1,.005,.002),6))
RED=material('Airfield beacon | flashing red',(.9,.006,.002),.0,.18,((1,.002,.001),5))
BLUE_L=material('Taxiway edge | blue',(.025,.16,.9),.0,.18,((.02,.18,1),4))
GLASS_L=material('ATC glass | blue tinted',(.045,.20,.28),.5,.16)
GOLD=material('VIP trim | champagne metal',(.54,.36,.14),.72,.3)
PANEL=material('Hangar cladding | satin steel',(.29,.32,.30),.72,.43)
STEEL=material('Hangar structure | olive steel',(.17,.20,.17),.58,.58)
DARK=material('Aircraft | charcoal olive',(.15,.19,.17),.56,.39)
JET_GLASS=material('Aircraft canopy | smoked teal',(.025,.11,.15),.72,.13)
JET_EX=material('Engine exhaust | idle',(.24,.055,.008),.12,.23,((.15,.018,.003),.6))
PROP=material('Trainer | pearl silver',(.64,.67,.63),.48,.33)

# Basic geometry helpers.
def box(name, loc, dims, mat, col, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Machined soft edges','BEVEL'); mod.width=bevel; mod.segments=2
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def cyl(name, loc, radius, depth, mat, col, vertices=16, rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    o=bpy.context.object; o.name=name
    if rot: o.rotation_euler=rot
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); o.data.materials.append(mat); return o

def sphere(name, loc, scale, mat, col):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); o.data.materials.append(mat); return o

def txt(name, body, loc, size, mat, col, rot=(math.pi/2,0,0)):
    cu=bpy.data.curves.new(name,'FONT'); cu.body=body; cu.size=size; cu.extrude=.006; cu.align_x='CENTER'; cu.align_y='CENTER'
    o=bpy.data.objects.new(name,cu); col.objects.link(o); o.location=loc; o.rotation_euler=rot; cu.materials.append(mat); return o

def mesh(name, verts, faces, mat, col, parent=None):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.materials.append(mat); me.update()
    o=bpy.data.objects.new(name,me); col.objects.link(o); o.parent=parent; return o

# Realistic-scale terrain and 1.1 km runway; runway 09/27 along the Y axis.
box('Terrain slab | airfield apron',(0,-800,-.72),(720,2000,1.25),material('Terrain | jungle airbase',( .10,.14,.10),0,.97),COL_AIR)
box('Runway 09/27 | 1100 m',(0,-750,-.035),(45,1100,.22),ASPH,COL_AIR,.06)
# Runway shoulders and threshold markings.
for x in (-25.5,25.5): box('Runway shoulder',(x,-750,-.055),(4.5,1100,.18),CONC,COL_AIR,.04)
for x in (-22.4,22.4): box('Runway edge stripe',(x,-750,.085),(.24,1097,.025),MARK,COL_AIR)
for y in (-205,-1295):
    for i in range(12):
        x=-18.8+i*3.42; box('Threshold piano key',(x,y,.105),(1.65,15,.03),MARK,COL_AIR,.015)
for y in range(-235,-1280,-30): box('Runway centerline dash',(0,y,.11),(.55,13,.03),MARK,COL_AIR)
# Runway numbers and aiming-point bars.
txt('Runway designation 09','09',(0,-230,.14),7,MARK,COL_AIR,(0,0,0))
txt('Runway designation 27','27',(0,-1270,.14),7,MARK,COL_AIR,(0,0,0))
for x in (-6.5,6.5): box('Aiming point bar',(x,-750,.11),(1.35,42,.03),MARK,COL_AIR)
# A simple paved connection from the existing apron to the runway threshold.
box('Connector taxiway',(0,-155,.015),(24,100,.22),CONC,COL_AIR,.06)
box('Taxi centerline',(0,-155,.14),(.18,98,.025),YEL,COL_AIR)
for x in (-11.7,11.7):
    for y in range(-108,-202,-12): cyl('Taxiway blue edge lamp',(x,y,.43),.18,.2,BLUE_L,COL_AIR,10)
# Correct lighting palette: white edges, green threshold, red runway end; blue taxiway edges.
for x in (-23.2,23.2):
    for y in range(-220,-1301,-30): cyl('Runway white edge lamp',(x,y,.38),.16,.22,WHITE_L,COL_AIR,10)
    for y,mat in ((-197,GREEN_L),(-1303,RED_L)):
        for dx in (-15,-10,-5,0,5,10,15): cyl('Threshold / runway-end lamp',(x+dx,y,.38),.18,.22,mat,COL_AIR,10)
# Centerline approach strobes in the clear approach beyond the threshold.
for y in range(-130,-190,-10):
    for x in (-3.5,0,3.5):
        o=cyl('Approach sequenced strobe',(x,y,.45),.15,.2,WHITE_L,COL_AIR,10)
        for f,v in ((1,.1),(12,1.0),(22,.1),(32,.1),(42,1.0),(52,.1)):
            o.scale=(v,v,v); o.keyframe_insert(data_path='scale',frame=f)
# Runway and taxiway identifiers.
txt('Taxiway identifier A','A',(-8,-120,.26),3,YEL,COL_AIR,(0,0,0))

# Extend the main apron so it connects cleanly to the new runway approach.
box('Apron extension | taxi lead-in',(0,-85,.03),(72,84,.24),CONC,COL_AIR,.07)
for x in (-34,34):
    for y in range(-118,-45,8): box('Apron boundary marking',(x,y,.17),(.22,3.2,.025),YEL,COL_AIR)

# VIP frontage annex: glazed lounge, brass canopy, entrance lights and seating cues.
box('VIP lounge foundation',(19,0,.30),(11,17,.55),CONC,COL_LUX,.08)
box('VIP lounge rear wall',(19,8.2,3.3),(11,.25,6.0),PANEL,COL_LUX,.025)
for x in (13.7,24.3): box('VIP lounge side pier',(x,0,3.3),(.32,16.2,6.0),STEEL if 'STEEL' in globals() else material('VIP dark frame',(.1,.14,.14),.7,.3),COL_LUX,.03)
for y in (-7.8,-3.9,0,3.9):
    box('VIP panoramic window',(19,y,3.5),(10.1,.12,4.9),GLASS_L,COL_LUX,.02)
    box('VIP window mullion',(19,y,3.85),(.10,.2,5.6),GOLD,COL_LUX,.015)
box('VIP roof canopy',(19,0,6.45),(12,18,.28),GOLD,COL_LUX,.05)
box('VIP arrival canopy',(19,-10,3.6),(12,4,.28),GOLD,COL_LUX,.04)
for x in (15,19,23):
    cyl('VIP canopy column',(x,-10,1.75),.15,3.5,GOLD,COL_LUX,12)
    sphere('VIP entry sconce',(x,-10.2,4.8),(.18,.12,.18),WHITE_L,COL_LUX)
txt('VIP frontage sign','AIR WING  /  VIP LOUNGE',(19,-8.45,6.9),.62,MARK,COL_LUX)

# Aircraft store wall panel and pricing data, visible in the hangar interior.
box('Aircraft store fascia',(0,9.72,7.7),(15,.18,2.0),STEEL,COL_INT,.06)
txt('Aircraft store header','AIRCRAFT EXCHANGE',(0,9.60,8.15),.72,MARK,COL_INT)
txt('Aircraft store balance','SPEND FLIGHT POINTS  /  EARN POINTS PER SORTIE',(0,9.58,7.45),.32,YEL,COL_INT)
box('Aircraft store counter',(0,7.2,1.35),(8,1.5,1.5),STEEL,COL_INT,.07)
box('Store counter top',(0,7.2,2.12),(8.3,1.7,.14),GOLD,COL_INT,.025)
box('Store display screen',(0,6.28,2.7),(4.2,.12,1.1),GLASS_L,COL_INT,.04)
txt('Store display models','TRAINER  1,250 PTS     FIGHTER  12,000 PTS',(0,6.17,2.72),.29,MARK,COL_INT)

# Control tower on the apron edge: reinforced shaft, panoramic cab, radar and antenna.
box('ATC tower foundation',(51,-25,.24),(12,12,.48),CONC,COL_TWR,.08)
box('ATC tower shaft',(51,-25,8.4),(7.2,7.2,16.2),PANEL,COL_TWR,.08)
for z in (2.2,7.7,13.2):
    box('ATC shaft window band',(51,-28.65,z),(5.5,.08,1.6),GLASS_L,COL_TWR,.02)
for x in (48.5,53.5): box('ATC shaft corner rib',(x,-28.78,8.4),(.15,.16,16),STEEL if 'STEEL' in globals() else DARK,COL_TWR,.02)
box('ATC cab floor',(51,-25,17.3),(13,13,.6),GOLD,COL_TWR,.05)
box('ATC control room',(51,-25,20.1),(13,13,5.2),GLASS_L,COL_TWR,.06)
for x in (44.5,47.8,51,54.2,57.5): box('ATC panoramic mullion',(x,-31.57,20.1),(.12,.14,4.8),GOLD,COL_TWR,.01)
for y in (-31.5,-28.3,-25,-21.7,-18.5): box('ATC cab side mullion',(57.57,y,20.1),(.14,.12,4.8),GOLD,COL_TWR,.01)
box('ATC cab roof',(51,-25,22.9),(14,14,.55),STEEL if 'STEEL' in globals() else DARK,COL_TWR,.06)
txt('ATC tower ID','ATC',(51,-31.8,21.6),.9,MARK,COL_TWR)
radar=cyl('Animated ATC radar antenna',(51,-25,24.2),.22,.65,GOLD,COL_TWR,12)
radar_plate=box('Rotating radar reflector',(51,-25,25.2),(7.8,.32,.16),GOLD,COL_TWR,.03)
radar_plate.parent=radar; radar_plate.location=(0,0,1.0)
radar.rotation_euler.z=0; radar.keyframe_insert(data_path='rotation_euler',index=2,frame=1); radar.rotation_euler.z=2*math.pi; radar.keyframe_insert(data_path='rotation_euler',index=2,frame=180)
for fc in radar.animation_data.action.fcurves:
    for kp in fc.keyframe_points: kp.interpolation='LINEAR'
radar.animation_data.action.name='ATC radar | continuous sweep'
# Obstruction beacons on the tower and hangar.
for loc in ((51,-25,25.7),(47,-25,23.3),(55,-25,23.3)):
    o=sphere('RED_BLINK_ATC_OBSTRUCTION',loc,(.24,.24,.24),RED,COL_LIGHT)
    o['blink_rate_hz']=1.0
    for f in range(1,601,10):
        s=1 if ((f//10)%2)==0 else .12; o.scale=(s,s,s); o.keyframe_insert(data_path='scale',frame=f)

# Procedural but properly named aircraft models. Local axis: nose towards -Y.
def aircraft(name, kind, cost, display, col):
    root=bpy.data.objects.new(name,None); col.objects.link(root); root.location=display or (0,0,0)
    root['aircraft_class']=kind; root['purchase_cost_points']=cost; root['purchased']=False
    root['player_flyable']=True; root['purchase_unlock']='Earn points from takeoff, flight objectives, and safe landings.'
    # Loft the fuselage from a compact nose to a tapered tail.
    rings=[(-7.0,.08,.09),(-5.8,.34,.31),(-2.5,.62,.52),(1.5,.68,.58),(5.2,.42,.39),(6.4,.20,.22)]
    verts=[]; sides=12
    for y,rx,rz in rings:
        for i in range(sides):
            a=2*math.pi*i/sides; verts.append((rx*math.cos(a),y,1.35+rz*math.sin(a)))
    faces=[]
    for j in range(len(rings)-1):
        for i in range(sides): faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    faces += [tuple(range(sides-1,-1,-1)),tuple((len(rings)-1)*sides+i for i in range(sides))]
    bodymat=DARK if kind=='fighter' else PROP
    mesh(name+' | fuselage',verts,faces,bodymat,col,root)
    if kind=='fighter':
        mesh(name+' | swept delta wings',[(-.5,-1,1.25),(-5.8,1.2,1.25),(-4.8,3.5,1.25),(4.8,3.5,1.25),(5.8,1.2,1.25),(.5,-1,1.25)],[(0,1,2,3,4,5)],bodymat,col,root)
        mesh(name+' | tailplane',[(-.4,4.1,1.8),(-2.6,5.5,1.8),(2.6,5.5,1.8),(.4,4.1,1.8)],[(0,1,2,3)],bodymat,col,root)
        for x in (-.7,.7): mesh(name+' | vertical tail',[(x,3.3,1.6),(x*2.2,5.4,3.2),(x*2.2,3.8,3.1)],[(0,1,2)],bodymat,col,root)
    else:
        mesh(name+' | high wing',[(-6,0,2.4),(-.6,-1.2,2.4),(.6,-1.2,2.4),(6,0,2.4),(5.2,1.3,2.4),(-5.2,1.3,2.4)],[(0,1,2,3,4,5)],bodymat,col,root)
        for x in (-3.1,3.1):
            nac=cyl(name+' | prop nacelle',(x,0,2.0),.36,2.6,bodymat,col,12,(math.pi/2,0,0)); nac.parent=root; nac.location=(x,0,2.0)
            wheel=cyl(name+' | main tire',(x,-1.8,.45),.3,.18,material('Aircraft tires',(.02,.022,.02),0,.85),col,12,(0,math.pi/2,0)); wheel.parent=root; wheel.location=(x,-1.8,.45)
        wheel=cyl(name+' | nose tire',(0,-4.8,.4),.23,.16,material('Aircraft tires',(.02,.022,.02),0,.85),col,12,(0,math.pi/2,0)); wheel.parent=root; wheel.location=(0,-4.8,.4)
        prop=bpy.data.objects.new(name+' | spinning propeller',None); col.objects.link(prop); prop.parent=root; prop.location=(0,-6.55,1.35)
        for angle in (0,2*math.pi/3,4*math.pi/3):
            blade=box(name+' | propeller blade',(0,0,0),(.17,.12,1.35),DARK,col,.04); blade.parent=prop; blade.location=(0,0,.68); blade.rotation_euler.y=angle
        prop.rotation_euler.y=0; prop.keyframe_insert(data_path='rotation_euler',index=1,frame=1); prop.rotation_euler.y=2*math.pi*24; prop.keyframe_insert(data_path='rotation_euler',index=1,frame=40)
        for fc in prop.animation_data.action.fcurves:
            for kp in fc.keyframe_points: kp.interpolation='LINEAR'
        prop.animation_data.action.name='Trainer propeller | start and spin'
    canopy=sphere(name+' | canopy',(0,-2.2,1.82),(.40,1.25,.38),JET_GLASS,col); canopy.parent=root; canopy.location=(0,-2.2,1.82)
    for x in (-.6,.6):
        eng=cyl(name+' | exhaust glow',(x,5.5,1.25),.25,.12,JET_EX,col,12,(math.pi/2,0,0)); eng.parent=root; eng.location=(x,5.5,1.25)
        for f,s in ((1,.08),(22,.08),(32,.5),(46,1),(70,1),(85,.35),(100,.85),(130,1),(155,.25),(180,1),(210,.1),(250,.1)):
            eng.scale=(s,s,s); eng.keyframe_insert(data_path='scale',frame=f)
    # Gear, understated markings, and shop plinth for the display copy.
    for x,y in ((0,4.8),(-3,-1),(3,-1)):
        if kind=='fighter' and y==4.8: continue
        tire=cyl(name+' | landing tire',(x,y,.38),.34,.19,material('Aircraft tires',(.02,.022,.02),0,.85),col,12,(0,math.pi/2,0)); tire.parent=root; tire.location=(x,y,.38)
    if display:
        box(name+' | display stand',(display[0],display[1],.33),(15,10,.55),STEEL,col,.08)
        txt(name+' | points placard',f'{kind.upper()}   /   {cost:,} PTS',(display[0],display[1]-4.9,1.5),.4,YEL,col)
    return root

# Store-display versions have a catalogue tag; the fighter also carries taxi/takeoff/landing clips.
trainer=aircraft('AIRCRAFT_TRAINER | purchasable','trainer',1250,(-6,1,0),COL_AIRF)
fighter=aircraft('AIRCRAFT_FIGHTER | purchasable','fighter',12000,(6,1,0),COL_AIRF)
# The fighter clip parks in the display bay, taxis to the runway, takes off, then lands and returns.
def action_clip(root,name,keys):
    act=bpy.data.actions.new(name); root.animation_data_create(); root.animation_data.action=act
    for frame,loc,zrot in keys:
        root.location=loc; root.rotation_euler.z=zrot
        root.keyframe_insert(data_path='location',frame=frame,group='Aircraft movement')
        root.keyframe_insert(data_path='rotation_euler',index=2,frame=frame,group='Aircraft movement')
    root.animation_data.action=None
    tr=root.animation_data.nla_tracks.new(); tr.name=name
    st=tr.strips.new(name,keys[0][0],act); st.blend_type='REPLACE'; st.extrapolation='NOTHING'
    for fc in act.fcurves:
        for kp in fc.keyframe_points: kp.interpolation='BEZIER'
    return st
# Existing stored copy remains in the shop when viewed at frame 1. Demo duplicate performs flight path.
flying=aircraft('AIRCRAFT_FIGHTER | flight demo','fighter',12000,None,COL_AIRF)
flying['purchase_catalogue_entry']='AIRCRAFT_FIGHTER | purchasable'
flying.location=(6,1,0)
action_clip(flying,'fighter_taxi_and_takeoff',[(1,(6,1,0),0),(35,(6,-12,0),0),(65,(0,-80,0),0),(95,(0,-205,0),0),(215,(0,-1320,0),0),(250,(0,-1530,95),0)])
action_clip(flying,'fighter_approach_and_landing',[(301,(0,-1530,95),0),(423,(0,-220,0),0),(452,(0,-150,0),0),(480,(18,-70,0),math.pi/2),(515,(18,-35,0),math.pi/2)])
flying.location=(6,1,0); flying.rotation_euler.z=0; SC.frame_set(1)

# Day/night cycle: sun, world illumination, and practical airport lights.
bpy.ops.object.light_add(type='SUN',location=(0,0,150)); sun=bpy.context.object; sun.name='Day-night cycle | sun';
for c in list(sun.users_collection): c.objects.unlink(sun)
COL_PREV.objects.link(sun); sun.data.energy=2.0; sun.rotation_euler=(math.radians(22),math.radians(-25),math.radians(-30))
for f,energy,rx in ((1,2.0,math.radians(22)),(170,1.2,math.radians(68)),(250,.035,math.radians(93)),(390,.025,math.radians(95)),(520,1.2,math.radians(60)),(600,2.0,math.radians(22))):
    sun.data.energy=energy; sun.data.keyframe_insert(data_path='energy',frame=f)
    sun.rotation_euler.x=rx; sun.keyframe_insert(data_path='rotation_euler',frame=f)
# Explicit scene markers and reusable frame labels.
for name,frame in (('DAY',1),('HANGAR_DOORS_OPEN',70),('FIGHTER_TAKEOFF',250),('NIGHT',390),('FIGHTER_LANDING',423),('DAWN',600)):
    SC.timeline_markers.new(name,frame=frame)
SC['points_economy']='Aircraft objects include purchase_cost_points and purchased metadata. Award points after flight objectives and safe landings in the game runtime.'
SC['night_cycle']='Animated sun energy and elevation; runway, threshold, taxiway and obstruction lights are emissive.'
SC['phase_status']='Airfield 4.0 — runway, VIP hangar, tower, aircraft shop, day/night and flight animation complete'
SC.render.resolution_x,SC.render.resolution_y,SC.render.resolution_percentage=1600,900,100
# Set scene camera and viewport to cover all extended runway and airbase.
cam=bpy.data.objects.get('Preview camera | overview')
if cam:
    cam.location=(520,-1320,560); cam.rotation_euler=(Vector((0,-760,0))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=1920
SC.camera=cam
SC.frame_set(1)
# Preserve a clean editor viewport and save as the project's primary file.
SC['project']='BLOEDJUNGLE — MILITARY AIRFIELD 4.0'
SC.render.image_settings.file_format='PNG'
SC.render.engine='CYCLES'; SC.cycles.device='CPU'; SC.cycles.samples=16
SC.render.resolution_percentage=55
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Bloedjungle-Airfield.blend'))
# Create an overview preview and a night preview for the two important lighting states.
SC.render.filepath=str(ROOT/'preview_overview.png'); SC.frame_set(1); bpy.ops.render.render(write_still=True)
SC.render.filepath=str(ROOT/'preview_night.png'); SC.frame_set(390); bpy.ops.render.render(write_still=True)
SC.render.filepath='//'
SC.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Bloedjungle-Airfield.blend'))
print('AIRFIELD_UPGRADE_COMPLETE', bpy.app.version_string, len(SC.objects), str(ROOT/'Bloedjungle-Airfield.blend'))
