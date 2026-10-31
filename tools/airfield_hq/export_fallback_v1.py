"""Export the preserved V4 Airfield as a no-change baseline for side-by-side review."""
import bpy,os
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
src=os.path.join(root,'bron/airfield_hq/fallback_v4/Bloedjungle-Airfield-v4.0.blend')
out=os.path.join(root,'assets/vq2_baseline/airfield_v1.glb')
os.makedirs(os.path.dirname(out),exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=src)
items=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.visible_get()]
bpy.ops.object.select_all(action='DESELECT')
for o in items:o.select_set(True)
if items:bpy.context.view_layer.objects.active=items[0]
options=dict(filepath=out,export_format='GLB',use_selection=True,export_animations=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_texcoords=True,export_normals=True,export_apply=True)
known={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
bpy.ops.export_scene.gltf(**{k:v for k,v in options.items() if k in known})
print('AIRFIELD_V1_BASELINE',len(items),os.path.getsize(out))
