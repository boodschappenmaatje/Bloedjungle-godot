"""Static GLB and texture-memory audit. Run with workspace Python + Pillow."""
import io,json,os,struct,sys
from PIL import Image
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
out={}
for lod in range(3):
    rel=f'assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD{lod}.glb'
    raw=open(os.path.join(root,rel),'rb').read()
    assert raw[:4]==b'glTF' and struct.unpack_from('<I',raw,8)[0]==len(raw)
    jslen=struct.unpack_from('<I',raw,12)[0]
    j=json.loads(raw[20:20+jslen]);offset=20+jslen+8
    binchunk=raw[offset:]
    images=[];unique=set()
    for im in j.get('images',[]):
        bv=j['bufferViews'][im['bufferView']]
        data=binchunk[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
        with Image.open(io.BytesIO(data)) as image:width,height=image.size
        key=(data[:64],len(data),width,height)
        if key in unique:continue
        unique.add(key)
        images.append({'name':im.get('name'),'width':width,'height':height,'encoded_bytes':len(data)})
    primitives=sum(len(m['primitives']) for m in j['meshes'])
    unique_materials=len(j.get('materials',[]))
    rgba8_mib=sum(i['width']*i['height']*4*4/3 for i in images)/1048576
    out[f'LOD{lod}']={'bytes':len(raw),'mesh_nodes':len(j['meshes']),'primitives_draw_surface_proxy':primitives,'unique_materials':unique_materials,'images':images,'uncompressed_rgba8_mips_mib_upper_estimate':round(rgba8_mib,1),'animations':[a.get('name') for a in j.get('animations',[])], 'actual_gpu_drawcalls':'NOT_MEASURED','actual_gpu_memory':'NOT_MEASURED'}
path=os.path.join(root,'assets/airfield_hq_v22/GLB_AUDIT.json')
with open(path,'w') as f:json.dump(out,f,indent=2)
print(json.dumps({k:{x:v[x] for x in ['bytes','mesh_nodes','primitives_draw_surface_proxy','unique_materials','uncompressed_rgba8_mips_mib_upper_estimate','animations']} for k,v in out.items()},indent=2))
