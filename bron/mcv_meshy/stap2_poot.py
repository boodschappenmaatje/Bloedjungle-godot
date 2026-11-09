"""Stap 2 (poot): deelt de voxel-schil van de steunpoot in PootBoven en PootOnder, dicht, decimeert, UV's. Schrijft <cache>/poot_laag.blend.
Gebruik: python3 stap2_poot.py <cache-map>"""
import sys, time
import numpy as np
import bpy
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen_poot as D
import hulp as H

CACHE = Path(sys.argv[-1]).resolve()
DOEL = {"PootBoven": 3500, "PootOnder": 2500}
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene; view = bpy.context.view_layer
d = np.load(CACHE / "poot_voxel.npz")
co_m, tri = d["co"], d["tri"]
lab = D.indelen(co_m[tri].mean(axis=1))
game = D.naar_spel(co_m).astype(np.float32)
print("labels:", {int(k): int(v) for k, v in zip(*np.unique(lab, return_counts=True))}, flush=True)
delen = []
for label, naam in D.NAMEN.items():
    ob = H.deel_uit_schil(scene, naam, game, tri, lab == label)
    H.dichtmaken(ob)
    H.decimeer(view, ob, DOEL[naam])
    delen.append(ob)
    print("  %s -> %d driehoeken" % (naam, len(ob.data.polygons)), flush=True)
H.uv_atlas(view, delen)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "poot_laag.blend"))
print("laag klaar")
