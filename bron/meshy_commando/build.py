"""Build the player-only commando on the original Meshy 28-bone skin.
Run: blender -b -t 4 --python bron/meshy_commando/build.py
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/meshy_jungle_commando.glb'
OUT = ROOT / 'assets/meshy_commando_aaa.glb'
BLEND = ROOT / 'bron/meshy_commando/meshy_commando_aaa.blend'
TEX = ROOT / 'bron/soldaat_vq2/jungle_commando'

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
rig = bpy.data.objects['target_character']
rig.data.pose_position = 'REST'
base = bpy.data.objects['Mesh0']
added = []

def textile(name, prefix, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .82
    bsdf.inputs['Metallic'].default_value = .0
    for kind, socket, space in [('albedo', 'Base Color', 'sRGB'), ('roughness', 'Roughness', 'Non-Color')]:
        path = TEX / f'{prefix}_{kind}_512.png'
        if not path.exists():
            continue
        image = bpy.data.images.load(str(path), check_existing=True)
        image.colorspace_settings.name = space
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = image
        mat.node_tree.links.new(node.outputs['Color'], bsdf.inputs[socket])
    path = TEX / f'{prefix}_normal_512.png'
    if path.exists():
        image = bpy.data.images.load(str(path), check_existing=True)
        image.colorspace_settings.name = 'Non-Color'
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = image
        normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value = .45
        mat.node_tree.links.new(node.outputs['Color'], normal.inputs['Color'])
        mat.node_tree.links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
    return mat

def solid(name, color, rough=.75, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metallic
    return mat

nylon = textile('Olive nylon · PBR', 'olive_nylon', (.28,.31,.16))
webbing = textile('Dark olive webbing · PBR', 'dark_olive_webbing', (.16,.19,.10))
steel = textile('Parkerized steel · PBR', 'parkerized_steel', (.13,.15,.12))
rubber = solid('Headset rubber', (.055,.065,.055), .86)
lens = solid('Radio indicator glass', (.075,.18,.09), .35)

# Every new part is skinned to one existing bone. The head remains free to
# rotate, and the radio follows the vest instead of floating through the neck.
def skin(obj, bone, material):
    bpy.ops.object.select_all(action='DESELECT')
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    mod = obj.modifiers.new('Existing Mixamo skeleton', 'ARMATURE')
    mod.object = rig
    obj.data.materials.append(material)
    if not obj.data.uv_layers:
        uv = obj.data.uv_layers.new(name='Accessory UV')
        for loop in obj.data.loops:
            co = obj.data.vertices[loop.vertex_index].co
            uv.data[loop.index].uv = ((math.atan2(co.y, co.x) / (2 * math.pi)) % 1, co.z * 2 % 1)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    added.append(obj)
    return obj

def mesh(name, verts, faces, bone, material):
    datab = bpy.data.meshes.new(name)
    datab.from_pydata(verts, [], faces)
    datab.update()
    obj = bpy.data.objects.new(name, datab)
    bpy.context.collection.objects.link(obj)
    return skin(obj, bone, material)

def box(name, center, size, bone, material, bevel=.004):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        m=obj.modifiers.new('Soft machined edges','BEVEL');m.width=bevel;m.segments=2
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=m.name)
    return skin(obj,bone,material)

def tube(name, points, radius, bone, material, sides=8):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=16
    curve.bevel_depth=radius;curve.bevel_resolution=2
    poly=curve.splines.new('POLY');poly.points.add(len(points)-1)
    for point, xyz in zip(poly.points,points):
        point.co=(*xyz,1)
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH')
    return skin(bpy.context.object,bone,material)

def cap(name, center, radius, depth, bone, material, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center, rotation=(0,math.pi/2,0))
    obj=bpy.context.object;obj.name=name
    return skin(obj,bone,material)

HEAD='mixamorig:Head'
SPINE='mixamorig:Spine2'
# Low-profile shell: open front beneath the brow, no visor over the face.
verts=[];faces=[];count=32
rings=[(1.608,.123,.140),(1.645,.139,.151),(1.692,.125,.134),(1.730,.086,.097),(1.751,.018,.025)]
for z,rx,ry in rings:
    for i in range(count):
        a=2*math.pi*i/count
        verts.append((rx*math.cos(a),-.012+ry*math.sin(a),z))
for row in range(len(rings)-1):
    for i in range(count):
        j=(i+1)%count
        faces.append((row*count+i,row*count+j,(row+1)*count+j,(row+1)*count+i))
faces.append(tuple((len(rings)-1)*count+i for i in range(count)))
mesh('High-cut olive helmet shell',verts,faces,HEAD,nylon)
# The rim is thinner at the exposed forehead than over the ears.
tube('Helmet edge binding',[(.128*math.cos(2*math.pi*i/32),-.012+.146*math.sin(2*math.pi*i/32),1.608+(0.018 if math.sin(2*math.pi*i/32)<-.55 else 0)) for i in range(33)],.006,HEAD,webbing)
tube('Top reinforcing seam',[(0,-.148,1.648),(0,-.138,1.692),(0,-.101,1.729),(0,-.018,1.75),(0,.087,1.728),(0,.131,1.676)],.0035,HEAD,webbing)
for side in (-1,1):
    x=side*.134
    # Helmet rail and retention straps follow the head through lean and aim.
    tube(f'Helmet side rail {side}',[(x,-.105,1.652),(side*.146,-.045,1.633),(side*.134,.045,1.638),(side*.113,.097,1.655)],.009,HEAD,steel)
    tube(f'Chin retention strap {side}',[(side*.125,.028,1.621),(side*.123,-.02,1.532),(side*.086,-.095,1.475)],.004,HEAD,webbing)
    cap(f'Rail pivot {side}',(side*.144,-.031,1.636),.010,.008,HEAD,steel)
# Single left ear cup, boom mic and visible jack.
cap('Headset earcup',(-.155,.010,1.555),.044,.027,HEAD,rubber,24)
cap('Headset outer plate',(-.173,.010,1.555),.033,.008,HEAD,steel,24)
cap('Headset side dial',(-.180,-.012,1.556),.009,.006,HEAD,webbing)
tube('Headset overhead cable',[(-.155,.015,1.57),(-.147,.051,1.635),(-.111,.083,1.697),(-.03,.090,1.727)],.004,HEAD,rubber)
tube('Microphone flexible boom',[(-.176,-.015,1.535),(-.177,-.080,1.515),(-.142,-.135,1.485),(-.085,-.152,1.474)],.0045,HEAD,steel)
cap('Microphone capsule',(-.082,-.153,1.473),.010,.017,HEAD,rubber,12)
# Olive radio and antenna, kept behind the shoulders and clear of both weapons.
box('Rear tactical radio',(-.18,.188,1.220),(.108,.059,.168),SPINE,nylon,.009)
box('Radio front clip',(-.18,.156,1.239),(.065,.006,.036),SPINE,steel,.002)
box('Radio indicator',(-.18,.152,1.270),(.018,.004,.012),SPINE,lens,.001)
tube('Radio antenna',[(-.219,.184,1.293),(-.223,.190,1.388),(-.228,.198,1.468)],.0035,SPINE,rubber)
tube('Radio secured cord',[(-.149,.172,1.280),(-.102,.146,1.312),(-.055,.114,1.301)],.004,SPINE,rubber)
# Vest fastener/patch is a restrained silhouette read at gameplay distance.
box('Vest front name tab',(.074,-.218,1.256),(.085,.007,.024),SPINE,webbing,.002)

# Keep only the source skin, source rig and fitted accessories in the game GLB.
for obj in bpy.data.objects:
    if obj.type=='MESH' and obj not in added and obj != base:
        bpy.data.objects.remove(obj,do_unlink=True)
# Preserve the imported NLA tracks and all their keys. Clearing the rig action
# made Blender export clip names backed only by the rest pose.
rig.data.pose_position = 'POSE'
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,base,*added]: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', use_selection=True,
    export_apply=False, export_animations=True, export_skins=True, export_materials='EXPORT')
print('COMMANDO_EXPORT',OUT,'parts',len(added),'source',BLEND)
