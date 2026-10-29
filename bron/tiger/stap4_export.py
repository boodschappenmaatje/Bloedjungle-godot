"""Stap 4: hiërarchie met draaipunten, animatieclips, .blend en .glb.
Knopen (zoals tank.gd verwacht): Tank > Body > [RompMesh, Wiel*, RupsL, RupsR, Toren > [TorenMesh, Loop > [LoopMesh, Monding]]]
Voorkant = +Y in Blender (wordt -Z in Godot), 1 eenheid = 1 meter.
Clips (lus waar gemeld): Stationair-loop, Rijden-loop, Achteruit-loop, Draaien-loop, Schieten.
Het spel stuurt Tank, Toren (draait om Y) en Loop (kantelt om X) zelf; de clips bewegen alleen Body, wielen en LoopMesh.
Gebruik: python3 stap4_export.py <cache-map> <uit-map> [textuurgrootte spel]"""
import sys, math, time
import numpy as np
import bpy
from mathutils import Vector
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tiger_delen as TD

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
for n in ("Tiger_HQ", "Tiger_vox", "Romp_V", "Toren_V", "Romp_HQ", "Toren_HQ", "Kanon_HQ"):
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n])


def leeg(naam, loc=(0, 0, 0), parent=None):
    e = bpy.data.objects.new(naam, None)
    e.empty_display_type = "PLAIN_AXES"
    scene.collection.objects.link(e)
    e.location = loc
    if parent:
        e.parent = parent
    return e


def zet_origin(ob, punt):
    """object-oorsprong naar `punt` (wereldruimte) zonder de vorm te verplaatsen"""
    d = Vector(punt) - ob.location
    ob.data.transform(__import__("mathutils").Matrix.Translation(-d))
    ob.location = Vector(punt)


def hang(ob, ouder):
    m = ob.matrix_world.copy()
    ob.parent = ouder
    ob.matrix_parent_inverse = ouder.matrix_world.inverted()
    ob.matrix_world = m


# meshes eerst hun eindnaam geven, anders krijgen de lege knopen met dezelfde naam een ".001"
bpy.data.objects["Romp"].name = "RompMesh"
bpy.data.objects["Toren"].name = "TorenMesh"
bpy.data.objects["Kanon"].name = "LoopMesh"
tank = leeg("Tank", (0.0, TD.MIDDEN_Y, TD.GROND_Z))
body = leeg("Body", parent=tank)
toren_p = (0.0, -TD.TOREN_AS[0] * K, TD.TOREN_AS[1] * K)
kanon = bpy.data.objects["LoopMesh"]
loop_p = tuple(kanon["draaipunt"])
tilt = math.atan(kanon["helling"])
toren = leeg("Toren", toren_p, body)
loop = leeg("Loop", (0, 0, 0), toren)
loop.location = Vector(loop_p) - Vector(toren_p)
monding = leeg("Monding", (0, 0, 0), loop)
from mathutils import Matrix
monding.location = Matrix.Rotation(-tilt, 3, "X") @ (Vector(kanon["monding"]) - Vector(loop_p))

rompm = bpy.data.objects["RompMesh"]
zet_origin(rompm, (0, 0, 0)); hang(rompm, body)
torm = bpy.data.objects["TorenMesh"]
zet_origin(torm, toren_p); hang(torm, toren)
torm.location = (0, 0, 0)
zet_origin(kanon, loop_p); hang(kanon, loop)
kanon.location = (0, 0, 0)
kanon.rotation_euler = (-tilt, 0, 0)       # de bronloop wijst 3° omhoog; het spel richt zelf, dus recht gezet
for n in ("RupsL", "RupsR"):
    o = bpy.data.objects[n]; zet_origin(o, (0, 0, 0)); hang(o, body)
wielen = []
for o in [o for o in bpy.data.objects if o.name.startswith("Wiel")]:
    zet_origin(o, o["naaf"]); hang(o, body); wielen.append(o)
# loc van de losse meshes bij ouders: matrix_parent_inverse heeft de wereldpositie vastgelegd
view.update()

# ---------- clips ----------
R = float(np.mean([max(abs(v.co.y) for v in w.data.vertices) for w in wielen if "_w" in w.name]))   # wielstraal
print("wielstraal %.3f m" % R)
V_REF = 3.12                 # m/s: snelheid waarbij clip Rijden precies de rups bijhoudt (tank.gd ANIM_SPEED)
V_TURN = 2.2                 # m/s rupssnelheid in clip Draaien (ongeveer 1,5 rad/s)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data_clear()


RUST = {}


def clip(naam, seconden, sleutels, lus=True):
    """sleutels: lijst (object, eigenschap, index, functie t(0..1) -> waarde, soort). Elke clip is een NLA-spoor met de clipnaam
    (zo exporteert Blender alle objecten van één clip als één animatie); sleutels vanaf beeld 0 zodat de lengte exact klopt."""
    n = int(round(seconden * FPS))
    perobject = {}
    for s in sleutels:
        perobject.setdefault(s[0], []).append(s)
    for ob, lijst in perobject.items():
        ob.animation_data_create()
        act = bpy.data.actions.new("%s_%s" % (naam, ob.name))
        ob.animation_data.action = act
        for ob_, pad, idx, fn, kind in lijst:
            for f in range(n + 1):
                getattr(ob, pad)[idx] = fn(f / n)
                ob.keyframe_insert(pad, index=idx, frame=f)
        ob.animation_data.action = None
        tr = ob.animation_data.nla_tracks.new(); tr.name = naam
        tr.strips.new(act.name, 0, act)
        # rustpositie terug, zodat een volgende clip niet erop doorbouwt
        for ob_, pad, idx, fn, kind in lijst:
            getattr(ob, pad)[idx] = RUST.get((ob.name, pad, idx), 0.0)


def wiel_sleutels(snelheid_l, snelheid_r, seconden):
    """Elk wiel draait om zijn eigen as; links/rechts met eigen rupssnelheid (m/s, + = vooruit)"""
    out = []
    for w in wielen:
        vz = snelheid_l if w.name.startswith("WielL") else snelheid_r
        hoek = vz * seconden / R                            # radialen in de hele clip
        out.append((w, "rotation_euler", 0, (lambda t, h=hoek: -h * t), "rot"))
    return out


# Stationair: motor trilt, romp
act_st = clip("Stationair-loop", 1.0, [
    (body, "location", 2, lambda t: 0.012 * math.sin(2 * math.pi * t * 6), "loc"),
    (body, "rotation_euler", 0, lambda t: 0.0015 * math.sin(2 * math.pi * t * 4 + 1.0), "rot")])
T_RIJ = 2 * math.pi * R / V_REF           # eén wielomwenteling per lus
def rij_clip(naam, richting):
    s = [(body, "location", 2, lambda t: 0.03 * math.sin(2 * math.pi * t * 2), "loc"),
         (body, "rotation_euler", 0, lambda t: 0.004 * richting * math.sin(2 * math.pi * t * 2 + 0.8), "rot")]
    s += wiel_sleutels(richting * V_REF, richting * V_REF, T_RIJ)
    return clip(naam, T_RIJ, s)
rij_clip("Rijden-loop", 1)
rij_clip("Achteruit-loop", -1)
T_DR = 2 * math.pi * R / V_TURN
s = [(body, "location", 2, lambda t: 0.012 * math.sin(2 * math.pi * t * 3), "loc")]
s += wiel_sleutels(-V_TURN, V_TURN, T_DR)
clip("Draaien-loop", T_DR, s)
# Schieten: loop terugslag langs zijn as en de romp wipt na
def terug(t):
    """schot: de loop schiet in 0,04 s terug en komt rustig weer naar voren"""
    if t < 0.045:
        return -0.55 * t / 0.045
    return -0.55 * max(0.0, 1.0 - (t - 0.045) / 0.955) ** 2
clip("Schieten", 0.9, [
    (kanon, "location", 1, terug, "loc"),
    (body, "rotation_euler", 0, lambda t: 0.012 * math.exp(-t * 5) * math.sin(t * 22), "rot")])
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "tiger.blend"))
# game-textuur: kleiner dan de bake
for im in bpy.data.images:
    if im.name.startswith("Tiger_") and im.name.endswith(("_albedo", "_normal", "_orm")) and "rups" not in im.name:
        im.scale(GAME_TEX, GAME_TEX)
for o in bpy.data.objects:
    o.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(UIT / "tiger.glb"), export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_image_format="JPEG", export_jpeg_quality=88, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_optimize_animation_size=False)
print("STAP4 klaar; tiger.glb in", UIT)
