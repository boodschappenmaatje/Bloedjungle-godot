"""Stap 4 (vijandelijke tank): hiërarchie met draaipunten, animatieclips, .blend en .glb.
Knopen (contract met scripts/vijand_tank.gd): VijandTank > Body > [RompMesh, RupsL, RupsR, WielL_w1..w9, WielL_aandrijf, WielL_spanwiel (en R),
Toren > [TorenMesh, Kanon > [KanonMesh, Monding]]]. Voorkant = +Y in Blender (wordt -Z in Godot), 1 eenheid = 1 meter, grond op z = 0.
Clips (30 beelden/s): Vuren (loop schiet terug en veert, 0,4 s), Rijden-loop en Draaien-loop (wielen draaien).
Het spel stuurt Toren (draait om Y), Kanon (kantelt om X), wielen en rupsen (textuur-offset) zelf; de clips bewegen alleen Body, wielen en KanonMesh.
Gebruik: python3 stap4_export.py <cache-map> <uit-map> [textuurgrootte spel]"""
import sys, math, time
import numpy as np
import bpy
from mathutils import Vector, Matrix
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tank_delen as TD

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[-3:]
CACHE, UIT = Path(args[0]).resolve(), Path(args[1]).resolve()
GAME_TEX = int(args[2]) if len(args) > 2 else 2048
UIT.mkdir(parents=True, exist_ok=True)
K = TD.SCHAAL
FPS = 30
bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"   # sleutel elk beeld; lineair houdt wielen gelijkmatig
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "gebakken.blend"))
scene = bpy.context.scene
view = bpy.context.view_layer
scene.render.fps = FPS
for n in ("Tank_HQ", "Tank_vox", "Romp_V", "Toren_V", "Romp_HQ", "Toren_HQ", "Kanon_HQ"):
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n])
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.name = o.name


def leeg(naam, loc, ouder=None):
    e = bpy.data.objects.new(naam, None)
    e.empty_display_type = "PLAIN_AXES"; e.empty_display_size = 0.3
    scene.collection.objects.link(e)
    if ouder is not None:
        e.parent = ouder
        e.matrix_parent_inverse = Matrix.Identity(4)
    e.location = Vector(loc)
    return e


def zet_mesh(ob, ouder, punt, ouder_punt):
    """vorm blijft staan in modelruimte (spelmaat); de oorsprong van het object komt op `punt`, lokaal t.o.v. `ouder` (die op `ouder_punt` staat)"""
    ob.data.transform(Matrix.Translation(-Vector(punt)))
    ob.parent = ouder
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.location = Vector(punt) - Vector(ouder_punt)
    ob.rotation_euler = (0.0, 0.0, 0.0)


# meshes eerst hun eindnaam geven, anders krijgen de lege knopen met dezelfde naam een ".001"
bpy.data.objects["Romp"].name = "RompMesh"
bpy.data.objects["Toren"].name = "TorenMesh"
bpy.data.objects["Kanon"].name = "KanonMesh"
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.name = o.name
root = leeg("VijandTank", (0.0, TD.MIDDEN_Y, TD.GROND_Z))
body = leeg("Body", (0, 0, 0), root)
toren_p = (0.0, -TD.TOREN_AS[0] * K, TD.TOREN_AS[1] * K)
kanon_m = bpy.data.objects["KanonMesh"]
loop_p = tuple(kanon_m["draaipunt"])
tilt = math.atan(kanon_m["helling"])
toren = leeg("Toren", toren_p, body)
kanon = leeg("Kanon", Vector(loop_p) - Vector(toren_p), toren)
monding = leeg("Monding", Matrix.Rotation(-tilt, 3, "X") @ (Vector(kanon_m["monding"]) - Vector(loop_p)), kanon)

zet_mesh(bpy.data.objects["RompMesh"], body, (0, 0, 0), (0, 0, 0))
zet_mesh(bpy.data.objects["TorenMesh"], toren, toren_p, toren_p)
toren_m = bpy.data.objects["TorenMesh"]; toren_m.location = (0, 0, 0)
zet_mesh(kanon_m, kanon, loop_p, loop_p)
kanon_m.location = (0, 0, 0)
kanon_m.rotation_euler = (-tilt, 0, 0)       # de bronloop wijst 3° omhoog; het spel richt zelf, dus recht gezet
for n in ("RupsL", "RupsR"):
    zet_mesh(bpy.data.objects[n], body, (0, 0, 0), (0, 0, 0))
wielen = []
for o in [o for o in bpy.data.objects if o.name.startswith("Wiel")]:
    zet_mesh(o, body, tuple(o["naaf"]), (0, 0, 0)); wielen.append(o)
view.update()

# ---------- clips ----------
R = float(np.mean([max(abs(v.co.y) for v in w.data.vertices) for w in wielen if "_w" in w.name]))   # wielstraal
print("wielstraal %.3f m" % R)
V_REF = 4.0                  # m/s: snelheid waarbij clip Rijden precies de rups bijhoudt
V_TURN = 2.2                 # m/s rupssnelheid in clip Draaien
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data_clear()
RUST = {}


def clip(naam, seconden, sleutels):
    """sleutels: lijst (object, eigenschap, index, functie t(0..1) -> waarde). Elke clip is een NLA-spoor met de clipnaam
    (zo exporteert Blender alle objecten van één clip als één animatie); sleutels vanaf beeld 0 zodat de lengte exact klopt."""
    n = int(round(seconden * FPS))
    perobject = {}
    for s in sleutels:
        perobject.setdefault(s[0], []).append(s)
    for ob, lijst in perobject.items():
        ob.animation_data_create()
        act = bpy.data.actions.new("%s_%s" % (naam, ob.name))
        ob.animation_data.action = act
        for ob_, pad, idx, fn in lijst:
            for f in range(n + 1):
                getattr(ob, pad)[idx] = fn(f / n)
                ob.keyframe_insert(pad, index=idx, frame=f)
        ob.animation_data.action = None
        tr = ob.animation_data.nla_tracks.new(); tr.name = naam
        tr.strips.new(act.name, 0, act)
        for ob_, pad, idx, fn in lijst:     # rustpositie terug, zodat een volgende clip er niet op doorbouwt
            getattr(ob, pad)[idx] = RUST.get((ob.name, pad, idx), 0.0)


def wiel_sleutels(snelheid_l, snelheid_r, seconden):
    out = []
    for w in wielen:
        vz = snelheid_l if w.name.startswith("WielL") else snelheid_r
        hoek = vz * seconden / R
        out.append((w, "rotation_euler", 0, (lambda t, h=hoek: -h * t)))
    return out


T_RIJ = 2 * math.pi * R / V_REF            # één wielomwenteling per lus
s = [(body, "location", 2, lambda t: 0.025 * math.sin(2 * math.pi * t * 2)),
     (body, "rotation_euler", 0, lambda t: 0.004 * math.sin(2 * math.pi * t * 2 + 0.8))]
clip("Rijden-loop", T_RIJ, s + wiel_sleutels(V_REF, V_REF, T_RIJ))
T_DR = 2 * math.pi * R / V_TURN
clip("Draaien-loop", T_DR, [(body, "location", 2, lambda t: 0.012 * math.sin(2 * math.pi * t * 3))] + wiel_sleutels(-V_TURN, V_TURN, T_DR))


def terug(t):
    """schot: de loop schiet in 0,03 s terug en komt rustig weer naar voren (0,4 s)"""
    if t < 0.075:
        return -0.6 * t / 0.075
    return -0.6 * max(0.0, 1.0 - (t - 0.075) / 0.925) ** 2


clip("Vuren", 0.4, [
    (kanon_m, "location", 1, terug),
    (body, "rotation_euler", 0, lambda t: 0.014 * math.exp(-t * 6) * math.sin(t * 26))])
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "vijand_tank.blend"), compress=True)
# game-textuur: kleiner dan de bake
for im in bpy.data.images:
    if im.name.startswith("VijandTank_") and im.name.endswith(("_albedo", "_normal", "_orm")) and "rups" not in im.name and max(im.size) > GAME_TEX:
        im.scale(GAME_TEX, GAME_TEX)
for o in bpy.data.objects:
    o.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(UIT / "vijand_tank.glb"), export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_image_format="JPEG", export_jpeg_quality=88, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_optimize_animation_size=False)
print("driehoeken:", sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))
print("STAP4 klaar; vijand_tank.glb in", UIT)
