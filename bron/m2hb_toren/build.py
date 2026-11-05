"""Technical decimation of Dennis's approved Meshy OBJ; no replacement geometry."""
import bpy
import glob
import os

source = glob.glob('/tmp/m2src/**/*.obj', recursive=True)[0]
out = '/workspace/Bloedjungle-godot/assets/vijand_m2_toren.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=source)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert meshes
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
o = bpy.context.object
lo = [min(v.co[i] for v in o.data.vertices) for i in range(3)]
hi = [max(v.co[i] for v in o.data.vertices) for i in range(3)]
print('SOURCE BOUNDS', lo, hi, 'TRIS', len(o.data.polygons), flush=True)
# Meshy source uses Y as its vertical axis; Blender imported its raw coordinates.
# Convert once to Blender Z-up, then glTF exports Y-up for Godot.
scale = 6.0 / (hi[1] - lo[1])
for v in o.data.vertices:
    x, y, z = v.co[:]
    v.co = ((x - (lo[0] + hi[0]) / 2) * scale,
            -(z - (lo[2] + hi[2]) / 2) * scale,
            (y - lo[1]) * scale)
o.name = 'TowerStatic'
dec = o.modifiers.new('PreserveApprovedSilhouette', 'DECIMATE')
dec.ratio = min(1.0, 60000 / max(1, len(o.data.polygons)))
bpy.ops.object.modifier_apply(modifier=dec.name)
for mat in o.data.materials:
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image:
                n.image.pack()
print('GAME TRIS', len(o.data.polygons), flush=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_apply=True)
print('WROTE', out, os.path.getsize(out), flush=True)
