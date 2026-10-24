"""blender -b --python tools/vq2_source_check.py: verify actual editable sources."""
import bpy, json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sources=['bron/kazerne/uit/kazerne.blend','bron/wachttoren/uit/wachttoren.blend','bron/legerjeep/jeep.blend','bron/jeep/jeep.blend']
results=[]
for source in sources:
    path=ROOT/source
    bpy.ops.wm.open_mainfile(filepath=str(path))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    images=[i for i in bpy.data.images if i.type=='IMAGE' and i.source=='FILE']
    assert meshes,source
    assert all(i.packed_file is not None for i in images),(source,[i.name for i in images if i.packed_file is None])
    if 'wachttoren' in source:
        assert all(n in bpy.data.objects for n in ('Toren_dak','Toren_dakrib'))
    results.append({'source':source,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'editable_mesh_objects':len(meshes),'packed_image_files':len(images),'native_blender_load':'PASS'})
(ROOT/'docs/vq2/results/blend-source-check.json').write_text(json.dumps(results,indent=2)+'\n')
print('VQ2 BLEND SOURCES PASS: four editable Blender files loaded; all source texture images packed')
