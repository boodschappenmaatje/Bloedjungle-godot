"""Douglas C-47 Skytrain (transportvliegtuig voor de Parachutisten, E2): procedureel in Blender, PBR, echte clips.
Gebruik:  python3 maak_c47.py <uitmap> [--tex 1024] [--usdz]
Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van de romp, voorkant = +Y (in Godot -Z). Lengte 19,4 m (v2: ca. 45k driehoeken), spanwijdte 28,8 m.
Knopen: C47 > Romp (+ AileronAsL/R, ElevAs) (+ vleugel, staart, ramen, gestel), PropL/PropR (draaien om Y; blad + PropSchijfL/R), RoerAs > Roer, Deur (scharnier achter de linkerdeur).
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


import bmesh
root = vc.leeg("C47")
romp = vc.leeg("Romp", root)
ALU = vc.pbr("Aluminium", vc.metaal_textures("c47_alu", (0.62, 0.63, 0.62), size=TEX // 2, ruw=0.35, metaal=0.95, seed=91))
RUBBER = vc.pbr("Rubber", vc.metaal_textures("c47_rubber", (0.035, 0.035, 0.035), size=TEX // 2, ruw=0.9, metaal=0.0, seed=92))
GEEL = vc.pbr("Voorrandgeel", None, (0.85, 0.65, 0.05), 0.5, 0.0)
for m in (ALU, RUBBER, GEEL):
    m.use_backface_culling = False
RAD = math.radians


def revolve(naam, prof, mat, parent, loc, segs=56):
    """Draailichaam om de X-as: prof = [(axiaal, straal)]."""
    bm = bmesh.new()
    ringen = []
    for k in range(segs):
        a = math.tau * k / segs
        ringen.append([bm.verts.new((ax, r * math.cos(a), r * math.sin(a))) for ax, r in prof])
    m = len(prof)
    for k in range(segs):
        r0, r1 = ringen[k], ringen[(k + 1) % segs]
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new([r0[i], r0[j], r1[j], r1[i]])
    return vc.mesh_obj(naam, bm, mat, None, parent, loc, sharp=50)


# ---------------------------------------------------------------- romp (hoge resolutie)
SEC = [(9.7, 0.5, 0.6, -0.2, 2.0), (9.1, 1.3, 1.4, -0.05, 2.0), (8.0, 2.1, 2.2, 0.1, 2.2), (6.2, 2.5, 2.8, 0.2, 2.4),
       (3.0, 2.6, 3.0, 0.15, 2.6), (-2.0, 2.6, 3.0, 0.12, 2.6), (-5.5, 2.15, 2.5, 0.35, 2.4), (-8.5, 1.0, 1.2, 0.85, 2.1), (-9.8, 0.3, 0.45, 1.0, 2.0)]
SEC_F = vc.verfijn(SEC, 12)


def profiel_op(y):
    s = sorted(SEC_F, key=lambda t: t[0])
    for a, b in zip(s, s[1:]):
        if a[0] <= y <= b[0]:
            k = (y - a[0]) / max(b[0] - a[0], 1e-6)
            return tuple(a[i] + (b[i] - a[i]) * k for i in (1, 2, 3, 4))
    return s[0][1:5]


body = vc.loft("Romprompel", SEC_F, BOVEN, ONDER, romp, segs=72)


def band(naam, y0, y1, mat, grow=0.02):
    sec = []
    for i in range(7):
        y = y0 + (y1 - y0) * i / 6
        w, h, zc, p = profiel_op(y)
        sec.append((y, w + grow, h + grow, zc, p))
    return vc.loft(naam, sec, mat, None, romp, segs=48)


for i, (ya, yb) in enumerate([(-8.4, -7.7), (-7.0, -6.3), (-5.6, -4.9)]):
    band(f"StreepRomp{i}", ya, yb, WIT if i % 2 == 0 else ZWART)
band("StreepRomp3", -7.7, -7.0, ZWART)
band("StreepRomp4", -6.3, -5.6, WIT)

# ---------------------------------------------------------------- vleugel
KNOP = [(1.2, 1.7, 4.7, 0.75, -1.0), (5.0, 1.3, 4.1, 0.52, -0.92), (9.5, 0.5, 3.1, 0.36, -0.62), (14.4, -0.3, 1.9, 0.2, -0.15)]


def wsec(x):
    a = abs(x)
    if a <= KNOP[0][0]:
        k = KNOP[0]
        return (x, k[1], k[2], k[3], k[4])
    for p, q in zip(KNOP, KNOP[1:]):
        if p[0] <= a <= q[0]:
            u = (a - p[0]) / (q[0] - p[0])
            return (x,) + tuple(p[i] + (q[i] - p[i]) * u for i in range(1, 5))
    k = KNOP[-1]
    return (x, k[1], k[2], k[3], k[4])


def rij(x0, x1, n):
    return [wsec(x0 + (x1 - x0) * i / n) for i in range(n + 1)]


vc.vleugel("Vleugel", rij(-14.4, 14.4, 40), 0.0, 0.72, BOVEN, ONDER, romp, n=14)
vc.vleugel("Staartstuk", rij(-1.3, 1.3, 6), 0.72, 1.0, BOVEN, ONDER, romp, n=6)
for sg in (-1, 1):
    vc.vleugel(f"Klep{sg}", rij(sg * 1.3, sg * 7.6, 12) if sg > 0 else rij(-7.6, -1.3, 12), 0.72, 1.0, BOVEN, ONDER, romp, n=8)
    vc.vleugel(f"Vast{sg}", rij(sg * 7.6, sg * 8.5, 3) if sg > 0 else rij(-8.5, -7.6, 3), 0.72, 1.0, BOVEN, ONDER, romp, n=8)
AIL = {}
for sg, nm in ((-1, "L"), (1, "R")):
    gx = sg * 11.35
    w = wsec(gx)
    gy, gz = w[1] - 0.72 * w[2], w[4]
    as_ = vc.leeg(f"AileronAs{nm}", romp, (gx, gy, gz))
    sec = rij(sg * 8.5, sg * 14.2, 10) if sg > 0 else rij(-14.2, -8.5, 10)
    vc.vleugel(f"Rolroer{nm}", sec, 0.72, 1.0, BOVEN, ONDER, as_, loc=(-gx, -gy, -gz), n=8)
    AIL[nm] = as_
    # navigatielicht en landingslicht
    vc.doos(f"Navlicht{nm}", (0.14, 0.2, 0.1), GROEN if sg > 0 else ROOD, romp, (sg * 14.5, -0.1, -0.15))
    vc.cyl(f"Landingslicht{nm}", 0.14, 0.05, WIT, romp, (sg * 6.8, 0.45, -0.88), "y", 14)

# ---------------------------------------------------------------- staart
def ssec(x):
    a = abs(x) / 4.7
    return (x, -7.6 - 1.3 * a, 2.3 - 1.1 * a, 0.3 - 0.18 * a, 0.95)


xs_stab = [-4.7 + 9.4 * i / 16 for i in range(17)]
vc.vleugel("Stabilisator", [ssec(x) for x in xs_stab], 0.0, 0.62, BOVEN, ONDER, romp, n=8)
elev_as = vc.leeg("ElevAs", romp, (0, -9.05, 0.95))
vc.vleugel("Hoogteroer", [ssec(x) for x in xs_stab], 0.62, 1.0, BOVEN, ONDER, elev_as, loc=(0, 9.05, -0.95), n=8)
roer_as = vc.leeg("RoerAs", romp, (0, -9.15, 1.1))


def fsec(h, rudder=False):
    u = h / 3.3
    return (h, -6.5 - 1.9 * u, 3.6 - 1.6 * u, (0.36 - 0.24 * u) * (0.85 if rudder else 1.0), 0.0)


hs = [3.3 * i / 10 for i in range(11)]
fin = vc.vleugel("Kiel", [fsec(h) for h in hs], 0.0, 0.62, BOVEN, None, romp, n=8)
fin.rotation_euler = (0, math.radians(-90), 0)
fin.location = (0, 0, 1.05)
roer = vc.vleugel("Roer", [fsec(h, True) for h in hs], 0.62, 1.0, BOVEN, None, roer_as, n=8)
roer.rotation_euler = (0, math.radians(-90), 0)
roer.location = (0, 9.15, -0.05)
vc.doos("Trimvlak", (0.03, 0.5, 0.45), ALU, roer_as, (0, -0.5, 1.6))

# ---------------------------------------------------------------- motoren (sterren van 14 cilinders), kappen, propellers
PROPS = {}
for sgn, nm in ((-1, "L"), (1, "R")):
    x = sgn * 4.9
    SECN = vc.verfijn([(3.5, 1.9, 1.9, -0.85, 2.4), (3.3, 2.0, 2.0, -0.85, 2.4), (2.4, 2.08, 2.08, -0.85, 2.6), (0.5, 1.8, 1.8, -0.9, 2.4), (-2.0, 1.2, 1.15, -1.0, 2.2), (-4.4, 0.5, 0.45, -1.05, 2.0)], 5)
    vc.loft(f"Motorkap{nm}", SECN, BOVEN, ONDER, romp, loc=(x, 0, 0), segs=48, dicht=(False, True))
    vc.cyl(f"Lip{nm}", 0.97, 0.12, ALU, romp, (x, 3.45, -0.85), "y", 40, r2=0.97)
    mot = vc.leeg(f"Motor{nm}", romp, (x, 3.0, -0.85))
    vc.cyl(f"Carter{nm}", 0.52, 0.5, STAAL, mot, (0, 0.05, 0), "y", 28)
    vc.cyl(f"Reductie{nm}", 0.34, 0.3, STAAL, mot, (0, 0.4, 0), "y", 20)
    for row in range(2):
        for i in range(7):
            psi = math.tau * (i + 0.5 * row) / 7
            R = 0.76
            cx, cz = R * math.cos(psi), -R * math.sin(psi)
            yy = -0.07 + 0.2 * row
            ob = vc.cyl(f"Cil{nm}{row}{i}", 0.09, 0.42, DONKER, mot, (cx, yy, cz), "x", 10, r2=0.085)
            ob.rotation_euler = (0, psi, 0)
            for f in range(3):
                Rf = R - 0.08 + 0.09 * f
                fb = vc.cyl(f"CilRib{nm}{row}{i}{f}", 0.14, 0.03, STAAL, mot, (Rf * math.cos(psi), yy, -Rf * math.sin(psi)), "x", 12)
                fb.rotation_euler = (0, psi, 0)
            kop = vc.doos(f"CilKop{nm}{row}{i}", (0.1, 0.2, 0.2), STAAL, mot, ((R + 0.26) * math.cos(psi), yy, -(R + 0.26) * math.sin(psi)))
            kop.rotation_euler = (0, psi, 0)
    for i in range(12):
        ps = math.tau * i / 12
        fl = vc.doos(f"Kapklep{nm}{i}", (0.3, 0.5, 0.03), BOVEN, romp, (x + 0.9 * math.cos(ps), 1.45, -0.85 - 0.9 * math.sin(ps)))
        fl.rotation_euler = (0, ps + math.pi / 2, 0)
    for i in range(7):
        ps = math.pi + math.pi * (i + 0.5) / 7
        vc.cyl(f"Uitlaat{nm}{i}", 0.05, 0.4, DONKER, romp, (x + 0.97 * math.cos(ps), 2.7, -0.85 - 0.97 * math.sin(ps)), "y", 8)
    vc.doos(f"Oliekoeler{nm}", (0.6, 0.45, 0.2), DONKER, romp, (x, 1.8, -0.85 + 1.02))
    pr = vc.leeg(f"Prop{nm}", romp, (x, 3.95, -0.85))
    sp = vc.loft(f"Spinner{nm}", [(-0.25, 0.7, 0.7, 0, 2.0), (0.0, 0.62, 0.62, 0, 2.0), (0.3, 0.44, 0.44, 0, 2.0), (0.55, 0.14, 0.14, 0, 2.0), (0.62, 0.02, 0.02, 0, 2.0)], STAAL, None, pr, segs=24)
    for b in range(3):
        arm = vc.leeg(f"BladArm{nm}{b}", pr)
        arm.rotation_euler = (0, RAD(120 * b), 0)
        wb = [(0.35 + 1.7 * i / 7, 0.12 - 0.05 * i / 7, 0.30 - 0.08 * (i / 7) ** 2 + 0.12 * math.sin(math.pi * i / 7) * 0.5, 0.075 - 0.05 * i / 7, 0.0) for i in range(8)]
        bl = vc.vleugel(f"Blad{nm}{b}", wb, 0.0, 1.0, DONKER, None, arm, n=8)
        bl.rotation_euler = (RAD(62), 0, 0)
        tip = vc.doos(f"BladTip{nm}{b}", (0.26, 0.05, 0.05), GEEL, arm, (1.9, 0.0, 0.0))
        tip.rotation_euler = (RAD(62), 0, 0)
    vc.cyl(f"Naaf{nm}", 0.3, 0.1, STAAL, pr, (0, -0.02, 0), "y", 20)
    disc = vc.cyl(f"PropSchijf{nm}", 2.0, 0.01, SCHIJF, pr, (0, 0.05, 0), "y", 32)
    PROPS[nm] = (pr, disc)

    # hoofdgestel: schokdemper, schaarlinks, wielput, band met profiel, naaf, bouten, klep
    vc.doos(f"Wielput{nm}", (0.9, 1.4, 0.2), HOUT, romp, (x, 0.4, -1.5))
    vc.cyl(f"Oleo{nm}", 0.1, 1.0, STAAL, romp, (x - sgn * 0.12, 0.4, -2.0), "z", 16)
    vc.cyl(f"OleoZuiger{nm}", 0.07, 0.7, ALU, romp, (x - sgn * 0.12, 0.4, -2.55), "z", 16)
    vc.doos(f"Schaar1{nm}", (0.04, 0.06, 0.5), STAAL, romp, (x - sgn * 0.26, 0.4, -2.2), (0, 0, 0))
    vc.doos(f"Schaar2{nm}", (0.04, 0.06, 0.4), STAAL, romp, (x - sgn * 0.26, 0.5, -2.5), (RAD(18), 0, 0))
    vc.doos(f"Gaffel{nm}", (0.36, 0.06, 0.1), STAAL, romp, (x, 0.3, -2.76))
    PROF = [(-0.17, 0.32), (-0.19, 0.45), (-0.18, 0.57), (-0.13, 0.63), (-0.07, 0.655), (-0.03, 0.66), (0.03, 0.66), (0.07, 0.655), (0.13, 0.63), (0.18, 0.57), (0.19, 0.45), (0.17, 0.32)]
    revolve(f"Band{nm}", PROF, RUBBER, romp, (x, 0.3, -2.75), 56)
    vc.cyl(f"WielNaaf{nm}", 0.31, 0.38, ALU, romp, (x, 0.3, -2.75), "x", 32)
    for i in range(8):
        a = math.tau * i / 8
        vc.cyl(f"Bout{nm}{i}", 0.025, 0.06, STAAL, romp, (x + sgn * 0.2, 0.3 + 0.2 * math.cos(a), -2.75 + 0.2 * math.sin(a)), "x", 6)
    vc.doos(f"Gestelklep{nm}", (0.04, 0.55, 1.1), BOVEN, romp, (x + sgn * 0.45, 0.4, -2.05))

# staartwiel
vc.doos("StaartPoot", (0.1, 0.12, 1.3), STAAL, romp, (0, -8.5, -0.15))
vc.cyl("StaartOleo", 0.07, 0.6, ALU, romp, (0, -8.52, -0.55), "z", 14)
revolve("StaartBand", [(-0.06, 0.1), (-0.08, 0.17), (-0.05, 0.215), (0.0, 0.225), (0.05, 0.215), (0.08, 0.17), (0.06, 0.1)], RUBBER, romp, (0, -8.55, -0.95), 40)
vc.cyl("StaartNaaf", 0.1, 0.16, ALU, romp, (0, -8.55, -0.95), "x", 16)

# ---------------------------------------------------------------- cockpit, ramen met kozijnen, koepel, antennes, pitotbuis
vc.doos("Voorruit", (1.5, 0.08, 0.7), GLAS, romp, (0, 8.05, 0.8), (math.radians(35), 0, 0))
for i, dx in enumerate((-0.75, 0, 0.75)):
    vc.doos(f"Ruitstijl{i}", (0.05, 0.12, 0.75), ALU, romp, (dx, 8.05, 0.8), (math.radians(35), 0, 0))
vc.doos("Dashboard", (1.7, 0.5, 0.35), DONKER, romp, (0, 7.55, 0.52))
for sgn in (-1, 1):
    vc.doos(f"Zijruit{sgn}", (0.04, 1.2, 0.55), GLAS, romp, (sgn * 1.0, 7.0, 0.85))
    vc.doos(f"Stoel{sgn}", (0.5, 0.5, 0.8), HOUT, romp, (sgn * 0.45, 6.4, 0.1))
    for i in range(14):
        yy = 4.9 - 0.9 * i
        if abs(yy + 4.3) < 1.1:
            continue
        w = profiel_op(yy)
        xw = w[0] / 2 + 0.01
        vc.doos(f"Raam{sgn}{i}", (0.04, 0.42, 0.5), GLAS, romp, (sgn * xw, yy, 0.55))
        for k, (dy, dz, sy, sz) in enumerate([(0, 0.29, 0.52, 0.06), (0, -0.29, 0.52, 0.06), (-0.24, 0, 0.06, 0.52), (0.24, 0, 0.06, 0.52)]):
            vc.doos(f"Kozijn{sgn}{i}{k}", (0.05, sy, sz), ALU, romp, (sgn * (xw + 0.01), yy + dy, 0.55 + dz))
    vc.cyl(f"RondelRomp{sgn}", 0.62, 0.03, BLAUW, romp, (sgn * 1.315, -2.4, 0.3), "x", 32)
    vc.cyl(f"SterRomp{sgn}", 0.3, 0.035, STER, romp, (sgn * 1.32, -2.4, 0.3), "x", 5)
    vc.cyl(f"RondelWing{sgn}", 0.8, 0.03, BLAUW, romp, (sgn * 11.5, 0.2, 0.2), "z", 32).location.z = 0.02
vc.loft("Astrokoepel", [(2.0, 0.4, 0.4, 1.58, 2.0), (2.0 + 0.05, 0.32, 0.32, 1.66, 2.0), (2.15, 0.1, 0.1, 1.72, 2.0)], GLAS, None, romp, segs=16)
vc.cyl("Mast", 0.03, 0.7, DONKER, romp, (0, 2.8, 1.85), "z", 8)
vc.cyl("Pitot", 0.02, 0.8, STAAL, romp, (-1.0, 8.9, -0.3), "y", 8)
vc.cyl("Antennedraad", 0.008, 9.0, DONKER, romp, (0, -3.2, 2.9), "y", 5).rotation_euler = (RAD(-9.5), 0, 0)
vc.doos("Peilantenne", (0.1, 0.5, 0.06), DONKER, romp, (0, 1.2, 1.45))

# ---------------------------------------------------------------- deur met scharnier (links, achter) + springlicht + kozijn
vc.doos("DeurGat", (0.04, 1.4, 1.9), HOUT, romp, (-1.31, -5.0, 0.15))
for k, (dy, dz, sy, sz) in enumerate([(0, 1.0, 1.5, 0.08), (0, -1.0, 1.5, 0.08), (-0.75, 0, 0.08, 2.1), (0.75, 0, 0.08, 2.1)]):
    vc.doos(f"DeurKozijn{k}", (0.07, sy, sz), ALU, romp, (-1.32, -5.0 + dy, 0.15 + dz))
hinge = vc.leeg("Deur", romp, (-1.33, -4.3, 0.15))
panel = vc.doos("DeurPaneel", (0.06, 1.4, 1.9), BOVEN, hinge, (0, -0.7, 0))
vc.doos("DeurRaam", (0.07, 0.4, 0.45), GLAS, hinge, (-0.01, -0.45, 0.4))
vc.doos("DeurGreep", (0.07, 0.18, 0.05), ALU, hinge, (-0.03, -1.2, 0.0))
for dz in (-0.7, 0.0, 0.7):
    vc.cyl(f"Scharnier{dz}", 0.035, 0.18, STAAL, romp, (-1.34, -4.3, 0.15 + dz), "z", 8)
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
    w[elev_as] = {"rot": (0.05 * math.sin(math.tau * t / 2.0 + 0.6), 0, 0)}
    w[AIL["L"]] = {"rot": (0.04 * math.sin(math.tau * t / 2.0 + 1.5), 0, 0)}
    w[AIL["R"]] = {"rot": (-0.04 * math.sin(math.tau * t / 2.0 + 1.5), 0, 0)}
    return w


def bocht(t):
    k = vc.bump(t, 1.5, 0.7)
    w = vliegen(t)
    w[root] = {"loc": (0, 0, 0), "rot": (0.0, 0.42 * k, 0.0)}
    w[roer_as] = {"rot": (0, 0, 0.35 * k)}
    w[AIL["L"]] = {"rot": (-0.45 * k, 0, 0)}
    w[AIL["R"]] = {"rot": (0.45 * k, 0, 0)}
    w[elev_as] = {"rot": (-0.1 * k, 0, 0)}
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
        d = {root: {"loc": (0, 0, 0), "rot": (0, 0, 0)}, roer_as: {"rot": (0, 0, 0)}, elev_as: {"rot": (0, 0, 0)}, AIL["L"]: {"rot": (0, 0, 0)}, AIL["R"]: {"rot": (0, 0, 0)}, hinge: {"rot": (0, 0, 0)},
             lamp_g: {"scale": (0.001, 0.001, 0.001)}, lamp_r: {"scale": (1, 1, 1)}}
        for pr, disc in PROPS.values():
            d[pr] = {"rot": (0, 0, 0)}
            d[disc] = {"scale": (1, 1, 1)}
        d.update(f(t))
        return d
    return g


ACT = [("Stationair-loop", 90, stationair), ("Vliegen-loop", 60, vliegen), ("Bocht", 90, bocht), ("Droppen", 120, droppen)]
for naam, frames, f in ACT:
    doel = [o for o in vc.ALLE if o.type == "EMPTY" and o.name in ("C47", "PropL", "PropR", "RoerAs", "Deur", "ElevAs", "AileronAsL", "AileronAsR")] + [d for _, d in PROPS.values()] + [lamp_g, lamp_r]
    vc.zet_actie(naam, frames, vol(f), doel)
for o in doel:
    o.rotation_euler = (0, 0, 0)
    o.location = o.location

# vaste delen per materiaalcombinatie samenvoegen: ~430 meshes worden een handvol drawcalls voor de iPhone
groepen = {}
for o in list(bpy.data.objects):
    if o.type == "MESH" and o not in (lamp_g, lamp_r) and not o.name.startswith("PropSchijf") and o.animation_data is None:
        groepen.setdefault((o.parent.name if o.parent else "", tuple(m.name for m in o.data.materials)), []).append(o)
for i, (sleutel, lijst) in enumerate(groepen.items()):
    bpy.ops.object.select_all(action="DESELECT")
    for o in lijst:
        o.select_set(True)
    bpy.context.view_layer.objects.active = lijst[0]
    if len(lijst) > 1:
        bpy.ops.object.join()
    bpy.context.view_layer.objects.active.name = "Vast_%s_%s" % (sleutel[0], "_".join(sleutel[1]).replace(" ", ""))
    bpy.context.view_layer.objects.active.data.name = "VastMesh%d" % i
ALLES = list(bpy.data.objects)
bpy.ops.object.select_all(action="DESELECT")
for o in ALLES:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "c47.glb"), export_format="GLB", export_apply=False, export_yup=True, use_selection=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
                          export_image_format="JPEG", export_jpeg_quality=90, export_lights=False, export_cameras=False)
tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
print("C47 driehoeken", tris, "materialen", len(bpy.data.materials), "tex", TEX)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "c47.blend"))

if "--usdz" in ARGS:
    start = 0
    for naam, lengte, _ in ACT:
        for o in bpy.data.objects:
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
