"""Voorraadtruck met kraan en grijper (Generals-plan stap 4b, stijl Intendance).

    python bron/voorraad/maak_truck.py hq     # bewerkbare bron: uit/Voorraadtruck_HQ.blend (procedurele materialen, geen bake)
    python bron/voorraad/maak_truck.py game   # Godot-versie: assets/voorraadtruck.glb (+ uit/Voorraadtruck.usdz)
    python bron/voorraad/maak_truck.py lod1   # uitgezoomd: assets/voorraadtruck_lod1.glb

Zware 6x6-legertruck, ca. 6,6 m lang, voorkant +z (Godot). Kraan achter de cabine met zwenkkolom, telescoopgiek, ketting en een grijper met
vier klauwen. Echte Blender-clips (NLA): `Laden` en `Lossen` (4,5 s, 30 fps, beginpose = eindpose). Onderdelen voor Godot: Wiel_FL..Wiel_RR
(draaien om hun eigen x-as), Lading (kisten in de bak, verbergbaar), Kist_vast (kist in de klauwen, alleen zichtbaar tijdens de clip), Wrak
(apart model: uitgebrand, kraan scheef; staat standaard verborgen en heet `Voorraadtruck_wrak` in zijn eigen glb).
"""
import math
import random

from vc import *  # noqa: F401,F403

# ---- maten (Godot-assen, meter)
AXLES = {"F": 2.35, "M": -1.15, "R": -2.40}
TRACK = 1.08
WR, WW = 0.55, 0.40
BED_TOP = 1.35
CAB_Z0, CAB_Z1 = 0.85, 2.25
CRANE_Z = 0.42
PIVOT_Y = 3.30           # hoogte van het giekscharnier
BOOM_L = 2.6             # buitenste gieksectie; twee telescoopdelen van 1,9 m schuiven eruit (reikwijdte 2,75 tot 6,55 m)
LAD_T = 135              # Laden en Lossen: 135 frames = 4,5 s
SEGW = {"hq": 40, "game": 22, "lod1": 12}[LEVEL]
TREAD = {"hq": 30, "game": 14, "lod1": 0}[LEVEL]


def gset():
    return {k: G() for k in ("olijf", "olijf2", "staal", "donker", "geel", "gevaar", "hout", "zwart", "wit", "glas", "amber", "rood", "witlamp")}


# ------------------------------------------------------------------ wiel: een band en een velg, rond de oorsprong (as langs x, buitenkant +x)
def wheel_geo(M):
    gt, gr, gb = G(), G(), G()
    r, w = WR, WW
    seg = SEGW
    disc(gt, (0, 0, 0), r, w, "x", seg=seg)
    if D >= 1:
        disc(gt, (0, 0, 0), r * 0.97, w + 0.03, "x", seg=seg)      # afgeronde flanken
        disc(gt, (0, 0, 0), r * 0.62, w + 0.04, "x", seg=seg)      # zijwand
    for i in range(TREAD):
        a = 2 * math.pi * i / TREAD
        c = (0, math.cos(a) * (r + 0.012), math.sin(a) * (r + 0.012))
        bx(gt, c, (w * 0.92, 0.05, 0.16 * 2 * math.pi * r / TREAD / 1.1 * 1.0), pitch=a, bevel=False)
        if D >= 2:
            # tussenribbels: kleine blokjes op de rand van het loopvlak
            c2 = (0, math.cos(a + math.pi / TREAD) * (r + 0.008), math.sin(a + math.pi / TREAD) * (r + 0.008))
            bx(gt, c2, (w * 0.5, 0.035, 0.07), pitch=a + math.pi / TREAD, bevel=False)
    # velg: ring, hoofdschijf, naafdop en bouten
    disc(gr, (0.05, 0, 0), r * 0.62, w * 0.62, "x", seg=seg)
    disc(gr, (w / 2 + 0.005, 0, 0), r * 0.44, 0.05, "x", seg=seg)
    disc(gr, (w / 2 + 0.04, 0, 0), 0.14, 0.07, "x", seg=max(10, seg // 2))
    nb = 8 if D >= 1 else 0
    for i in range(nb):
        a = 2 * math.pi * i / nb
        disc(gb, (w / 2 + 0.03, math.cos(a) * 0.22, math.sin(a) * 0.22), 0.026, 0.045, "x", seg=6)
    return gt, gr, gb


# ------------------------------------------------------------------ chassis, assen, banden
def build_chassis(S, root):
    for sx in (-0.52, 0.52):
        if D >= 2:
            bar(S["staal"], (sx, 0.88, -3.18), (sx, 0.88, 3.05), 0.05, 0.24)
            bar(S["staal"], (sx, 1.0, -3.18), (sx, 1.0, 3.05), 0.16, 0.035)
            bar(S["staal"], (sx, 0.76, -3.18), (sx, 0.76, 3.05), 0.16, 0.035)
        else:
            bx(S["staal"], (sx, 0.88, -0.07), (0.12, 0.24, 6.23))
    for z in (-3.0, -2.0, -0.7, 0.4, 1.4, 2.5):
        bx(S["staal"], (0, 0.9, z), (1.1, 0.12, 0.1))
    for name, z in AXLES.items():
        disc(S["donker"], (0, 0.55, z), 0.07, 2.0, "x", seg=SEGC)
        if D >= 1:
            disc(S["donker"], (0, 0.55, z), 0.17, 0.3, "z", seg=SEGC)             # differentieel
            for sx in (-0.74, 0.74):
                leaves = 5 if D >= 2 else 3
                for i in range(leaves):
                    bx(S["donker"], (sx, 0.69 + 0.032 * i, z), (0.11, 0.028, 1.25 - 0.2 * i), bevel=False)
                bx(S["donker"], (sx, 0.69 + 0.032 * leaves, z), (0.14, 0.06, 0.16), bevel=False)
                bar(S["donker"], (sx, 0.76 + 0.032 * leaves, z), (sx * 0.72, 0.86, z), 0.05, 0.05, bevel=False)
    if D >= 1:
        cyl(S["donker"], (0, 0.62, -2.4), (0, 0.62, 2.35), 0.045, seg=8)
        for z in (-1.8, -0.4, 0.9, 1.9):
            bx(S["donker"], (0, 0.62, z), (0.12, 0.12, 0.1), bevel=False)
    # brandstoftank, accubak, uitlaat
    disc(S["olijf2"], (-0.82, 0.78, 0.55), 0.20, 1.5, "z", seg=SEGC)
    for dz in (-0.5, 0.5):
        bx(S["staal"], (-0.82, 0.78, 0.55 + dz), (0.46, 0.05, 0.05), bevel=False)
    bx(S["olijf2"], (0.84, 0.82, 0.55), (0.42, 0.34, 0.8))
    cyl(S["donker"], (1.12, 0.8, 0.78), (1.12, 2.95, 0.78), 0.06, seg=8)
    cyl(S["staal"], (1.12, 2.95, 0.78), (1.12, 3.05, 0.78), 0.085, seg=8, r2=0.06)
    disc(S["donker"], (1.12, 1.0, 0.78), 0.12, 0.5, "y", seg=SEGC)
    # spatborden
    for sx in (-1, 1):
        bx(S["olijf"], (sx * 1.07, 1.2, AXLES["F"]), (0.5, 0.05, 1.3))
        bx(S["olijf"], (sx * 1.07, 1.1, AXLES["F"] + 0.68), (0.5, 0.22, 0.05), pitch=0.5)
        bx(S["olijf"], (sx * 1.07, 1.1, AXLES["F"] - 0.68), (0.5, 0.22, 0.05), pitch=-0.5)
        bx(S["olijf"], (sx * 1.07, 1.2, -1.775), (0.5, 0.05, 2.4))
        bx(S["zwart"], (sx * 1.07, 0.78, -3.05), (0.46, 0.5, 0.03), bevel=False)   # modderflappen
        bx(S["zwart"], (sx * 1.07, 0.78, 1.6), (0.46, 0.4, 0.03), bevel=False)
    # bumpers met waarschuwingsbanden, lier, sleephaken
    bx(S["gevaar"], (0, 0.83, 3.3), (2.4, 0.26, 0.16))
    bx(S["gevaar"], (0, 0.83, -3.36), (2.4, 0.26, 0.14))
    disc(S["donker"], (0, 0.72, 3.12), 0.11, 0.95, "x", seg=SEGC)
    if D >= 1:
        for sx in (-0.5, 0.5):
            cyl(S["donker"], (sx, 0.72, 3.38), (sx, 0.72, 3.55), 0.03, seg=6)
            bx(S["donker"], (sx, 0.72, 3.55), (0.1, 0.1, 0.05), bevel=False)
        cyl(S["donker"], (0, 0.72, -3.43), (0, 0.72, -3.62), 0.04, seg=6)
        bx(S["donker"], (0, 0.72, -3.62), (0.16, 0.1, 0.05), bevel=False)
    # treden
    for sx in (-1, 1):
        bx(S["staal"], (sx * 1.22, 0.78, 1.55), (0.18, 0.04, 0.55))
        if D >= 1:
            bx(S["staal"], (sx * 1.22, 0.78 + 0.25, 1.55), (0.14, 0.04, 0.5))


def build_cab(S, K, root):
    gl = S["glas"]
    # romp van de cabine en motorkap
    bx(S["olijf"], (0, 1.825, 1.55), (2.28, 1.75, 1.4))
    bx(S["olijf"], (0, 2.74, 1.55), (2.34, 0.08, 1.52))
    bx(S["olijf"], (0, 1.43, 2.75), (1.95, 0.85, 1.0))
    bx(S["olijf2"], (0, 1.0, 2.75), (2.0, 0.08, 1.05))
    # motorkaplijn en luchtgleuven
    if D >= 1:
        for sx in (-1, 1):
            for i in range(4 if D >= 2 else 2):
                bx(S["donker"], (sx * 0.98, 1.45 + 0.0, 2.45 + i * 0.16), (0.03, 0.34, 0.07), bevel=False)
        for i in range(7 if D >= 2 else 4):
            bx(S["donker"], (0, 1.25 + i * 0.065, 3.255), (1.3, 0.03, 0.04), bevel=False)
        bx(S["donker"], (0, 1.45, 3.245), (1.38, 0.52, 0.03), bevel=False)
    # voorruit, zijruiten, achterruit
    bx(gl, (0, 2.25, 2.275), (1.9, 0.66, 0.03), pitch=-0.1, bevel=False)
    for sx in (-1, 1):
        bx(gl, (sx * 1.145, 2.22, 1.5), (0.03, 0.62, 0.9), bevel=False)
    bx(gl, (0, 2.25, 0.84), (1.3, 0.5, 0.03), bevel=False)
    if D >= 1:
        for sx in (-1, 1):
            # ruitkaders
            bx(S["olijf2"], (sx * 1.15, 2.57, 1.5), (0.04, 0.05, 0.98))
            bx(S["olijf2"], (sx * 1.15, 1.89, 1.5), (0.04, 0.05, 0.98))
            # deurnaden en handgrepen
            for z in (1.02, 2.02):
                bx(S["donker"], (sx * 1.142, 1.55, z), (0.012, 1.45, 0.018), bevel=False)
            bx(S["donker"], (sx * 1.15, 1.7, 1.9), (0.04, 0.05, 0.14), bevel=False)
            # spiegels
            bar(S["staal"], (sx * 1.15, 2.25, 2.1), (sx * 1.46, 2.4, 2.2), 0.04, 0.04)
            bx(S["staal"], (sx * 1.48, 2.4, 2.2), (0.04, 0.4, 0.22))
        # ruitenwissers
        for sx in (-0.45, 0.45):
            bar(S["donker"], (sx, 2.0, 2.3), (sx + 0.28, 2.3, 2.3), 0.02, 0.01, bevel=False)
        # zonneklep, dakrails
        bx(S["olijf2"], (0, 2.86, 2.28), (2.1, 0.03, 0.3), pitch=-0.15)
    if D >= 2:
        for sx in (-0.9, 0.9):
            bx(S["donker"], (sx, 2.79, 1.55), (0.04, 0.03, 1.4), bevel=False)
    # koplampen met beschermkap, richtingaanwijzers
    for sx in (-1, 1):
        disc(S["witlamp"], (sx * 0.7, 1.55, 3.23), 0.12, 0.04, "z", seg=SEGC)
        if D >= 1:
            for k in range(3):
                bx(S["donker"], (sx * 0.7, 1.55 + (k - 1) * 0.06, 3.27), (0.3, 0.015, 0.015), bevel=False)
        bx(S["amber"], (sx * 0.96, 1.55, 3.2), (0.07, 0.07, 0.05), bevel=False)
    # waarschuwingslamp op het dak
    disc(S["amber"], (0.7, 2.86, 1.2), 0.09, 0.1, "y", seg=SEGC)
    if D >= 1:
        disc(S["donker"], (0.7, 2.79, 1.2), 0.11, 0.05, "y", seg=SEGC)
    # stencil en embleem
    if D >= 0:
        decal_at(K, "int", (1.153, 1.95, 1.5), 0.42, 0.18, yaw=math.pi / 2)
        decal_at(K, "int", (-1.153, 1.95, 1.5), 0.42, 0.18, yaw=-math.pi / 2)
        decal_at(K, "n01", (1.153, 1.55, 1.5), 0.22, 0.18, yaw=math.pi / 2)
        decal_at(K, "chevron", (0, 1.82, 3.275), 0.5, 0.5)
        decal_at(K, "int", (0, 2.755, 1.3), 0.9, 0.4, pitch=-math.pi / 2)


def build_bed(S, K, root):
    # vloer: planken, onderbalken
    for i in range(8):
        bx(S["hout"], (-1.0 + i * 0.285, BED_TOP - 0.035, -1.65), (0.27, 0.07, 3.3))
    for z in (-3.1, -2.4, -1.7, -1.0, -0.3):
        bx(S["staal"], (0, BED_TOP - 0.1, z), (2.4, 0.08, 0.09))
    for sx in (-1, 1):
        bx(S["olijf"], (sx * 1.17, BED_TOP + 0.38, -1.65), (0.06, 0.75, 3.3))
        bx(S["staal"], (sx * 1.2, BED_TOP + 0.78, -1.65), (0.09, 0.06, 3.36))
        if D >= 1:
            for z in (-3.1, -2.45, -1.8, -1.15, -0.5):
                bx(S["staal"], (sx * 1.2, BED_TOP + 0.38, z), (0.05, 0.75, 0.07))
        if D >= 2:
            for z in (-2.8, -1.4, -0.2):
                bx(S["donker"], (sx * 1.21, BED_TOP + 0.55, z), (0.03, 0.06, 0.12), bevel=False)    # sluithaken
    # voorschot (hoog), achterklep met waarschuwingsband
    bx(S["olijf"], (0, BED_TOP + 0.55, -0.08), (2.4, 1.1, 0.08))
    bx(S["olijf"], (0, BED_TOP + 0.38, -3.3), (2.4, 0.75, 0.07))
    bx(S["gevaar"], (0, BED_TOP + 0.12, -3.343), (2.34, 0.16, 0.02), bevel=False)
    if D >= 1:
        for sx in (-1.05, 1.05):
            disc(S["donker"], (sx, BED_TOP + 0.02, -3.35), 0.04, 0.12, "x", seg=8)    # scharnieren
        chain(S["donker"], (1.12, BED_TOP + 0.7, -3.34), (1.12, BED_TOP + 0.78, -3.0), link=0.07) if D >= 2 else None
    # achterlichten
    for sx in (-1, 1):
        bx(S["rood"], (sx * 1.02, BED_TOP + 0.1, -3.4), (0.2, 0.12, 0.04), bevel=False)
    decal_at(K, "depot01", (0, BED_TOP + 0.5, -3.36), 1.3, 0.3, yaw=math.pi)
    decal_at(K, "intendance", (1.205, BED_TOP + 0.34, -1.65), 2.6, 0.3, yaw=math.pi / 2)
    decal_at(K, "intendance", (-1.205, BED_TOP + 0.34, -1.65), 2.6, 0.3, yaw=-math.pi / 2)


# ------------------------------------------------------------------ lading en kist in de klauwen
CB = (0.96, 0.62, 1.3)   # kist in de bak en in de klauwen (iets kleiner dan de stapelkist: past tussen de bakwanden en de klauwen)
DROP = (0.0, BED_TOP + 0.31, CRANE_Z - 2.75)   # waar de kist in de bak komt (onder de uiteinde van de ingetrokken giek)


def build_load(root, M):
    """De kisten in de bak: groep `Lading` (schaal door de clip: 0 bij leeg, 1 bij geladen). De achterste kist ligt op de plek waar de grijper hem loslaat."""
    pivot = empty("Lading", root, (0, 0, 0))
    gs, gm, gy, gk = G(), G(), G(), bmesh.new()
    crate(gs, gm, gy, gk, DROP, yaw=0.0, stencil="batch", size=CB)
    crate(gs, gm, gy, gk, (-0.5, BED_TOP + 0.31, -1.0), yaw=0.03, stencil="int", size=CB)
    crate(gs, gm, gy, gk, (0.5, BED_TOP + 0.31, -1.05), yaw=-0.03, stencil="swl", size=CB)
    crate(gs, gm, gy, gk, (0.0, BED_TOP + 0.93, -1.0), yaw=0.06, stencil="n02", size=CB)
    objs = []
    for suffix, g, mat, tile in (("Lading_kisten", gs, M["olijf"], 1.0), ("Lading_beslag", gm, M["staal"], 0.5), ("Lading_band", gy, M["geel"], 0.5)):
        o = commit(suffix, g, mat, pivot, tile=tile, bevel=(suffix == "Lading_kisten" and D >= 2))
        if o:
            objs.append(o)
            o["nocull"] = True
    if gk.faces:
        objs.append(F.new_obj("Lading_stencil", gk, M["stencil"], smooth=False, parent=pivot))
    else:
        gk.free()
    return pivot, objs


def build_held_crate(grab, M):
    pivot = empty("Kist_vast", grab, (0, 0, 0))
    gs, gm, gy, gk = G(), G(), G(), bmesh.new()
    crate(gs, gm, gy, gk, (0, -0.43, 0), stencil="batch", size=CB)
    objs = []
    for suffix, g, mat, tile in (("Kist_vast_romp", gs, M["olijf"], 1.0), ("Kist_vast_beslag", gm, M["staal"], 0.5), ("Kist_vast_band", gy, M["geel"], 0.5)):
        o = commit(suffix, g, mat, pivot, tile=tile, bevel=(suffix == "Kist_vast_romp" and D >= 1))
        if o:
            objs.append(o)
            o["nocull"] = True
    if gk.faces:
        objs.append(F.new_obj("Kist_vast_stencil", gk, M["stencil"], smooth=False, parent=pivot))
    else:
        gk.free()
    return pivot, objs


# ------------------------------------------------------------------ kraan en grijper
def build_crane(M, root):
    """Geeft (parts, pivots, objs): pivots = Kolom, Giek, Mid, Uit, Kettingpunt, Ketting, Grijper, Klauwen."""
    objs = []
    # vaste voet: platform en sokkel met bouten, uitgeklapte steunpoten
    gv, gb = G(), G()
    bx(gv, (0, BED_TOP - 0.02, 0.43), (2.3, 0.08, 0.86))
    disc(gv, (0, BED_TOP + 0.17, CRANE_Z), 0.44, 0.34, "y", seg=SEGC)
    disc(gv, (0, BED_TOP + 0.36, CRANE_Z), 0.5, 0.06, "y", seg=SEGC)
    if D >= 1:
        for i in range(10):
            a = 2 * math.pi * i / 10
            disc(gb, (math.cos(a) * 0.44, BED_TOP + 0.41, CRANE_Z + math.sin(a) * 0.44), 0.025, 0.04, "y", seg=6)
        for sx in (-1, 1):
            bar(gv, (sx * 0.4, BED_TOP + 0.25, CRANE_Z), (sx * 1.3, BED_TOP + 0.22, CRANE_Z), 0.12, 0.12)
            bx(gv, (sx * 1.3, BED_TOP + 0.1, CRANE_Z), (0.34, 0.06, 0.34))
            disc(gb, (sx * 1.3, BED_TOP + 0.01, CRANE_Z), 0.07, 0.15, "y", seg=8)
    o = commit("Kraanvoet", gv, M["staal"], root, tile=0.8)
    objs.append(o)
    if gb.c.faces:
        objs.append(commit("Kraanvoet_bouten", gb, M["donker"], root, tile=0.4, bevel=False))
    else:
        gb.b.free(), gb.c.free()
    y0 = BED_TOP + 0.4
    kolom = empty("Kolom", root, (0, y0, CRANE_Z))
    # kolom en koepel, hydrauliek en schamierplaten
    gk, gt = G(), G()
    disc(gk, (0, 0.55, 0), 0.30, 1.1, "y", seg=SEGC)
    bx(gk, (0, 1.4, 0.0), (0.76, 0.55, 0.85))
    bx(gt, (0, 1.78, -0.1), (0.5, 0.04, 0.5))
    for sx in (-0.25, 0.25):
        bx(gt, (sx, PIVOT_Y - y0, -0.02), (0.06, 0.55, 0.45))              # scharnierplaten
    disc(gt, (0, PIVOT_Y - y0, -0.02), 0.07, 0.6, "x", seg=8)
    gy_ = G()
    bx(gy_, (0, 0.32, 0.0), (0.7, 0.08, 0.7))
    objs.append(commit("Kolom_romp", gk, M["olijf"], kolom, tile=0.8))
    objs.append(commit("Kolom_beslag", gt, M["staal"], kolom, tile=0.5))
    objs.append(commit("Kolom_band", gy_, M["gevaar"], kolom, tile=0.5, bevel=False))
    # hydraulische cilinder: romp op de kolom, stang aan de giek
    A = Vector((0, 0.5, 0.3))
    boom_rel = PIVOT_Y - y0
    C = Vector((0, boom_rel - 0.2, -1.0))      # aanhechting aan de giek (t.o.v. Kolom)
    Bp = A + (C - A) * 0.6
    gh = G()
    cyl(gh, tuple(A), tuple(Bp), 0.075, seg=SEGC)
    cyl(gh, tuple(A + Vector((0, -0.1, 0.0))), tuple(A), 0.10, seg=SEGC)
    co = commit("Kolom_cilinder", gh, M["staal"], kolom, tile=0.5, bevel=False)
    co["nocull"] = True
    objs.append(co)
    giek = empty("Giek", kolom, (0, boom_rel, 0))
    gg, gs_, gd = G(), G(), G()
    bx(gg, (0, 0, -1.2), (0.34, 0.36, 2.6))
    bx(gg, (0, 0, 0.32), (0.42, 0.46, 0.5))                               # contragewicht
    for z in (-0.35, -1.0, -1.65, -2.3):
        bx(gs_, (0, 0, z), (0.37, 0.39, 0.05))
    bx(gd, (0, 0, -2.45), (0.355, 0.375, 0.12), bevel=False)
    go = commit("Giek_buis", gg, M["olijf"], giek, tile=0.8)
    go["nocull"] = True
    objs.append(go)
    for nm, g, mat in (("Giek_beslag", gs_, M["staal"]), ("Giek_band", gd, M["gevaar"])):
        o = commit(nm, g, mat, giek, tile=0.5)
        o["nocull"] = True
        objs.append(o)
    Cg = Vector((0, -0.2, -1.0))
    Bg = Bp - Vector((0, boom_rel, 0))
    gr = G()
    cyl(gr, tuple(Bg), tuple(Cg), 0.04, seg=8)
    bx(gr, tuple(Cg), (0.14, 0.1, 0.1), bevel=False)
    ro = commit("Giek_stang", gr, M["staal"], giek, tile=0.4, bevel=False)
    ro["nocull"] = True
    objs.append(ro)
    # twee telescoopdelen
    mid = empty("GiekMid", giek, (0, 0, 0))
    gm_ = G()
    bx(gm_, (0, 0, -1.45), (0.29, 0.31, 2.0))
    o = commit("Giek_mid", gm_, M["staal"], mid, tile=0.6)
    o["nocull"] = True
    objs.append(o)
    uit = empty("GiekUit", mid, (0, 0, 0))
    gu, gp = G(), G()
    bx(gu, (0, 0, -1.8), (0.24, 0.26, 2.1))
    bx(gp, (0, -0.02, -2.77), (0.28, 0.32, 0.1))
    disc(gp, (0, -0.16, -2.7), 0.09, 0.2, "x", seg=SEGC)
    o = commit("Giek_uit", gu, M["olijf"], uit, tile=0.6)
    o["nocull"] = True
    objs.append(o)
    o = commit("Giek_kop", gp, M["donker"], uit, tile=0.4)
    o["nocull"] = True
    objs.append(o)
    # ketting en grijper
    kp = empty("Kettingpunt", uit, (0, -0.2, -2.72))
    gc = G()
    chain(gc["donker"] if False else gc, (0, 0, 0), (0, -1.0, 0), link=0.08)
    ko = commit("Ketting", gc, M["donker"], kp, tile=0.3, bevel=False)
    ko["nocull"] = True
    objs.append(ko)
    grab = empty("Grijper", kp, (0, -0.5, 0))
    gh_, gy2, gl = G(), G(), G()
    bx(gh_, (0, 0.0, 0), (1.5, 0.14, 0.22))
    bx(gh_, (0, 0.0, 0), (0.22, 0.14, 1.1))
    bx(gl, (0, 0.18, 0), (0.34, 0.24, 0.34))
    disc(gl, (0, 0.34, 0), 0.1, 0.12, "y", seg=SEGC)
    for sx in (-0.62, 0.62):
        bx(gy2, (sx, 0.0, 0), (0.2, 0.15, 0.24), bevel=False)
    for sz in (-0.45, 0.45):
        bx(gy2, (0, 0.0, sz), (0.24, 0.15, 0.2), bevel=False)
    o = commit("Grijper_kop", gh_, M["staal"], grab, tile=0.5)
    o["nocull"] = True
    objs.append(o)
    o = commit("Grijper_nok", gl, M["olijf2"], grab, tile=0.5)
    o["nocull"] = True
    objs.append(o)
    o = commit("Grijper_band", gy2, M["gevaar"], grab, tile=0.4, bevel=False)
    o["nocull"] = True
    objs.append(o)
    claws = {}
    for sx in (-1, 1):
        gcl = G()
        # klauw: arm omlaag met een tip die naar binnen steekt; de pivot ligt bovenin
        bx(gcl, (0, -0.33, 0), (0.07, 0.66, 0.2))
        bx(gcl, (-sx * 0.05, -0.64, 0), (0.17, 0.07, 0.2))
        bx(gcl, (-sx * 0.12, -0.58, 0), (0.04, 0.1, 0.2), bevel=False)
        if D >= 1:
            for dz in (-0.07, 0.07):
                bx(gcl, (-sx * 0.12, -0.68, dz), (0.05, 0.07, 0.04), bevel=False)
        for sz in (-1, 1):
            e = empty(f"Klauw_{'R' if sx > 0 else 'L'}{'V' if sz > 0 else 'A'}", grab, (sx * 0.66, -0.07, sz * 0.42))
            claws[(sx, sz)] = e
        # gedeelde geometrie: een object per klauw, dezelfde mesh
        o0 = commit(f"Klauw_geo_{'R' if sx > 0 else 'L'}", gcl, M["donker"], claws[(sx, 1)], tile=0.4)
        o0["nocull"] = True
        objs.append(o0)
        o1 = bpy.data.objects.new(f"Klauw_geo_{'R' if sx > 0 else 'L'}2", o0.data)
        bpy.context.scene.collection.objects.link(o1)
        o1.parent = claws[(sx, -1)]
        o1["nocull"] = True
        objs.append(o1)
    return dict(kolom=kolom, giek=giek, mid=mid, uit=uit, kp=kp, ketting=ko, grab=grab, claws=claws), objs


def animate(parts, load, held, wheels):
    """Clips Laden en Lossen (135 frames, 30 fps). Beginpose = eindpose (giek achterover boven de bak, grijper opgetrokken, klauwen open)."""
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    sc.frame_end = LAD_T
    smooth_interp()
    kolom, giek, mid, uit, kp, ketting, grab, claws = (parts[k] for k in ("kolom", "giek", "mid", "uit", "kp", "ketting", "grab", "claws"))
    for o in (kolom, giek, mid, uit, kp, ketting, grab, load, held, *claws.values()):
        o.rotation_mode = "XYZ"
    pi = math.pi
    TIPZ = {"mid": 0.0, "uit": 0.0}

    def key_all(ch):
        """ch: dict kanaal -> [(frame, waarde)] ; kanalen: yaw, ext, elev, L, claw, held, load."""
        frames = sorted({f for seq in ch.values() for f, _ in seq})

        def val(seq, f):
            # lineair tussen de sleutels (waarden liggen op de sleutelframes)
            for (f0, v0), (f1, v1) in zip(seq, seq[1:]):
                if f0 <= f <= f1:
                    return v0 if f1 == f0 else v0 + (v1 - v0) * (f - f0) / (f1 - f0)
            return seq[-1][1]

        for f in frames:
            yaw, ext, elev, L, claw = (val(ch[k], f) for k in ("yaw", "ext", "elev", "L", "claw"))
            kolom.rotation_euler = (0, 0, yaw)
            kolom.keyframe_insert("rotation_euler", frame=f)
            giek.rotation_euler = (elev, 0, 0)
            giek.keyframe_insert("rotation_euler", frame=f)
            mid.location = P(0, 0, -ext / 2)
            mid.keyframe_insert("location", frame=f)
            uit.location = P(0, 0, -ext / 2)
            uit.keyframe_insert("location", frame=f)
            kp.rotation_euler = (-elev, 0, 0)
            kp.keyframe_insert("rotation_euler", frame=f)
            ketting.scale = (1, 1, max(0.05, L - 0.0))
            ketting.keyframe_insert("scale", frame=f)
            grab.location = P(0, -L, 0)
            grab.keyframe_insert("location", frame=f)
            for (sx, sz), c in claws.items():
                c.rotation_euler = (0, -sx * claw, 0)
                c.keyframe_insert("rotation_euler", frame=f)
            s = val(ch["held"], f)
            held.scale = (s, s, s)
            held.keyframe_insert("scale", frame=f)
            s2 = val(ch["load"], f)
            load.scale = (s2, s2, s2)
            load.keyframe_insert("scale", frame=f)

    def add(name):
        for o in (kolom, giek, mid, uit, kp, ketting, grab, load, held, *claws.values()):
            ad = o.animation_data
            if ad is None or ad.action is None:
                continue
            ad.action.name = f"{name}_{o.name}"
            tr = ad.nla_tracks.new()
            tr.name = name
            st_ = tr.strips.new(name, 0, ad.action)
            st_.name = name
            ad.action = None

    E = 0.001
    # kettinglengte (grijper onder het kettingpunt): grijpen van een kist op de grond, rijden, in de bak leggen, neerzetten op de laadplaat (0,17 m hoog)
    LG, LC, LB, LP = 2.14, 0.5, 1.01, 2.19
    # --- Laden: zwenk naar voren, grijp een kist van de stapel, zwenk terug en leg hem in de bak
    key_all(dict(
        yaw=[(0, 0.0), (40, pi), (88, pi), (118, 0.0), (135, 0.0)],
        ext=[(0, 0.0), (40, 3.5), (88, 3.5), (118, 0.0), (135, 0.0)],
        elev=[(0, 0.0), (70, 0.0), (84, 0.06), (100, 0.2), (112, 0.2), (122, 0.0), (135, 0.0)],
        L=[(0, LC), (40, LC), (62, LG), (70, LG), (88, LC), (112, LC), (126, LB), (130, LB), (135, LC)],
        claw=[(0, 0.5), (62, 0.5), (70, 0.0), (124, 0.0), (130, 0.5), (135, 0.5)],
        held=[(0, E), (66, E), (67, 1.0), (128, 1.0), (129, E), (135, E)],
        load=[(0, E), (127, E), (128, 1.0), (135, 1.0)],
    ))
    add("Laden")
    # --- Lossen: kist uit de bak tillen, naar voren zwenken en op de grond neerzetten
    key_all(dict(
        yaw=[(0, 0.0), (36, 0.0), (72, pi), (108, pi), (135, 0.0)],
        ext=[(0, 0.0), (36, 0.0), (72, 2.5), (108, 2.5), (135, 0.0)],
        elev=[(0, 0.0), (24, 0.0), (36, 0.2), (72, 0.1), (90, 0.0), (108, 0.0), (120, 0.1), (135, 0.0)],
        L=[(0, LC), (16, LB), (24, LB), (36, LC), (72, LC), (90, LP), (98, LP), (108, LC), (135, LC)],
        claw=[(0, 0.5), (16, 0.5), (24, 0.0), (92, 0.0), (98, 0.5), (135, 0.5)],
        held=[(0, E), (19, E), (20, 1.0), (94, 1.0), (95, E), (135, E)],
        load=[(0, 1.0), (19, 1.0), (20, E), (135, E)],
    ))
    add("Lossen")
    # rustpose: beginpose van Laden
    sc.frame_set(0)
    kolom.rotation_euler = (0, 0, 0)
    giek.rotation_euler = (0, 0, 0)
    mid.location = P(0, 0, 0)
    uit.location = P(0, 0, 0)
    kp.rotation_euler = (0, 0, 0)
    ketting.scale = (1, 1, LC)
    grab.location = P(0, -LC, 0)
    for (sx, sz), c in claws.items():
        c.rotation_euler = (0, -sx * 0.5, 0)
    held.scale = (E, E, E)
    load.scale = (E, E, E)


def build_wheels(root, M):
    gt, gr, gb = wheel_geo(M)
    tire = commit("Band_geo", gt, M["zwart"], None, tile=0.5, bevel=False)
    rim = commit("Velg_geo", gr, M["staal"], None, tile=0.5, bevel=False)
    bolts = commit("Bouten_geo", gb, M["donker"], None, tile=0.3, bevel=False) if gb.c.faces else None
    for g in (gt, gr, gb):
        pass
    wheels = []
    objs = []
    for key, z in AXLES.items():
        for side, sx in (("L", -1), ("R", 1)):
            name = f"Wiel_{key if key != 'F' else 'F'}{side}" if False else None
    names = {("F", "L"): "Wiel_FL", ("F", "R"): "Wiel_FR", ("M", "L"): "Wiel_ML", ("M", "R"): "Wiel_MR", ("R", "L"): "Wiel_RL", ("R", "R"): "Wiel_RR"}
    for (ax, side), nm in names.items():
        sx = -1 if side == "L" else 1
        pv = empty(nm, root, (sx * TRACK, WR, AXLES[ax]))
        if sx < 0:
            pv.rotation_euler = (0, 0, math.pi)
        wheels.append(pv)
        for base, mesh_obj in (("Band", tire), ("Velg", rim), ("Bouten", bolts)):
            if mesh_obj is None:
                continue
            o = bpy.data.objects.new(f"{base}_{nm[5:]}", mesh_obj.data)
            bpy.context.scene.collection.objects.link(o)
            o.parent = pv
            o["nocull"] = True
            objs.append(o)
    for geo in (tire, rim, bolts):
        if geo is not None:
            bpy.data.objects.remove(geo, do_unlink=True)
    return wheels, objs


def build(root, M):
    S = gset()
    K = bmesh.new()
    build_chassis(S, root)
    build_cab(S, K, root)
    build_bed(S, K, root)
    objs = []
    names = (("olijf", "Carrosserie", M["olijf"], 1.0, True), ("olijf2", "Carrosserie_donker", M["olijf2"], 1.0, True), ("staal", "Beslag", M["staal"], 0.6, D >= 2),
             ("donker", "Techniek", M["donker"], 0.4, False), ("geel", "Geel", M["geel"], 0.5, True), ("gevaar", "Gevaarband", M["gevaar"], 0.5, True),
             ("hout", "Laadvloer", M["hout"], 0.6, D >= 2), ("zwart", "Rubber", M["zwart"], 0.5, False), ("glas", "Glas", M["glas"], 1.0, False),
             ("amber", "Lamp_amber", M["amber"], 1.0, False), ("rood", "Lamp_rood", M["rood"], 1.0, False), ("witlamp", "Lamp_wit", M["wit_lamp"], 1.0, False))
    for key, nm, mat, tile, bev in names:
        o = commit(nm, S[key], mat, root, tile=tile, bevel=bev)
        if o:
            objs.append(o)
    if K.faces:
        objs.append(F.new_obj("Stencil", K, M["stencil"], smooth=False, parent=root))
    else:
        K.free()
    return objs


def main():
    sc = fresh_scene()
    M = materials()
    root = bpy.data.objects.new("Voorraadtruck", None)
    sc.collection.objects.link(root)
    objs = build(root, M)
    wheels, wobjs = build_wheels(root, M)
    # LOD1 (ver weg) heeft geen wisselende lading: een vaste kist zou kloppen bij een lege truck niet
    load, lobjs = build_load(root, M) if LEVEL != "lod1" else (None, [])
    parts, cobjs = build_crane(M, root)
    held, hobjs = build_held_crate(parts["grab"], M) if LEVEL != "lod1" else (None, [])
    tris = tri_count()
    print(f"[{LEVEL}] driehoeken: {tris}")
    if os.environ.get("VR_STATS"):
        dg = bpy.context.evaluated_depsgraph_get()
        rows = sorted(((sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).to_mesh().polygons), o.name) for o in bpy.data.objects if o.type == "MESH"), reverse=True)
        for n, name in rows[:25]:
            print(f"   {n:6d}  {name}")
        return
    if LEVEL != "lod1":
        animate(parts, load, held, wheels)
    if LEVEL != "hq":
        bake_groups([("truck", bakeable())])
    print(f"[{LEVEL}] driehoeken na snoeien: {tri_count()}  materialen: {len(bpy.data.materials)}")
    stem = {"hq": "Voorraadtruck_HQ", "game": "voorraadtruck", "lod1": "voorraadtruck_lod1"}[LEVEL]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    if LEVEL == "hq":
        print("HQ-bron opgeslagen:", OUT / f"{stem}.blend")
        return
    export_glb(ROOT / "assets" / f"{stem}.glb")
    if LEVEL == "game":
        export_usdz(OUT / "Voorraadtruck.usdz")


if __name__ == "__main__":
    main()
