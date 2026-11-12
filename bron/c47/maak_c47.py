"""Douglas C-47 Skytrain (transportvliegtuig voor de Parachutisten, E2): procedureel in Blender, PBR, echte clips.
Gebruik:  python3 maak_c47.py <uitmap> [--tex 1024] [--usdz]
Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van de romp, voorkant = +Y (in Godot -Z). Lengte 19,4 m, spanwijdte 28,8 m.
Knopen: C47 > Romp (+ vleugel, staart, ramen, gestel), PropL/PropR (draaien om Y; blad + PropSchijfL/R), RoerAs > Roer, Deur (scharnier achter de linkerdeur).
Clips: Stationair-loop (3 s, propellers los), Vliegen-loop (2 s, schijf), Bocht (3 s), Droppen (4 s, deur open, springlicht, deur weer dicht)."""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import bpy
from mathutils import Vector
import vlieg_common as vc

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(ARGS[0])
TEX = int(ARGS[ARGS.index("--tex") + 1]) if "--tex" in ARGS else 1024
scene = vc.init(OUT, TEX)
FPS = vc.FPS

BOVEN = vc.pbr("Boven", vc.lak_textures("c47_boven", [(0.27, 0.30, 0.17)], False, size=TEX, seed=51, vlek=0.14, roet_k=0.3))   # Olive Drab 41
ONDER = vc.pbr("Onder", vc.lak_textures("c47_onder", [(0.52, 0.54, 0.52)], False, size=TEX, seed=52, vlek=0.12, roet_k=0.25))  # Neutral Grey
STAAL = vc.pbr("Staal", vc.metaal_textures("c47_staal", (0.32, 0.32, 0.30), size=TEX // 2))
DONKER = vc.pbr("Donker", vc.metaal_textures("c47_donker", (0.06, 0.06, 0.06), size=TEX // 2, ruw=0.55, metaal=0.5, seed=81))
WIT = vc.pbr("InvasieWit", None, (0.85, 0.85, 0.82), 0.6, 0.0)
ZWART = vc.pbr("InvasieZwart", None, (0.03, 0.03, 0.03), 0.6, 0.0)
BLAUW = vc.pbr("Rondel", None, (0.04, 0.10, 0.30), 0.5, 0.0)
STER = vc.pbr("Ster", None, (0.9, 0.9, 0.9), 0.5, 0.0)
GLAS = vc.pbr("Glas", None, (0.10, 0.14, 0.16), 0.08, 0.6)
HOUT = vc.pbr("Binnenkant", None, (0.10, 0.10, 0.08), 0.8, 0.0)
GROEN = vc.pbr("Springlicht", None, (0.1, 1.0, 0.2), 0.4, 0.0, emit=(0.1, 1.0, 0.2), strength=3.0)
ROOD = vc.pbr("Springlicht rood", None, (1.0, 0.1, 0.05), 0.4, 0.0, emit=(1.0, 0.1, 0.05), strength=2.0)
SCHIJF = vc.pbr("PropSchijf", None, (0.05, 0.05, 0.05), 0.6, 0.0, alpha=0.22)
for m in (BOVEN, ONDER, STAAL, DONKER, WIT, ZWART, BLAUW, STER, GLAS, HOUT, GROEN, ROOD, SCHIJF):
    m.use_backface_culling = False

root = vc.leeg("C47")
romp = vc.leeg("Romp", root)

# ---------------------------------------------------------------- romp
SEC = [(9.7, 0.5, 0.6, -0.2, 2.0), (9.1, 1.3, 1.4, -0.05, 2.0), (8.0, 2.1, 2.2, 0.1, 2.2), (6.2, 2.5, 2.8, 0.2, 2.4),
       (3.0, 2.6, 3.0, 0.15, 2.6), (-2.0, 2.6, 3.0, 0.12, 2.6), (-5.5, 2.15, 2.5, 0.35, 2.4), (-8.5, 1.0, 1.2, 0.85, 2.1), (-9.8, 0.3, 0.45, 1.0, 2.0)]
SEC_F = vc.verfijn(SEC, 4)


def profiel_op(y):
    """Lineair geinterpoleerde doorsnede (w, h, zc) op hoogte y, voor de strepen."""
    s = sorted(SEC_F, key=lambda t: t[0])
    for a, b in zip(s, s[1:]):
        if a[0] <= y <= b[0]:
            k = (y - a[0]) / max(b[0] - a[0], 1e-6)
            return tuple(a[i] + (b[i] - a[i]) * k for i in (1, 2, 3, 4))
    return s[0][1:5]


body = vc.loft("Romprompel", SEC_F, BOVEN, ONDER, romp, segs=24)


def band(naam, y0, y1, mat, grow=0.02):
    ys = [y0 + (y1 - y0) * i / 4 for i in range(5)]
    sec = []
    for y in ys:
        w, h, zc, p = profiel_op(y)
        sec.append((y, w + grow, h + grow, zc, p))
    return vc.loft(naam, sec, mat, None, romp, segs=24)


for i, (ya, yb) in enumerate([(-8.4, -7.7), (-7.0, -6.3), (-5.6, -4.9)]):
    band(f"StreepRomp{i}", ya, yb, WIT if i % 2 == 0 else ZWART)
band("StreepRomp3", -7.7, -7.0, ZWART)
band("StreepRomp4", -6.3, -5.6, WIT)

# ---------------------------------------------------------------- vleugel (laag, verjongd) over de hele spanwijdte
half = [(1.2, 1.7, 4.7, 0.75, -1.0), (5.0, 1.3, 4.1, 0.52, -0.92), (9.5, 0.5, 3.1, 0.36, -0.62), (14.4, -0.3, 1.9, 0.2, -0.15)]
vl = [(-x, y0, c, d, z) for (x, y0, c, d, z) in reversed(half[1:])] + [(-0.6, 1.7, 4.8, 0.78, -1.0), (0.6, 1.7, 4.8, 0.78, -1.0)] + half[1:]
wing = vc.vleugel("Vleugel", vl, 0.0, 1.0, BOVEN, ONDER, romp, n=9)

# ---------------------------------------------------------------- staart
stab_sec = [(-4.7, -8.9, 1.2, 0.12, 0.95), (0.0, -7.6, 2.3, 0.3, 0.95), (4.7, -8.9, 1.2, 0.12, 0.95)]
vc.vleugel("Stabilisator", stab_sec, 0.0, 0.62, BOVEN, ONDER, romp, n=6)
roer_as = vc.leeg("RoerAs", romp, (0, -9.15, 1.1))
fin_sec = [(0.0, -6.5, 3.6, 0.36, 0.0), (3.3, -8.4, 2.0, 0.12, 0.0)]
fin = vc.vleugel("Kiel", fin_sec, 0.0, 0.62, BOVEN, None, romp)
fin.rotation_euler = (0, math.radians(-90), 0)
fin.location = (0, 0, 1.05)
for v in fin.data.vertices:
    pass
roer = vc.vleugel("Roer", [(0.0, -6.5, 3.6, 0.3, 0.0), (3.3, -8.4, 2.0, 0.1, 0.0)], 0.62, 1.0, BOVEN, None, roer_as)
roer.rotation_euler = (0, math.radians(-90), 0)
roer.location = (0, 9.15, -0.05)

# ---------------------------------------------------------------- motoren, propellers
PROPS = {}
for sgn, nm in ((-1, "L"), (1, "R")):
    x = sgn * 4.9
    nac = vc.loft(f"Motorkap{nm}", [(3.5, 1.1, 1.1, -0.85, 2.4), (3.3, 1.9, 1.9, -0.85, 2.4), (2.4, 2.0, 2.0, -0.85, 2.6), (0.5, 1.7, 1.7, -0.9, 2.4), (-2.0, 1.2, 1.15, -1.0, 2.2), (-4.4, 0.5, 0.45, -1.05, 2.0)], BOVEN, ONDER, romp, loc=(x, 0, 0), segs=20)
    vc.cyl(f"Uitlaat{nm}", 0.07, 0.8, DONKER, romp, (x + sgn * 0.95, 2.3, -0.5), "y", 8)
    pr = vc.leeg(f"Prop{nm}", romp, (x, 3.75, -0.85))
    vc.cyl(f"Spinner{nm}", 0.28, 0.5, STAAL, pr, (0, 0.2, 0), "y", 12, r2=0.06)
    for b in range(3):
        a = math.radians(120 * b)
        arm = vc.leeg(f"BladArm{nm}{b}", pr)
        arm.rotation_euler = (0, a, 0)
        bl = vc.doos(f"Blad{nm}{b}", (0.26, 0.05, 1.75), DONKER, arm, (0, 0, 1.05))
        bl.rotation_euler = (0, 0, 0)
        tip = vc.doos(f"BladTip{nm}{b}", (0.2, 0.052, 0.18), STER, arm, (0, 0, 1.85))
    disc = vc.cyl(f"PropSchijf{nm}", 2.0, 0.01, SCHIJF, pr, (0, 0.05, 0), "y", 24)
    PROPS[nm] = (pr, disc)
    # hoofdwiel (vast uitgeklapt) met schokdemper
    vc.doos(f"Poot{nm}", (0.18, 0.3, 1.9), STAAL, romp, (x, 0.3, -1.95))
    w = vc.cyl(f"Wiel{nm}", 0.62, 0.34, DONKER, romp, (x, 0.3, -2.75), "x", 16)

# staartwiel
vc.doos("StaartPoot", (0.1, 0.12, 1.3), STAAL, romp, (0, -8.5, -0.15))
vc.cyl("StaartWiel", 0.22, 0.12, DONKER, romp, (0, -8.55, -0.9), "x", 12)

# ---------------------------------------------------------------- cockpit en ramen
vc.doos("Voorruit", (1.5, 0.08, 0.7), GLAS, romp, (0, 8.05, 0.8), (math.radians(35), 0, 0))
for sgn in (-1, 1):
    vc.doos(f"Zijruit{sgn}", (0.04, 1.2, 0.55), GLAS, romp, (sgn * 1.0, 7.0, 0.85), (0, 0, 0))
    for i in range(7):
        vc.doos(f"Raam{sgn}{i}", (0.04, 0.45, 0.5), GLAS, romp, (sgn * 1.31, 4.2 - 1.15 * i, 0.55 - 0.0))
    vc.cyl(f"RondelRomp{sgn}", 0.62, 0.03, BLAUW, romp, (sgn * 1.315, -2.4, 0.3), "x", 20)
    vc.cyl(f"RondelWing{sgn}", 0.8, 0.03, BLAUW, romp, (sgn * 11.5, 0.55 - 0.8 * 2.0 / 4.9 + 0.1, -0.38), "z", 20).location.z = 0
# sterren: witte schijfjes in de rondels (gestileerd)
for sgn in (-1, 1):
    vc.cyl(f"SterRomp{sgn}", 0.3, 0.035, STER, romp, (sgn * 1.32, -2.4, 0.3), "x", 5)

# ---------------------------------------------------------------- deur met scharnier (linker kant, achter de vleugel) + springlicht
vc.doos("DeurGat", (0.04, 1.4, 1.9), HOUT, romp, (-1.31, -5.0, 0.15))
hinge = vc.leeg("Deur", romp, (-1.33, -4.3, 0.15))
panel = vc.doos("DeurPaneel", (0.06, 1.4, 1.9), BOVEN, hinge, (0, -0.7, 0))
lamp_g = vc.doos("LampGroen", (0.1, 0.12, 0.12), GROEN, romp, (-1.2, -3.8, 1.5))
lamp_r = vc.doos("LampRood", (0.1, 0.12, 0.12), ROOD, romp, (-1.2, -3.8, 1.2))

# ---------------------------------------------------------------- clips
def pr_rot(t, rev_per_s):
    return (0, math.tau * rev_per_s * t, 0)


def stationair(t):
    w = {}
    for nm, (pr, disc) in PROPS.items():
        w[pr] = {"rot": pr_rot(t, 1.0 + 0.05 * (nm == "R"))}
        w[disc] = {"scale": (0.001, 0.001, 0.001)}
    w[root] = {"loc": (0, 0, 0.012 * math.sin(math.tau * t / 3.0)), "rot": (0.002 * math.sin(math.tau * t / 1.5), 0, 0)}
    return w


def vliegen(t):
    w = {}
    for nm, (pr, disc) in PROPS.items():
        w[pr] = {"rot": pr_rot(t, 2.0)}
        w[disc] = {"scale": (1, 1, 1)}
    w[root] = {"loc": (0.03 * math.sin(math.tau * t / 2.0), 0, 0.05 * math.sin(math.tau * t / 2.0 + 0.8)), "rot": (0.012 * math.sin(math.tau * t / 2.0 + 1.0), 0, 0.02 * math.sin(math.tau * t / 2.0))}
    w[roer_as] = {"rot": (0, 0, 0.04 * math.sin(math.tau * t / 2.0))}
    return w


def bocht(t):
    k = vc.bump(t, 1.5, 0.7)
    w = vliegen(t)
    w[root] = {"loc": (0, 0, 0), "rot": (0.0, 0.42 * k, 0.0)}
    w[roer_as] = {"rot": (0, 0, 0.35 * k)}
    return w


def droppen(t):
    w = vliegen(t * 0.5 + 0.0)
    for nm, (pr, disc) in PROPS.items():
        w[pr] = {"rot": pr_rot(t, 2.0)}
    open_k = vc.smooth((t - 0.4) / 0.9) * (1 - vc.smooth((t - 3.0) / 0.8))
    w[hinge] = {"rot": (0, 0, math.radians(-105) * open_k)}
    on = 1.0 if 0.9 < t < 3.2 else 0.001
    w[lamp_g] = {"scale": (on, on, on)}
    w[lamp_r] = {"scale": (1.001 - on if on > 0.5 else 1.0,) * 3}
    return w


def vol(f):
    """Elke clip zet elke bewegende knoop (ook in rust): zo laat de exporter geen knopen weg."""
    def g(t):
        d = {root: {"loc": (0, 0, 0), "rot": (0, 0, 0)}, roer_as: {"rot": (0, 0, 0)}, hinge: {"rot": (0, 0, 0)},
             lamp_g: {"scale": (0.001, 0.001, 0.001)}, lamp_r: {"scale": (1, 1, 1)}}
        for pr, disc in PROPS.values():
            d[pr] = {"rot": (0, 0, 0)}
            d[disc] = {"scale": (1, 1, 1)}
        d.update(f(t))
        return d
    return g


ACT = [("Stationair-loop", 90, stationair), ("Vliegen-loop", 60, vliegen), ("Bocht", 90, bocht), ("Droppen", 120, droppen)]
for naam, frames, f in ACT:
    doel = [o for o in vc.ALLE if o.type == "EMPTY" and o.name in ("C47", "PropL", "PropR", "RoerAs", "Deur")] + [d for _, d in PROPS.values()] + [lamp_g, lamp_r]
    vc.zet_actie(naam, frames, vol(f), doel)
for o in doel:
    o.rotation_euler = (0, 0, 0)
    o.location = o.location

bpy.ops.object.select_all(action="DESELECT")
for o in vc.ALLE:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "c47.glb"), export_format="GLB", export_apply=False, export_yup=True, use_selection=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
                          export_image_format="JPEG", export_jpeg_quality=90, export_lights=False, export_cameras=False)
tris = sum(len(p.vertices) - 2 for o in vc.ALLE if o.type == "MESH" for p in o.data.polygons)
print("C47 driehoeken", tris, "materialen", len(bpy.data.materials), "tex", TEX)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "c47.blend"))

if "--usdz" in ARGS:
    start = 0
    for naam, lengte, _ in ACT:
        for o in vc.ALLE:
            ad = o.animation_data
            if ad:
                for tr in ad.nla_tracks:
                    if tr.name == naam:
                        tr.strips[0].frame_start_ui = start
        start += lengte + 10
    scene.frame_start, scene.frame_end = 0, start - 10
    bpy.ops.wm.usd_export(filepath=os.path.join(OUT, "c47.usdz"), selected_objects_only=False, export_animation=True, export_materials=True,
                          generate_preview_surface=True, export_textures_mode="NEW", overwrite_textures=True, evaluation_mode="RENDER")
    print("C47 USDZ geschreven")
