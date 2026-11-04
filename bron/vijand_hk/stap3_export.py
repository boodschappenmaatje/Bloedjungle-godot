"""Stap 3: LOD1 en wrak maken en exporteren naar vijand_hk.glb + vijand_hk.blend.
Gebruik: python3 stap3_export.py <cache-map> <uit-map>
Contract met scripts/vijand_hk.gd: knopen Romp (± 45.000 driehoeken), Romp_LOD1 (5.000, dezelfde atlas) en Wrak (ingestort, ± 7.000,
dezelfde atlas; het spel maakt hem donker). Voorkant (deur, "HQ") = -Y in Blender = +Z in Godot, onderkant op de grond, midden in de oorsprong."""
import sys, json, math
import numpy as np
import bpy
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
CACHE, UIT = Path(args[0]).resolve(), Path(args[1]).resolve()
UIT.mkdir(parents=True, exist_ok=True)
M = json.loads((CACHE / "maten.json").read_text())
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "gebakken.blend"))
scene = bpy.context.scene; view = bpy.context.view_layer
FPS = 30; scene.render.fps = FPS
LOD1_TRIS = 5000
WRAK_TRIS = 7000


def alleen(o):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); view.objects.active = o


# enkelzijdig: de romp is een gesloten schil (Meshy zette alles dubbelzijdig)
for m in bpy.data.materials:
    m.use_backface_culling = True

romp = bpy.data.objects["Romp"]


def kopie(naam, doel):
    o = romp.copy(); o.data = romp.data.copy(); o.name = naam; scene.collection.objects.link(o)
    alleen(o)
    d = o.modifiers.new("dec", "DECIMATE"); d.ratio = doel / len(o.data.polygons)
    bpy.ops.object.modifier_apply(modifier="dec")
    return o


lod = kopie("Romp_LOD1", LOD1_TRIS)
wrak = kopie("Wrak", WRAK_TRIS)

# wrak: ingestort tot 30% van de hoogte, een beetje uitgespreid en deukerig (zelfde UV's, het spel maakt hem zwart)
me = wrak.data
co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
hoog = float(M["bbox_max"][2])
rel = np.clip(co[:, 2] / hoog, 0, 1)
ruis = (np.sin(co[:, 0] * 1.9 + co[:, 1] * 2.3) + np.sin(co[:, 1] * 1.4 - co[:, 0] * 2.7 + 1.3) + np.sin(co[:, 0] * 4.1 + co[:, 1] * 3.3 + co[:, 2] * 2.2)) / 3.0
co[:, 2] = np.maximum(0.0, co[:, 2] * 0.30 + ruis * 0.45 * (0.25 + rel))
co[:, 0] *= 1.0 + 0.05 * rel
co[:, 1] *= 1.0 + 0.05 * rel
co[:, 0] += np.sin(co[:, 1] * 2.1 + co[:, 2]) * 0.18 * rel
me.vertices.foreach_set("co", co.ravel()); me.update()
print("LOD1", len(lod.data.polygons), "driehoeken; wrak", len(wrak.data.polygons), "; romp", len(romp.data.polygons), flush=True)

scene.frame_start, scene.frame_end = 0, 60
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "vijand_hk.blend"), compress=True)
bpy.ops.export_scene.gltf(filepath=str(UIT / "vijand_hk.glb"), export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False,
                          export_lights=False, export_image_format="JPEG", export_jpeg_quality=88, export_animations=False)
print("STAP3 klaar", UIT, flush=True)
