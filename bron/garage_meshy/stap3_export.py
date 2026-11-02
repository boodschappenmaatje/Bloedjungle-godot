"""Stap 3: draaipunten, lampen, LOD1, clips Open/Dicht/Show-loop en export naar garage.glb + garage.blend.
Gebruik: python3 stap3_export.py <cache-map> <uit-map>
Contract met scripts/buildings.gd: Romp, Romp_LOD1, Binnen, DeurL/DeurR (scharnieren buitenkant, draaien naar buiten),
lampen DeurLampL/M/R en BinnenLamp. Voorkant = -Y in Blender = +Z in Godot."""
import sys, json, math
import bpy
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
CACHE, UIT = Path(args[0]).resolve(), Path(args[1]).resolve()
UIT.mkdir(parents=True, exist_ok=True)
M = json.loads((CACHE / "maten.json").read_text())
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "gebakken.blend"))
scene = bpy.context.scene; view = bpy.context.view_layer
FPS = 30; scene.render.fps = FPS
PX0, PX1 = M["poort_x"]; PY = M["poort_y"][0]
LOD1_TRIS = 5000
HOEK = math.radians(88)

def alleen(o):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); view.objects.active = o

# scharnier = buitenste voorrand van elke deur
for naam, x in (("DeurL", PX0), ("DeurR", PX1)):
    o = bpy.data.objects[naam]; alleen(o)
    scene.cursor.location = (x, PY, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

# enkelzijdig: de romp is een gesloten schil, de binnenbak kijkt naar binnen (Meshy zette alles dubbelzijdig)
for m in bpy.data.materials:
    m.use_backface_culling = True

# LOD1: vereenvoudigde romp met dezelfde atlas
romp = bpy.data.objects["Romp"]
lod = romp.copy(); lod.data = romp.data.copy(); lod.name = "Romp_LOD1"; scene.collection.objects.link(lod)
alleen(lod)
d = lod.modifiers.new("dec", "DECIMATE"); d.ratio = LOD1_TRIS / len(lod.data.polygons)
bpy.ops.object.modifier_apply(modifier="dec")
print("LOD1", len(lod.data.polygons), "driehoeken; romp", len(romp.data.polygons), flush=True)

# lampen (waarden zijn Godot-energie; het spel zet bereik en zichtbaarheid)
def lamp(naam, soort, loc, energie, rot=(0, 0, 0), kleur=(1.0, 0.82, 0.55)):
    ld = bpy.data.lights.new(naam, soort); ld.energy = energie; ld.color = kleur
    if soort == "SPOT":
        ld.spot_size = math.radians(80); ld.spot_blend = 0.5
    ob = bpy.data.objects.new(naam, ld); ob.location = loc; ob.rotation_euler = rot; scene.collection.objects.link(ob)
    return ob
neer = (math.radians(35), 0, 0)    # schuin naar voren omlaag, het voorplein op
lamp("DeurLampL", "SPOT", (-1.75, -4.5, 3.6), 2.0, neer)
lamp("DeurLampM", "SPOT", (0.0, -4.6, 4.15), 2.0, neer)
lamp("DeurLampR", "SPOT", (1.75, -4.5, 3.55), 2.0, neer)
lamp("BinnenLamp", "POINT", ((PX0 + PX1) / 2, PY + 3.0, 3.4), 1.2)

# clips: deuren draaien naar buiten (L: -88°, R: +88° om Z)
def zacht(t):
    return t * t * (3 - 2 * t)

def clip(naam, sec, fn):
    n = int(round(sec * FPS))
    for o, teken in ((bpy.data.objects["DeurL"], -1), (bpy.data.objects["DeurR"], 1)):
        o.animation_data_create()
        act = bpy.data.actions.new("%s_%s" % (naam, o.name)); o.animation_data.action = act
        for f in range(n + 1):
            o.rotation_euler[2] = teken * HOEK * fn(f / n)
            o.keyframe_insert("rotation_euler", index=2, frame=f)
        o.animation_data.action = None
        tr = o.animation_data.nla_tracks.new(); tr.name = naam; tr.strips.new(act.name, 0, act)
        o.rotation_euler[2] = 0.0

clip("Dicht", 2.0, lambda t: 1 - zacht(t))   # eerst: rustpose dicht
clip("Open", 2.0, lambda t: zacht(t))
clip("Show-loop", 6.0, lambda t: zacht(min(1, t * 3)) if t < 0.5 else 1 - zacht(min(1, (t - 0.5) * 3)))
scene.frame_start, scene.frame_end = 0, 60

bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "garage.blend"), compress=True)
bpy.ops.export_scene.gltf(filepath=str(UIT / "garage.glb"), export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False,
                          export_lights=True, export_import_convert_lighting_mode="RAW",
                          export_image_format="JPEG", export_jpeg_quality=88, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_optimize_animation_size=False)
print("STAP3 klaar", UIT, flush=True)
