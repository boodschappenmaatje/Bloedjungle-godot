import bpy, pathlib, math
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Bloedjungle-Airfield.blend'))
S=bpy.context.scene
COL=bpy.data.collections.new('12 Ground Operations | lighting and service')
S.collection.children.link(COL)
def mat(name,color,metal=0,rough=.5,emit=None):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    if emit:
        inp=bs.inputs.get('Emission Color') or bs.inputs.get('Emission'); inp.default_value=(*emit[0],1); bs.inputs['Emission Strength'].default_value=emit[1]
    return m
rubber=mat('Service vehicle tires',(.018,.02,.02),0,.9); white=mat('Service vehicle warm white',(.7,.72,.68),.25,.38); olive=mat('Service vehicle olive drab',(.17,.21,.16),.5,.42); fire=mat('Airport fire vehicle red',(.72,.025,.012),.2,.4); glass=mat('Vehicle glass',(.035,.13,.17),.55,.16); green=mat('Perimeter jungle canopy',(.035,.095,.045),0,.92); green2=mat('Perimeter jungle highlights',(.065,.14,.055),0,.9); trunk=mat('Tropical tree trunks',(.16,.105,.055),0,.9)
def box(n,l,d,m,b=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=l); o=bpy.context.object; o.name=n; o.dimensions=d; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m); COL.objects.link(o)
    for c in list(o.users_collection):
        if c!=COL:c.objects.unlink(o)
    if b:
        md=o.modifiers.new('Soft fabricated corners','BEVEL'); md.width=b; md.segments=2; bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=md.name)
    return o
def cyl(n,l,r,d,m,rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d,location=l); o=bpy.context.object; o.name=n; o.data.materials.append(m); COL.objects.link(o)
    for c in list(o.users_collection):
        if c!=COL:c.objects.unlink(o)
    if rot:o.rotation_euler=rot
    return o
def sphere(n,l,s,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=l); o=bpy.context.object; o.name=n; o.scale=s; o.data.materials.append(m); COL.objects.link(o)
    for c in list(o.users_collection):
        if c!=COL:c.objects.unlink(o)
    return o
# Ground vehicles on the apron add scale and believable activity.
def vehicle(name,x,y,bodymat,length=6):
    box(name+' | chassis',(x,y,1.35),(2.4,length,1.25),bodymat,.22)
    box(name+' | cab',(x,y-1.25,2.35),(2.25,2.5,1.1),white,.16)
    box(name+' | windshield',(x,y-2.54,2.55),(1.75,.08,.62),glass,.04)
    for sx in (-1.25,1.25):
        for sy in (-length*.32,length*.32): cyl(name+' | wheel',(x+sx,y+sy,.7),.53,.32,rubber,(0,math.pi/2,0))
    beacon=sphere(name+' | beacon',(x,y-1.25,3.02),(.22,.22,.13),mat('Vehicle amber strobe',(.9,.25,.02),0,.15,((1,.12,.005),4)))
    for f,sc in ((1,1),(10,.15),(20,1),(30,.15),(40,1)):
        beacon.scale=(sc,sc,sc); beacon.keyframe_insert(data_path='scale',frame=f)
vehicle('Fire and rescue truck',-25,-29,fire,7)
vehicle('Aircraft tug',26,-42,olive,4.5)
vehicle('Fuel service truck',-24,-48,olive,8)
# Apron floodlight masts with dusk/night illumination.
for x,y in ((-38,-35),(38,-35),(-38,-100),(38,-100)):
    cyl('Apron high mast',(x,y,10),.20,20,olive)
    box('Floodlight crossbar',(x,y,19.7),(3.2,.22,.2),olive,.04)
    for dx in (-1,0,1):
        sphere('Floodlight lens',(x+dx,y-.2,19.4),(.18,.12,.13),mat('Floodlight emission',(.8,.9,1),0,.2,((.72,.82,1),7)))
        bpy.ops.object.light_add(type='AREA',location=(x+dx,y,19.3)); l=bpy.context.object; l.name='Apron floodlight | night'; l.data.energy=2200; l.data.shape='DISK'; l.data.size=2; l.rotation_euler=(math.radians(22),0,0); COL.objects.link(l)
        for c in list(l.users_collection):
            if c!=COL:c.objects.unlink(l)
# Jungle belt set well outside the runway protected area.
for side in (-1,1):
    for i,y in enumerate(range(-170,-1750,-110)):
        x=side*(286+((i*37)%40))
        h=18+(i%4)*3
        cyl('Jungle tree trunk',(x,y,h*.42),.65,h*.85,trunk)
        sphere('Jungle canopy',(x,y,h), (7+(i%3),7+(i%2)*2,8),green if i%2 else green2)
        sphere('Jungle canopy cluster',(x+side*5,y+2,h-3),(5,5,6),green2 if i%2 else green)
# Add interior and tower lighting so evening is readable.
for loc,power,color,size in (((0,-1,10.4),2600,(.9,.84,.68),9),((19,0,5.9),1800,(.84,.72,.48),6),((51,-25,22),1200,(.55,.73,1),5)):
    bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object; l.name='Airfield practical | interior'; l.data.energy=power; l.data.shape='DISK'; l.data.size=size; COL.objects.link(l)
    for c in list(l.users_collection):
        if c!=COL:c.objects.unlink(l)
# Hero view shows the luxury hangar, shop aircraft, tower and the start of the runway.
cam_data=bpy.data.cameras.new('Camera data | airfield hero'); cam=bpy.data.objects.new('Camera | airfield hero',cam_data); COL.objects.link(cam)
cam.location=(210,-285,210); target=Vector((0,-65,0)); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=360; cam.data.lens=42
S.camera=cam
# Separate high overview camera makes the complete runway length easy to inspect.
map_data=bpy.data.cameras.new('Camera data | runway overview'); mapcam=bpy.data.objects.new('Camera | runway overview',map_data); COL.objects.link(mapcam)
mapcam.location=(180,-700,1500); mapcam.rotation_euler=(Vector((0,-800,0))-mapcam.location).to_track_quat('-Z','Y').to_euler(); mapcam.data.type='ORTHO'; mapcam.data.ortho_scale=1780
S['presentation_cameras']='Camera | airfield hero and Camera | runway overview'
S.render.engine='CYCLES'; S.cycles.device='CPU'; S.cycles.samples=24; S.render.resolution_x=1600; S.render.resolution_y=900; S.render.resolution_percentage=70
S.frame_set(1); S.render.filepath=str(ROOT/'preview_overview.png'); bpy.ops.render.render(write_still=True)
S.render.resolution_percentage=60; S.render.filepath=str(ROOT/'preview_night.png'); S.frame_set(390); bpy.ops.render.render(write_still=True)
S.camera=cam; S.frame_set(1); S.render.resolution_percentage=100; bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Bloedjungle-Airfield.blend'))
print('POLISH_COMPLETE',len(S.objects))
