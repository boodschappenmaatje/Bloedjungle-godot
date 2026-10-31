"""Merge the visible red warning bulbs and author one mobile glTF blink clip."""
import bpy,os,json,bmesh,math
from mathutils import Vector
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
source=os.path.join(root,'assets/airfield_hq/high_quality/Bloedjungle_Airfield_HQ_Source.blend')
metrics_path=os.path.join(root,'assets/airfield_hq/high_quality/source_metrics.json')
bpy.ops.wm.open_mainfile(filepath=source)
collection=bpy.data.collections['07_Lighting']
red=bpy.data.materials['Red obstruction warning lamp']
cluster=bpy.data.objects.get('Blinking red runway and tower markers');lamp_count=29
if cluster is None:
    lamps=[o for o in collection.objects if o.type=='MESH' and (o.name.startswith('Shielded runway incandescent lamp') or o.name.startswith('Tower incandescent obstruction beacon'))]
    if len(lamps)<20: raise RuntimeError(f'Expected runway and tower red lamps, found {len(lamps)}')
    vertices=[];faces=[];groups=[];offset=0
    for obj in lamps:
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        groups.append(list(range(offset,offset+len(points))));vertices.extend(points)
        faces.extend([tuple(offset+i for i in p.vertices) for p in obj.data.polygons]);offset+=len(points)
    mesh=bpy.data.meshes.new('Single call red light cluster');mesh.from_pydata(vertices,[],faces);mesh.materials.append(red);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
    cluster=bpy.data.objects.new('Blinking red runway and tower markers',mesh);collection.objects.link(cluster)
    for obj in lamps:bpy.data.objects.remove(obj,do_unlink=True)
    cluster.shape_key_add(name='Basis');off=cluster.shape_key_add(name='Lights Off')
    for indices in groups:
        center=sum((vertices[i] for i in indices),Vector())/len(indices)
        for i in indices:off.data[i].co=center
    for start in range(1,121,30):
        sequence=[(start,1),(start+3,0),(start+8,1),(start+10,0),(start+20,0),(start+21,1),(start+22,0),(start+27,0),(start+28,1),(min(start+30,120),1)]
        for frame,value in sequence:off.value=value;off.keyframe_insert(data_path='value',frame=frame,group='Red warning marker strobe')
    action=cluster.data.shape_keys.animation_data.action;action.name='Blink_Red_Markers'
    for curve in action.fcurves:
        for point in curve.keyframe_points:point.interpolation='CONSTANT'
    uv=mesh.uv_layers.new(name='UV0_4m_tile')
    for poly in mesh.polygons:
        normal=poly.normal;axis=max(range(3),key=lambda i:abs(normal[i]));axes=({0:(1,2),1:(0,2),2:(0,1)})[axis]
        for li in poly.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]*.25,co[axes[1]]*.25)
scene=bpy.context.scene;scene['HISTORICAL_LIGHTING']='Low incandescent edge markers with a blinking red warning-beacon morph clip'
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.42,.48,.55,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.8
if not bpy.data.objects.get('Late morning sun'):
    sun_data=bpy.data.lights.new('Late morning sun','SUN');sun_data.energy=2.0;sun_data.angle=.0021;sun_data.color=(1.0,.91,.78)
    sun=bpy.data.objects.new('Late morning sun',sun_data);scene.collection.objects.link(sun);sun.location=(-80,-100,150);sun.rotation_euler=(Vector((0,180,0))-sun.location).to_track_quat('-Z','Y').to_euler()
# Fully clear the 44 m door opening by sliding each 20 m leaf just beyond its
# side jamb. The saved first-pass source used 19.3 m; retime to 21.2 m here.
for door in [o for o in scene.objects if o.type=='MESH' and o.name.startswith('Hangar sliding door')]:
    if not door.animation_data or not door.animation_data.action: continue
    closed_x=-10.2 if 'LEFT' in door.name else 10.2
    for curve in door.animation_data.action.fcurves:
        if curve.data_path=='location' and curve.array_index==0:
            travel=max(abs(key.co.y-closed_x) for key in curve.keyframe_points)
            if travel<20.5:
                for key in curve.keyframe_points:key.co.y=closed_x+(key.co.y-closed_x)*(21.2/19.3)
    door.animation_data.action.update_tag()
# Historic USAAF star-and-bar roundels move with the separate sliding leaves.
def preserve_parent_world(obj,parent):
    bpy.context.view_layer.update();world=obj.matrix_world.copy();obj.parent=parent;obj.matrix_parent_inverse=parent.matrix_world.inverted();obj.matrix_world=world
badge_blue=bpy.data.materials.new('Faded USAAF insignia blue');badge_blue.diffuse_color=(.045,.105,.28,1);badge_blue.use_nodes=True
badge_bs=badge_blue.node_tree.nodes.get('Principled BSDF');badge_bs.inputs['Base Color'].default_value=(.045,.105,.28,1);badge_bs.inputs['Roughness'].default_value=.77
ivory=bpy.data.materials['Faded wartime runway paint']
for door in [o for o in scene.objects if o.type=='MESH' and o.name.startswith('Hangar sliding door')]:
    cx=door.location.x;cz=7.45;y=door.location.y-.48
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=1.12,depth=.055,location=(cx,y,cz));disc=bpy.context.object;disc.name='USAAF blue insignia roundel';disc.rotation_euler[0]=math.pi/2;disc.data.materials.append(badge_blue);collection_door=bpy.data.collections['02_Hangar_Sliding_Doors'];
    for col in list(disc.users_collection):col.objects.unlink(disc)
    collection_door.objects.link(disc);preserve_parent_world(disc,door)
    verts=[];faces=[]
    for i in range(10):
        angle=math.pi/2+i*math.pi/5;radius=.91 if i%2==0 else .39
        verts.append((cx+math.cos(angle)*radius,y-.04,cz+math.sin(angle)*radius))
    faces.append(tuple(range(10)))
    for x0,x1 in ((cx-2.15,cx-1.02),(cx+1.02,cx+2.15)):
        first=len(verts);half=.21;verts.extend([(x0,y-.04,cz-half),(x1,y-.04,cz-half),(x1,y-.04,cz+half),(x0,y-.04,cz+half)]);faces.append((first,first+1,first+2,first+3))
    mesh=bpy.data.meshes.new('USAAF star and bar stencil mesh');mesh.from_pydata(verts,[],faces);mesh.materials.append(ivory);mesh.update();insignia=bpy.data.objects.new('USAAF white star and bar stencil',mesh);collection_door.objects.link(insignia);preserve_parent_world(insignia,door)
# Period-correct building identification over the main sliding doors.
dark=bpy.data.materials['Deep shadowed structural steel'];front=-19.0
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,front-.28,14.15));board=bpy.context.object;board.name='Hangar fascia identification board';board.dimensions=(28,.18,1.55);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);board.data.materials.append(dark)
for col in list(board.users_collection):col.objects.unlink(board)
bpy.data.collections['01_Hangar_HQ'].objects.link(board)
bpy.ops.object.text_add(location=(0,front-.40,13.78));sign=bpy.context.object;sign.name='USAAF hangar sign';sign.data.body='U.S. ARMY AIR FORCES  -  FIELD 18';sign.data.align_x='CENTER';sign.data.size=.85;sign.data.extrude=.012;sign.rotation_euler[0]=math.pi/2;sign.data.materials.append(ivory)
for col in list(sign.users_collection):col.objects.unlink(sign)
bpy.data.collections['01_Hangar_HQ'].objects.link(sign);bpy.context.view_layer.objects.active=sign;bpy.ops.object.convert(target='MESH');sign=bpy.context.object;sign.name='USAAF hangar sign lettering'
# The new stencil/sign geometry also receives UV0 at the project's 4 m tile scale.
decal_meshes=[o for o in bpy.data.objects if o.type=='MESH' and (o.name.startswith('USAAF blue insignia roundel') or o.name.startswith('USAAF white star and bar stencil') or o.name in {'Hangar fascia identification board','USAAF hangar sign lettering'})]
for obj in decal_meshes:
    if obj.type!='MESH' or obj.data.uv_layers:continue
    uv=obj.data.uv_layers.new(name='UV0_4m_tile')
    for poly in obj.data.polygons:
        normal=poly.normal;axis=max(range(3),key=lambda i:abs(normal[i]));axes=({0:(1,2),1:(0,2),2:(0,1)})[axis]
        for li in poly.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]*.25,co[axes[1]]*.25)
cam=bpy.data.objects.get('Hero_Camera')
if cam:
    cam.location=(86,-88,52);cam.rotation_euler=(Vector((4,5,8))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=50
deps=bpy.context.evaluated_depsgraph_get();mesh_objects=[o for o in scene.objects if o.type=='MESH' and not o.name.startswith('COL_')]
tri=0
for obj in mesh_objects:
    evaluated=obj.evaluated_get(deps);data=evaluated.to_mesh();tri+=sum(max(0,len(p.vertices)-2) for p in data.polygons);evaluated.to_mesh_clear()
with open(metrics_path) as f:metrics=json.load(f)
metrics['source_mesh_objects']=len(mesh_objects);metrics['source_evaluated_triangles']=tri;metrics['animation_actions']=['Open_Left_Door','Open_Right_Door','Blink_Red_Markers'];metrics['warning_marker_geometry_objects']=lamp_count;metrics['warning_marker_runtime_meshes']=1
with open(metrics_path,'w') as f:json.dump(metrics,f,indent=2)
bpy.ops.wm.save_as_mainfile(filepath=source)
print('AIRFIELD_WARNING_LIGHT_ANIMATION',lamp_count,tri)
