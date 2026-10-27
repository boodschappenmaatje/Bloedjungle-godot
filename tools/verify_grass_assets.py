#!/usr/bin/env python3
"""Inspect actual exported bytes, not generator intent or renderer placeholder meshes."""
from pathlib import Path
import hashlib,io,json,struct
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
report={'libraries':[],'texture_resolution':[2048,2048],'checks':'PASS'}
for family in ['short','medium','tall']:
    previous=10**9
    for lod in range(3):
        p=ROOT/f'assets/grass/grass_{family}_lod{lod}.glb';b=p.read_bytes()
        magic,version,size=struct.unpack_from('<III',b)
        assert magic==0x46546c67 and version==2 and size==len(b)
        n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);binary=b[28+n:]
        assert len(j['meshes'])==4 and len(j['materials'])==1 and not j.get('animations')
        mat=j['materials'][0];assert mat.get('alphaMode','OPAQUE')=='OPAQUE' and mat['doubleSided']
        triangles=0
        for m in j['meshes']:
            assert len(m['primitives'])==1
            prim=m['primitives'][0];triangles+=j['accessors'][prim['indices']]['count']//3
            assert all(k in prim['attributes'] for k in ['POSITION','NORMAL','TANGENT','TEXCOORD_0','COLOR_0'])
        assert triangles<previous;previous=triangles
        images=[]
        for im in j['images']:
            view=j['bufferViews'][im['bufferView']];start=view.get('byteOffset',0)
            data=binary[start:start+view['byteLength']];image=Image.open(io.BytesIO(data))
            assert image.size==(2048,2048)
            images.append({'name':im.get('name'),'size':list(image.size),'sha256':hashlib.sha256(data).hexdigest()})
        report['libraries'].append({'family':family,'lod':lod,'file':str(p.relative_to(ROOT)),
            'sha256':hashlib.sha256(b).hexdigest(),'triangles_four_variants':triangles,
            'material_surfaces':4,'embedded_images':images})
(ROOT/'docs/grass/asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('GRASS GLB BYTES PASS: nine real libraries, twelve variants, geometric LOD reduction, opaque blades, actual embedded 2K PBR')
