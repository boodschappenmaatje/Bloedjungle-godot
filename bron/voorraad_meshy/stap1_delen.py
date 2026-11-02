"""Stap 1: Meshy-bron (3,73 miljoen driehoeken) -> gesloten voxel-schil op ware grootte, vlakken per deel gelabeld, debugbeelden.
Gebruik: python3 stap1_delen.py <bron.glb> <cache-map> [voxel in m]"""
import sys, time
import numpy as np
import bpy, bmesh
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen as D

BRON, CACHE = Path(sys.argv[-3]).resolve(), Path(sys.argv[-2]).resolve()
VOXEL = float(sys.argv[-1])
CACHE.mkdir(parents=True, exist_ok=True)
t0 = time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BRON))
hoog = next(o for o in bpy.data.objects if o.type == "MESH")
me = hoog.data
print("bron: %d driehoeken, %.0f s" % (len(me.polygons), time.time() - t0), flush=True)
# eerst op ware grootte in bronassen (alleen schalen), zodat de voxelgrootte in meters is
vox = bpy.data.objects.new("Vrachtwagen_vox", me.copy())
bpy.context.scene.collection.objects.link(vox)
vox.scale = (D.SCHAAL,) * 3
bpy.context.view_layer.objects.active = vox
for o in bpy.data.objects:
    o.select_set(o is vox)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
vox.data.remesh_voxel_size = VOXEL
vox.data.remesh_voxel_adaptivity = 0.0
bpy.ops.object.voxel_remesh()
bm = bmesh.new(); bm.from_mesh(vox.data); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(vox.data); bm.free()
vme = vox.data
print("voxel-remesh %.3f m: %d driehoeken, %.0f s" % (VOXEL, len(vme.polygons), time.time() - t0), flush=True)
vv = np.empty(len(vme.vertices) * 3, np.float32); vme.vertices.foreach_get("co", vv); vv = vv.reshape(-1, 3)
vt = np.empty(len(vme.polygons) * 3, np.int32); vme.polygons.foreach_get("vertices", vt); vt = vt.reshape(-1, 3)
vc = (vv[vt[:, 0]] + vv[vt[:, 1]] + vv[vt[:, 2]]) / 3.0 / D.SCHAAL      # terug naar bronmaat voor de indeling
lab = D.indelen(vc)
print({int(k): int(v) for k, v in zip(*np.unique(lab, return_counts=True))})
np.savez(CACHE / "voxel.npz", co=vv, tri=vt, lab=lab)
print("STAP1 klaar %.0f s" % (time.time() - t0))
