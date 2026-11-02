"""Stap 1: Meshy-garage op ware grootte zetten, poort meten, gesloten schil maken (voxel-remesh) en vereenvoudigen.
Gebruik: python3 stap1_laag.py <bron.glb> <cache-map> [schaal] [doel-driehoeken]
Schaal 6,5 = keuze B (poort 3,9 x 2,6 m, net als de oude garage). Schrijft hq.blend en laag.blend in de cache."""
import sys, json, time
import numpy as np
import bpy
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
SRC, CACHE = Path(args[0]).resolve(), Path(args[1]).resolve()
S = float(args[2]) if len(args) > 2 else 6.5
DOEL = int(args[3]) if len(args) > 3 else 36000
VOXEL = 0.035
CACHE.mkdir(parents=True, exist_ok=True)
t0 = time.time()

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SRC))
hq = next(o for o in bpy.data.objects if o.type == "MESH")
hq.name = "Garage_HQ"
bpy.context.view_layer.objects.active = hq
hq.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

me = hq.data
co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
co *= S
mn, mx = co.min(0), co.max(0)
# midden van het totale terrein in x/y, onderkant op de grond
shift = np.array([-(mn[0] + mx[0]) / 2, -(mn[1] + mx[1]) / 2, -mn[2]], np.float32)
co += shift
me.vertices.foreach_set("co", co.ravel()); me.update()
mn, mx = co.min(0), co.max(0)

# poort meten: de deurplaat is het voorste grote vlak in het midden (Meshy-eenheden -0.66..-0.59 in y)
door_y_unit = (-0.66, -0.585)
yu = (co[:, 1] - shift[1]) / S
zu = co[:, 2] / S
m = (np.abs((co[:, 0] - shift[0]) / S) < 0.33) & (yu > door_y_unit[0]) & (yu < door_y_unit[1]) & (zu > 0.04) & (zu < 0.40)
dx = np.percentile(co[m, 0], [0.5, 99.5])
dz = np.percentile(co[m, 2], [0.5, 99.5])
dy = np.percentile(co[m, 1], [2, 50, 98])
info = {"schaal": S, "bbox_min": mn.tolist(), "bbox_max": mx.tolist(), "shift": shift.tolist(),
        "poort_x": dx.tolist(), "poort_z": dz.tolist(), "poort_y": dy.tolist(), "hq_tris": len(me.polygons)}
print("INFO", json.dumps(info), flush=True)
(CACHE / "maten.json").write_text(json.dumps(info, indent=1))
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "hq.blend"))

# gesloten schil en vereenvoudigen
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
low.data.uv_layers.clear() if hasattr(low.data.uv_layers, "clear") else None
while len(low.data.uv_layers):
    low.data.uv_layers.remove(low.data.uv_layers[0])
bpy.data.objects.remove(hq)
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "laag.blend"))
print("klaar %.0f s" % (time.time() - t0), flush=True)
