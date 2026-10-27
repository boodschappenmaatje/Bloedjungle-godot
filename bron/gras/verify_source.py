"""Open with Blender, inspect the actual editable packed source without saving it."""
import bpy
import json
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'bron/gras/gras.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
assert len(meshes)==36
images=[]
for name in ['albedo.jpg','normal.png','orm.png']:
    image=bpy.data.images[name]
    assert tuple(image.size)==(2048,2048) and image.packed_file
    images.append({'name':name,'size':list(image.size),'packed':True})
for obj in meshes:
    m=obj.data
    color=m.color_attributes['BladeTintWind']
    uv=m.uv_layers['BladeAtlasUV']
    for loop in m.loops:
        c=color.data[loop.index].color
        assert abs(c[0]-c[1])<1e-6 and abs(c[1]-c[2])<1e-6
        if m.vertices[loop.vertex_index].co.z<1e-6:
            assert c[3]==0 and abs(uv.data[loop.index].uv.y)<1e-6
report={'native_blender_open':'PASS','source':str(source.relative_to(ROOT)),
    'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'editable_mesh_objects':len(meshes),
    'packed_images':images,'actual_uv_and_pinned_root_color_data':'PASS'}
(ROOT/'docs/grass/blend-source-check.json').write_text(json.dumps(report,indent=2)+'\n')
print('GRASS NATIVE SOURCE PASS: 36 editable meshes, three packed native 2K maps, correct UV/wind data')
