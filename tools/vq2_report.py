#!/usr/bin/env python3
"""Inspect actual GLB bytes, including textures and changing animation channels."""
from pathlib import Path
from io import BytesIO
import hashlib
import json
import struct
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]


def read_glb(path):
    data=Path(path).read_bytes()
    magic,version,length=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and length==len(data)
    offset=12; binary=b''; doc=None
    while offset<len(data):
        size,kind=struct.unpack_from('<I4s',data,offset); offset+=8
        chunk=data[offset:offset+size]; offset+=size
        if kind==b'JSON': doc=json.loads(chunk)
        elif kind==b'BIN\0': binary=chunk
    return doc,binary,data


def accessor(doc,binary,index):
    a=doc['accessors'][index]; view=doc['bufferViews'][a['bufferView']]
    types={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}
    widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    dtype=np.dtype(types[a['componentType']]); width=widths[a['type']]
    offset=view.get('byteOffset',0)+a.get('byteOffset',0)
    return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=offset,
                      strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()


def inspect(path):
    doc,binary,data=read_glb(path)
    tri=sum(doc['accessors'][p['indices']]['count']//3 if 'indices' in p else doc['accessors'][p['attributes']['POSITION']]['count']//3
            for m in doc.get('meshes',[]) for p in m['primitives'] if p.get('mode',4)==4)
    images=[]
    for img in doc.get('images',[]):
        view=doc['bufferViews'][img['bufferView']]; start=view.get('byteOffset',0)
        raw=binary[start:start+view['byteLength']]
        image=Image.open(BytesIO(raw))
        images.append({'name':img.get('name',''), 'size':list(image.size),'encoded_bytes':len(raw)})
    clips=[]
    for anim in doc.get('animations',[]):
        changing=[]
        for channel in anim['channels']:
            sampler=anim['samplers'][channel['sampler']]
            values=accessor(doc,binary,sampler['output'])
            delta=float(np.ptp(values,axis=0).max())
            if delta>1e-5:
                target=channel['target']
                changing.append({'node':doc['nodes'][target['node']].get('name',''), 'path':target['path'], 'range':round(delta,6)})
        duration=max(float(accessor(doc,binary,s['input']).max()) for s in anim['samplers'])
        clips.append({'name':anim.get('name',''), 'duration_s':duration,'channels':len(anim['channels']), 'changing_channels':changing})
    return {'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),
            'triangles':tri,'meshes':len(doc.get('meshes',[])),
            'material_surfaces':sum(len(m['primitives']) for m in doc.get('meshes',[])),
            'materials':len(doc.get('materials',[])),'images':images,
            'rgba8_with_mips_MiB':round(sum(i['size'][0]*i['size'][1]*4*4/3 for i in images)/1024**2,2),
            'pbr_materials':sum('baseColorTexture' in m.get('pbrMetallicRoughness',{}) and 'normalTexture' in m and 'metallicRoughnessTexture' in m.get('pbrMetallicRoughness',{}) for m in doc.get('materials',[])),
            'node_names':[n.get('name','') for n in doc.get('nodes',[])], 'clips':clips}


def main():
    assets={}
    for model in ('kazerne','wachttoren','legerjeep'):
        assets[model]={version:inspect(ROOT/('assets/vq2_baseline' if version=='v1' else 'assets')/(model+'.glb')) for version in ('v1','v2')}
    assets['playable_jeep']=inspect(ROOT/'assets/jeep.glb')
    old,oldbin,_=read_glb(ROOT/'assets/vq2_baseline/jeep.glb')
    new,newbin,_=read_glb(ROOT/'assets/jeep.glb')
    same_geometry=True
    for oldmesh,newmesh in zip(old['meshes'],new['meshes']):
        before=np.concatenate([accessor(old,oldbin,p['attributes']['POSITION']) for p in oldmesh['primitives']])
        after=np.concatenate([accessor(new,newbin,p['attributes']['POSITION']) for p in newmesh['primitives']])
        same_geometry &= {tuple(v) for v in np.round(before,5)}=={tuple(v) for v in np.round(after,5)}
    compatibility={
        'hierarchy_preserved':[(n.get('name'),n.get('children')) for n in old['nodes']]==[(n.get('name'),n.get('children')) for n in new['nodes']],
        'geometry_positions_preserved_1e_5_m':same_geometry,
        'materials_preserved':old['materials']==new['materials'],
        'seven_clip_names_preserved':[a['name'] for a in old['animations']]==[a['name'] for a in new['animations']],
        'repair':'Bocht now exports an actual steering channel; all seven original clip names and node hierarchy retained.'}
    assert all(compatibility[k] for k in compatibility if k!='repair'),compatibility
    assert assets['legerjeep']['v2']['triangles']<assets['legerjeep']['v1']['triangles']
    assert {'Toren_dak','Toren_dakrib'}.issubset(assets['wachttoren']['v2']['node_names'])
    assert len(assets['playable_jeep']['clips'])==7
    for name in ('kazerne','wachttoren','legerjeep'):
        assert assets[name]['v2']['pbr_materials']>=3
        print(name,assets[name]['v1']['triangles'],'->',assets[name]['v2']['triangles'])
    out=ROOT/'docs/vq2/results';out.mkdir(parents=True,exist_ok=True)
    (out/'asset-report.json').write_text(json.dumps({'baseline_commit':'967e9c23baffa0f5e5d62eedce3af30b8634d7c0','assets':assets,'playable_jeep_compatibility':compatibility,
       'memory_note':'RGBA8 worst case including mips, per GLB image list, not measured GPU VRAM. Godot platform compression/sharing may reduce this. No physical iPhone timings measured.'},indent=2)+'\n')
    print('GLB invariants PASS; detailed report written')


if __name__=='__main__':
    main()
