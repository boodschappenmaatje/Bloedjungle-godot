"""Stap 2 (module): deelt de gesloten voxel-schil van de module in (delen_module.py), maakt de delen dicht, decimeert en geeft UV's.
Schrijft <cache>/module_laag.blend. Gebruik: python3 stap2_module.py <cache-map>"""
import sys, time
import numpy as np
import bpy
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen_module as D
import hulp as H

CACHE = Path(sys.argv[-1]).resolve()
t0 = time.time()
DOEL = {"Kern": 14000, "Dak_L": 6500, "Dak_R": 6500, "Mast": 4500, "Schotel": 3000}
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene; view = bpy.context.view_layer
d = np.load(CACHE / "module_voxel.npz")
co_m, tri = d["co"], d["tri"]
lab = D.indelen(co_m[tri].mean(axis=1))
game = D.naar_spel(co_m).astype(np.float32)
print("labels:", {int(k): int(v) for k, v in zip(*np.unique(lab, return_counts=True))}, flush=True)
delen = []
for label, naam in D.NAMEN.items():
    ob = H.deel_uit_schil(scene, naam, game, tri, lab == label)
    print("deel %s: %d driehoeken voor decimeren" % (naam, len(ob.data.polygons)), flush=True)
    H.dichtmaken(ob)
    H.decimeer(view, ob, DOEL[naam])
    delen.append(ob)
    print("  -> %d driehoeken" % len(ob.data.polygons), flush=True)
H.uv_atlas(view, delen)
print("laag klaar: %d driehoeken, %.0f s" % (sum(len(o.data.polygons) for o in delen), time.time() - t0))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "module_laag.blend"))
