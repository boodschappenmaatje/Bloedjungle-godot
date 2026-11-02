"""Voorraaddepot (Generals-plan stap 4b, stijl Intendance).

    python bron/voorraad/maak_depot.py hq     # bewerkbare bron: uit/Voorraaddepot_HQ.blend (procedurele materialen, geen bake)
    python bron/voorraad/maak_depot.py game   # Godot-versie: assets/voorraaddepot.glb (+ uit/Voorraaddepot.usdz)
    python bron/voorraad/maak_depot.py lod1   # uitgezoomd: assets/voorraaddepot_lod1.glb (statisch)

Voetafdruk 9 x 6,5 m (x breed, z diep), voorkant +z, oorsprong midden op de grond. Achter: een golfplaatschuur (rolpoort, spanten, stellingen met
kisten). Voor: een betonnen laadperron met een gele portaalkraan op rails, een laadplaat (hier zet de truck zijn kist neer), een opslagpallet,
een weegplateau, afzetpalen en nachtlampen. Echte Blender-clips (NLA, 30 fps):
  `Poort`         60 frames  rolpoort dicht (frame 0) -> open (frame 60); dichtdoen = achteruit afspelen
  `Kraan-lossen`  135 frames portaalkraan pakt de kist van de laadplaat en zet hem op het opslagpallet (beginpose = eindpose van de kraan)
Onderdelen voor Godot: Perron, Schuur, Poort, Portaalkraan (Brug > Loopkat > Ketting/Haak > Kist_vast), Kisten (Kist_perron, Kist_opslag), Lampen.
"""
import math
import os
import random

from vc import *  # noqa: F401,F403

# ---- maten (Godot-assen, meter); de voetafdruk is x -4,5..4,5 en z -3,25..3,25
SL = 0.14                      # dikte van de betonplaat
SX = 4.3                       # schuur: halve breedte
SZ0, SZ1 = -3.2, 0.5           # schuur: achterwand, voorgevel (buitenkant)
WT = 0.16                      # wanddikte
EAVE = 3.55                    # goothoogte (absoluut)
RIDGE = 4.3                    # nokhoogte
RZ = (SZ0 + SZ1) / 2.0         # nok boven het midden van de schuur
DOOR_W, DOOR_H = 3.8, 3.0      # poortopening
PAD = (0.0, 2.0)               # laadplaat (x, z): hier zet de truck zijn kist neer
STK = (3.0, 1.2)               # opslagpallet (x, z)
RAILX = 4.15                   # rails van de portaalkraan (x = -4,15 en 4,15)
GIRDER_Y = 4.55                # hoogte van de brugligger (midden)
PAL = (1.25, 1.5)              # pallet onder een kist (x, z)
CB = (0.96, 0.62, 1.3)         # kist die de kraan hanteert: dezelfde als in de truck
LOD = LEVEL == "lod1"
FRAMES_K = 135
FRAMES_P = 60
M = {}


def gset():
    return {k: G() for k in ("olijf", "olijf2", "staal", "donker", "geel", "gevaar", "hout", "zwart", "wit", "beton", "dak", "glas", "amber",
                             "rood", "witlamp", "doek")}


TILES = {"olijf": ("olijf", 1.0, 1), "olijf2": ("olijf2", 1.0, 1), "staal": ("staal", 0.6, 1), "donker": ("donker", 0.4, 99),
         "geel": ("geel", 0.5, 1), "gevaar": ("gevaar", 0.5, 99), "hout": ("hout", 0.6, 2), "zwart": ("zwart", 0.5, 99),
         "wit": ("wit", 1.0, 1), "beton": ("beton", 1.0, 2), "dak": ("dak", 1.0, 99), "glas": ("glas", 1.0, 99),
         "amber": ("amber", 1.0, 99), "rood": ("rood", 1.0, 99), "witlamp": ("wit_lamp", 1.0, 99), "doek": ("doek", 1.0, 99)}
# tweede getal van elke regel: vanaf welk detailniveau D de dozen een afschuining krijgen (1 = ook in de gameversie, 2 = alleen de HQ-bron)
NAMES = {"olijf": "Verf", "olijf2": "Verf_donker", "staal": "Staal", "donker": "Techniek", "geel": "Geel", "gevaar": "Gevaarband", "hout": "Hout",
         "zwart": "Rubber", "wit": "Binnenwand", "beton": "Beton", "dak": "Golfplaat", "glas": "Glas", "amber": "Lamp_amber", "rood": "Rood",
         "witlamp": "Lamp_wit", "doek": "Doek"}


def commit_set(S, K, parent, prefix, nocull=False, hq_only=False):
    objs = []
    for key, (mk, tile, bev) in TILES.items():
        g = S[key]
        o = commit(f"{prefix}_{NAMES[key]}", g, M[mk], parent, tile=tile, bevel=D >= (2 if hq_only and bev == 1 and key in ("staal", "geel") else bev))
        if o:
            if nocull:
                o["nocull"] = True
            objs.append(o)
    if K is not None:
        if K.faces:
            o = F.new_obj(f"{prefix}_Stencil", K, M["stencil"], smooth=False, parent=parent)
            if nocull:
                o["nocull"] = True
            objs.append(o)
        else:
            K.free()
    return objs


# ------------------------------------------------------------------ bouwstenen: golfplaat en prisma
def corrugated(bm, o, u, n, w, h, pitch=0.11, amp=0.022, seg=4):
    """Golfplaat van w (langs u) x h (langs v = n x u), linkeronderhoek o, uitgaande normaal n (alles in Godot-assen). Golven langs u."""
    o, u, n = P(*o), P(*u).normalized(), P(*n).normalized()
    v = n.cross(u)
    nw = max(1, int(round(w / pitch)))
    N = nw * (seg if D >= 1 else 2)
    rows = []
    for j in (0, 1):
        rows.append([bm.verts.new(o + u * (i / N * w) + v * (h * j) + n * (amp * (1.0 + math.sin(2 * math.pi * i / N * nw)) if D >= 1 else amp * (i % 2)))
                     for i in range(N + 1)])
    for i in range(N):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))


def prism(g, pts, x0, x1):
    """Prisma: veelhoek pts = [(z, y), ...] (Godot) over x0 -> x1."""
    bm = g.b
    a = [bm.verts.new(P(x0, y, z)) for z, y in pts]
    b = [bm.verts.new(P(x1, y, z)) for z, y in pts]
    faces = [bm.faces.new(a), bm.faces.new(b[::-1])]
    n = len(pts)
    for i in range(n):
        faces.append(bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def vlak(bm, o, u, n, w, h):
    """Een vlak (voor ruiten en doek), zie corrugated."""
    corrugated(bm, o, u, n, w, h, pitch=max(w, 0.01), amp=0.0, seg=1)


# ------------------------------------------------------------------ onderdelen: perron
def build_perron(root):
    S, K = gset(), bmesh.new()
    bx(S["beton"], (0, SL / 2, 0), (9.0, SL, 6.5))
    # voegen en een betonnen kantstrook
    for x in (-3.0, -1.5, 1.5, 3.0) if D >= 1 else (-2.25, 2.25):
        bx(S["donker"], (x, SL + 0.002, 0.0), (0.025, 0.004, 6.44), bevel=False)
    for z in (-1.7, 0.5, 1.9) if D >= 1 else (1.9,):
        bx(S["donker"], (0, SL + 0.002, z), (8.94, 0.004, 0.025), bevel=False)
    bx(S["gevaar"], (0, SL + 0.004, 3.12), (8.9, 0.008, 0.16), bevel=False)
    bx(S["gevaar"], (0, SL + 0.004, 3.12), (8.9, 0.008, 0.16), bevel=False) if False else None
    # laadplaat: stalen ruitplaat met gele rand en hoekmarkeringen
    px, pz = PAD
    bx(S["staal"], (px, SL + 0.016, pz), (2.0, 0.032, 2.0))
    for s in (-1, 1):
        bx(S["geel"], (px + s * 0.97, SL + 0.036, pz), (0.06, 0.012, 2.0), bevel=False)
        bx(S["geel"], (px, SL + 0.036, pz + s * 0.97), (2.0, 0.012, 0.06), bevel=False)
    if D >= 1:
        for sx in (-0.82, 0.82):
            for sz in (-0.82, 0.82):
                disc(S["donker"], (px + sx, SL + 0.04, pz + sz), 0.035, 0.012, "y", seg=8)
        for i in range(-4, 5) if D >= 2 else (-2, 0, 2):
            bx(S["donker"], (px + i * 0.2, SL + 0.034, pz), (0.012, 0.004, 1.74), bevel=False)
    if not LOD:
        decal_at(K, "keepclear", (0.0, SL + 0.012, 0.76), 2.3, 0.34, pitch=-math.pi / 2)
    # afzetpalen (geel met zwarte band) langs de voorkant
    for x in (-4.3, -2.6, 2.6, 4.3):
        disc(S["geel"], (x, SL + 0.45, 2.95), 0.1, 0.9, "y", seg=SEGC)
        disc(S["gevaar"], (x, SL + 0.62, 2.95), 0.104, 0.16, "y", seg=SEGC)
        disc(S["gevaar"], (x, SL + 0.28, 2.95), 0.104, 0.16, "y", seg=SEGC)
        disc(S["geel"], (x, SL + 0.915, 2.95), 0.115, 0.03, "y", seg=SEGC)
    # weegplateau met paal en display (links voor)
    wx, wz = -3.1, 2.0
    bx(S["donker"], (wx, SL + 0.03, wz), (1.35, 0.06, 1.35))
    bx(S["staal"], (wx, SL + 0.07, wz), (1.25, 0.03, 1.25))
    for i in range(-4, 5) if D >= 2 else ():
        bx(S["donker"], (wx + i * 0.13, SL + 0.088, wz), (0.012, 0.006, 1.12), bevel=False)
    for sx in (-0.62, 0.62):
        for sz in (-0.62, 0.62):
            bx(S["geel"], (wx + sx, SL + 0.095, wz + sz), (0.09, 0.02, 0.09), bevel=False)
    cyl(S["donker"], (wx + 0.9, SL, wz - 0.5), (wx + 0.9, SL + 1.3, wz - 0.5), 0.035, seg=8)
    bx(S["donker"], (wx + 0.9, SL + 1.38, wz - 0.5), (0.34, 0.24, 0.1))
    bx(S["amber"], (wx + 0.9, SL + 1.38, wz - 0.445), (0.26, 0.14, 0.012), bevel=False)
    # opslagpallet met twee kisten (de kraan zet er een derde bovenop)
    sx_, sz_ = STK
    pallet(S["hout"], S["staal"], (sx_, SL + 0.24, sz_), w=PAL[0], d=PAL[1], boards=5)
    for i in range(2):
        crate(S["olijf"], S["staal"], S["geel"], K, (sx_, SL + 0.24 + CB[1] * (i + 0.5), sz_), yaw=0.05 * (i * 2 - 1), stencil=("batch", "int")[i], size=CB)
    # elektrakast en brandblusser tegen de voorgevel
    bx(S["olijf2"], (-4.0, SL + 0.55, SZ1 + 0.13), (0.5, 1.1, 0.22))
    bx(S["staal"], (-4.0, SL + 0.55, SZ1 + 0.255), (0.42, 1.0, 0.012), bevel=False)
    bx(S["gevaar"], (-4.0, SL + 1.14, SZ1 + 0.13), (0.52, 0.06, 0.24), bevel=False)
    cyl(S["rood"], (2.45, SL + 0.95, SZ1 + 0.1), (2.45, SL + 1.35, SZ1 + 0.1), 0.065, seg=10)
    bx(S["donker"], (2.45, SL + 1.1, SZ1 + 0.04), (0.2, 0.7, 0.04), bevel=False)
    # hekwerk langs de zijkanten van het perron (laag, gaas tussen palen)
    for sx in (-1, 1):
        for z in (0.9, 3.2):
            cyl(S["geel"], (sx * 4.44, SL, z), (sx * 4.44, SL + 1.0, z), 0.04, seg=8)
        bx(S["staal"], (sx * 4.44, SL + 0.95, 2.05), (0.03, 0.03, 2.3), bevel=False)
        bx(S["staal"], (sx * 4.44, SL + 0.45, 2.05), (0.03, 0.03, 2.3), bevel=False)
        if D >= 1:
            for z in np.arange(1.0, 3.15, 0.18 if D >= 2 else 0.36):
                bx(S["donker"], (sx * 4.44, SL + 0.5, z), (0.012, 0.9, 0.012), bevel=False)
    return commit_set(S, K, root, "Perron")


# ------------------------------------------------------------------ onderdelen: schuur (wanden, dak, spanten, binnenwerk)
def build_shed(root, interior_root):
    S, K = gset(), bmesh.new()
    y0 = SL
    hh = EAVE - y0
    # kernwanden (binnenkant licht)
    bx(S["wit"], (0, y0 + hh / 2, SZ0 + WT / 2), (2 * SX, hh, WT))
    for sx in (-1, 1):
        bx(S["wit"], (sx * (SX - WT / 2), y0 + hh / 2, (SZ0 + SZ1) / 2), (WT, hh, SZ1 - SZ0))
    wing = SX - DOOR_W / 2
    for sx in (-1, 1):
        bx(S["wit"], (sx * (DOOR_W / 2 + wing / 2), y0 + hh / 2, SZ1 - WT / 2), (wing, hh, WT))
    hdr_h = EAVE - (y0 + DOOR_H)
    bx(S["wit"], (0, y0 + DOOR_H + hdr_h / 2, SZ1 - WT / 2), (DOOR_W, hdr_h, WT))
    # gevelspitsen (driehoeken boven de goot)
    for sx in (-1, 1):
        prism(S["wit"], [(SZ0, EAVE), (SZ1, EAVE), (RZ, RIDGE)], sx * (SX - WT), sx * SX)
    # betonnen plint rondom, golfplaatbekleding erboven
    pl = 0.42
    bx(S["beton"], (0, y0 + pl / 2, SZ0 - 0.03), (2 * SX + 0.08, pl, 0.08))
    for sx in (-1, 1):
        bx(S["beton"], (sx * (SX + 0.03), y0 + pl / 2, (SZ0 + SZ1) / 2), (0.08, pl, SZ1 - SZ0 + 0.08))
        bx(S["beton"], (sx * (DOOR_W / 2 + wing / 2), y0 + pl / 2, SZ1 + 0.03), (wing + 0.08, pl, 0.08))
    bx(S["beton"], (0, y0 + 0.03, SZ1 + 0.03), (DOOR_W, 0.06, 0.1))                 # drempel
    c = S["olijf"].c
    hc = EAVE - y0 - pl
    corrugated(c, (SX, y0 + pl, SZ0), (-1, 0, 0), (0, 0, -1), 2 * SX, hc)            # achterwand (gezien van achteren loopt x naar links)
    for sx in (-1, 1):
        # zijwanden: u = omhoog x naar buiten gekeerd (zie corrugated: u x v = n met v omhoog)
        corrugated(c, (sx * SX, y0 + pl, SZ1 if sx > 0 else SZ0), (0, 0, -sx), (sx, 0, 0), SZ1 - SZ0, hc)
        corrugated(c, ((DOOR_W / 2 if sx > 0 else -SX), y0 + pl, SZ1), (1, 0, 0), (0, 0, 1), wing, hc)
    corrugated(c, (-DOOR_W / 2, y0 + DOOR_H, SZ1), (1, 0, 0), (0, 0, 1), DOOR_W, EAVE - y0 - DOOR_H)
    # staalkolommen op de hoeken en bij de poort, schoren en stalen zoom
    for sx in (-1, 1):
        for z in (SZ0, SZ1):
            bx(S["staal"], (sx * (SX + 0.01), (y0 + EAVE) / 2, z), (0.2, hh, 0.2))
        bx(S["geel"], (sx * (DOOR_W / 2 + 0.07), y0 + DOOR_H / 2, SZ1 + 0.04), (0.14, DOOR_H, 0.14))
        for k in range(8 if D >= 1 else 4):
            yb = y0 + 0.1 + k * 0.3
            bx(S["gevaar"] if False else S["zwart"], (sx * (DOOR_W / 2 + 0.07), yb + 0.075, SZ1 + 0.115), (0.145, 0.15, 0.012), bevel=False) if False else None
        bx(S["gevaar"], (sx * (DOOR_W / 2 + 0.07), y0 + 0.5, SZ1 + 0.116), (0.14, 1.0, 0.01), bevel=False)
    bx(S["geel"], (0, y0 + DOOR_H + 0.06, SZ1 + 0.04), (DOOR_W + 0.28, 0.12, 0.14))                    # latei
    # rolpoortkast boven de poort
    bx(S["olijf2"], (0, y0 + DOOR_H + 0.3, SZ1 + 0.2), (DOOR_W + 0.3, 0.42, 0.3))
    bx(S["gevaar"], (0, y0 + DOOR_H + 0.3, SZ1 + 0.352), (DOOR_W + 0.1, 0.1, 0.012), bevel=False)
    if D >= 1:
        for sx in (-1, 1):
            bx(S["staal"], (sx * (DOOR_W / 2 + 0.17), y0 + DOOR_H + 0.3, SZ1 + 0.2), (0.04, 0.44, 0.32))
    # goot, fascia en afvoerpijp
    ez = SZ1 + 0.3
    for sz, z in ((1, ez), (-1, SZ0 - 0.3)):
        bx(S["staal"], (0, EAVE - 0.1, z), (2 * SX + 0.4, 0.14, 0.12))
        if D >= 1:
            bx(S["olijf2"], (0, EAVE - 0.02, z + sz * 0.02), (2 * SX + 0.4, 0.1, 0.04), bevel=False)
    cyl(S["staal"], (SX + 0.14, y0 + 0.1, SZ1 + 0.05), (SX + 0.14, EAVE - 0.1, SZ1 + 0.05), 0.035, seg=8)
    for k in range(4):
        bx(S["donker"], (SX + 0.14, y0 + 0.4 + k * 0.85, SZ1 + 0.05), (0.08, 0.04, 0.08), bevel=False)
    # dak: twee golfplaatvlakken (eigen UV's, dus in de golfplaatset) met nokkap, randen en gevelplaten
    dyr = RIDGE - (EAVE - 0.08)
    for sgn, zeave in ((1, ez), (-1, SZ0 - 0.3)):
        dz = abs(RZ - zeave)
        ln = math.hypot(dz, dyr)
        ngodot = (0.0, dz / ln, sgn * dyr / ln)          # normaal omhoog en naar buiten
        corrugated(S["dak"].c, (-sgn * (SX + 0.18), EAVE - 0.08, zeave), (sgn, 0, 0), ngodot, 2 * SX + 0.36, ln, pitch=0.12, amp=0.03)
    bx(S["staal"], (0, RIDGE + 0.04, RZ), (2 * SX + 0.4, 0.1, 0.34))
    bx(S["olijf2"], (0, RIDGE + 0.08, RZ), (2 * SX + 0.42, 0.04, 0.2), bevel=False)
    for sx in (-1, 1):                     # windveren langs de gevelranden
        for sgn, ze in ((1, ez), (-1, SZ0 - 0.3)):
            a = (sx * (SX + 0.18), EAVE - 0.08, ze)
            b = (sx * (SX + 0.18), RIDGE, RZ)
            bar(S["olijf2"], a, b, 0.2, 0.05)
    # ventilatiekappen op de nok
    for x in (-2.2, 2.2):
        cyl(S["staal"], (x, RIDGE + 0.05, RZ), (x, RIDGE + 0.5, RZ), 0.17, seg=10)
        cyl(S["donker"], (x, RIDGE + 0.5, RZ), (x, RIDGE + 0.62, RZ), 0.3, seg=12, r2=0.05)
    # tekst en embleem op de voorgevel
    if not LOD:
        decal_at(K, "depot01", (-3.15, y0 + 2.25, SZ1 + 0.005), 1.9, 0.4)
        decal_at(K, "chevron", (3.28, y0 + 2.0, SZ1 + 0.006), 1.0, 1.0)
        decal_at(K, "plaat", (-3.15, y0 + 1.2, SZ1 + 0.006), 1.5, 0.82)
    out = commit_set(S, K, root, "Schuur")
    # ---- binnenwerk (zichtbaar als de poort open is): spanten, gordingen, stelling, kisten, vaten, lampen
    if LOD:
        return out
    S2, K2 = gset(), bmesh.new()
    xs = (-3.6, -1.8, 0.0, 1.8, 3.6) if D >= 1 else (-3.0, 0.0, 3.0)
    ty = EAVE - 0.2
    zi0, zi1 = SZ0 + WT, SZ1 - WT
    for x in xs:
        bar(S2["staal"], (x, ty, zi0), (x, ty, zi1), 0.12, 0.1)                       # trekbalk
        bar(S2["staal"], (x, ty, zi0), (x, RIDGE - 0.14, RZ), 0.1, 0.1)               # rafters
        bar(S2["staal"], (x, ty, zi1), (x, RIDGE - 0.14, RZ), 0.1, 0.1)
        bar(S2["staal"], (x, ty, RZ), (x, RIDGE - 0.14, RZ), 0.08, 0.08)              # nokstijl
        if D >= 1:
            bar(S2["staal"], (x, ty, zi0 + 0.6), (x, RIDGE - 0.4, RZ - 0.15), 0.06, 0.06)
            bar(S2["staal"], (x, ty, zi1 - 0.6), (x, RIDGE - 0.4, RZ + 0.15), 0.06, 0.06)
    for k in (0.35, 0.7):                                                              # gordingen langs x
        for sgn, zz in ((1, zi1), (-1, zi0)):
            z = zz + (RZ - zz) * k
            y = ty + (RIDGE - 0.14 - ty) * k
            bar(S2["staal"], (-SX + WT, y, z), (SX - WT, y, z), 0.07, 0.08)
    # lampen: hangende kappen met een lichtschijf
    for x in (-2.7, 0.0, 2.7):
        cyl(S2["donker"], (x, ty, -1.2), (x, ty - 0.25, -1.2), 0.012, seg=6)
        cyl(S2["donker"], (x, ty - 0.25, -1.2), (x, ty - 0.45, -1.2), 0.06, seg=12, r2=0.32)
        cyl(S2["witlamp"], (x, ty - 0.46, -1.2), (x, ty - 0.47, -1.2), 0.24, seg=12)
    # stelling langs de achterwand: staanders, liggers, dekplanken, kisten op pallets
    rz0, rz1 = SZ0 + WT + 0.15, SZ0 + WT + 1.15
    ups = (-3.9, -1.3, 1.3, 3.9)
    for x in ups:
        for z in (rz0, rz1):
            bx(S2["donker"], (x, (SL + 2.6) / 2 + 0.0, z), (0.08, 2.6 - SL, 0.08))
    for lvl in (0.35, 1.45, 2.55) if D >= 1 else (0.35, 1.45):
        for i in range(3):
            xa, xb = ups[i], ups[i + 1]
            for z in (rz0, rz1):
                bx(S2["geel"], ((xa + xb) / 2, lvl, z), (xb - xa, 0.12, 0.06))
            for k in range(6):
                zz = rz0 + (rz1 - rz0) * (k + 0.5) / 6
                bx(S2["hout"], ((xa + xb) / 2, lvl + 0.07, zz), (xb - xa - 0.05, 0.03, 0.17))
    rng = random.Random(5)
    for i, (xa, xb) in enumerate(zip(ups[:-1], ups[1:])):
        xm = (xa + xb) / 2
        for lvl, nn in ((0.35, 2), (1.45, 2), (2.55, 1 if i != 1 else 0)):
            for k in range(nn):
                cx = xm + (k - (nn - 1) / 2) * 1.0
                crate(S2["olijf"], S2["staal"], S2["geel"], K2, (cx + rng.uniform(-0.03, 0.03), lvl + 0.085 + CB[1] / 2, (rz0 + rz1) / 2), yaw=rng.uniform(-0.05, 0.05) + math.pi / 2,
                      stencil=rng.choice(["batch", "int", "swl", "n01", "n02", "n03"]), size=CB)
    # pallets met kisten op de vloer en een paar vaten
    for (x, z, n_) in ((-3.2, -0.7, 2), (2.9, -0.9, 2), (3.3, 0.05, 1)):
        pallet(S2["hout"], S2["staal"], (x, SL + 0.24, z), w=PAL[0], d=PAL[1], boards=5)
        for i in range(n_):
            crate(S2["olijf"], S2["staal"], S2["geel"], K2, (x, SL + 0.24 + CB[1] * (i + 0.5), z), yaw=rng.uniform(-0.08, 0.08), stencil=rng.choice(["batch", "int", "swl"]), size=CB)
    for (x, z) in ((-3.7, -2.1), (-3.2, -2.3), (-3.7, -1.65)) if False else ():
        pass
    for k, (x, z) in enumerate(((-3.95, -0.1), (-3.5, 0.05), (-3.95, 0.3))):
        cyl(S2["olijf2"] if k != 1 else S2["rood"], (x, SL, z), (x, SL + 0.88, z), 0.28, seg=SEGC + 4)
        for yb in (0.2, 0.44, 0.68):
            cyl(S2["staal"], (x, SL + yb, z), (x, SL + yb + 0.04, z), 0.292, seg=SEGC + 4)
    # lichtkoepel van het dak als lijst (een lichtstreep langs de nok)
    out += commit_set(S2, K2, interior_root, "Binnen", nocull=True, hq_only=True)
    return out


# ------------------------------------------------------------------ rolpoort (animeerbaar)
def build_door(root):
    """Poort: een stapel lamellen die omhoog wegrolt (schaal in y tot een dun pakket onder de kast) en een onderbalk met gevaarband (verplaatst mee)."""
    ztop = SL + DOOR_H
    pv = empty("Poort", root, (0, ztop, SZ1 - WT - 0.03))
    pv["nocull"] = True
    pb = empty("Poort_balk", root, (0, SL + 0.07, SZ1 - WT - 0.03))
    S, S2 = gset(), gset()
    n = int(DOOR_H / 0.12) if D >= 1 else 14
    hs = (DOOR_H - 0.14) / n
    for i in range(n):
        bx(S["staal"], (0, -(i + 0.5) * hs, 0), (DOOR_W - 0.02, hs * 0.94, 0.045))
        if D >= 2 and i % 3 == 1:
            for k in range(3):
                bx(S["donker"], (-DOOR_W / 2 + 0.6 + k * (DOOR_W - 1.2) / 2, -(i + 0.5) * hs, 0.026), (0.3, hs * 0.5, 0.01), bevel=False)
    bx(S2["geel"], (0, 0, 0), (DOOR_W - 0.02, 0.14, 0.06))
    bx(S2["gevaar"], (0, 0, 0.032), (DOOR_W - 0.06, 0.1, 0.01), bevel=False)
    for sx in (-1, 1):
        bx(S2["donker"], (sx * (DOOR_W / 2 - 0.12), 0.0, 0.04), (0.1, 0.16, 0.05))
    out = commit_set(S, None, pv, "Poort_lamellen", nocull=True)
    out += commit_set(S2, None, pb, "Poort_onderbalk", nocull=True)
    # geleiderails in de gevel (niet animeren)
    S3 = gset()
    for sx in (-1, 1):
        bx(S3["donker"], (sx * (DOOR_W / 2 + 0.02), SL + DOOR_H / 2, SZ1 - WT - 0.03), (0.07, DOOR_H, 0.09))
    out += commit_set(S3, None, root, "Poort_geleiders")
    return pv, pb, out


# ------------------------------------------------------------------ portaalkraan
def build_portal(root):
    """Portaalkraan: rails op het perron; Brug (loopt langs z) > Loopkat (loopt langs x) > Ketting (hijsketting) + Haak met spreider > Kist_vast."""
    S0 = gset()
    for sx in (-1, 1):
        x = sx * RAILX
        bx(S0["staal"], (x, SL + 0.04, 1.95), (0.1, 0.06, 2.55))
        for z in np.arange(0.8, 3.1, 0.38 if D >= 1 else 0.76):
            bx(S0["beton"], (x, SL + 0.02, z), (0.34, 0.04, 0.16))
        for z in (0.68, 3.2):
            bx(S0["gevaar"], (x, SL + 0.14, z), (0.3, 0.2, 0.12))
    objs = commit_set(S0, None, root, "Rails")
    z0 = 1.2
    brug = empty("Brug", root, (0, 0, z0))
    brug["nocull"] = True
    S = gset()
    # poten: twee kolommen per kant met kruisverband en voetblokken met wielen
    for sx in (-1, 1):
        x = sx * RAILX
        for dz in (-0.34, 0.34):
            bx(S["geel"], (x, (SL + GIRDER_Y) / 2, dz), (0.2, GIRDER_Y - SL - 0.2, 0.18))
            bx(S["donker"], (x, SL + 0.14, dz), (0.34, 0.16, 0.3))
            for wz in (-0.1, 0.1) if D >= 1 else ():
                disc(S["staal"], (x, SL + 0.12, dz + wz), 0.09, 0.2, "x", seg=SEGC)
        bx(S["geel"], (x, GIRDER_Y - 0.15, 0), (0.2, 0.16, 0.9))
        for yy in (1.0, 2.6):
            bx(S["geel"], (x, yy, 0), (0.12, 0.1, 0.72))
        for yy0, yy1 in ((SL + 0.3, 1.0), (1.0, 2.6), (2.6, GIRDER_Y - 0.2)):
            bar(S["staal"], (x, yy0, -0.32), (x, yy1, 0.32), 0.07, 0.07)
            if D >= 2:
                bar(S["staal"], (x, yy0, 0.32), (x, yy1, -0.32), 0.07, 0.07)
        for yy in np.arange(SL + 0.15, 1.0, 0.25):
            pass
        bx(S["gevaar"], (x - sx * 0.0, SL + 0.5, -0.34 - 0.0), (0.205, 0.7, 0.185), bevel=False) if False else None
        for dz in (-0.34, 0.34):
            bx(S["gevaar"], (x, SL + 0.62, dz), (0.205, 0.8, 0.185), bevel=False)
    # brugligger: kokerbalk met schotten, looppad met leuning
    gx = RAILX + 0.2
    bx(S["geel"], (0, GIRDER_Y, 0), (2 * gx, 0.52, 0.62))
    bx(S["donker"], (0, GIRDER_Y - 0.28, 0), (2 * gx - 0.2, 0.04, 0.5))               # onderflens waarop de loopkat rijdt
    if D >= 1:
        for x in np.arange(-RAILX + 0.4, RAILX, 0.8 if D >= 2 else 1.6):
            bx(S["staal"], (x, GIRDER_Y, 0.33), (0.07, 0.5, 0.02), bevel=False)
            bx(S["staal"], (x, GIRDER_Y, -0.33), (0.07, 0.5, 0.02), bevel=False)
    bx(S["gevaar"], (0, GIRDER_Y - 0.15, 0.318), (1.1, 0.14, 0.01), bevel=False)
    bx(S["gevaar"], (0, GIRDER_Y - 0.15, -0.318), (1.1, 0.14, 0.01), bevel=False)
    for sx in (-1, 1):
        bx(S["gevaar"], (sx * (gx - 0.5), GIRDER_Y - 0.15, 0.318), (0.9, 0.14, 0.01), bevel=False)
        bx(S["gevaar"], (sx * (gx - 0.5), GIRDER_Y - 0.15, -0.318), (0.9, 0.14, 0.01), bevel=False)
    if D >= 1:
        bx(S["staal"], (0, GIRDER_Y + 0.3, 0.0), (2 * gx - 0.4, 0.04, 0.5))
        for sz in (-0.27, 0.27):
            bx(S["staal"], (0, GIRDER_Y + 0.8, sz), (2 * gx - 0.4, 0.03, 0.03))
            bx(S["staal"], (0, GIRDER_Y + 0.55, sz), (2 * gx - 0.4, 0.03, 0.03))
            for x in np.arange(-RAILX, RAILX + 0.1, 1.15 if D >= 2 else 2.3):
                bx(S["staal"], (x, GIRDER_Y + 0.54, sz), (0.03, 0.52, 0.03))
    # motorkast en waarschuwingslamp op de brug
    bx(S["olijf2"], (RAILX - 0.9, GIRDER_Y + 0.5, 0.0), (0.7, 0.48, 0.5))
    bx(S["amber"], (RAILX - 0.9, GIRDER_Y + 0.82, 0.0), (0.14, 0.1, 0.14), bevel=False)
    objs += commit_set(S, None, brug, "Portaalkraan", nocull=True)
    # loopkat: hangt onder de brug, rijdt langs x
    kat = empty("Loopkat", brug, (0, GIRDER_Y - 0.36, 0))
    kat["nocull"] = True
    S = gset()
    bx(S["donker"], (0, 0, 0), (0.7, 0.2, 0.72))
    bx(S["geel"], (0, -0.2, 0), (0.55, 0.28, 0.52))
    for sx in (-0.34, 0.34):
        for sz in (-0.24, 0.24):
            disc(S["staal"], (sx, 0.14, sz), 0.07, 0.08, "z" if False else "z", seg=SEGC) if False else None
            bx(S["staal"], (sx, 0.12, sz), (0.1, 0.08, 0.16))
    bx(S["olijf2"], (0.3, -0.12, 0), (0.3, 0.3, 0.4))
    bx(S["amber"], (0, -0.2, 0.27), (0.18, 0.05, 0.012), bevel=False)
    objs += commit_set(S, None, kat, "Loopkat", nocull=True)
    # hijsketting (schaalt in y) en haak met spreider
    ketting = empty("Ketting", kat, (0, -0.36, 0))
    ketting["nocull"] = True
    gk = G()
    chain(gk["donker"] if False else gk, (0, 0, 0), (0, -1.0, 0), link=0.08)
    ko = commit("Hijsketting", gk, M["donker"], ketting, tile=0.3, bevel=False)
    ko["nocull"] = True
    objs.append(ko)
    haak = empty("Haak", kat, (0, -1.5, 0))
    haak["nocull"] = True
    S = gset()
    bx(S["staal"], (0, 0.0, 0), (0.18, 0.2, 0.18))
    disc(S["donker"], (0, 0.12, 0), 0.06, 0.1, "z", seg=SEGC)
    bx(S["geel"], (0, -0.14, 0), (1.2, 0.07, 0.08))
    bx(S["geel"], (0, -0.14, 0), (0.08, 0.07, 1.4))
    for sx in (-0.58, 0.58):
        for sz in (-0.66, 0.66):
            pass
    for sx in (-0.52, 0.52):
        for sz in (-0.62, 0.62):
            cyl(S["donker"], (sx * 0.2, -0.14, sz * 0.2), (sx, -0.14 - 0.0, sz), 0.012, seg=5) if False else None
            chain(S["donker"], (sx, -0.16, sz), (sx, -0.62, sz), link=0.07)
            bx(S["donker"], (sx, -0.66, sz), (0.1, 0.07, 0.1), bevel=False)
    objs += commit_set(S, None, haak, "Haak", nocull=True)
    # de kist aan de haak
    kv = empty("Kist_vast", haak, (0, 0, 0))
    kv["nocull"] = True
    gs, gm, gy, gk2 = G(), G(), G(), bmesh.new()
    crate(gs, gm, gy, gk2, (0, -0.66 - 0.04 - CB[1] / 2, 0), stencil="batch", size=CB)
    for suf, g, mat, tile in (("Kist_vast_romp", gs, "olijf", 1.0), ("Kist_vast_beslag", gm, "staal", 0.5), ("Kist_vast_band", gy, "geel", 0.5)):
        o = commit(suf, g, M[mat], kv, tile=tile, bevel=(suf == "Kist_vast_romp" and D >= 1))
        if o:
            o["nocull"] = True
            objs.append(o)
    if gk2.faces:
        o = F.new_obj("Kist_vast_stencil", gk2, M["stencil"], smooth=False, parent=kv)
        o["nocull"] = True
        objs.append(o)
    else:
        gk2.free()
    return dict(brug=brug, kat=kat, ketting=ketting, haak=haak, kist_vast=kv), objs


def build_kisten(root):
    """Kist_perron (de kist die de truck neerzet, op de laadplaat) en Kist_opslag (hetzelfde, bovenop de opslagstapel): de clip schakelt ze met schaal."""
    objs = []
    out = {}
    px, pz = PAD
    sx_, sz_ = STK
    for name, c in (("Kist_perron", (px, SL + 0.032 + CB[1] / 2, pz)), ("Kist_opslag", (sx_, SL + 0.24 + CB[1] * 2.5, sz_))):
        pv = empty(name, root, (0, 0, 0))
        pv["nocull"] = True
        gs, gm, gy, gk = G(), G(), G(), bmesh.new()
        crate(gs, gm, gy, gk, c, yaw=0.03, stencil="batch" if name == "Kist_perron" else "swl", size=CB)
        for suf, g, mat, tile in ((f"{name}_romp", gs, "olijf", 1.0), (f"{name}_beslag", gm, "staal", 0.5), (f"{name}_band", gy, "geel", 0.5)):
            o = commit(suf, g, M[mat], pv, tile=tile, bevel=(suf.endswith("romp") and D >= 1))
            if o:
                o["nocull"] = True
                objs.append(o)
        if gk.faces:
            o = F.new_obj(f"{name}_stencil", gk, M["stencil"], smooth=False, parent=pv)
            o["nocull"] = True
            objs.append(o)
        else:
            gk.free()
        out[name] = pv
    return out, objs


# ------------------------------------------------------------------ lampen
def build_lights(root):
    S = gset()
    # lampen boven de poort en aan de gevelhoeken: kooi, glas (gloeit 's nachts) en een arm
    for x in (-2.6, 2.6):
        bx(S["donker"], (x, SL + 3.2, SZ1 + 0.1), (0.1, 0.1, 0.16))
        bx(S["staal"], (x, SL + 3.2, SZ1 + 0.24), (0.34, 0.14, 0.16))
        bx(S["witlamp"], (x, SL + 3.2, SZ1 + 0.325), (0.28, 0.1, 0.02), bevel=False)
    # lichtmasten op het perron
    for sx in (-1, 1):
        cyl(S["staal"], (sx * 4.35, SL, 2.55), (sx * 4.35, SL + 4.4, 2.55), 0.055, seg=8, r2=0.04)
        bx(S["donker"], (sx * 4.35, SL + 4.45, 2.55), (0.12, 0.12, 0.12))
        bx(S["staal"], (sx * 4.05, SL + 4.52, 2.55), (0.62, 0.06, 0.1))
        bx(S["witlamp"], (sx * 3.95, SL + 4.47, 2.55), (0.42, 0.03, 0.2), bevel=False)
        bx(S["gevaar"], (sx * 4.35, SL + 0.5, 2.55 + 0.0), (0.12, 0.7, 0.12), bevel=False) if False else None
    # waarschuwingslamp op de lantaarn van de kraan komt bij de brug (amber)
    return commit_set(S, None, root, "Lampen")


# ------------------------------------------------------------------ animatie
def set_interp(kind):
    (smooth_interp if kind == "bezier" else linear)()


def animate(door, door_bar, crane, kist):
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    smooth_interp()
    E = 0.001
    brug, kat, ketting, haak = crane["brug"], crane["kat"], crane["ketting"], crane["haak"]
    kv, kp, ko = crane["kist_vast"], kist["Kist_perron"], kist["Kist_opslag"]
    all_o = (door, door_bar, brug, kat, ketting, haak, kv, kp, ko)
    for o in all_o:
        o.rotation_mode = "XYZ"

    def clip(name, objs):
        for o in objs:
            ad = o.animation_data
            if ad is None or ad.action is None:
                continue
            ad.action.name = f"{name}_{o.name}"
            tr = ad.nla_tracks.new()
            tr.name = name
            st_ = tr.strips.new(name, 0, ad.action)
            st_.name = name
            ad.action = None

    # --- Poort: de lamellen rollen omhoog (schaal), de onderbalk schuift mee naar boven
    top = SL + DOOR_H
    zlock = SZ1 - WT - 0.03
    sc.frame_end = FRAMES_P
    door.scale = (1, 1, 1)
    keys(door, "scale", [(0, (1, 1, 1)), (60, (1, 1, 0.045))])
    keys(door_bar, "location", [(0, P(0, SL + 0.07, zlock)), (60, P(0, top - 0.14, zlock))])
    clip("Poort", (door, door_bar))
    # --- Kraan-lossen
    sc.frame_end = FRAMES_K
    zr, xr = STK[1], STK[0]      # rust: boven het opslagpallet
    zp, xp = PAD[1], PAD[0]
    z0 = 1.2                     # de rustpositie van de brug (zie build_portal)
    kat_y = GIRDER_Y - 0.36
    # kettinglengte: de haak hangt op afstand L onder de loopkat (kettingpunt); de kist hangt 0,7 onder de haak
    hang = kat_y - 0.36
    HK = 0.66 + 0.04 + CB[1]                 # de onderkant van de kist hangt zoveel onder de haak
    L_pad = hang - (SL + 0.032 + HK)         # haak zakt tot de kist op de laadplaat staat
    L_stk = hang - (SL + 0.24 + CB[1] * 2 + HK)   # en tot de kist op de twee kisten van het opslagpallet staat
    L_rest = 0.5                             # opgehesen (reizen met een kist: onderkant kist boven de stapel)
    Eps = E
    seq = dict(
        bz=[(0, z0), (30, zp), (68, zp), (98, z0), (135, z0)],
        kx=[(0, xr), (30, xp), (68, xp), (98, xr), (135, xr)],
        L=[(0, L_rest), (30, L_rest), (46, L_pad), (54, L_pad), (68, L_rest), (98, L_rest), (112, L_stk), (118, L_stk), (130, L_rest), (135, L_rest)],
        held=[(0, Eps), (50, Eps), (51, 1.0), (115, 1.0), (116, Eps), (135, Eps)],
        perron=[(0, 1.0), (50, 1.0), (51, Eps), (135, Eps)],
        opslag=[(0, Eps), (115, Eps), (116, 1.0), (135, 1.0)],
    )

    def val(s, f):
        for (f0, v0), (f1, v1) in zip(s, s[1:]):
            if f0 <= f <= f1:
                return v0 if f1 == f0 else v0 + (v1 - v0) * (f - f0) / (f1 - f0)
        return s[-1][1]

    frames = sorted({f for s in seq.values() for f, _ in s})
    for f in frames:
        brug.location = P(0, 0, val(seq["bz"], f))
        brug.keyframe_insert("location", frame=f)
        kat.location = P(val(seq["kx"], f), kat_y, 0)
        kat.keyframe_insert("location", frame=f)
        L = val(seq["L"], f)
        ketting.scale = (1, 1, max(0.05, L))
        ketting.keyframe_insert("scale", frame=f)
        haak.location = P(val(seq["kx"], f) * 0, -0.36 - L, 0) if False else P(0, -0.36 - L, 0)
        haak.keyframe_insert("location", frame=f)
        s = val(seq["held"], f)
        kv.scale = (s, s, s)
        kv.keyframe_insert("scale", frame=f)
        s = val(seq["perron"], f)
        kp.scale = (s, s, s)
        kp.keyframe_insert("scale", frame=f)
        s = val(seq["opslag"], f)
        ko.scale = (s, s, s)
        ko.keyframe_insert("scale", frame=f)
    clip("Kraan-lossen", (brug, kat, ketting, haak, kv, kp, ko))
    # rustpose (beginpose van de clips): poort dicht, kraan boven het opslagpallet, geen losse kisten zichtbaar
    sc.frame_set(0)
    door.scale = (1, 1, 1)
    door_bar.location = P(0, SL + 0.07, zlock)
    brug.location = P(0, 0, z0)
    kat.location = P(xr, kat_y, 0)
    ketting.scale = (1, 1, L_rest)
    haak.location = P(0, -0.36 - L_rest, 0)
    for o in (kv, kp, ko):
        o.scale = (E, E, E)


# ------------------------------------------------------------------ hoofdprogramma
def main():
    global M
    sc = fresh_scene()
    M = materials()
    root = bpy.data.objects.new("Voorraaddepot", None)
    sc.collection.objects.link(root)
    perron = empty("Perron", root)
    schuur = empty("Schuur", root)
    binnen = empty("Binnen", schuur)
    portaal = empty("Portaalkraan_rails", root)
    kisten = empty("Kisten", root)
    lampen = empty("Lampen", root)
    build_perron(perron)
    build_shed(schuur, binnen)
    pv, pb, _ = build_door(schuur)
    crane, cobjs = build_portal(portaal)
    kist, kobjs = build_kisten(kisten)
    build_lights(lampen)
    print(f"[{LEVEL}] driehoeken (voor snoeien): {tri_count()}")
    if os.environ.get("VR_STATS"):
        dg = bpy.context.evaluated_depsgraph_get()
        rows = sorted(((sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).to_mesh().polygons), o.name) for o in bpy.data.objects if o.type == "MESH"), reverse=True)
        for n, name in rows[:30]:
            print(f"   {n:6d}  {name}")
        return
    if not LOD:
        animate(pv, pb, crane, kist)
    if LEVEL != "hq":
        bake_groups([("depot", bakeable())])
    print(f"[{LEVEL}] driehoeken: {tri_count()}  materialen: {len(bpy.data.materials)}")
    stem = {"hq": "Voorraaddepot_HQ", "game": "voorraaddepot", "lod1": "voorraaddepot_lod1"}[LEVEL]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    if LEVEL == "hq":
        print("HQ-bron opgeslagen:", OUT / f"{stem}.blend")
        return
    export_glb(ROOT / "assets" / f"{stem}.glb")
    if LEVEL == "game":
        export_usdz(OUT / "Voorraaddepot.usdz")


if __name__ == "__main__":
    main()
