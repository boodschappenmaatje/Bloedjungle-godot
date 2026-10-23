"""Build a detailed, original military utility jeep in Blender 4.3.

Run: blender -b -t 4 --python maak_jeep.py
Blender units are metres. Vehicle front is Blender +Y (Godot -Z after glTF export).
"""

import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablock in bpy.data.materials:
    bpy.data.materials.remove(datablock)

asset = bpy.data.collections.new('Military Jeep | export')
bpy.context.scene.collection.children.link(asset)

def mat(name, color, metallic=0.0, roughness=0.7, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, alpha)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, alpha)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Alpha'].default_value = alpha
    if alpha < 1:
        m.surface_render_method = 'DITHERED'
    return m

olive = mat('01 | weathered olive drab', (0.29, 0.32, 0.19), .34, .69)
olive_light = mat('02 | sun-faded olive', (0.36, 0.38, 0.24), .26, .76)
olive_dark = mat('03 | shadowed olive', (0.19, 0.23, 0.14), .38, .72)
rubber = mat('04 | charcoal tyre rubber', (0.055, 0.056, 0.051), .02, .92)
rubber_edge = mat('05 | tyre sidewall', (0.09, 0.09, 0.08), .02, .91)
steel = mat('06 | dark gunmetal', (0.105, 0.118, 0.112), .72, .5)
bare_metal = mat('07 | worn steel', (0.33, 0.36, 0.32), .76, .48)
canvas = mat('08 | khaki seat canvas', (0.39, 0.36, 0.25), .02, .95)
canvas_dark = mat('09 | seat seams', (0.23, 0.22, 0.16), .02, .92)
glass = mat('10 | slightly tinted windshield', (0.38, 0.49, 0.48), .0, .12, .32)
lamp = mat('11 | warm headlamp glass', (0.94, 0.83, 0.56), .04, .19)
red = mat('12 | rear light lens', (0.55, 0.075, 0.04), .03, .22)
amber = mat('13 | signal lens', (0.8, 0.37, 0.06), .03, .27)
white = mat('14 | faded identification mark', (0.72, 0.72, 0.60), .02, .88)
rust = mat('15 | exposed primer', (0.35, 0.19, 0.11), .16, .91)

def put(obj, name, material):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    asset.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    return obj

def bevel(obj, amount=.015, segments=2):
    mod = obj.modifiers.new('soft manufactured edges', 'BEVEL')
    mod.width = amount
    mod.segments = segments
    mod.affect = 'EDGES'
    mod2 = obj.modifiers.new('weighted corner normals', 'WEIGHTED_NORMAL')
    mod2.keep_sharp = True
    return obj

def box(name, pos, size, material, bevel_amount=0.0, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = put(bpy.context.object, name, material)
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        o.rotation_euler = rotation
    if bevel_amount:
        bevel(o, bevel_amount)
    return o

def cyl(name, pos, radius, depth, material, vertices=20, axis='Z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    o = put(bpy.context.object, name, material)
    if axis == 'X': o.rotation_euler[1] = math.pi/2
    if axis == 'Y': o.rotation_euler[0] = math.pi/2
    bevel(o, min(.008, radius*.09), 2)
    return o

def torus(name, pos, major, minor, material, axis='Z', major_segments=40, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(major_segments=major_segments, minor_segments=minor_segments,
        location=pos, major_radius=major, minor_radius=minor)
    o = put(bpy.context.object, name, material)
    if axis == 'X': o.rotation_euler[1] = math.pi/2
    if axis == 'Y': o.rotation_euler[0] = math.pi/2
    return o

def bar(name, start, end, radius, material, vertices=10):
    a, b = Vector(start), Vector(end)
    o = cyl(name, (a+b)*.5, radius, (b-a).length, material, vertices)
    o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return o

def prism(name, points, faces, material, edge=.0):
    me = bpy.data.meshes.new(name)
    me.from_pydata(points, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    asset.objects.link(ob)
    me.materials.append(material)
    if edge: bevel(ob, edge)
    return ob

def star(name, x, y, z, outer, material):
    verts=[]
    for i in range(10):
        a = math.pi/2 + i*math.pi/5
        r = outer if i%2==0 else outer*.41
        py = y+r*math.sin(a)
        bonnet_z = 1.145 - (py-.19)*(.070/1.39) + .006
        verts.append((x+r*math.cos(a),py,bonnet_z))
    return prism(name, verts, [tuple(range(10))], material)

# Ladder chassis, longitudinal drive train, and simple visible suspension.
for x in (-.48,.48):
    box('boxed chassis rail', (x,-.02,.47), (.075,3.04,.12), steel, .012)
for y in (-1.38,-.79,.52,1.36):
    box('chassis crossmember', (0,y,.46), (1.09,.075,.09), steel, .01)
bar('prop shaft', (0,-.97,.45),(0,1.10,.45), .047, steel)
box('transfer case', (0,-.08,.50),(.34,.34,.20), steel,.045)
box('engine sump', (0,1.02,.57),(.47,.52,.22), steel,.055)
for y in (-1.07,1.10):
    cyl('solid axle centre', (0,y,.43), .12, .28, steel, 16, 'X')
    bar('solid front/rear axle',(-.85,y,.43),(.85,y,.43),.044,steel)
    for x in (-.49,.49):
        for offset in (-.11,.11):
            box('leaf spring', (x,y+offset,.51),(.083,.53,.025),steel,.012)
            bar('angled shock', (x,y-.2,.47),(x,y+.18,.72),.024,bare_metal)

# Body tub: floor, running boards, partial side doors and squared rear corners.
box('pressed steel cabin floor', (0,-.72,.665),(1.34,1.77,.095),olive_dark,.025)
box('raised transmission tunnel', (0,-.45,.74),(.31,.93,.13),olive,.032)
box('rear tailgate', (0,-1.63,.86),(1.40,.075,.43),olive,.026)
box('tailgate top rolled edge', (0,-1.64,1.095),(1.40,.055,.045),olive_light,.018)
for x in (-.69,.69):
    box('rear side panel', (x,-1.20,.89),(.075,.81,.46),olive,.021)
    box('front cowl side', (x,-.025,.89),(.075,.49,.46),olive,.022)
    box('low open side sill', (x,-.68,.70),(.078,.64,.08),olive,.018)
    box('outer step', (x*1.19,-.64,.64),(.22,.64,.055),olive_dark,.013)
    box('step anti-slip strip', (x*1.19,-.64,.677),(.17,.53,.008),rubber)
    box('rolled side rim, rear', (x,-1.19,1.135),(.09,.80,.047),olive_light,.02)
    box('rolled side rim, front', (x,-.02,1.135),(.09,.49,.047),olive_light,.02)

# Bonnet slopes slightly down toward the upright grille.
hood_v=[(-.62,.19,.86),(.62,.19,.86),(.62,1.58,.78),(-.62,1.58,.78),
        (-.62,.19,1.145),(.62,.19,1.145),(.62,1.58,1.075),(-.62,1.58,1.075)]
prism('sloped engine bonnet',hood_v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],olive,.025)
box('front grille panel',(0,1.615,.925),(1.27,.075,.305),olive_dark,.02)
for x in (-.58,.58):
    box('front mudguard wing',(x,1.07,.80),(.41,1.19,.095),olive,.044)
    box('front wing flange',(x*1.35,1.08,.76),(.047,1.16,.092),olive_dark,.015)
    box('rear wheel top cover',(x,-1.05,.84),(.29,.73,.07),olive,.035)
    box('rear fender flare',(x*1.34,-1.06,.76),(.07,.76,.14),olive_dark,.023)
box('grille upper lip',(0,1.665,1.092),(1.37,.11,.052),olive,.016)
for x in (-.38,-.19,0,.19,.38):
    box('vertical radiator vent',(x,1.659,.93),(.045,.012,.20),steel,.009)
    box('vent highlight',(x-.017,1.672,.93),(.006,.004,.18),bare_metal)
box('front bumper',(0,1.77,.57),(1.57,.095,.11),steel,.017)
for x in (-.49,.49):
    box('front bumper bracket',(x,1.67,.57),(.08,.27,.085),steel,.008)
    torus('bumper recovery eye',(x,1.84,.545),.053,.018,steel,'X',16,6)

# Functional-looking headlamp assemblies, markers and rear lights.
for x in (-.49,.49):
    cyl('black headlamp housing',(x,1.685,.975),.132,.10,steel,24,'Y')
    cyl('headlamp reflector',(x,1.748,.975),.105,.014,bare_metal,24,'Y')
    cyl('headlamp lens',(x,1.758,.975),.086,.011,lamp,24,'Y')
    torus('headlamp retaining ring',(x,1.765,.975),.105,.012,steel,'Y',24,6)
    cyl('amber marker',(x*1.49,1.575,.78),.038,.018,amber,16,'Y')
    box('rear lamp housing',(x*1.24,-1.683,.84),(.13,.05,.115),steel,.013)
    box('rear red lens',(x*1.24,-1.713,.85),(.10,.012,.07),red,.009)

# Open windscreen: two panes, divided frame, hinges, rubber seal, wipers.
for x in (-.59,0,.59):
    bar('windshield upright',(x,.13,1.105),(x,-.035,1.785),.024,steel)
bar('windshield upper frame',(-.60,-.035,1.785),(.60,-.035,1.785),.025,steel)
bar('windshield lower frame',(-.60,.13,1.105),(.60,.13,1.105),.025,steel)
for x in (-.31,.31):
    g=box('separate safety glass',(x,.047,1.45),(.55,.010,.617),glass,.003)
    g.rotation_euler[0]=-.238
    bar('wiper arm',(x+.12,-.056,1.73),(x-.11,-.042,1.37),.006,steel,8)
    bar('wiper blade',(x-.20,-.042,1.37),(x+.02,-.042,1.37),.009,rubber,8)
for x in (-.62,.62):
    cyl('windscreen folding hinge',(x,.13,1.11),.048,.065,steel,16,'X')

# Instrument panel and believable driver controls.
box('instrument dash',(0,-.01,1.075),(1.27,.12,.20),olive_dark,.023)
for x,r in ((-.32,.063),(-.17,.034),(.12,.043),(.27,.033)):
    cyl('instrument bezel',(x,-.079,1.091),r,.012,steel,20,'Y')
    cyl('instrument dark face',(x,-.087,1.091),r*.76,.008,rubber,20,'Y')
    bar('instrument needle',(x,-.096,1.091),(x+r*.45,-.096,1.091+r*.24),.003,white,6)
bar('steering column',(-.36,-.09,.91),(-.36,-.38,1.37),.028,steel)
torus('three-spoke steering wheel',(-.36,-.37,1.38),.165,.019,rubber,'Y',36,8)
cyl('steering wheel hub',(-.36,-.37,1.38),.045,.035,steel,16,'Y')
for a in (0,2*math.pi/3,4*math.pi/3):
    bar('steering spoke',(-.36,-.37,1.38),(-.36+.15*math.cos(a),-.37,1.38+.15*math.sin(a)),.012,steel,8)
bar('gear lever',(0,-.47,.75),(.03,-.49,1.00),.015,steel)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=.039, location=(.03,-.49,1.00))
put(bpy.context.object,'gear knob',rubber)
for x in (-.45,-.29,-.14):
    box('driver pedal',(x,-.23,.77),(.10,.025,.11),rubber,.007)

# Separately upholstered front bucket seats and rear bench.
for x in (-.36,.36):
    box('front seat steel pedestal',(x,-.66,.78),(.43,.38,.13),steel,.02)
    box('front seat cushion',(x,-.68,.91),(.53,.49,.16),canvas,.07)
    back=box('front seat back',(x,-.945,1.20),(.52,.12,.57),canvas,.045)
    back.rotation_euler[0]=-.095
    box('front seat upper seam',(x,-.969,1.46),(.43,.012,.012),canvas_dark,.005)
    for dx in (-.18,.18):
        box('seat cushion stitched panel',(x+dx,-.69,.997),(.006,.34,.002),canvas_dark)
box('rear bench steel base',(0,-1.405,.75),(1.17,.38,.15),steel,.025)
box('rear bench cushion',(0,-1.405,.90),(1.20,.40,.16),canvas,.058)
box('rear bench back',(0,-1.577,1.075),(1.2,.10,.28),canvas,.038)
for x in (-.40,0,.40):
    box('rear bench stitching',(x,-1.403,.984),(.008,.28,.002),canvas_dark)

# Wheels: radial tyre, paired sidewalls, inset rim, lug nuts, actual tread blocks.
def wheel(name, x, y, z=.392, axle='X', spare=False):
    side = 1 if x>0 else -1
    if spare:
        axis='Y'; center=(x,y,z)
        cyl(name+' tyre carcass',center,.337,.18,rubber,40,axis)
        torus(name+' rounded tread',center,.286,.084,rubber,axis,40,10)
        for dy in (-.091,.091):
            torus(name+' sidewall', (x,y+dy,z),.25,.045,rubber_edge,axis,40,8)
            cyl(name+' pressed wheel rim',(x,y+dy*1.25,z),.178,.026,olive_dark,32,axis)
            cyl(name+' centre cap',(x,y+dy*1.40,z),.071,.018,steel,20,axis)
        for i in range(28):
            a=2*math.pi*i/28
            bx=x+.344*math.cos(a); bz=z+.344*math.sin(a)
            b=box(name+' tread lug',(bx,y,bz),(.105,.135,.045),rubber_edge,.008)
            b.rotation_euler[1]=-a
        return
    center=(x,y,z)
    cyl(name+' radial carcass',center,.334,.185,rubber,40,'X')
    torus(name+' rounded shoulder',center,.287,.083,rubber,'X',40,10)
    for dx in (-.096,.096):
        torus(name+' tyre sidewall',(x+dx,y,z),.253,.044,rubber_edge,'X',40,8)
    outer=x+side*.117
    cyl(name+' steel rim',(outer,y,z),.186,.022,olive_dark,32,'X')
    torus(name+' rim outer lip',(outer+side*.013,y,z),.173,.013,bare_metal,'X',32,6)
    cyl(name+' inner wheel disc',(outer+side*.016,y,z),.119,.009,olive,24,'X')
    cyl(name+' axle cap',(outer+side*.026,y,z),.058,.027,steel,20,'X')
    for i in range(5):
        a=2*math.pi*i/5
        cyl(name+' wheel lug',(outer+side*.029,y+.087*math.cos(a),z+.087*math.sin(a)),.012,.010,bare_metal,8,'X')
    for i in range(28):
        a=2*math.pi*i/28
        for dx in (-.048,.048):
            yy=y+.345*math.cos(a); zz=z+.345*math.sin(a)
            block=box(name+' alternating chevron tread',(x+dx,yy,zz),(.066,.11,.044),rubber_edge,.006)
            block.rotation_euler[0]=-a
            block.rotation_euler[1]=.16 if dx>0 else -.16

for y, tag in ((1.10,'front'),(-1.07,'rear')):
    for x, side in ((-.72,'left'),(.72,'right')):
        wheel(tag+' '+side,x,y)

# Rear-mounted spare, fuel can, towing pintle and side tools.
box('spare wheel carrier',(0,-1.78,1.03),(.36,.22,.15),steel,.022)
wheel('rear spare',.32,-1.87,1.11,spare=True)
box('fuel can steel body',(-.43,-1.77,.93),(.26,.17,.43),olive_dark,.024)
box('fuel can pressed cross',(-.43,-1.868,.95),(.19,.012,.19),olive,.012)
box('fuel can neck',(-.43,-1.77,1.17),(.085,.08,.055),steel,.008)
bar('fuel can handle',(-.51,-1.77,1.20),(-.35,-1.77,1.20),.018,steel)
box('rear towing pintle',(0,-1.755,.54),(.17,.17,.09),steel,.012)
torus('rear towing loop',(0,-1.87,.54),.070,.018,steel,'X',16,6)
bar('shovel wooden shaft',(.74,-1.37,.99),(.74,-.29,.99),.016,canvas,10)
box('shovel spade',(.74,-1.43,.99),(.075,.19,.07),steel,.02)
for y in (-1.15,-.55):
    box('shovel retaining strap',(.754,y,1.00),(.025,.065,.063),canvas_dark,.006)

# A subdued identification star and small wear chips add readable scale.
star('faded five point bonnet star',0,.78,1.120,.235,white)
for x,y,z in ((-.61,1.48,1.075),(.55,1.43,1.08),(-.60,.29,1.145),(.52,.23,1.14),
              (-.68,-1.47,1.10),(.68,-1.37,1.10)):
    box('small edge paint chip',(x,y,z),(.043,.021,.003),rust,.001)
for x in (-.46,.46):
    for y in (.40,1.43):
        cyl('bonnet fixing bolt',(x,y,1.133),.012,.008,bare_metal,8)

# Flatten the many editable parts to a single export mesh with material groups.
# The .blend retains all individual parts for further editing.
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects: o.select_set(True)
bpy.context.view_layer.objects.active = next(iter(asset.objects))
bpy.ops.object.duplicate()
for o in list(bpy.context.selected_objects):
    bpy.context.view_layer.objects.active = o
    for modifier in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
bpy.ops.object.join()
export_mesh = bpy.context.view_layer.objects.active
export_mesh.name = 'Bloedjungle | Army Jeep'
bpy.ops.export_scene.gltf(filepath=str(ROOT/'jeep.glb'), export_format='GLB',
    use_selection=True, export_apply=True, export_yup=True, export_materials='EXPORT',
    export_cameras=False, export_lights=False)
bpy.data.objects.remove(export_mesh, do_unlink=True)

studio = bpy.data.collections.new('Preview only | excluded from GLB')
bpy.context.scene.collection.children.link(studio)
def studio_link(o):
    for c in list(o.users_collection): c.objects.unlink(o)
    studio.objects.link(o)
    return o
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,.006))
ground=studio_link(bpy.context.object)
ground.name='preview ground'
ground.data.materials.append(mat('Preview background',(.22,.225,.205),0,.95))

world=bpy.context.scene.world
world.color=(.28,.28,.28)
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.48,.51,.54,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.75
def area(name, loc, power, size, target):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    ob=bpy.data.objects.new(name,data); studio.objects.link(ob); ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
area('large softbox',(-3,2,6),1050,5,(0,0,.7))
area('rim light',(3,-3,4),850,4,(0,0,1))
cam_data=bpy.data.cameras.new('three-quarter product camera')
camera=bpy.data.objects.new('three-quarter product camera',cam_data)
studio.objects.link(camera)
camera.location=(4.7,5.7,3.35)
camera.rotation_euler=(Vector((0,0,1.0))-camera.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO'; cam_data.ortho_scale=4.9
bpy.context.scene.camera=camera
bpy.context.scene.render.engine='CYCLES'
bpy.context.scene.cycles.samples=48
bpy.context.scene.cycles.use_denoising=False
bpy.context.scene.render.resolution_x=1280
bpy.context.scene.render.resolution_y=960
bpy.context.scene.render.resolution_percentage=100
bpy.context.scene.render.image_settings.file_format='PNG'
bpy.context.scene.render.filepath=str(ROOT/'preview.png')
bpy.context.scene.view_settings.view_transform='AgX'
bpy.context.scene.render.film_transparent=False
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'jeep.blend'))
bpy.ops.render.render(write_still=True)
print(f'EXPORTED {len(asset.objects)} asset objects to {ROOT}')
