"""Stap 1: Tiger-bron (Meshy, 4,1 miljoen driehoeken) op ware grootte zetten, voorkant naar +Y, vlakken indelen in delen.
Schrijft in de cache-map: delen_hoog.blend (bron + hoge versies van romp/toren/kanon), geo.npz (hoekpunten, driehoeken, labels).
Gebruik: python3 stap1_delen.py <bron.glb> <cache-map>"""
import sys, time
import numpy as np
import bpy, bmesh
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tiger_delen as TD

BRON, CACHE = Path(sys.argv[-2]).resolve(), Path(sys.argv[-1]).resolve()
CACHE.mkdir(parents=True, exist_ok=True)
VOXEL = 0.03
t0 = time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BRON))
hoog = next(o for o in bpy.data.objects if o.type == "MESH")
me = hoog.data
nv, npoly = len(me.vertices), len(me.polygons)
co = np.empty(nv * 3, np.float32); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
tri = np.empty(npoly * 3, np.int32); me.polygons.foreach_get("vertices", tri); tri = tri.reshape(-1, 3)
uv = np.empty(len(me.loops) * 2, np.float32); me.uv_layers[0].data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
assert len(me.loops) == npoly * 3, "bron is niet volledig driehoeken"
cen = (co[tri[:, 0]] + co[tri[:, 1]] + co[tri[:, 2]]) / 3.0
lab = TD.indelen(cen)
print({int(k): int(v) for k, v in zip(*np.unique(lab, return_counts=True))})
gco = TD.naar_spel(co)

# hele bron in spelpositie (voor het bakken)
me.vertices.foreach_set("co", gco.ravel()); me.update()
hoog.name = me.name = "Tiger_HQ"
mat = me.materials[0]
mat.use_backface_culling = False


def deel_mesh(naam, sel):
    """mesh met alleen de vlakken `sel`, met UV's van de bron"""
    f = tri[sel]
    uniek, inv = np.unique(f.ravel(), return_inverse=True)
    m = bpy.data.meshes.new(naam)
    m.vertices.add(len(uniek)); m.vertices.foreach_set("co", gco[uniek].ravel())
    n = len(f)
    m.loops.add(n * 3); m.loops.foreach_set("vertex_index", inv.astype(np.int32))
    m.polygons.add(n); m.polygons.foreach_set("loop_start", np.arange(0, n * 3, 3, dtype=np.int32))
    m.polygons.foreach_set("loop_total", np.full(n, 3, np.int32))
    m.update(calc_edges=True)
    layer = m.uv_layers.new(name="UVMap")
    lu = uv.reshape(npoly, 3, 2)[sel].reshape(-1, 2)
    layer.data.foreach_set("uv", lu.ravel())
    m.materials.append(mat)
    ob = bpy.data.objects.new(naam, m)
    bpy.context.scene.collection.objects.link(ob)
    ob.hide_render = True
    return ob


hoog.hide_render = True
np.savez(CACHE / "geo.npz", co=gco, tri=tri, lab=lab, uv=uv)

# gesloten tussenmodel: de bron heeft losse schilfers en dubbele schillen, dat levert na decimeren scherven op.
# Een voxel-remesh van het hele model (gesloten, schoon) wordt daarna op dezelfde manier in delen gesneden.
vox = bpy.data.objects.new("Tiger_vox", me.copy()); bpy.context.scene.collection.objects.link(vox)
bpy.context.view_layer.objects.active = vox
for o in bpy.data.objects:
    o.select_set(o is vox)
vox.data.remesh_voxel_size = VOXEL
vox.data.remesh_voxel_adaptivity = 0.0
bpy.ops.object.voxel_remesh()
bm0 = bmesh.new(); bm0.from_mesh(vox.data); bmesh.ops.triangulate(bm0, faces=bm0.faces); bm0.to_mesh(vox.data); bm0.free()
vme = vox.data
print("voxel-remesh: %d driehoeken, %.0f s" % (len(vme.polygons), time.time() - t0), flush=True)
vv = np.empty(len(vme.vertices) * 3, np.float32); vme.vertices.foreach_get("co", vv); vv = vv.reshape(-1, 3)
vt = np.empty(len(vme.polygons) * 3, np.int32); vme.polygons.foreach_get("vertices", vt); vt = vt.reshape(-1, 3)
vc = (vv[vt[:, 0]] + vv[vt[:, 1]] + vv[vt[:, 2]]) / 3.0
bron_c = np.stack([-vc[:, 1] / TD.SCHAAL, vc[:, 0] / TD.SCHAAL, vc[:, 2] / TD.SCHAAL], axis=1)     # terug naar bronmaat voor de indeling
vlab = TD.indelen(bron_c)
np.savez(CACHE / "voxel.npz", co=vv, tri=vt, lab=vlab)


def vdeel(naam, sel):
    f = vt[sel]
    uniek, inv = np.unique(f.ravel(), return_inverse=True)
    m = bpy.data.meshes.new(naam)
    m.vertices.add(len(uniek)); m.vertices.foreach_set("co", vv[uniek].ravel())
    n = len(f)
    m.loops.add(n * 3); m.loops.foreach_set("vertex_index", inv.astype(np.int32))
    m.polygons.add(n); m.polygons.foreach_set("loop_start", np.arange(0, n * 3, 3, dtype=np.int32))
    m.polygons.foreach_set("loop_total", np.full(n, 3, np.int32))
    m.update(calc_edges=True)
    bm = bmesh.new(); bm.from_mesh(m)
    bmesh.ops.holes_fill(bm, edges=bm.edges, sides=4000)       # draaivlakken en sneden dichtmaken
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(m); bm.free()
    ob = bpy.data.objects.new(naam, m)
    bpy.context.scene.collection.objects.link(ob)
    ob.hide_render = True
    return ob


for naam, label in (("Romp_V", TD.ROMP), ("Toren_V", TD.TOREN)):
    ob = vdeel(naam, vlab == label)
    print(naam, len(ob.data.polygons), "driehoeken (dichtgemaakt)")
vox.hide_render = True
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "delen_hoog.blend"))
print("STAP1 klaar in %.0f s" % (time.time() - t0))
