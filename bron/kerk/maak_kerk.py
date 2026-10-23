"""Oude kerk met toren voor de stad achter de brug (Bloedjungle): een verweerd koloniaal kerkje met een schip van
9,5 x 14 m onder een zadeldak van oude pannen, en een vierkante toren van 5 x 5 m aan de voorkant met vier lagen:
ingang, uurwerkkamer, klokkenkamer met galmgaten en bovenop een plat torendak met kantelen (uitkijkpost).
Steile trappen brengen je helemaal naar boven. Oud: vergeelde witkalk met zwarte schimmelstrepen, mos, scheuren en
plekken waar de kalk eraf is en de natuursteen eronder zit; kapotte glas-in-loodramen.
Alles kan kapot: elke muur bestaat uit losse stukken met een hele en een kapotte versie (M* toren, S* schip, P0
torenboog), de torenvloeren en het dak hebben een kapotte versie, en de toren en het schip storten elk apart in tot
een ruïne ('RuineToren', 'RuineSchip').
Blender: voorkant aan -Y (wordt +Z in Godot), Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van het geheel.
Gebruik: python3 maak_kerk.py <uitmap>  ->  kerk.glb, kerk.blend  (bouwfuncties gedeeld met maak_winkel.py)

Hiërarchie (namen die het spel gebruikt):
  Kerk
    Begane       Fundering
      TorenVoet  muurstukken M0* en P0 (boog naar het schip), TrapA, DeurVoorL/R, InrichtingToren0
      Schip      muurstukken S0*, DeurZij, InrichtingSchip, Licht0
    Toren1       Vloer1 (heel / kapot), muurstukken M1*, TrapB, Inrichting1 (uurwerk)
    Toren2       Vloer2, muurstukken M2*, TrapC, Inrichting2 (klok in de klokkenstoel)
    Toren3       Vloer3 (torendak met luik), borstwering M3* met kantelen en pinakels, Inrichting3 (zandzakken, vlag)
    Dak          Dak_heel / Dak_kapot (zadeldak met de twee topgevels)
    Puin         PuinGroot, PuinKlein, Brok0..3 (sjablonen voor sloop)
    Ruine        RuineToren, RuineSchip (verborgen tot de toren of het schip instort)
  Muurstuk X: leeg knooppunt met kinderen X_heel en X_kapot. Deuren: het knooppunt is het scharnier.
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector, Euler

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rng = np.random.default_rng(11)

# ---------- maten ----------
TT = 0.5                    # muurdikte toren
TS = 0.45                   # muurdikte schip
TX = 2.5                    # toren: x -2,5..2,5
TY0, TY1 = -9.5, -4.5       # toren: y -9,5..-4,5 (voorkant)
NX = 4.75                   # schip: x -4,75..4,75
NY0, NY1 = -4.5, 9.5        # schip: y -4,5..9,5
L0, L1, L2, L3 = 0.3, 3.9, 7.5, 11.1    # vloeren: ingang, uurwerk, klokkenkamer, torendak
LEVELS = (L0, L1, L2, L3)
TOPS = 6.3                  # bovenkant muren schip
NOK = 10.5                  # nok van het zadeldak
PAR_H = 1.2                 # borstwering op de toren
PT = 0.35                   # dikte borstwering
SLAB = 0.25
TI0, TI1 = -TX + TT, TX - TT            # binnenkant toren x
TYI0, TYI1 = TY0 + TT, TY1 - TT         # binnenkant toren y (-9..-5)
# trappen in de toren (Blender-y): A (0 -> 1) langs de westmuur naar achter, B (1 -> 2) langs de oostmuur naar voor,
# C (2 -> 3) weer langs de westmuur naar achter, door het luik op het torendak
ST_W = 1.05                 # breed genoeg voor de speler (straal 0,45)
A_X0, A_X1 = TI0, TI0 + ST_W
B_X0, B_X1 = TI1 - ST_W, TI1
HOLE1 = (A_X0, A_X1, -8.0, -6.0)
HOLE2 = (B_X0, B_X1, -8.0, -6.0)
HOLE3 = (A_X0, A_X1, -8.0, -6.0)
NSTEP = 14


# ---------- texturen ----------
def noise(size, scale, seed, sy=None):
    """Zachte waardenruis, naadloos herhalend; sy = andere schaal in de hoogte (strepen)."""
    sy = sy or scale
    nx, ny = size // scale, size // sy
    g = np.random.default_rng(seed).random((ny + 1, nx + 1))
    g[ny, :] = g[0, :]
    g[:, nx] = g[:, 0]
    y, x = np.mgrid[0:size, 0:size]
    x, y = x / scale, y / sy
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def sm(v, e0, e1):
    return np.clip((v - e0) / (e1 - e0), 0, 1)[..., None]


def save_img(name, img, size):
    """img[rij 0] = bovenkant van het plaatje (v = 1)."""
    im = bpy.data.images.new(name, size, size)
    rgba = np.concatenate([np.clip(img, 0, 1), np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, name + ".png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im



def mat(name, color, rough=0.85, metal=0.0, image=None, emit=None, strength=0.0, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    if emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha is not None:
        p.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m



def cracks(size, n, seed, length=180):
    """Masker met scheuren: grillige lijnen die vooral naar beneden lopen, soms vertakt."""
    r = np.random.default_rng(seed)
    m = np.zeros((size, size))
    for k in range(n):
        x, y = r.uniform(0, size), r.uniform(0, size)
        dx = r.uniform(-0.6, 0.6)
        for i in range(int(length * r.uniform(0.5, 1.2))):
            dx = np.clip(dx + r.uniform(-0.35, 0.35), -1.2, 1.2)
            x += dx
            y += 1.0
            xi, yi = int(x) % size, int(y) % size
            m[yi, xi] = 1.0
            m[yi, (xi + 1) % size] = max(m[yi, (xi + 1) % size], 0.5)
            if r.random() < 0.01:
                dx = -dx
    return m[..., None]


def blokken(size, cols, rows, seed, kleur, var=0.35, voeg_kleur=(0.5, 0.48, 0.42)):
    """Natuursteen in lagen: 'cols' blokken per rij met een verspringing, grillige randen."""
    y, x = np.mgrid[0:size, 0:size] / size
    rij = np.floor(y * rows).astype(int)
    r = np.random.default_rng(seed)
    off = r.random(rows + 1)
    xs = x * cols + off[rij % rows]
    kol = np.floor(xs).astype(int)
    fx, fy = xs - kol, y * rows - rij
    t = r.random((rows + 1, cols + 2))[rij % rows, kol % (cols + 1)]
    rand = 0.04 + 0.03 * noise(size, 8, seed + 1)
    voeg = (fx < rand) | (fy < rand * 1.4)
    img = np.array(kleur) * (1 - var / 2 + var * t[..., None]) * (0.85 + 0.25 * noise(size, 8, seed + 2)[..., None])
    img = np.where(voeg[..., None], np.array(voeg_kleur) * (0.8 + 0.2 * noise(size, 4, seed + 3)[..., None]), img)
    return img


def pleister_image(size=512):
    """Vergeelde witkalk, 3,2 m breed en 6,4 m hoog (v = 0 is de grond). Zwarte schimmelstrepen die van boven
    naar beneden lopen, groene aanslag en mos onderaan, scheuren, en plekken waar de kalk eraf is (natuursteen)."""
    v = (1 - np.mgrid[0:size, 0:size][0] / size)[..., None]
    img = np.array([0.82, 0.8, 0.71]) * (0.88 + 0.16 * noise(size, 64, 1)[..., None] + 0.06 * noise(size, 8, 2)[..., None])
    # grote grauwe vlekken
    a = sm(noise(size, 128, 5), 0.4, 0.85) * 0.4
    img = img * (1 - a) + np.array([0.5, 0.5, 0.42]) * a
    # schimmelstrepen vanaf de bovenkant (en een tweede rij halverwege, onder de lijsten): breed en zacht, niet overal
    streep = (noise(size, 16, 3, 256) * 0.65 + noise(size, 64, 14, 512) * 0.35)[..., None]
    lang = noise(size, 32, 4, 512)[..., None]
    for top, kracht in ((1.0, 0.5), (0.56, 0.3)):
        d = top - v
        s = np.clip((streep - 0.5) * 3.0, 0, 1) * np.clip(1 - d / (0.06 + 0.32 * lang), 0, 1) ** 1.5 * (d > 0)
        img = img * (1 - kracht * s) + np.array([0.16, 0.17, 0.13]) * kracht * s
    # opspattend vuil: de onderste meter is grauwer
    spat = np.clip(1 - v / 0.22, 0, 1) * 0.35
    img = img * (1 - spat) + np.array([0.42, 0.4, 0.32]) * spat
    # groene aanslag en mos onderaan, en mosplekken hoger op
    vuil = np.clip(1 - v / 0.14, 0, 1) * (0.6 + 0.4 * noise(size, 16, 6)[..., None])
    img = img * (1 - 0.7 * vuil) + np.array([0.22, 0.27, 0.13]) * 0.7 * vuil
    mos = sm(noise(size, 32, 7) * 0.7 + noise(size, 8, 8) * 0.3 - v[..., 0] * 0.6, 0.45, 0.62) * 0.65
    img = img * (1 - mos) + np.array([0.25, 0.33, 0.12]) * mos
    # kalk eraf: natuursteen eronder
    gat = noise(size, 64, 9) * 0.7 + noise(size, 8, 10) * 0.3
    rand = sm(gat, 0.64, 0.66) * 0.5
    img = img * (1 - rand) + np.array([0.48, 0.45, 0.38]) * rand
    steen = sm(gat, 0.665, 0.675)
    img = img * (1 - steen) + blokken(size, 8, 26, 12, (0.5, 0.46, 0.38)) * steen
    # scheuren
    c = cracks(size, 9, 13) * 0.75
    img = img * (1 - c) + np.array([0.12, 0.11, 0.1]) * c
    return save_img("kerk_pleister", img, size)


def binnen_image(size=512):
    """Binnenkalk, 3,2 x 6,4 m: optrekkend vocht onderin (groen-grijs met een bruine rand), schimmelplekjes, vlekken."""
    v = (1 - np.mgrid[0:size, 0:size][0] / size)[..., None]
    img = np.array([0.8, 0.79, 0.71]) * (0.9 + 0.12 * noise(size, 32, 21)[..., None])
    rand = 0.13 + 0.05 * noise(size, 32, 22)[..., None]
    vocht = np.clip((rand - v) / 0.06, 0, 1)
    img = img * (1 - 0.45 * vocht) + np.array([0.42, 0.45, 0.36]) * 0.45 * vocht
    lijn = np.clip(1 - np.abs(v - rand) / 0.01, 0, 1) * 0.5
    img = img * (1 - lijn) + np.array([0.45, 0.36, 0.24]) * lijn
    vlek = sm(noise(size, 16, 23) * 0.6 + noise(size, 64, 24) * 0.4, 0.62, 0.78) * 0.3
    img = img * (1 - vlek) + np.array([0.35, 0.36, 0.3]) * vlek
    streep = noise(size, 8, 25, 128)[..., None]
    s = np.clip((streep - 0.55) * 2, 0, 1) * np.clip((v - 0.6) / 0.4, 0, 1) * 0.35
    img = img * (1 - s) + np.array([0.4, 0.38, 0.32]) * s
    c = cracks(size, 4, 26) * 0.5
    img = img * (1 - c) + np.array([0.3, 0.28, 0.25]) * c
    return save_img("kerk_binnen", img, size)


def steen_image(size=512):
    """Natuursteen (breukvlakken en ruïne), 1,6 x 1,6 m: grijsbruine blokken, mos in de voegen."""
    img = blokken(size, 4, 6, 31, (0.52, 0.48, 0.4), 0.45)
    mos = sm(noise(size, 32, 32) * 0.6 + noise(size, 8, 33) * 0.4, 0.6, 0.72) * 0.5
    img = img * (1 - mos) + np.array([0.24, 0.3, 0.13]) * mos
    return save_img("kerk_steen", img, size)


def tegels_image(size=512):
    """Kerkvloer: grote plavuizen van 60 cm, zwart en wit geblokt, gesleten, gebarsten, vuil."""
    y, x = np.mgrid[0:size, 0:size] / size
    tx, ty = np.floor(x * 2).astype(int), np.floor(y * 2).astype(int)
    fx, fy = x * 2 - tx, y * 2 - ty
    licht = np.array([0.78, 0.75, 0.66])
    donker = np.array([0.24, 0.24, 0.23])
    img = np.where(((tx + ty) % 2 == 0)[..., None], licht, donker) * (0.85 + 0.2 * noise(size, 32, 41)[..., None])
    voeg = (fx < 0.012) | (fy < 0.012)
    img = np.where(voeg[..., None], np.array([0.32, 0.3, 0.26]), img)
    vuil = sm(noise(size, 64, 42), 0.45, 0.85) * 0.5
    img = img * (1 - vuil) + np.array([0.3, 0.27, 0.2]) * vuil
    c = cracks(size, 5, 43, 120) * 0.7
    img = img * (1 - c) + np.array([0.1, 0.1, 0.09]) * c
    return save_img("kerk_tegels", img, size)


def dakpan_image(size=1024):
    """Oude holle pannen, 4,8 x 4,8 m: 24 pannen breed en 16 rijen (v naar de nok). Verkleurd, veel mos en zwarte
    aanslag in grote vlekken, hier en daar een gebroken of ontbrekende pan (donkere latten)."""
    y, x = np.mgrid[0:size, 0:size] / size
    v = 1 - y
    rij = np.floor(v * 16).astype(int)
    fv = v * 16 - rij
    xs = x * 24 + (rij % 2) * 0.5
    kol = np.floor(xs).astype(int)
    fx = xs - kol
    r = np.random.default_rng(51).random((17, 26, 2))
    t = r[rij % 16, kol % 24, 0]
    kleur = np.array([0.5, 0.27, 0.17]) * (0.7 + 0.4 * t[..., None])
    img = kleur * (0.62 + 0.5 * np.sin(fx * math.pi))[..., None] * (0.55 + 0.45 * np.clip(fv / 0.25, 0, 1))[..., None]
    img = np.where((fx < 0.04)[..., None], img * 0.45, img)
    mos = sm(noise(size, 64, 52) * 0.6 + noise(size, 16, 53) * 0.4, 0.5, 0.64) * 0.8
    img = img * (1 - mos) + np.array([0.21, 0.26, 0.11]) * mos
    zwart = sm(noise(size, 128, 54) * 0.7 + noise(size, 32, 55) * 0.3, 0.42, 0.8) * 0.55
    img = img * (1 - zwart) + np.array([0.13, 0.11, 0.09]) * zwart
    weg = (r[rij % 16, kol % 24, 1] > 0.965)[..., None]   # ontbrekende pan: donkere latten
    img = np.where(weg, np.array([0.09, 0.06, 0.05]), img)
    return save_img("kerk_dakpan", img, size)


def planken_image(size=512):
    """Oude donkere vloerplanken (toren): 8 planken van 15 cm per 1,2 m, met naden en stof."""
    y, x = np.mgrid[0:size, 0:size] / size
    rij = np.floor(y * 8).astype(int)
    fy = y * 8 - rij
    r = np.random.default_rng(61).random((9, 4))
    naad_x = (x + r[rij % 8, 0]) % 1.0
    t = r[rij % 8, 1]
    nerf = noise(size, 64, 62, 4)[..., None]
    kleur = np.array([0.4, 0.28, 0.18]) * (0.65 + 0.35 * t[..., None]) * (0.85 + 0.3 * nerf)
    img = np.where(((fy < 0.05) | (naad_x < 0.006))[..., None], np.array([0.1, 0.07, 0.05]), kleur)
    stof = sm(noise(size, 32, 63), 0.5, 0.9) * 0.35
    img = img * (1 - stof) + np.array([0.55, 0.52, 0.45]) * stof
    return save_img("kerk_planken", img, size)


def glaslood_image(size=256):
    """Glas-in-lood: ruitjes in een loden net, diep blauw, rood, amber en groen, vuil en dof."""
    y, x = np.mgrid[0:size, 0:size] / size
    a, b = (x + y) * 4, (x - y) * 4
    ia, ib = np.floor(a).astype(int), np.floor(b).astype(int)
    fa, fb = a - ia, b - ib
    pal = np.array([[0.12, 0.2, 0.5], [0.55, 0.1, 0.1], [0.7, 0.5, 0.15], [0.15, 0.35, 0.18], [0.5, 0.55, 0.6]])
    r = np.random.default_rng(71).integers(0, 5, (20, 20))
    img = pal[r[ia % 20, ib % 20]] * (0.75 + 0.3 * noise(size, 16, 72)[..., None])
    lood = (fa < 0.06) | (fb < 0.06)
    img = np.where(lood[..., None], np.array([0.08, 0.08, 0.08]), img)
    vuil = sm(noise(size, 32, 73), 0.4, 0.9) * 0.4
    img = img * (1 - vuil) + np.array([0.12, 0.12, 0.1]) * vuil
    return save_img("kerk_glaslood", img, size)


def vlag_image(size=128):
    """Verschoten rode vlag met een witte baan, vuil."""
    v = (1 - np.mgrid[0:size, 0:size][0] / size)[..., None]
    img = np.where(v > 0.5, np.array([0.55, 0.12, 0.1]), np.array([0.82, 0.8, 0.74]))
    img = img * (0.8 + 0.25 * noise(size, 16, 81)[..., None])
    return save_img("kerk_vlag", img, size)


PLEISTER = mat("Pleister", (0.82, 0.8, 0.71), 0.95, image=pleister_image())
BINNEN = mat("Binnen", (0.8, 0.79, 0.71), 0.9, image=binnen_image())
STEEN = mat("Steen", (0.52, 0.48, 0.4), 0.95, image=steen_image())
BAKSTEEN = STEEN            # de gedeelde bouwfuncties snijden met 'BAKSTEEN': bij de kerk is dat natuursteen
TEGELS = mat("Tegels", (0.6, 0.58, 0.52), 0.55, image=tegels_image())
DAKPAN = mat("Dakpan", (0.56, 0.28, 0.17), 0.85, image=dakpan_image())
PLANKEN = mat("Planken", (0.4, 0.28, 0.18), 0.8, image=planken_image())
GLASLOOD = mat("GlasLood", (0.4, 0.3, 0.3), 0.15, 0.1, image=glaslood_image(), emit=(0.5, 0.4, 0.35), strength=0.25)
VLAG = mat("Vlag", (0.6, 0.2, 0.15), 0.95, image=vlag_image())
RAND = mat("Rand", (0.66, 0.63, 0.55), 0.9)          # natuurstenen randen om ramen en deuren, lijsten
HARDSTEEN = mat("Beton", (0.5, 0.49, 0.45), 0.95)    # stoepen, treden, altaar (zelfde naam als bij de andere huizen)
HOUT = mat("Hout", (0.3, 0.2, 0.12), 0.85)
HOUTLICHT = mat("HoutLicht", (0.48, 0.34, 0.2), 0.8)
IJZER = mat("IJzer", (0.12, 0.11, 0.1), 0.6, 0.7)
ROEST = mat("Roest", (0.38, 0.22, 0.13), 0.85, 0.4)
BRONS = mat("Brons", (0.3, 0.37, 0.31), 0.55, 0.7)   # klok met groene patina
GOUD = mat("Goud", (0.75, 0.6, 0.3), 0.4, 0.9)
LOOD = mat("Lood", (0.36, 0.37, 0.38), 0.7, 0.3)
WIJZERPLAAT = mat("Wijzerplaat", (0.84, 0.82, 0.74), 0.7)
STOF = mat("Stof", (0.5, 0.12, 0.1), 0.95)
STOF3 = mat("Stof3", (0.68, 0.6, 0.44), 0.95)
KAARS = mat("Kaars", (0.9, 0.87, 0.76), 0.6, emit=(1.0, 0.8, 0.5), strength=0.3)
DONKER = mat("Donker", (0.05, 0.05, 0.05), 0.8)
BLAD = mat("Blad", (0.24, 0.4, 0.14), 0.7)
LAMPGLAS = mat("LampGlas", (1.0, 0.85, 0.55), 0.3, emit=(1.0, 0.8, 0.45), strength=4.0)
BETON = HARDSTEEN

# per materiaal: schaal (u, v) van de wereld-UV in meters per herhaling
UVS = {"Pleister": (3.2, 6.4), "Binnen": (3.2, 6.4), "Steen": (1.6, 1.6), "Tegels": (1.2, 1.2), "Planken": (1.2, 1.2),
       "GlasLood": (1.0, 1.0), "Dakpan": (4.8, 4.8), "Vlag": (1.4, 0.9)}


# ---------- hulpfuncties ----------
def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def empty(name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    e = link(bpy.data.objects.new(name, None), parent)
    e.location = loc
    e.rotation_euler = rot
    return e


def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if material:
        me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = loc
    return link(o, parent)


def box(name, size, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    o = mesh_obj(name, bm, material, parent, loc)
    o.rotation_euler = rot
    return o


def cyl(name, r1, r2, depth, material, axis="Z", segs=10, parent=None, loc=(0, 0, 0), smooth=True, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    o = mesh_obj(name, bm, material, parent, loc, smooth)
    o.rotation_euler = rot
    return o


def join(target, parts):
    parts = [p for p in parts if p is not target]
    if not parts:
        return target
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def bake(obj):
    """Modifiers toepassen zonder operator-context."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    me.name = obj.name
    bpy.data.meshes.remove(old)
    return obj


def cut(obj, cutters):
    """Boolean-verschil; de snijvlakken krijgen het materiaal van de snijder (baksteen)."""
    bpy.context.view_layer.update()
    for c in cutters:
        if c.name not in scene.collection.objects:
            scene.collection.objects.link(c)
        c.matrix_world = obj.matrix_world.copy()   # snijders zijn in lokale coördinaten van obj gegeven
        m = obj.modifiers.new("cut", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.solver = "EXACT"
        m.object = c
        m.material_mode = "TRANSFER"
    bake(obj)
    for c in cutters:
        bpy.data.objects.remove(c, do_unlink=True)
    return obj


def cutter_box(size, loc, material=BAKSTEEN, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, verts=bm.verts, vec=loc)
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    return bpy.data.objects.new("cutter", me)


def cutter_jagged(center, radius, axis, depth, seed, nverts=11, material=BAKSTEEN, squash=1.0):
    """Grillige veelhoek (breukrand) als prisma langs 'axis' ('Y' door een muur, 'Z' door een vloer of dak)."""
    r = np.random.default_rng(seed)
    bm = bmesh.new()
    pts = []
    for i in range(nverts):
        a = i / nverts * math.tau + r.uniform(-0.2, 0.2)
        rr = radius * r.uniform(0.5, 1.0)
        pts.append((math.cos(a) * rr, math.sin(a) * rr * squash))
    bot, top = [], []
    for (a, b) in pts:
        if axis == "Y":
            bot.append(bm.verts.new((center[0] + a, center[1] - depth / 2, center[2] + b)))
            top.append(bm.verts.new((center[0] + a, center[1] + depth / 2, center[2] + b)))
        else:
            bot.append(bm.verts.new((center[0] + a, center[1] + b, center[2] - depth / 2)))
            top.append(bm.verts.new((center[0] + a, center[1] + b, center[2] + depth / 2)))
    bm.faces.new(bot)
    bm.faces.new(list(reversed(top)))
    for i in range(nverts):
        j = (i + 1) % nverts
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    return bpy.data.objects.new("cutter", me)


def drop_floating(obj, zmin=0.05):
    """Verwijder losse brokken die nergens op steunen (onderkant hoger dan zmin, lokaal)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen = set()
    kill = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, island = [v], []
        seen.add(v.index)
        while stack:
            a = stack.pop()
            island.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in seen:
                    seen.add(b.index)
                    stack.append(b)
        if min(x.co.z for x in island) > zmin:
            kill += island
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def world_uv(o):
    """UV uit wereldcoördinaten (per vlak de dominante as), geschaald per materiaal; muren: u langs de muur, v = hoogte."""
    me = o.data
    mw = o.matrix_world
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvl = me.uv_layers[0]
    rot = mw.to_3x3()
    for poly in me.polygons:
        mi = min(poly.material_index, len(me.materials) - 1)
        mname = me.materials[mi].name if me.materials else ""
        if mname == "Dakpan":
            continue
        su, sv = UVS.get(mname, (1.6, 1.6))
        n = rot @ poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            c = mw @ me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uv = (c.y * (1 if n.x > 0 else -1), c.z)
            elif ax == 1:
                uv = (c.x * (-1 if n.y > 0 else 1), c.z)
            else:
                uv = (c.x, c.y)
            if mname == "Binnen" and ax != 2:
                uv = (uv[0], (c.z - max([l for l in LEVELS if c.z > l - 0.01] or [F0])) if c.z > 0 else c.z)
            uvl.data[li].uv = (uv[0] / su, uv[1] / sv)


def set_materials(o, mats):
    o.data.materials.clear()
    for m in mats:
        o.data.materials.append(m)




def world_uv(o):
    """UV uit wereldcoördinaten (per vlak de dominante as), geschaald per materiaal; muren: u langs de muur, v = hoogte.
    Binnenkalk in de toren telt per verdieping vanaf de vloer, in het schip vanaf de kerkvloer (vochtrand onderin)."""
    me = o.data
    mw = o.matrix_world
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvl = me.uv_layers[0]
    rot = mw.to_3x3()
    for poly in me.polygons:
        mi = min(poly.material_index, len(me.materials) - 1)
        mname = me.materials[mi].name if me.materials else ""
        if mname in ("Dakpan", "Vlag") and o.get("eigen_uv"):
            continue
        su, sv = UVS.get(mname, (1.6, 1.6))
        n = rot @ poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        cc = mw @ poly.center
        for li in poly.loop_indices:
            c = mw @ me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uv = (c.y * (1 if n.x > 0 else -1), c.z)
            elif ax == 1:
                uv = (c.x * (-1 if n.y > 0 else 1), c.z)
            else:
                uv = (c.x, c.y)
            if mname == "Binnen" and ax != 2:
                toren = cc.y < TY1 - 0.05 and abs(cc.x) < TX + 0.05
                base = max([l for l in LEVELS if cc.z > l - 0.01] or [L0]) if toren else L0
                uv = (uv[0], c.z - base)
            uvl.data[li].uv = (uv[0] / su, uv[1] / sv)


def cutter_jagged(center, radius, axis, depth, seed, nverts=11, material=STEEN, squash=1.0):
    """Grillige veelhoek (breukrand) als prisma langs 'axis' ('Y' of 'X' door een muur, 'Z' door een vloer of dak)."""
    r = np.random.default_rng(seed)
    bm = bmesh.new()
    pts = []
    for i in range(nverts):
        a = i / nverts * math.tau + r.uniform(-0.2, 0.2)
        rr = radius * r.uniform(0.5, 1.0)
        pts.append((math.cos(a) * rr, math.sin(a) * rr * squash))
    bot, top = [], []
    cx, cy, cz = center
    for (a, b) in pts:
        if axis == "Y":
            bot.append(bm.verts.new((cx + a, cy - depth / 2, cz + b)))
            top.append(bm.verts.new((cx + a, cy + depth / 2, cz + b)))
        elif axis == "X":
            bot.append(bm.verts.new((cx - depth / 2, cy + a, cz + b)))
            top.append(bm.verts.new((cx + depth / 2, cy + a, cz + b)))
        else:
            bot.append(bm.verts.new((cx + a, cy + b, cz - depth / 2)))
            top.append(bm.verts.new((cx + a, cy + b, cz + depth / 2)))
    bm.faces.new(bot)
    bm.faces.new(list(reversed(top)))
    for i in range(nverts):
        j = (i + 1) % nverts
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    return bpy.data.objects.new("cutter", me)


def prism_bm(pts, depth, y0=0.0):
    """Prisma uit een veelhoek in het x-z-vlak (tegen de klok in), dikte 'depth' langs y rond y0."""
    bm = bmesh.new()
    a = [bm.verts.new((x, y0 - depth / 2, z)) for (x, z) in pts]
    b = [bm.verts.new((x, y0 + depth / 2, z)) for (x, z) in pts]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prism(name, pts, depth, material, parent=None, y0=0.0):
    return mesh_obj(name, prism_bm(pts, depth, y0), material, parent)


def cutter_prism(pts, depth, material=STEEN, y0=0.0):
    me = bpy.data.meshes.new("cutter")
    bm = prism_bm(pts, depth, y0)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    return bpy.data.objects.new("cutter", me)


def spits_pts(cx, w, zb, h, n=7):
    """Spitsboog: rechte zijkanten en een spitse top uit twee cirkelbogen (straal 0,8 x de breedte)."""
    R = w * 0.8
    c = w / 2 - R
    th = math.acos(-c / R)
    zs = max(zb + 0.05, zb + h - R * math.sin(th))
    pts = [(cx - w / 2, zb), (cx + w / 2, zb)]
    for i in range(n + 1):
        a = th * i / n
        pts.append((cx + c + R * math.cos(a), zs + R * math.sin(a)))
    for i in range(n - 1, -1, -1):
        a = th * i / n
        pts.append((cx - c - R * math.cos(a), zs + R * math.sin(a)))
    return pts


def rond_pts(cx, cz, r, n=18):
    return [(cx + r * math.cos(i / n * math.tau), cz + r * math.sin(i / n * math.tau)) for i in range(n)]


def opening_pts(cx, w, zb, h, kind, H):
    if kind == "roos":
        return rond_pts(cx, zb + h / 2, w / 2)
    if kind == "kanteel":
        return [(cx - w / 2, zb), (cx + w / 2, zb), (cx + w / 2, H + 1.0), (cx - w / 2, H + 1.0)]
    return spits_pts(cx, w, zb, h)


def ring(name, outer_pts, inner_pts, depth, material, parent, y0):
    """Rand om een opening: buitenvorm min binnenvorm."""
    o = prism(name, outer_pts, depth, material, parent, y0)
    cut(o, [cutter_prism(inner_pts, depth + 0.2, material, y0)])
    return o


# ---------- muurstukken ----------
def wall_segment(name, parent, center, angle, L, H, z0, openings, inner=BINNEN, outer=PLEISTER, ends=(True, True),
                 thick=TS, seed=0, extra=None, band=None, cornice=False, plint=False, broken=0.35):
    """Een stuk muur met een hele en een kapotte versie.
    Lokaal: x langs de muur (-L/2..L/2), -y = buitenkant, z = 0..H. openings: lijst (cx, breedte, onder, hoogte, soort)
    met soort 'spits' (glas-in-lood), 'boog' (open spitsboog), 'deur', 'sleuf' (smalle schietgleuf), 'roos' (rond
    raam) of 'kanteel' (uitsparing in de borstwering). extra(seg, kapot) geeft losse delen (steunberen, pinakels)
    voor beide versies."""
    seg = empty(name, parent, (center[0], center[1], z0), (0, 0, angle))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(L, thick, H), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, H / 2))
    heel = mesh_obj(name + "_heel", bm, None, seg)
    mats = [outer] + ([inner] if inner is not outer else []) + [STEEN]
    set_materials(heel, mats)
    i_out, i_in, i_steen = 0, mats.index(inner), len(mats) - 1
    cutters = [cutter_prism(opening_pts(cx, w, zb, h, k, H), thick + 0.4, outer) for (cx, w, zb, h, k) in openings]
    if cutters:
        cut(heel, cutters)
    for p in heel.data.polygons:
        n = p.normal
        c = p.center
        if n.y < -0.5:
            p.material_index = i_out
        elif n.y > 0.5:
            p.material_index = i_in
        elif abs(n.x) > 0.5 and abs(abs(c.x) - L / 2) < 0.01 and ends[0 if c.x < 0 else 1]:
            p.material_index = i_steen
        elif n.z > 0.5 and c.z > H - 0.01:
            p.material_index = i_steen if outer is PLEISTER and not cornice else i_out
        else:
            p.material_index = i_out
    # de kapotte versie: zelfde muur met een grillig gat (vaak door de bovenrand)
    kapot = heel.copy()
    kapot.data = heel.data.copy()
    kapot.name = kapot.data.name = name + "_kapot"
    link(kapot, seg)
    r = np.random.default_rng(1000 + seed)
    cx = r.uniform(-L * 0.22, L * 0.22)
    cz = r.uniform(H * 0.55, H * 1.0)
    rad = min(L * 0.55, r.uniform(0.75, 1.1) * (H / 2.9) ** 0.5 * 1.15)
    kc = [cutter_jagged((cx, 0, cz), rad, "Y", thick + 0.4, 2000 + seed, squash=1.25)]
    if r.random() < 0.7:
        kc.append(cutter_jagged((r.uniform(-L * 0.4, L * 0.4), 0, r.uniform(0.6, H * 0.6)), r.uniform(0.2, 0.38) * max(1.0, H / 4),
                                "Y", thick + 0.4, 3000 + seed, 8))
    cut(kapot, kc)
    drop_floating(kapot)
    # details van de hele muur: natuurstenen randen, glas-in-lood, lijsten
    det = []
    yo = -thick / 2
    for (cx, w, zb, h, kind) in openings:
        if kind in ("spits", "boog", "deur", "sleuf"):
            e = 0.16 if kind != "sleuf" else 0.1
            det.append(ring("rand", spits_pts(cx, w + 2 * e, zb - (0.06 if kind in ("spits", "sleuf") else 0.0), h + e),
                            spits_pts(cx, w, zb, h), 0.07, RAND, seg, yo - 0.02))
        if kind == "spits":
            gl = prism("glas", spits_pts(cx, w + 0.02, zb, h), 0.03, GLASLOOD, seg, 0.0)
            if r.random() < broken:   # kapotte ruit: gat in het glas
                cut(gl, [cutter_jagged((cx + r.uniform(-w / 4, w / 4), 0, zb + h * r.uniform(0.3, 0.7)), w * 0.45, "Y", 0.3,
                                       4000 + seed + int(cx * 10), 9, GLASLOOD)])
            det.append(gl)
            det.append(box("roede", (0.04, 0.05, h * 0.75), IJZER, seg, (cx, 0, zb + h * 0.375)))
            for f in (0.3, 0.55):
                det.append(box("roede", (w, 0.05, 0.035), IJZER, seg, (cx, 0, zb + h * f)))
            det.append(box("dorpel", (w + 0.3, 0.2, 0.08), RAND, seg, (cx, yo - 0.04, zb - 0.06)))
        elif kind == "boog" and zb > 0.1:
            det.append(box("dorpel", (w + 0.2, thick + 0.12, 0.1), RAND, seg, (cx, 0, zb - 0.03)))
        elif kind == "roos":
            rr = w / 2
            det.append(ring("rand", rond_pts(cx, zb + h / 2, rr + 0.16), rond_pts(cx, zb + h / 2, rr), 0.08, RAND, seg, yo - 0.02))
            det.append(prism("glas", rond_pts(cx, zb + h / 2, rr + 0.01), 0.03, GLASLOOD, seg, 0.0))
            for k in range(4):
                a = k / 4 * math.pi
                det.append(box("spaak", (w, 0.06, 0.06), RAND, seg, (cx, -0.02, zb + h / 2), (0, a, 0)))
            det.append(cyl("hart", 0.12, 0.12, 0.1, RAND, "Y", 10, seg, (cx, -0.02, zb + h / 2)))
    if band is not None:   # lijst (natuursteen) op hoogte 'band'
        det.append(box("lijst", (L, 0.1, 0.16), RAND, seg, (0, yo - 0.04, band)))
    if cornice:            # kroonlijst bovenaan
        det.append(box("kroon", (L, 0.18, 0.14), RAND, seg, (0, yo - 0.06, H - 0.12)))
        det.append(box("kroon", (L, 0.26, 0.08), RAND, seg, (0, yo - 0.09, H - 0.02)))
    if plint:              # natuurstenen plint, onderbroken bij deuren
        stukken = [(-L / 2, L / 2)]
        for (cx, w, zb, h, kind) in openings:
            if kind in ("deur", "boog") and zb < 0.05:
                stukken = [q for (a, b) in stukken for q in ((a, min(b, cx - w / 2 - 0.16)), (max(a, cx + w / 2 + 0.16), b))
                           if q[1] - q[0] > 0.02]
        for (a, b) in stukken:
            det.append(box("plint", (b - a, 0.06, 0.7), STEEN, seg, ((a + b) / 2, yo - 0.03, 0.05)))
    if extra:
        det += extra(seg, False)
        join(kapot, extra(seg, True))
    if det:
        join(heel, det)
    heel.name = name + "_heel"
    kapot.name = name + "_kapot"
    return seg


def add_to_heel(seg, objs):
    heel = [c for c in seg.children if c.name.endswith("_heel")][0]
    nm = heel.name
    join(heel, objs)
    heel.name = nm


def steunbeer(seg, x, H, kapot):
    """Steunbeer tegen de buitenkant (lokaal -y) van een muurstuk, op plek x; trapsgewijs smaller naar boven."""
    yo = -TS / 2
    d = []
    h1 = H * 0.55
    d.append(box("beer", (0.55, 0.8, h1), PLEISTER, seg, (x, yo - 0.4, h1 / 2 - 0.3)))
    d.append(box("beerkap", (0.6, 0.62, 0.12), RAND, seg, (x, yo - 0.42, h1 - 0.3), (0.55, 0, 0)))
    if not kapot:
        h2 = H * 0.3
        d.append(box("beer", (0.5, 0.5, h2), PLEISTER, seg, (x, yo - 0.25, h1 - 0.3 + h2 / 2)))
        d.append(box("beerkap", (0.56, 0.42, 0.1), RAND, seg, (x, yo - 0.28, h1 - 0.3 + h2), (0.6, 0, 0)))
    return d


# ---------- gebouw ----------
root = empty("Kerk")
beg = empty("Begane", root)
tvoet = empty("TorenVoet", beg)
schip = empty("Schip", beg)
t1 = empty("Toren1", root)
t2 = empty("Toren2", root)
t3 = empty("Toren3", root)
dak = empty("Dak", root)
puin = empty("Puin", root)
ruine = empty("Ruine", root)

# --- schip: zijmuren in vier stukken met spitsboogramen en steunberen, achtergevel met roosvenster, voorgevel naast de toren
HS = TOPS - L0
SIDE = [(-4.05, -0.775), (-0.775, 2.5), (2.5, 5.775), (5.775, 9.05)]
for i, (a, b) in enumerate(SIDE):
    mid, L = (a + b) / 2, b - a
    for side, x, ang in (("W", -NX + TS / 2, -math.pi / 2), ("O", NX - TS / 2, math.pi / 2)):
        if side == "O" and i == 3:
            ops = [(0.0, 1.2, 0.0, 2.8, "deur")]
        else:
            ops = [(0.0, 1.1, 1.5, 3.6, "spits")]
        # steunbeer aan het achtereinde (lokaal x = -L/2 aan de westkant, +L/2 aan de oostkant)
        bx = (-L / 2 + 0.3) if side == "W" else (L / 2 - 0.3)
        wall_segment(f"S0{side}{i}", schip, (x, mid), ang, L, HS, L0, ops, plint=True, band=HS - 0.1, seed=10 * i + ord(side),
                     extra=lambda seg, k, bx=bx: steunbeer(seg, bx, HS, k))
BACK = [(-NX, -1.583), (-1.583, 1.583), (1.583, NX)]
for i, (a, b) in enumerate(BACK):
    mid, L = (a + b) / 2, b - a
    ops = [(0.0, 1.9, 3.0, 1.9, "roos")] if i == 1 else [(0.0, 0.8, 1.9, 3.0, "spits")]
    wall_segment(f"S0A{i}", schip, (mid, NY1 - TS / 2), math.pi, L, HS, L0, ops, plint=True, band=HS - 0.1, seed=60 + i)
for i, (a, b) in enumerate([(-NX, -TX), (TX, NX)]):
    mid, L = (a + b) / 2, b - a
    wall_segment(f"S0V{i}", schip, (mid, NY0 + TS / 2), 0.0, L, HS, L0, [(0.0, 0.6, 2.6, 2.4, "spits")], plint=True,
                 band=HS - 0.1, seed=70 + i)

# --- toren: per laag vier muren (voor, west, oost, achter); de achtermuur van de ingang is de boog naar het schip (P0)
TH = L1 - L0


def torenlaag(k, z0, front, side, back, band=None, cornice=False):
    pre = f"M{k}"
    par = (tvoet, t1, t2)[k]
    wall_segment(pre + "V0", par, (0, TY0 + TT / 2), 0.0, 2 * TX, TH, z0, front, thick=TT, seed=100 + 10 * k,
                 band=band, cornice=cornice, plint=(k == 0))
    wall_segment(pre + "W0", par, (-TX + TT / 2, (TYI0 + TYI1) / 2), -math.pi / 2, TYI1 - TYI0, TH, z0, side, thick=TT,
                 seed=101 + 10 * k, band=band, cornice=cornice, plint=(k == 0))
    wall_segment(pre + "O0", par, (TX - TT / 2, (TYI0 + TYI1) / 2), math.pi / 2, TYI1 - TYI0, TH, z0, side, thick=TT,
                 seed=102 + 10 * k, band=band, cornice=cornice, plint=(k == 0))
    if back is not None:
        wall_segment(pre + "A0", par, (0, TY1 - TT / 2), math.pi, 2 * TX, TH, z0, back, thick=TT, seed=103 + 10 * k,
                     band=band, cornice=cornice, inner=BINNEN, outer=PLEISTER)


torenlaag(0, L0, [(0.0, 1.7, 0.0, 3.0, "deur")], [(0.0, 0.32, 1.2, 1.4, "sleuf")], None)
wall_segment("P0", tvoet, (0, TY1 - TT / 2), math.pi, 2 * TX, TH, L0, [(0.0, 2.0, 0.0, 3.3, "boog")], thick=TT, seed=99,
             inner=BINNEN, outer=BINNEN)
torenlaag(1, L1, [(0.0, 0.32, 0.4, 1.3, "sleuf")], [(0.0, 0.32, 1.0, 1.4, "sleuf")], [], band=0.0)
torenlaag(2, L2, [(0.0, 1.4, 0.95, 2.25, "boog")], [(0.0, 1.4, 0.95, 2.25, "boog")], [(0.0, 0.32, 1.4, 1.3, "sleuf")],
          band=0.0, cornice=True)


# borstwering met kantelen en pinakels op de hoeken
def pinakels(seg, L, kapot):
    d = []
    for sx in (-1, 1):
        if kapot and sx > 0:
            continue
        x = sx * (L / 2 - 0.2)
        d.append(box("pinvoet", (0.42, 0.42, 0.7), PLEISTER, seg, (x, 0.0, PAR_H + 0.35)))
        d.append(box("pinlijst", (0.5, 0.5, 0.08), RAND, seg, (x, 0.0, PAR_H + 0.72)))
        d.append(cyl("pinspits", 0.3, 0.0, 0.9, RAND, "Z", 4, seg, (x, 0.0, PAR_H + 1.2), smooth=False, rot=(0, 0, math.pi / 4)))
        d.append(cyl("pinbol", 0.07, 0.07, 0.14, RAND, "Z", 6, seg, (x, 0.0, PAR_H + 1.7)))
    return d


KANT_FV = [(x, 0.45, 0.62, 1.0, "kanteel") for x in (-1.65, -0.55, 0.55, 1.65)]
KANT_Z = [(x, 0.45, 0.62, 1.0, "kanteel") for x in (-1.1, 0.0, 1.1)]
SPL = 2 * (TX - PT)
wall_segment("M3V0", t3, (0, TY0 + PT / 2), 0.0, 2 * TX, PAR_H, L3, KANT_FV, thick=PT, seed=140, cornice=False,
             extra=lambda seg, k: pinakels(seg, 2 * TX, k))
wall_segment("M3A0", t3, (0, TY1 - PT / 2), math.pi, 2 * TX, PAR_H, L3, KANT_FV, thick=PT, seed=141,
             extra=lambda seg, k: pinakels(seg, 2 * TX, k))
wall_segment("M3W0", t3, (-TX + PT / 2, (TY0 + TY1) / 2), -math.pi / 2, (TY1 - TY0) - 2 * PT, PAR_H, L3, KANT_Z, thick=PT,
             seed=142)
wall_segment("M3O0", t3, (TX - PT / 2, (TY0 + TY1) / 2), math.pi / 2, (TY1 - TY0) - 2 * PT, PAR_H, L3, KANT_Z, thick=PT,
             seed=143)

# uurwerk op de voorgevel (laag 1), stilgestaan op twintig voor vijf
seg = bpy.data.objects["M1V0"]
uw = []
yo = -TT / 2 - 0.02
cz = 2.55
uw.append(cyl("wijzerplaat", 0.62, 0.62, 0.05, WIJZERPLAAT, "Y", 24, seg, (0, yo, cz)))
uw.append(ring("wijzerrand", rond_pts(0, cz, 0.72, 24), rond_pts(0, cz, 0.6, 24), 0.08, RAND, seg, yo))
for k in range(12):
    a = k / 12 * math.tau
    uw.append(box("streep", (0.04, 0.03, 0.12 if k % 3 else 0.18), IJZER, seg, (0.5 * math.sin(a), yo - 0.04, cz + 0.5 * math.cos(a)),
                  (0, -a, 0)))
for (lang, hoek) in ((0.42, 2 * math.pi * 40 / 60), (0.3, 2 * math.pi * (4.66 / 12))):
    uw.append(box("wijzer", (0.05, 0.03, lang), IJZER, seg, (lang / 2 * math.sin(hoek), yo - 0.06, cz + lang / 2 * math.cos(hoek)),
                  (0, -hoek, 0)))
add_to_heel(seg, uw)

# ---------- fundering, vloeren, stoepen ----------
fund = []
fund.append(box("Fund", (2 * NX - 0.02, NY1 - NY0 - 0.02, L0), HARDSTEEN, beg, (0, (NY0 + NY1) / 2, L0 / 2)))
fund.append(box("FundT", (2 * TX - 0.02, TY1 - TY0, L0), HARDSTEEN, beg, (0, (TY0 + TY1) / 2, L0 / 2)))
fund.append(box("Vloer0", (2 * NX - 2 * TS + 0.02, NY1 - NY0 - 2 * TS + 0.02, 0.02), TEGELS, beg, (0, (NY0 + NY1) / 2, L0 + 0.01)))
fund.append(box("Vloer0T", (TI1 - TI0, TYI1 - TYI0 + TT, 0.02), TEGELS, beg, (0, (TYI0 + TY1) / 2, L0 + 0.01)))
for k in range(3):   # bordes van drie treden voor de torendeur
    fund.append(box("trede", (3.2 - 0.3 * k, 0.9 - 0.3 * k, 0.1 * (k + 1)), HARDSTEEN, beg, (0, TY0 - (0.9 - 0.3 * k) / 2, 0.05 * (k + 1))))
fund.append(box("tredeZ", (0.6, 1.4, 0.3), HARDSTEEN, beg, (NX + 0.3, 7.41, 0.15)))   # stoep bij de zijdeur
# altaarverhoging
fund.append(box("Koor", (2 * NX - 2 * TS, 2.4, 0.16), HARDSTEEN, beg, (0, NY1 - TS - 1.2, L0 + 0.08)))
fund.append(box("KoorTegel", (2 * NX - 2 * TS - 0.1, 2.3, 0.02), TEGELS, beg, (0, NY1 - TS - 1.15, L0 + 0.17)))
fundering = join(fund[0], fund[1:])
fundering.name = "Fundering"


# ---------- trappen ----------
def steile_trap(name, parent, x0, x1, y0, y1, z0, z1, wang_x, ladder=False):
    """Steile houten torentrap van (y0, z0) naar (y1, z1): losse treden tussen twee bomen, leuning aan de open kant.
    ladder: smalle sporten, leuningen aan beide kanten (de laatste trap naar het luik)."""
    tr = []
    n = NSTEP
    rise = (z1 - z0) / n
    sd = (y1 - y0) / n
    L = math.hypot(y1 - y0, z1 - z0)
    pitch = math.atan2(z1 - z0, y1 - y0)
    for sx in ((x0 + 0.05), (x1 - 0.05)):
        tr.append(box("boom", (0.08, L, 0.26), HOUT, parent, (sx, (y0 + y1) / 2, (z0 + z1) / 2 + 0.05), (pitch, 0, 0)))
    for k in range(n):
        zt = z0 + rise * (k + 1)
        ya = y0 + (k + 0.5) * sd
        tr.append(box("trede", (x1 - x0 - 0.1, abs(sd) * (0.6 if ladder else 1.1), 0.05), HOUTLICHT, parent, ((x0 + x1) / 2, ya, zt - 0.025)))
    rails = (x0 + 0.05, x1 - 0.05) if ladder else (wang_x,)
    for rx in rails:
        tr.append(box("leuning", (0.06, L, 0.06), HOUT, parent, (rx, (y0 + y1) / 2, (z0 + z1) / 2 + 0.95), (pitch, 0, 0)))
        for k in range(1, n, 4):
            tr.append(box("spijl", (0.05, 0.05, 0.95), HOUT, parent, (rx, y0 + (k + 0.5) * sd, z0 + rise * (k + 1) + 0.475)))
    o = join(tr[0], tr[1:])
    o.name = name
    return o


steile_trap("TrapA", tvoet, A_X0, A_X1, TYI0, -6.0, L0, L1, A_X1 - 0.03)
steile_trap("TrapB", t1, B_X0, B_X1, TYI1, -8.0, L1, L2, B_X0 + 0.03)
steile_trap("TrapC", t2, A_X0, A_X1, TYI0, -6.0, L2, L3, A_X1 - 0.03, ladder=True)


# ---------- torenvloeren: heel met trapgat, kapot gebroken met de oosthelft naar beneden ----------
def vloer(name, parent, ztop, hole, hinge_deg, seed, top=PLANKEN, x0=TI0, x1=TI1, y0=TYI0, y1=TYI1, slab=SLAB):
    node = empty(name, parent)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(x1 - x0, y1 - y0, slab), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, (y0 + y1) / 2, ztop - slab / 2))
    v = mesh_obj(name + "_heel", bm, None, node)
    set_materials(v, [top, PLANKEN if top is PLANKEN else HARDSTEEN, HOUT, STEEN])
    hx0, hx1, hy0, hy1 = hole
    cut(v, [cutter_box((hx1 - hx0 + 0.02, hy1 - hy0, 1.0), ((hx0 + hx1) / 2, (hy0 + hy1) / 2, ztop), HOUT)])
    for p in v.data.polygons:
        p.material_index = 0 if p.normal.z > 0.5 else (1 if p.normal.z < -0.5 else 2)
    vk = v.copy()
    vk.data = v.data.copy()
    vk.name = vk.data.name = name + "_kapot"
    link(vk, node)
    bm = bmesh.new()
    r = np.random.default_rng(seed)
    ys = np.linspace(y0 - 0.3, y1 + 0.3, 10)
    left = [bm.verts.new((0.15 + r.uniform(-0.25, 0.1), y, ztop - 1)) for y in ys]
    right = [bm.verts.new((0.45 + r.uniform(-0.1, 0.25), y, ztop - 1)) for y in ys]
    f = bm.faces.new(left + list(reversed(right)))
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=(0, 0, 2))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(STEEN)
    cut(vk, [bpy.data.objects.new("cutter", me)])
    bm = bmesh.new()
    bm.from_mesh(vk.data)
    oost = [q for q in bm.verts if q.co.x > 0.3]
    west = [q for q in bm.verts if q.co.x <= 0.3]
    bmesh.ops.rotate(bm, verts=oost, cent=Vector((x1, 0, ztop - slab)), matrix=Matrix.Rotation(math.radians(-hinge_deg), 3, "Y"))
    bmesh.ops.rotate(bm, verts=west, cent=Vector((x0, 0, ztop - slab)), matrix=Matrix.Rotation(math.radians(hinge_deg * 0.4), 3, "Y"))
    bm.to_mesh(vk.data)
    bm.free()
    return node


vloer("Vloer1", t1, L1, HOLE1, 36, 81)
vloer("Vloer2", t2, L2, HOLE2, 32, 82)
vloer("Vloer3", t3, L3, HOLE3, 28, 83, top=STEEN, x0=-TX + PT, x1=TX - PT, y0=TY0 + PT, y1=TY1 - PT, slab=0.3)


def reling(lst, parent, z, lijnen):
    for (a, b) in lijnen:
        a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        L = (b - a).length
        mid = (a + b) / 2
        horiz = abs(b.x - a.x) > abs(b.y - a.y)
        lst.append(box("rel", (L if horiz else 0.06, 0.06 if horiz else L, 0.06), HOUT, parent, (mid.x, mid.y, z + 0.95)))
        n = max(2, int(L / 0.45))
        for k in range(n + 1):
            p = a + (b - a) * (k / n)
            lst.append(box("spijl", (0.04, 0.04, 0.95), HOUT, parent, (p.x, p.y, z + 0.475)))


def wang(lst, parent, x, y0, y1, z0, z1):
    """Dicht houten beschot onder de open kant van een trap (driehoek)."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for (y, z) in ((y0, z0), (y1, z1), (y1, z0))]
    bm.faces.new(vs)
    lst.append(mesh_obj("wang", bm, HOUT, parent))


inr0t, inr1, inr2, inr3 = [], [], [], []
wang(inr0t, tvoet, A_X1, TYI0, -6.0, L0, L1)
reling(inr1, t1, L1, [((A_X1 + 0.03, -8.0), (A_X1 + 0.03, -6.0)), ((A_X0, -8.03), (A_X1 + 0.03, -8.03))])
wang(inr1, t1, B_X0, TYI1, -8.0, L1, L2)
reling(inr2, t2, L2, [((B_X0 - 0.03, -8.0), (B_X0 - 0.03, -6.0)), ((B_X0 - 0.03, -5.97), (B_X1, -5.97))])
wang(inr2, t2, A_X1, TYI0, -6.0, L2, L3)
reling(inr3, t3, L3, [((A_X1 + 0.03, -8.0), (A_X1 + 0.03, -6.0)), ((A_X0, -8.03), (A_X1 + 0.03, -8.03))])


# ---------- deuren (knooppunt = scharnier) ----------
def deur(name, parent, hinge, width, height, angle, sx=1):
    """Oude eikenhouten deur met ijzeren banden en spijkers."""
    h = empty(name, parent, hinge, (0, 0, angle))
    parts = [box(name + "Blad", (width - 0.03, 0.08, height - 0.02), HOUT, h, (sx * width / 2, 0, height / 2))]
    for z in (0.35, height / 2, height - 0.35):
        parts.append(box("band", (width * 0.85, 0.1, 0.07), IJZER, h, (sx * width * 0.44, 0, z)))
    for k in range(5):
        parts.append(box("plank", (0.015, 0.09, height - 0.1), DONKER, h, (sx * width * (k + 1) / 6, 0, height / 2)))
    parts.append(cyl("ring", 0.07, 0.07, 0.02, IJZER, "Y", 10, h, (sx * (width - 0.15), -0.06, 1.1)))
    join(parts[0], parts[1:])
    parts[0].name = name + "Blad"
    return h


deur("DeurVoorL", tvoet, (-0.84, TY0 + TT / 2, L0), 0.84, 2.25, 0.0, 1)
deur("DeurVoorR", tvoet, (0.84, TY0 + TT / 2, L0), 0.84, 2.25, 0.0, -1)
# boogveld boven de deuren (hoort bij de voorgevel: valt mee als die kapot gaat)
_bv = [p for p in spits_pts(0, 1.72, 0.0, 3.0, 12) if p[1] > 2.3]
_bv = [(_bv[0][0], 2.25)] + _bv + [(_bv[-1][0], 2.25)]
add_to_heel(bpy.data.objects["M0V0"], [prism("boogveld", _bv, 0.06, HOUT, bpy.data.objects["M0V0"], 0.0)])
deur("DeurZij", schip, (NX - TS / 2, 7.4125 - 0.6, L0), 1.2, 2.3, math.pi / 2, 1)


# ---------- losse brokken en puinhopen ----------
def brok(name, size, seed, parent, loc=(0, 0, 0), material=None, mats=None):
    r = np.random.default_rng(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
    for v in bm.verts:
        v.co = Vector((v.co.x * r.uniform(0.7, 1.3), v.co.y * r.uniform(0.7, 1.3), v.co.z * r.uniform(0.5, 1.0)))
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    mats = mats or [PLEISTER, STEEN, STEEN, HARDSTEEN]
    m = material or mats[r.integers(0, len(mats))]
    o = mesh_obj(name, bm, m, parent, loc)
    o.rotation_euler = tuple(r.uniform(0, math.tau, 3))
    return o


def hoop(name, R, Hh, n, seed, parent=puin, at=(0, 0, 0), extra=True, mats=None):
    r = np.random.default_rng(seed)
    parts = []
    for k in range(n):
        a = r.uniform(0, math.tau)
        d = R * math.sqrt(r.uniform(0, 1))
        z = Hh * (1 - (d / R) ** 2) * r.uniform(0.5, 1.0)
        s = r.uniform(0.3, 0.75) * (R / 1.4) ** 0.5
        parts.append(brok("b", (s, s * r.uniform(0.6, 1.2), s * 0.6), seed * 100 + k, parent,
                          (at[0] + d * math.cos(a), at[1] + d * math.sin(a), at[2] + z), mats=mats))
    if extra:
        parts.append(box("balk", (0.14, R * 1.5, 0.14), HOUT, parent, (at[0] + 0.2, at[1], at[2] + Hh * 0.5), (0.3, 0.1, r.uniform(0, 3))))
        parts.append(box("muurstuk", (0.9 * R, 0.45, 0.6 * R), PLEISTER, parent, (at[0] - 0.3 * R, at[1] + 0.2, at[2] + Hh * 0.35),
                         (1.1, 0.2, r.uniform(0, 3))))
    o = join(parts[0], parts[1:])
    o.name = name
    return o


def kerkbank(lst, parent, x, y, seed, lengte=3.0):
    """Houten kerkbank; soms scheef geschoven of omgevallen."""
    r = np.random.default_rng(seed)
    p = []
    p.append(box("zit", (lengte, 0.42, 0.06), HOUTLICHT, parent, (0, 0, 0.45)))  # eerste deel = oorsprong
    p.append(box("rug", (lengte, 0.06, 0.55), HOUTLICHT, parent, (0, 0.22, 0.78)))
    p.append(box("plank", (lengte, 0.3, 0.03), HOUT, parent, (0, 0.38, 0.62)))  # boekenplankje voor de bank erachter
    for sx in (-1, 1):
        p.append(box("wang", (0.07, 0.55, 1.0), HOUT, parent, (sx * lengte / 2, 0.05, 0.5)))
    p.append(box("kniel", (lengte - 0.1, 0.12, 0.08), HOUT, parent, (0, -0.35, 0.12)))
    o = join(p[0], p[1:])
    o.data.transform(Matrix.Translation((0, 0, 0.45)))   # oorsprong op de vloer, onder het midden van de bank
    o.location = (x, y, L0)
    q = r.random()
    if q < 0.18:      # omgevallen naar achter
        o.rotation_euler = (-1.45, 0, r.uniform(-0.15, 0.15))
        o.location = (x, y + 0.5, L0 + 0.25)
    elif q < 0.45:    # scheef geschoven
        o.rotation_euler = (0, 0, r.uniform(-0.25, 0.25))
        o.location = (x + r.uniform(-0.3, 0.3), y + r.uniform(-0.15, 0.15), L0)
    lst.append(o)


def klok(name, parent, loc, rot=(0, 0, 0)):
    """Bronzen luidklok (draaivlak), onderkant op z = 0 van het object, met klepel."""
    prof = [(0.0, 1.02), (0.18, 1.0), (0.3, 0.95), (0.34, 0.8), (0.36, 0.6), (0.42, 0.35), (0.52, 0.15), (0.6, 0.04),
            (0.62, 0.0), (0.55, 0.0), (0.5, 0.08)]
    bm = bmesh.new()
    vs = [bm.verts.new((r_, 0, z)) for (r_, z) in prof]
    edges = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=16, use_merge=True)
    o = mesh_obj(name, bm, BRONS, parent, loc, smooth=True)
    o.rotation_euler = rot
    kl = cyl("klepel", 0.03, 0.03, 0.7, IJZER, "Z", 6, o, (0, 0, 0.5))
    kb = cyl("klepelbol", 0.09, 0.09, 0.16, IJZER, "Z", 8, o, (0, 0, 0.18))
    kroon = box("kroon", (0.25, 0.08, 0.2), BRONS, o, (0, 0, 1.1))
    join(o, [kl, kb, kroon])
    o.name = name
    return o


# ---------- inrichting van het schip: banken, altaar, kruis, preekstoel, doopvont, gevallen kroonluchter ----------
sch = []
for side in (-1, 1):
    for i in range(7):
        kerkbank(sch, schip, side * 2.35, -2.6 + 1.15 * i, 300 + i * 7 + (side > 0) * 50)
K = L0 + 0.16    # vloer van het koor
sch.append(box("Altaar", (2.2, 0.9, 1.0), HARDSTEEN, schip, (0, 8.1, K + 0.5)))
sch.append(box("AltaarBlad", (2.4, 1.05, 0.08), RAND, schip, (0, 8.1, K + 1.04)))
sch.append(box("Altaarkleed", (2.3, 1.0, 0.02), STOF, schip, (0, 8.08, K + 1.09)))
sch.append(box("Antependium", (1.9, 0.02, 0.55), STOF, schip, (0, 7.62, K + 0.8)))
for sx in (-1, 1):
    sch.append(cyl("Kandelaar", 0.08, 0.05, 0.4, GOUD, "Z", 8, schip, (sx * 0.8, 8.2, K + 1.28)))
    sch.append(cyl("Kaars", 0.035, 0.035, 0.3, KAARS, "Z", 6, schip, (sx * 0.8, 8.2, K + 1.63)))
    sch.append(cyl("Standaard", 0.04, 0.04, 1.5, GOUD, "Z", 6, schip, (sx * 1.9, 7.0, K + 0.75)))
    sch.append(cyl("Voet", 0.2, 0.12, 0.1, GOUD, "Z", 8, schip, (sx * 1.9, 7.0, K + 0.05)))
    sch.append(cyl("KaarsGroot", 0.06, 0.06, 0.45, KAARS, "Z", 6, schip, (sx * 1.9, 7.0, K + 1.72)))
sch.append(box("Kruis", (0.16, 0.08, 1.9), HOUT, schip, (0, NY1 - TS - 0.06, K + 1.9)))
sch.append(box("Kruis", (1.0, 0.08, 0.16), HOUT, schip, (0, NY1 - TS - 0.06, K + 2.4)))
sch.append(cyl("Lessenaar", 0.06, 0.06, 1.0, HOUT, "Z", 6, schip, (-1.6, 6.3, K + 0.5)))
sch.append(box("Boek", (0.45, 0.35, 0.06), STOF, schip, (-1.6, 6.3, K + 1.05), (0.4, 0, 0.2)))
# preekstoel (achtkant) met trapje, het klankbord is naar beneden gekomen
sch.append(cyl("Kuip", 0.55, 0.5, 1.1, HOUT, "Z", 8, schip, (-3.55, 5.4, L0 + 1.75), smooth=False))
sch.append(cyl("Kuiprand", 0.6, 0.6, 0.08, HOUTLICHT, "Z", 8, schip, (-3.55, 5.4, L0 + 2.33), smooth=False))
sch.append(cyl("Kuipvoet", 0.15, 0.25, 1.2, HOUT, "Z", 8, schip, (-3.55, 5.4, L0 + 0.6)))
for k in range(6):
    sch.append(box("PreekTrede", (0.7, 0.28, 0.06), HOUTLICHT, schip, (-3.6, 4.65 - k * 0.28, L0 + 1.2 - k * 0.2)))
sch.append(cyl("Klankbord", 0.85, 0.85, 0.08, HOUT, "Z", 8, schip, (-2.7, 4.4, L0 + 0.25), smooth=False, rot=(0.25, -0.1, 0.3)))
# doopvont bij de ingang
sch.append(cyl("Vontvoet", 0.18, 0.22, 0.75, HARDSTEEN, "Z", 8, schip, (3.3, -3.2, L0 + 0.37)))
sch.append(cyl("Vont", 0.45, 0.28, 0.35, HARDSTEEN, "Z", 10, schip, (3.3, -3.2, L0 + 0.92)))
# gevallen kroonluchter
sch.append(cyl("Luchter", 0.7, 0.7, 0.05, IJZER, "Z", 14, schip, (0.2, 1.9, L0 + 0.12), rot=(0.15, 0.1, 0)))
for k in range(6):
    a = k / 6 * math.tau
    sch.append(cyl("LuchterKaars", 0.03, 0.03, 0.2, KAARS, "Z", 6, schip, (0.2 + 0.68 * math.cos(a), 1.9 + 0.68 * math.sin(a), L0 + 0.25)))
# zandzakken in de torenboog en munitiekisten: hier is gevochten
for k in range(7):
    sch.append(box("Zandzak", (0.6, 0.32, 0.22), STOF3, schip, (-2.0 + (k % 4) * 0.62 + (0.3 if k >= 4 else 0) + (2.5 if k % 4 > 1 else 0),
                                                             -3.6, L0 + 0.11 + (0.22 if k >= 4 else 0)), (0, 0, 0.05 * (k % 3))))
for k, (x, y) in enumerate(((-3.5, 3.3), (-3.6, 2.7))):
    sch.append(box(f"Munitiekist{k}", (0.7, 0.4, 0.35), HOUT, schip, (x, y, L0 + 0.175 + 0.35 * k * 0)))
# brokken kalk en pannen onder de gaten in het dak
for k in range(9):
    sch.append(brok("brok", (0.35, 0.3, 0.12), 500 + k, schip, (rng.uniform(-3.5, 3.5), rng.uniform(-2, 6), L0 + 0.06),
                    mats=[PLEISTER, DAKPAN, DAKPAN, STEEN]))
inrs = join(sch[0], sch[1:])
inrs.name = "InrichtingSchip"
l = bpy.data.lights.new("Licht0", "POINT")
l.energy = 1.5
l.color = (1.0, 0.8, 0.5)
o = link(bpy.data.objects.new("Licht0", l), schip)
o.location = (0, 7.0, 2.6)

# ---------- inrichting van de toren ----------
# ingang: bank langs de oostmuur, een oude kist, klokkentouw
inr0t.append(box("Bank", (0.4, 2.0, 0.08), HOUT, tvoet, (TI1 - 0.25, -7.0, L0 + 0.45)))
for dy in (-0.85, 0.85):
    inr0t.append(box("BankPoot", (0.35, 0.08, 0.45), HOUT, tvoet, (TI1 - 0.25, -7.0 + dy, L0 + 0.225)))
inr0t.append(box("Kist", (0.9, 0.5, 0.5), HOUT, tvoet, (0.6, -5.6, L0 + 0.25)))
inr0t.append(box("KistBand", (0.92, 0.52, 0.06), IJZER, tvoet, (0.6, -5.6, L0 + 0.35)))
inrt0 = join(inr0t[0], inr0t[1:])
inrt0.name = "InrichtingToren0"

# laag 1: het uurwerk achter de wijzerplaat, kisten
B = L1
inr1.append(box("Uurwerk", (0.9, 0.5, 0.06), IJZER, t1, (0.0, TYI0 + 0.4, B + 0.9)))
for sx in (-1, 1):
    inr1.append(box("UurwerkPoot", (0.06, 0.5, 0.9), IJZER, t1, (sx * 0.42, TYI0 + 0.4, B + 0.45)))
    inr1.append(box("UurwerkRaam", (0.06, 0.06, 0.8), IJZER, t1, (sx * 0.42, TYI0 + 0.4, B + 1.3)))
inr1.append(box("UurwerkTop", (0.9, 0.06, 0.06), IJZER, t1, (0.0, TYI0 + 0.4, B + 1.7)))
for k, (x, z, r_) in enumerate(((-0.15, 1.2, 0.22), (0.18, 1.35, 0.14), (0.05, 1.55, 0.1))):
    inr1.append(cyl("Tandwiel", r_, r_, 0.04, ROEST, "Y", 12, t1, (x, TYI0 + 0.38, B + z)))
inr1.append(cyl("As", 0.025, 0.025, 0.5, IJZER, "Y", 6, t1, (0.0, TYI0 + 0.1, B + 2.55)))
inr1.append(cyl("Gewicht", 0.1, 0.1, 0.35, IJZER, "Z", 8, t1, (0.35, TYI0 + 0.6, B + 0.4)))
inr1.append(box("Kist1", (0.7, 0.5, 0.45), HOUT, t1, (-0.2, -7.0, B + 0.225), (0, 0, 0.3)))
inr1.append(box("Kist2", (0.5, 0.5, 0.4), HOUTLICHT, t1, (0.5, -6.4, B + 0.2)))
inrt1 = join(inr1[0], inr1[1:])
inrt1.name = "Inrichting1"

# laag 2: de klok in de klokkenstoel
B = L2
KY = -6.8
for sx in (-1, 1):
    inr2.append(box("Stijl", (0.2, 0.2, 2.95), HOUT, t2, (sx * 0.75, KY, B + 1.475)))
    inr2.append(box("Voetbalk", (0.2, 1.6, 0.2), HOUT, t2, (sx * 0.75, KY, B + 0.1)))
    for sy in (-1, 1):
        inr2.append(box("Schoor", (0.14, 0.14, 1.4), HOUT, t2, (sx * 0.75, KY + sy * 0.42, B + 0.65), (sy * 0.62, 0, 0)))
inr2.append(box("Klokbalk", (1.8, 0.24, 0.26), HOUT, t2, (0, KY, B + 2.95)))
inr2.append(box("Juk", (0.5, 0.3, 0.25), HOUT, t2, (0, KY, B + 2.7)))
inr2.append(klok("Klok", t2, (0, KY, B + 1.55)))
inr2.append(cyl("Touw", 0.015, 0.015, 1.3, STOF3, "Z", 4, t2, (0.45, KY, B + 1.2), rot=(0, 0.08, 0)))
inr2.append(box("Wiel", (0.06, 0.9, 0.9), HOUT, t2, (0.5, KY, B + 2.7), (0.785, 0, 0)))
inrt2 = join(inr2[0], inr2[1:])
inrt2.name = "Inrichting2"

# laag 3: torendak met luik, zandzakken (uitkijkpost) en de vlag
B = L3
for (sx, sy, cx, cy) in ((A_X1 - A_X0 + 0.1, 0.1, (A_X0 + A_X1) / 2, -8.05), (A_X1 - A_X0 + 0.1, 0.1, (A_X0 + A_X1) / 2, -5.95),
                         (0.1, 2.2, A_X1 + 0.05, -7.0)):
    inr3.append(box("Luikrand", (sx, sy, 0.16), HOUT, t3, (cx, cy, B + 0.08)))
inr3.append(box("Luik", (0.95, 0.06, 1.0), HOUT, t3, ((A_X0 + A_X1) / 2, -5.9, B + 0.55), (0.12, 0, 0)))
inr3.append(box("LuikBand", (0.85, 0.07, 0.06), IJZER, t3, ((A_X0 + A_X1) / 2, -5.92, B + 0.8), (0.12, 0, 0)))
for k in range(8):
    inr3.append(box("Zandzak", (0.6, 0.32, 0.22), STOF3, t3, (0.05 + (k % 4) * 0.55, TY0 + PT + 0.2, B + 0.11 + (0.22 if k >= 4 else 0)),
                    (0, 0, 0.06 * ((k % 3) - 1))))
inr3.append(box("Munitiekist3", (0.7, 0.4, 0.35), HOUT, t3, (1.2, -6.6, B + 0.175), (0, 0, 0.4)))
inr3.append(cyl("Vlaggenstok", 0.04, 0.035, 3.6, HOUT, "Z", 6, t3, (1.8, -5.4, B + 1.8)))
inr3.append(cyl("StokVoet", 0.12, 0.12, 0.25, IJZER, "Z", 8, t3, (1.8, -5.4, B + 0.12)))
vl = prism("Vlag", [(1.84, B + 2.6), (3.2, B + 2.75), (3.05, B + 3.1), (3.3, B + 3.25), (1.84, B + 3.55)], 0.02, VLAG, t3, -5.4)
cut(vl, [cutter_jagged((2.9, -5.4, B + 3.0), 0.18, "Y", 0.3, 91, 7, VLAG)])
inr3.append(vl)
inrt3 = join(inr3[0], inr3[1:])
inrt3.name = "Inrichting3"


# ---------- zadeldak met topgevels ----------
TAN = (NOK - TOPS) / NX
OV = 0.45
ZOFF = 0.2


def dakschild(name, s, kapot):
    """Eén dakvlak (s = -1 west, +1 oost): pannen boven, planken onder. UV van de pannen: u langs de nok, v naar de nok."""
    yf, yb = NY0 - 0.3, NY1 + 0.35
    xe = s * (NX + OV)
    zr = NOK + ZOFF
    ze = zr - (NX + OV) * TAN
    dz = 0.16 * math.sqrt(1 + TAN * TAN)
    bm = bmesh.new()
    top = [bm.verts.new(p) for p in ((0, yf, zr), (xe, yf, ze), (xe, yb, ze), (0, yb, zr))]
    bot = [bm.verts.new((v.co.x, v.co.y, v.co.z - dz)) for v in top]
    f_top = bm.faces.new(top if s > 0 else list(reversed(top)))
    bm.faces.new(list(reversed(bot)) if s > 0 else bot)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([top[i], top[j], bot[j], bot[i]] if s < 0 else [top[j], top[i], bot[i], bot[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uvl = bm.loops.layers.uv.new("UVMap")
    slope = math.sqrt(1 + TAN * TAN)
    for f in bm.faces:
        for lp in f.loops:
            c = lp.vert.co
            lp[uvl].uv = (c.y / 4.8, (NX + OV - abs(c.x)) * slope / 4.8)
    o = mesh_obj(name, bm, None, dak)
    set_materials(o, [DAKPAN, PLANKEN, HOUT])
    for p in o.data.polygons:
        p.material_index = 0 if p.normal.z > 0.3 else (1 if p.normal.z < -0.3 else 2)
    o["eigen_uv"] = 1
    if kapot:
        gaten = [(2.2, 1.0, 1.8, 61), (1.6, 6.8, 1.0, 62)] if s > 0 else [(-1.9, 5.2, 1.4, 63), (-2.6, -2.2, 0.95, 64)]
        cs = []
        for (x, y, rr, sd) in gaten:
            cs.append(cutter_jagged((x, y, zr - abs(x) * TAN), rr, "Z", 3.0, sd, 11, HOUT))
        cut(o, cs)
    return o


def gevel_top(name, y0, inner_sign, kapot):
    o = prism(name, [(-NX, TOPS), (NX, TOPS), (0, NOK)], TS, PLEISTER, dak, y0)
    set_materials(o, [PLEISTER, BINNEN, STEEN])
    for p in o.data.polygons:
        p.material_index = 1 if p.normal.y * inner_sign > 0.5 else (2 if p.normal.z > 0.3 else 0)
    return o


def dak_stuk(name, kapot):
    d = [dakschild("schild", -1, kapot), dakschild("schild", 1, kapot)]
    voor = gevel_top("gevelV", NY0 + TS / 2, 1, kapot)
    achter = gevel_top("gevelA", NY1 - TS / 2, -1, kapot)
    # oculus in de achtergevel en een stenen kruis op de top
    cut(achter, [cutter_prism(rond_pts(0, 8.1, 0.38), 1.0, STEEN, NY1 - TS / 2)])
    d.append(ring("oculus", rond_pts(0, 8.1, 0.52), rond_pts(0, 8.1, 0.38), 0.08, RAND, dak, NY1 + 0.02))
    if kapot:
        cut(achter, [cutter_jagged((0.6, NY1 - TS / 2, NOK - 0.2), 1.3, "Y", 1.0, 71, 9, STEEN)])
        drop_floating(achter, TOPS + 0.05)
    else:
        d.append(box("kruisvoet", (0.4, 0.3, 0.3), RAND, dak, (0, NY1 - TS / 2, NOK + 0.25)))
        d.append(box("kruis", (0.14, 0.14, 1.2), RAND, dak, (0, NY1 - TS / 2, NOK + 0.95)))
        d.append(box("kruis", (0.6, 0.14, 0.14), RAND, dak, (0, NY1 - TS / 2, NOK + 1.15)))
    d += [voor, achter]
    # nokvorst
    d.append(cyl("nok", 0.14, 0.14, NY1 - NY0 + 0.65, DAKPAN, "Y", 8, dak, (0, (NY0 + NY1) / 2 + 0.02, NOK + ZOFF + 0.02)))
    if kapot:
        # gebroken spanten en latten in de gaten, losse pannen
        r = np.random.default_rng(77)
        for (x, y) in ((2.2, 1.0), (-1.9, 5.2), (1.6, 6.8), (-2.6, -2.2)):
            for k in range(3):
                yy = y + (k - 1) * 0.6
                zz = NOK + ZOFF - abs(x) * TAN - 0.25
                d.append(box("spant", (0.12, 0.14, r.uniform(1.2, 2.2)), HOUT, dak, (x + r.uniform(-0.4, 0.4), yy, zz),
                             (0, math.atan2(-math.copysign(1.0, x), TAN) + r.uniform(-0.25, 0.25), r.uniform(-0.3, 0.3))))
        for k in range(8):
            d.append(brok("pan", (0.32, 0.22, 0.08), 720 + k, dak, (rng.uniform(-3.5, 3.5), rng.uniform(-3, 8), TOPS + 0.3), DAKPAN))
    o = d[0]
    join(o, d[1:])
    o.name = name
    o["eigen_uv"] = 1
    return o


dak_stuk("Dak_heel", False)
dak_stuk("Dak_kapot", True)

# ---------- puin (sjablonen) ----------
hoop("PuinGroot", 1.5, 0.9, 42, 5)
hoop("PuinKlein", 0.8, 0.5, 16, 6)
for k in range(4):
    brok(f"Brok{k}", (0.25 + 0.1 * k, 0.2 + 0.08 * k, 0.15 + 0.05 * k), 900 + k, puin, (k * 0.8 - 1.2, 3.0, 0.1),
         [PLEISTER, STEEN, HARDSTEEN, STEEN][k])


# ---------- ruïnes: de toren en het schip storten elk apart in ----------
def stomp(name, size, loc, parent, axis, cut_at, rad, seed, squash=1.0):
    o = box(name, size, PLEISTER, parent, loc)
    set_materials(o, [PLEISTER, STEEN])
    c = (cut_at[0] - loc[0], cut_at[1] - loc[1], cut_at[2] - loc[2])   # snijders in lokale coördinaten
    cut(o, [cutter_jagged(c, rad, axis, max(size) + 1.0, seed, 10, STEEN, squash)])
    drop_floating(o, -size[2] / 2 + 0.05)
    return o


rt_node = empty("RuineToren", ruine)
rr = np.random.default_rng(321)
rt = []
rt.append(stomp("rest", (2 * TX, TT, 2.8), (0, TY0 + TT / 2, 1.4), rt_node, "Y", (0.5, TY0 + TT / 2, 2.9), 1.9, 401))
rt.append(stomp("rest", (TT, TYI1 - TYI0, 6.0), (-TX + TT / 2, -7.0, 3.0), rt_node, "X", (-TX + TT / 2, -6.0, 6.2), 2.4, 402, 1.2))
rt.append(stomp("rest", (TT, TYI1 - TYI0, 3.6), (TX - TT / 2, -7.0, 1.8), rt_node, "X", (TX - TT / 2, -7.6, 3.6), 1.7, 403))
ach = stomp("rest", (2 * TX, TT, 7.6), (0, TY1 - TT / 2, 3.8), rt_node, "Y", (-0.9, TY1 - TT / 2, 7.4), 2.6, 404, 1.3)
cut(ach, [cutter_prism([(x, z - 3.8 + 0.3) for (x, z) in spits_pts(0, 2.0, 0.0, 3.3)], 1.5, STEEN, 0.0)])
rt.append(ach)
rt.append(hoop("berg", 3.0, 2.3, 55, 41, rt_node, (0, -7.2, 0), extra=False))
rt.append(hoop("berg", 2.1, 0.9, 26, 42, rt_node, (0.5, -10.9, 0), extra=False))
rt.append(klok("klokrest", rt_node, (1.6, -11.3, 0.62), (1.35, 0.2, 0.6)))
for k in range(6):
    rt.append(box("balk", (0.16, rr.uniform(1.6, 3.0), 0.18), HOUT, rt_node,
                  (rr.uniform(-2, 2), rr.uniform(-10, -5), rr.uniform(1.0, 2.4)), tuple(rr.uniform(-0.7, 0.7, 3))))
kant = box("kantelstuk", (2.2, PT, PAR_H), PLEISTER, rt_node, (0, 0, 0))
set_materials(kant, [PLEISTER, STEEN])
cut(kant, [cutter_box((0.45, 1, 1), (x, 0, 0.5), STEEN) for x in (-0.55, 0.55)])
kant.location = (-2.5, -11.6, 0.5)
kant.rotation_euler = (1.2, 0.25, 0.4)
rt.append(kant)
rt.append(cyl("pinakel", 0.3, 0.0, 0.9, RAND, "Z", 4, rt_node, (2.6, -9.8, 0.3), smooth=False, rot=(1.5, 0, 0.8)))
rt.append(cyl("wijzerplaat", 0.62, 0.62, 0.05, WIJZERPLAAT, "Y", 24, rt_node, (-1.2, -10.8, 0.4), rot=(1.3, 0.3, 0)))
rt.append(box("trede", (3.2, 0.9, 0.1), HARDSTEEN, rt_node, (0, TY0 - 0.45, 0.05)))
o = join(rt[0], rt[1:])
o.name = "RuineTorenMesh"

rs_node = empty("RuineSchip", ruine)
rs = []
for i, (a, b) in enumerate(SIDE):
    for sx in (-1, 1):
        h = rr.uniform(1.2, 4.8)
        x = sx * (NX - TS / 2)
        rs.append(stomp("rest", (TS, b - a, h), (x, (a + b) / 2, h / 2), rs_node, "X", (x, (a + b) / 2 + rr.uniform(-0.8, 0.8), h),
                        rr.uniform(1.1, 1.6), 500 + i * 2 + (sx > 0), 1.3))
for i, (a, b) in enumerate(BACK):
    h = (2.6, 5.6, 3.4)[i]
    rs.append(stomp("rest", (b - a, TS, h), ((a + b) / 2, NY1 - TS / 2, h / 2), rs_node, "Y", ((a + b) / 2 + rr.uniform(-0.5, 0.5), NY1 - TS / 2, h),
                    1.5, 520 + i, 1.2))
for i, (a, b) in enumerate([(-NX, -TX), (TX, NX)]):
    rs.append(stomp("rest", (b - a, TS, 3.0), ((a + b) / 2, NY0 + TS / 2, 1.5), rs_node, "Y", ((a + b) / 2, NY0 + TS / 2, 3.0), 1.4, 530 + i))
rs.append(hoop("berg", 3.6, 1.9, 60, 51, rs_node, (0.3, -0.8, 0), extra=False, mats=[PLEISTER, STEEN, DAKPAN, DAKPAN, HARDSTEEN]))
rs.append(hoop("berg", 3.4, 1.6, 55, 52, rs_node, (-0.4, 4.6, 0), extra=False, mats=[PLEISTER, STEEN, DAKPAN, DAKPAN]))
rs.append(hoop("berg", 2.0, 1.0, 20, 53, rs_node, (2.6, 7.8, 0), extra=False))
for k, (x, y, z, rx, ry) in enumerate(((-1.5, 0.5, 1.6, 0.35, -0.5), (1.8, 3.0, 1.4, -0.3, 0.6), (-0.8, 6.5, 1.2, 0.2, -0.4))):
    pl = box("dakstuk", (3.2, 2.4, 0.16), DAKPAN, rs_node, (x, y, z), (rx, ry, rr.uniform(-0.4, 0.4)))
    rs.append(pl)
for k in range(9):
    rs.append(box("spant", (0.14, rr.uniform(2.0, 4.0), 0.16), HOUT, rs_node,
                  (rr.uniform(-3.5, 3.5), rr.uniform(-3.5, 8), rr.uniform(1.0, 2.2)), tuple(rr.uniform(-0.6, 0.6, 3))))
for k in range(4):
    rs.append(box("bankrest", (rr.uniform(1.2, 2.4), 0.42, 0.06), HOUTLICHT, rs_node,
                  (rr.uniform(-3.5, 3.5), rr.uniform(-3.5, 2), rr.uniform(0.6, 1.4)), tuple(rr.uniform(-0.8, 0.8, 3))))
rs.append(box("altaarrest", (2.2, 0.9, 1.0), HARDSTEEN, rs_node, (0.3, 8.2, 0.5), (0, 0.12, 0.1)))
rs.append(box("kruisrest", (0.16, 0.08, 1.9), HOUT, rs_node, (-0.6, 8.4, 1.4), (0.4, 0.5, 0)))
rs.append(box("kruisrest", (1.0, 0.08, 0.16), HOUT, rs_node, (-0.75, 8.5, 1.7), (0.4, 0.5, 0)))
o = join(rs[0], rs[1:])
o.name = "RuineSchipMesh"

# ---------- afwerking ----------
bpy.context.view_layer.update()
for o in list(scene.objects):
    if o.type == "MESH":
        bad = [p for p in o.data.polygons if p.material_index >= len(o.data.materials)]
        if bad:
            print("MATFOUT", o.name, len(bad), [m.name for m in o.data.materials])
        world_uv(o)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "kerk.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "kerk.blend"))
tris = {}
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        top = o
        while top.parent and top.parent.name not in ("Kerk",):
            top = top.parent
        key = "kapot" if o.name.endswith("_kapot") else top.name
        tris[key] = tris.get(key, 0) + len(o.data.loop_triangles)
print("TRIS", tris, "OBJECTEN", len([o for o in scene.objects if o.type == "MESH"]))
