"""Blender production: 12 curved geometric tufts, three LODs, shared native 2K PBR.
Run after tools/build_grass_textures.py. All output units metres, Z up in Blender.
"""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/grass'
TEX = ROOT/'assets/textures/grass_2k'
FAMILIES = {'short':(.10,.25,20,5,.012,.025,.10),
            'medium':(.35,.65,24,7,.020,.043,.18),
            'tall':(.90,1.40,30,9,.032,.065,.23)}


def material():
    mat=bpy.data.materials.new('VQ2_Grass_2K')
    mat.use_nodes=True
    mat.use_backface_culling=False
    n,l=mat.node_tree.nodes,mat.node_tree.links
    bs=n.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.75
    bs.inputs['Subsurface Weight'].default_value=.05
    for name, noncolor in [('albedo.jpg',False),('normal.png',True),('orm.png',True)]:
        im=bpy.data.images.load(str(TEX/name));im.pack()
        if noncolor: im.colorspace_settings.name='Non-Color'
        node=n.new('ShaderNodeTexImage');node.image=im;node.label=name
        if name=='albedo.jpg':l.new(node.outputs['Color'],bs.inputs['Base Color'])
        if name=='normal.png':
            norm=n.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.35
            l.new(node.outputs['Color'],norm.inputs['Color']);l.new(norm.outputs['Normal'],bs.inputs['Normal'])
        if name=='orm.png':
            split=n.new('ShaderNodeSeparateColor');l.new(node.outputs['Color'],split.inputs['Color'])
            l.new(split.outputs['Green'],bs.inputs['Roughness'])
            # glTF exporter recognises the named occlusion input group.
            group=bpy.data.node_groups.new('glTF Material Output','ShaderNodeTree')
            group.interface.new_socket(name='Occlusion',in_out='INPUT',socket_type='NodeSocketFloat')
            group.nodes.new('NodeGroupInput')
            ao=n.new('ShaderNodeGroup');ao.node_tree=group;l.new(split.outputs['Red'],ao.inputs['Occlusion'])
    return mat


def blade_specs(kind, variant):
    lo,hi,count,segs,wlo,whi,radius=FAMILIES[kind]
    rng=random.Random(7100+list(FAMILIES).index(kind)*100+variant)
    result=[]
    for i in range(count+variant*2):
        angle=rng.uniform(0,math.tau)
        rr=math.sqrt(rng.random())*radius
        height=rng.uniform(lo,hi)
        # A few outward leaves frame a tighter upright centre.
        lean=height*rng.uniform(.14,.65)
        result.append(dict(root=Vector((math.cos(angle)*rr,math.sin(angle)*rr,0)),
            yaw=angle+rng.uniform(-.9,.9),h=height,lean=lean,width=rng.uniform(wlo,whi),
            curl=rng.uniform(-.17,.17),droop=rng.uniform(.06,.25),lane=rng.randrange(8),
            tint=rng.uniform(.84,1.0)))
    return result


def tuft(kind,variant,lod,mat):
    specs=blade_specs(kind,variant)
    base_segs=FAMILIES[kind][3]
    segs=base_segs if lod==0 else max(3,base_segs//2) if lod==1 else 3
    indices=list(range(len(specs))) if lod==0 else list(range(0,len(specs),2)) if lod==1 else list(range(0,len(specs),max(1,len(specs)//7)))[:7]
    verts,faces,uvs,cols=[],[],[],[]
    stride=3 if lod<2 else 2
    for idx in indices:
        a=specs[idx];d=Vector((math.cos(a['yaw']),math.sin(a['yaw']),0));side=Vector((-d.y,d.x,0))
        start=len(verts)
        for row in range(segs+1):
            t=row/segs
            # Curved centreline: upright at the root, flexed tip and natural lateral twist.
            c=a['root']+d*(a['lean']*t*t)+side*(a['curl']*a['h']*math.sin(math.pi*t)*t)
            c.z=a['h']*(t+a['droop']*math.sin(math.pi*t))
            width=a['width']*(.58+.60*math.sin(t*math.pi*.8))*max(.006,(1-t)**.68)
            for k in range(stride):
                cross=k/(stride-1)
                v=c+side*((cross-.5)*width)
                # Folded blade midrib, not a flat billboard.
                if stride==3 and k==1:v+=Vector((0,0,width*.19*(1-t)))
                verts.append(tuple(v))
                uvs.append(((a['lane']+.02+.96*cross)/8,t))
                cols.append((a['tint'],a['tint'],a['tint'],t))
        for row in range(segs):
            for k in range(stride-1):
                a0=start+row*stride+k;b=a0+1;c0=a0+stride;dd=c0+1
                faces.extend([(a0,b,c0),(b,dd,c0)])
    name=f'Grass_{kind}_{variant+1:02d}_LOD{lod}'
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    mesh.uv_layers.new(name='BladeAtlasUV')
    mesh.color_attributes.new(name='BladeTintWind',type='FLOAT_COLOR',domain='CORNER')
    mesh.color_attributes.active_color_index=0
    mesh.color_attributes.render_color_index=0
    # Adding a CustomData layer invalidates earlier Blender RNA layer pointers.
    # Resolve both only after every layer exists, then fill the correct arrays in bulk.
    uv_data=[];color_data=[]
    for poly in mesh.polygons:
        poly.use_smooth=True
        for loop in poly.loop_indices:
            vid=mesh.loops[loop].vertex_index;uv_data.extend(uvs[vid]);color_data.extend(cols[vid])
    mesh.uv_layers['BladeAtlasUV'].data.foreach_set('uv',uv_data)
    mesh.color_attributes['BladeTintWind'].data.foreach_set('color',color_data)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(mat)
    obj.location=(variant*.85-1.275,0,0)
    obj['family']=kind;obj['variant']=variant+1;obj['lod']=lod;obj['wind']='Godot shader only, no GLB clips'
    return obj


def main():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    OUT.mkdir(parents=True,exist_ok=True)
    mat=material();report={'source':'bron/gras/gras.blend','units':'metres','texture_resolution':[2048,2048],
        'texture_method':'Original full-resolution procedural PBR, not upscaled photos','families':{}}
    all_objects=[]
    for kind in FAMILIES:
        report['families'][kind]={}
        for lod in range(3):
            objects=[tuft(kind,v,lod,mat) for v in range(4)]
            all_objects+=objects
            bpy.ops.object.select_all(action='DESELECT')
            for obj in objects:obj.select_set(True)
            path=OUT/f'grass_{kind}_lod{lod}.glb'
            bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                export_yup=True,export_animations=False,export_extras=True,export_apply=True,
                export_texcoords=True,export_normals=True,export_tangents=True,
                export_vertex_color='ACTIVE',export_all_vertex_colors=False,
                export_materials='EXPORT',export_image_format='AUTO')
            report['families'][kind][str(lod)]={'glb':str(path.relative_to(ROOT)),
                'variants':[{'name':o.name,'triangles':len(o.data.polygons),
                  'height_m':round(max(v.co.z for v in o.data.vertices),4),
                  'vertices':len(o.data.vertices),'surfaces':1} for o in objects]}
    # Editable sources show three rows; exporters above keep each library grounded at y=0.
    for obj in all_objects:
        kind=obj['family'];lod=obj['lod'];obj.location.y=list(FAMILIES).index(kind)*2+lod*.4
        obj.hide_viewport=lod!=0;obj.hide_render=lod!=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'bron/gras/gras.blend'))
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print('GRASS BLENDER COMPLETE: 12 tufts, 3 geometric LODs, 9 GLBs and packed editable source')


if __name__=='__main__':main()
