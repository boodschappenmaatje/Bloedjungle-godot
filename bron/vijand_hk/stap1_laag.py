"""Stap 1: Dennis' vijandelijke hoofdkwartier (Meshy, "Enemy hk.glb") op spelmaat zetten, meten en vereenvoudigen.
Gebruik: python3 stap1_laag.py <bron.glb> <cache-map> [breedte-m] [doel-driehoeken]
Breedte 9,0 m = even breed als het blok dat tot stap 5a-1 de vijand-HK was (Dennis: formaten gelijk houden).
Schrijft hq.blend (bron op maat), laag.blend (gesloten schil, ~doel driehoeken) en maten.json in de cache."""
import sys, json, time
import numpy as np
import bpy
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
SRC, CACHE = Path(args[0]).resolve(), Path(args[1]).resolve()
BREEDTE = float(args[2]) if len(args) > 2 else 9.0
DOEL = int(args[3]) if len(args) > 3 else 45000
VOXEL = 0.04
CACHE.mkdir(parents=True, exist_ok=True)
t0 = time.time()

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SRC))
hq = next(o for o in bpy.data.objects if o.type == "MESH")
hq.name = "HK_HQ"
bpy.context.view_layer.objects.active = hq
hq.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

me = hq.data
co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
mn, mx = co.min(0), co.max(0)
S = BREEDTE / max(mx[0] - mn[0], mx[1] - mn[1])
co *= S
mn, mx = co.min(0), co.max(0)
# midden van het grondvlak in x/y, onderkant op de grond; de voorkant (deur, "HQ") kijkt naar -Y in Blender (= +Z in Godot)
shift = np.array([-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2]], np.float32)
co += shift
me.vertices.foreach_set("co", co.ravel()); me.update()
mn, mx = co.min(0), co.max(0)

# kern van het gebouw (zonder de steunberen onderaan en de mast): bbox van de middelste hoogtes, voor de botsvorm in het spel
hoog = mx[2] - mn[2]
mid = (co[:, 2] > mn[2] + 0.35 * hoog) & (co[:, 2] < mn[2] + 0.55 * hoog)
kern_min, kern_max = np.percentile(co[mid], 1, axis=0), np.percentile(co[mid], 99, axis=0)
# dakhoogte: de hoogte waarop het meeste oppervlak ligt boven de helft (vlakke bovenkant)
bovenste = co[co[:, 2] > mn[2] + 0.5 * hoog, 2]
hist, edges = np.histogram(bovenste, bins=60)
dak = float(edges[int(np.argmax(hist))])
info = {"schaal": float(S), "bbox_min": mn.tolist(), "bbox_max": mx.tolist(), "shift": shift.tolist(),
        "kern_min": kern_min.tolist(), "kern_max": kern_max.tolist(), "dak_z": dak, "hq_tris": len(me.polygons)}
print("INFO", json.dumps(info), flush=True)
(CACHE / "maten.json").write_text(json.dumps(info, indent=1))
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "hq.blend"))

# gesloten schil (voxel-remesh) en vereenvoudigen
low = hq.copy(); low.data = hq.data.copy(); low.name = "Romp"
bpy.context.scene.collection.objects.link(low)
bpy.ops.object.select_all(action="DESELECT"); low.select_set(True); bpy.context.view_layer.objects.active = low
mod = low.modifiers.new("remesh", "REMESH"); mod.mode = "VOXEL"; mod.voxel_size = VOXEL; mod.adaptivity = 0.0
bpy.ops.object.modifier_apply(modifier="remesh")
print("remesh %d vlakken %.0f s" % (len(low.data.polygons), time.time() - t0), flush=True)
bpy.ops.object.modifier_add(type="TRIANGULATE"); bpy.ops.object.modifier_apply(modifier="Triangulate")
n = len(low.data.polygons)
mod = low.modifiers.new("dec", "DECIMATE"); mod.ratio = min(1.0, DOEL / n)
bpy.ops.object.modifier_apply(modifier="dec")
print("decimate %d driehoeken %.0f s" % (len(low.data.polygons), time.time() - t0), flush=True)
while len(low.data.uv_layers):
    low.data.uv_layers.remove(low.data.uv_layers[0])
bpy.data.objects.remove(hq)
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "laag.blend"))
print("klaar %.0f s" % (time.time() - t0), flush=True)
