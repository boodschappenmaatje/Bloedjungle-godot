"""MCV-bouwwagen uit Dennis' Meshy-modellen (wagen, module, poot), stap 1: bron (miljoenen driehoeken) -> gesloten voxel-schil op ware grootte.
Gebruik: python3 stap1_schil.py <bron.glb> <cache-map> <naam> <schaal bronmaat->m> <voxel in m>
Bewaart <cache>/<naam>_voxel.npz (co, tri) in Blender-assen na glTF-import (X = lengte, Y = breedte, Z = omhoog), geschaald, onverschoven."""
import sys, time
import numpy as np
import bpy, bmesh
from pathlib import Path

BRON, CACHE, NAAM = Path(sys.argv[-5]).resolve(), Path(sys.argv[-4]).resolve(), sys.argv[-3]
SCHAAL, VOXEL = float(sys.argv[-2]), float(sys.argv[-1])
CACHE.mkdir(parents=True, exist_ok=True)
t0 = time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BRON))
hoog = next(o for o in bpy.data.objects if o.type == "MESH")
me = hoog.data
print("%s bron: %d driehoeken, %.0f s" % (NAAM, len(me.polygons), time.time() - t0), flush=True)
vox = bpy.data.objects.new(NAAM + "_vox", me.copy())
bpy.context.scene.collection.objects.link(vox)
vox.scale = (SCHAAL,) * 3
bpy.context.view_layer.objects.active = vox
for o in bpy.data.objects:
    o.select_set(o is vox)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
vox.data.remesh_voxel_size = VOXEL
vox.data.remesh_voxel_adaptivity = 0.0
bpy.ops.object.voxel_remesh()
bm = bmesh.new(); bm.from_mesh(vox.data); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(vox.data); bm.free()
vme = vox.data
vv = np.empty(len(vme.vertices) * 3, np.float32); vme.vertices.foreach_get("co", vv); vv = vv.reshape(-1, 3)
vt = np.empty(len(vme.polygons) * 3, np.int32); vme.polygons.foreach_get("vertices", vt); vt = vt.reshape(-1, 3)
print("voxel-remesh %.3f m: %d driehoeken, bbox %s .. %s, %.0f s" % (VOXEL, len(vt), vv.min(0).round(3), vv.max(0).round(3), time.time() - t0), flush=True)
np.savez(CACHE / (NAAM + "_voxel.npz"), co=vv, tri=vt)
print("STAP1 klaar %.0f s" % (time.time() - t0))
