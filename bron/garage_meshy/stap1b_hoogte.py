"""Stap 1b: hogere poort. De legertruck (dak tot ~4,1 m) paste niet onder de poort van 2,3 m. Het model wordt in Z
uitgerekt: onder B0 blijft alles gelijk, tussen B0 en de bovenkant van de poort (B1) wordt de wand D m hoger, alles
erboven (latei, schilden, bord, dak, lampen) schuift D m omhoog. Breedte en diepte veranderen niet.
Gebruik: python3 stap1b_hoogte.py <cache-in> <cache-uit> [D=1.8]
Leest hq.blend, laag.blend, maten.json van stap 1; schrijft dezelfde bestanden (hoger) naar <cache-uit>."""
import sys, json, shutil
import numpy as np
import bpy, bmesh
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
IN, UIT = Path(args[0]).resolve(), Path(args[1]).resolve()
D = float(args[2]) if len(args) > 2 else 1.8
B0 = 1.0
UIT.mkdir(parents=True, exist_ok=True)
M = json.loads((IN / "maten.json").read_text())
B1 = M["poort_z"][1]
F = (B1 - B0 + D) / (B1 - B0)


def warp(z):
    return np.where(z <= B0, z, np.where(z < B1, B0 + (z - B0) * F, z + D))


def warp_object(ob, bisect):
    me = ob.data
    if bisect:  # eerst doorsnijden op B0 en B1, zodat grote driehoeken netjes meerekken
        bm = bmesh.new(); bm.from_mesh(me)
        for z in (B0, B1):
            bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-5, plane_co=(0, 0, z), plane_no=(0, 0, 1))
        bm.to_mesh(me); bm.free()
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    co[:, 2] = warp(co[:, 2].astype(np.float64)).astype(np.float32)
    me.vertices.foreach_set("co", co.ravel())
    me.update()


bpy.ops.wm.open_mainfile(filepath=str(IN / "laag.blend"))
romp = bpy.data.objects["Romp"]
assert np.allclose(np.array(romp.matrix_world), np.eye(4)), "Romp heeft een transform"
warp_object(romp, True)
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "laag.blend"))

bpy.ops.wm.open_mainfile(filepath=str(IN / "hq.blend"))
hq = bpy.data.objects["Garage_HQ"]
assert np.allclose(np.array(hq.matrix_world), np.eye(4)), "HQ heeft een transform"
warp_object(hq, False)
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "hq.blend"))

M["poort_z"][1] = B1 + D
M["bbox_max"][2] = M["bbox_max"][2] + D
M["hoogte_extra"] = D
(UIT / "maten.json").write_text(json.dumps(M, indent=1))
print("klaar: poort tot", B1 + D, "bouwhoogte", M["bbox_max"][2])
