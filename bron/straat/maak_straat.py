"""Straatset voor de stad achter de brug (Bloedjungle): de wegdelen van de stadseditor als echte modellen met texturen.
Elk wegdeel is 6 x 6 m (Stad.CELL), het plein 12 x 12 m. Asfalt ligt op 0,03 m, de stoep (met een betonnen stoeprand) op 0,12 m.
Blender: Z omhoog, noord = +Y (wordt -Z in Godot), 1 eenheid = 1 meter, oorsprong = midden van het wegdeel op de grond.
Gebruik: python3 maak_straat.py <uitmap>  ->  straat.glb, straat.blend

Objecten (het spel pakt alleen de mesh; de objecten staan voor de viewer naast elkaar):
  Recht    rechte weg noord-zuid, stoep links en rechts, stippellijn, putdeksel en kolk
  Bocht    bocht van noord naar oost, ronde stoeprand (binnen 1 m, buiten 5 m), gebogen stippellijn
  TStuk    T-kruising open naar noord, oost en zuid; stoep aan de westkant
  Kruis    kruispunt met vier ronde stoephoeken en een putdeksel in het midden
  Steeg    smalle steeg (2 m keien) met brede oude stoep
  Zebra    rechte weg met zebrapad
  Stoep    vol stoeptegels (opvulling naast gebouwen en pleinen)
  Plein    plein van 12 x 12 m: keien, stenen rand en een stenen cirkel om de fontein
  Fontein  fontein met water (los object, het spel zet er een botsvorm omheen)
Materialen met wereld-UV (Asfalt 12 m, Stoep 1,2 m, Keien 1 m, Steen 2 m): het spel rekent de UV van bovenvlakken opnieuw uit de
wereldpositie uit, zodat de texturen naadloos doorlopen over gedraaide wegdelen.
"""
import math, os, sys
import bpy, bmesh
import numpy as np

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

C = 3.0          # halve cel
ASF = 0.03       # bovenkant asfalt
SW = 0.12        # bovenkant stoep
BW = 0.15        # breedte stoeprand
DET = 0.006      # putdeksels en strepen liggen net boven het asfalt


# ---------- texturen ----------
def noise(size, scale, seed, sy=None):
    """Zachte waardenruis, naadloos herhalend."""
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
    return np.clip((v - e0) / (e1 - e0), 0, 1)


def save_img(name, img, non_color=False):
    """img[rij 0] = bovenkant van het plaatje (v = 1)."""
    size = img.shape[0]
    im = bpy.data.images.new(name, size, size)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    rgba = np.concatenate([np.clip(img, 0, 1), np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, name + ".png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


def normal_img(name, h, strength):
    """Normal map (OpenGL, zoals glTF) uit een hoogtekaart; naadloos door np.roll."""
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    gr = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.stack([-gx, gr, np.ones_like(h)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return save_img(name, n * 0.5 + 0.5, True)


def kleur(c):
    return np.array(c)[None, None, :]


def asfalt_image(size=512):
    """Versleten asfalt, één herhaling per twee wegdelen (12 m): grind, scheuren, opgelapte stukken en olievlekken."""
    rng = np.random.default_rng(11)
    n1 = noise(size, 128, 1)
    img = kleur((0.2, 0.2, 0.196)) * (0.82 + 0.3 * n1[..., None] + 0.08 * noise(size, 16, 2)[..., None])
    # grind: losse lichte en donkere korrels
    korrel = rng.random((size, size))
    img = img * (0.9 + 0.2 * korrel[..., None])
    licht = korrel > 0.985
    img[licht] = img[licht] * 1.7
    # opgelapte stukken: donkerder en gladder, met een randje
    for (x0, y0, w, h) in ((40, 300, 90, 50), (330, 60, 60, 100)):
        m = np.zeros((size, size))
        m[y0:y0 + h, x0:x0 + w] = 1
        rand = np.zeros((size, size))
        rand[y0 - 2:y0 + h + 2, x0 - 2:x0 + w + 2] = 1
        rand -= m
        img = img * (1 - 0.2 * m[..., None]) + kleur((0.16, 0.16, 0.16)) * 0.2 * m[..., None]
        img = img * (1 - 0.2 * rand[..., None])
    # scheuren: dunne lijnen langs ruisranden, alleen in vlekken
    for s, sc, sterk in ((5, 64, 1.0), (7, 32, 0.6)):
        r = np.abs(noise(size, sc, s) - 0.5)
        lijn = (1 - sm(r, 0.0, 0.012)) * sm(noise(size, 128, s + 10), 0.5, 0.62) * sterk
        img = img * (1 - 0.7 * lijn[..., None])
    # olievlekken en vuil
    olie = sm(noise(size, 16, 21) * 0.6 + noise(size, 128, 22) * 0.4, 0.68, 0.8) * 0.3
    img = img * (1 - olie[..., None]) + kleur((0.08, 0.075, 0.07)) * olie[..., None]
    stof = sm(noise(size, 64, 23), 0.55, 0.8) * 0.25
    img = img * (1 - stof[..., None]) + kleur((0.42, 0.37, 0.29)) * stof[..., None]
    return save_img("straat_asfalt", img)


def tegels_hoogte(size, n, seed, voeg=2):
    """Hoogte- en tegelnummerkaart voor n x n vierkante tegels."""
    t = size // n
    y, x = np.mgrid[0:size, 0:size]
    tx, ty = x % t, y % t
    d = np.minimum(np.minimum(tx, t - 1 - tx), np.minimum(ty, t - 1 - ty))
    h = np.clip((d - voeg + 1) / 3.0, 0, 1)
    idx = (y // t) * n + (x // t)
    return h, idx, d


def stoep_image(size=256):
    """Grijze betontegels van 30 x 30 cm (4 x 4 per herhaling van 1,2 m), mos in de voegen, een paar gebarsten tegels."""
    rng = np.random.default_rng(31)
    h, idx, d = tegels_hoogte(size, 4, 31)
    per = rng.uniform(0.86, 1.08, 16)[idx]
    img = kleur((0.5, 0.49, 0.45)) * (per * (0.92 + 0.12 * noise(size, 16, 32)))[..., None]
    img = img * (0.94 + 0.08 * rng.random((size, size)))[..., None]
    # gebarsten tegels: diagonale barst
    y, x = np.mgrid[0:size, 0:size]
    t = size // 4
    for k in (2, 9, 14):
        cx, cy = (k % 4) * t, (k // 4) * t
        inn = (x >= cx) & (x < cx + t) & (y >= cy) & (y < cy + t)
        barst = inn & (np.abs((x - cx) - (y - cy) * 0.8 - 6 * np.sin((y - cy) / 6.0)) < 1.0)
        img[barst] *= 0.55
        h = np.where(barst, h * 0.3, h)
    # vuil en mos in de voegen
    voeg = h < 0.5
    mos = sm(noise(size, 32, 33), 0.45, 0.7)
    img = np.where(voeg[..., None], kleur((0.22, 0.24, 0.16)) * (1 - mos[..., None]) + kleur((0.2, 0.3, 0.12)) * mos[..., None], img)
    vuil = sm(noise(size, 64, 34), 0.45, 0.85) * 0.4
    img = img * (1 - vuil[..., None]) + kleur((0.35, 0.3, 0.22)) * vuil[..., None]
    return save_img("straat_stoep", img), normal_img("straat_stoep_n", h, 2.0)


def keien_image(size=256):
    """Kinderkopjes: 8 rijen per meter, stenen van 10-17 cm, halfsteens verspringend; bol met donkere voegen."""
    rng = np.random.default_rng(41)
    rows = 8
    rh = size // rows
    h = np.zeros((size, size))
    sid = np.zeros((size, size), int)
    y, x = np.mgrid[0:size, 0:size]
    k = 0
    for r in range(rows):
        # breedtes die precies rond gaan (naadloos)
        ws = []
        while sum(ws) < size - 44:
            ws.append(int(rng.integers(26, 44)))
        ws.append(size - sum(ws))
        x0 = int(rng.integers(0, 30))
        for w in ws:
            k += 1
            cx = (x0 + w / 2) % size
            cy = r * rh + rh / 2
            dx = np.minimum(np.abs(x - cx), size - np.abs(x - cx)) / (w / 2 - 1.5)
            dy = np.abs(y - cy) / (rh / 2 - 1.5)
            dd = np.maximum(dx, dy) * 0.6 + np.sqrt(dx * dx + dy * dy) * 0.4
            dome = np.clip(1 - dd ** 3, 0, 1) * (dd < 1)
            better = dome > h
            h = np.where(better, dome, h)
            sid = np.where(better, k, sid)
            x0 += w
    per = rng.uniform(0.75, 1.15, k + 1)[sid]
    tint = rng.uniform(0, 1, k + 1)[sid]
    basis = kleur((0.47, 0.45, 0.42)) * (1 - tint[..., None] * 0.4) + kleur((0.5, 0.42, 0.33)) * tint[..., None] * 0.4
    img = basis * (per * (0.85 + 0.25 * h))[..., None] * (0.92 + 0.1 * noise(size, 8, 42))[..., None]
    voeg = h < 0.12
    mos = sm(noise(size, 32, 43), 0.5, 0.7)
    img = np.where(voeg[..., None], kleur((0.16, 0.15, 0.12)) * (1 - mos[..., None]) + kleur((0.18, 0.26, 0.1)) * mos[..., None], img)
    return save_img("straat_keien", img), normal_img("straat_keien_n", h, 3.0)


def steen_image(size=256):
    """Lichte natuursteen in platen van 50 x 50 cm (4 x 4 per 2 m) voor de pleinrand en de fontein."""
    rng = np.random.default_rng(51)
    h, idx, d = tegels_hoogte(size, 4, 51, 1)
    per = rng.uniform(0.88, 1.06, 16)[idx]
    img = kleur((0.64, 0.59, 0.5)) * (per * (0.9 + 0.14 * noise(size, 32, 52) + 0.05 * noise(size, 4, 53)))[..., None]
    ader = (1 - sm(np.abs(noise(size, 64, 54) - 0.5), 0, 0.02)) * 0.25
    img = img * (1 - ader[..., None])
    img = np.where((h < 0.4)[..., None], kleur((0.35, 0.32, 0.26)), img)
    vuil = sm(noise(size, 64, 55), 0.55, 0.85) * 0.3
    img = img * (1 - vuil[..., None]) + kleur((0.36, 0.34, 0.24)) * vuil[..., None]
    return save_img("straat_steen", img)


def verf_image(size=128):
    """Witte wegverf, afgesleten en vuil."""
    sl = sm(noise(size, 16, 61) * 0.6 + noise(size, 4, 62) * 0.4, 0.66, 0.8) * 0.75
    img = kleur((0.86, 0.85, 0.8)) * (0.9 + 0.1 * noise(size, 8, 63))[..., None]
    img = img * (1 - sl[..., None]) + kleur((0.3, 0.3, 0.29)) * sl[..., None]
    return save_img("straat_verf", img)


def ijzer_image(size=128):
    """Gietijzeren putdeksel (het hele plaatje is het deksel): rand, ringen, ribbels en roest."""
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size * 2 - 1
    r = np.sqrt(x * x + y * y)
    a = np.arctan2(y, x)
    h = np.full((size, size), 0.5)
    h = np.where(r > 0.86, 0.9, h)
    ring = (np.abs(r - 0.62) < 0.035) | (np.abs(r - 0.34) < 0.035) | (r < 0.1)
    rib = (np.abs(np.sin(a * 12)) < 0.18) & (r > 0.1) & (r < 0.86)
    ruit = ((np.floor((x + 1) * 7) + np.floor((y + 1) * 7)) % 2 == 0) & (r < 0.86)
    h = np.where(ring | rib, 0.85, np.where(ruit, 0.62, 0.5))
    img = kleur((0.2, 0.19, 0.18)) * (0.7 + 0.5 * h)[..., None]
    roest = sm(noise(size, 16, 71) * 0.7 + noise(size, 4, 72) * 0.3, 0.55, 0.75) * 0.6
    img = img * (1 - roest[..., None]) + kleur((0.38, 0.2, 0.1)) * roest[..., None]
    img = np.where((r > 0.97)[..., None], kleur((0.12, 0.12, 0.11)), img)
    return save_img("straat_ijzer", img)


def rooster_image(size=128):
    """Kolkrooster: ijzeren rand met sleuven."""
    y, x = np.mgrid[0:size, 0:size] / size
    gleuf = (np.abs(((x * 7) % 1) - 0.5) < 0.28) & (x > 0.1) & (x < 0.9) & (y > 0.16) & (y < 0.84)
    img = np.where(gleuf[..., None], kleur((0.03, 0.03, 0.03)), kleur((0.26, 0.24, 0.22)))
    roest = sm(noise(size, 16, 81), 0.55, 0.75) * 0.5
    img = img * (1 - roest[..., None]) + kleur((0.36, 0.2, 0.1)) * roest[..., None] * (~gleuf)[..., None]
    return save_img("straat_rooster", img)


def mat(name, color, rough=0.85, metal=0.0, image=None, normal=None, nstrength=1.0):
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
    if normal:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = normal
        nm = m.node_tree.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = nstrength
        m.node_tree.links.new(t.outputs["Color"], nm.inputs["Color"])
        m.node_tree.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    return m


stoep_img, stoep_n = stoep_image()
keien_img, keien_n = keien_image()
ASFALT = mat("Asfalt", (0.2, 0.2, 0.196), 0.92, image=asfalt_image())
STOEP = mat("Stoep", (0.5, 0.49, 0.45), 0.9, image=stoep_img, normal=stoep_n)
BAND = mat("Band", (0.56, 0.55, 0.51), 0.9)
KEIEN = mat("Keien", (0.47, 0.45, 0.42), 0.8, image=keien_img, normal=keien_n)
STEEN = mat("Steen", (0.72, 0.66, 0.55), 0.85, image=steen_image())
VERF = mat("Verf", (0.86, 0.85, 0.8), 0.7, image=verf_image())
IJZER = mat("Ijzer", (0.2, 0.19, 0.18), 0.55, 0.6, image=ijzer_image())
ROOSTER = mat("Rooster", (0.26, 0.24, 0.22), 0.6, 0.6, image=rooster_image())
WATER = mat("Water", (0.12, 0.2, 0.17), 0.05)
MATS = [ASFALT, STOEP, BAND, KEIEN, STEEN, VERF, IJZER, ROOSTER, WATER]
MI = {m.name: i for i, m in enumerate(MATS)}
# wereld-UV: meters per herhaling (zelfde getallen als Stad.WORLD_UV in het spel)
WORLD = {"Asfalt": 12.0, "Stoep": 1.2, "Keien": 1.0, "Steen": 2.0}


# ---------- bouwstenen ----------
class Stuk:
    """Eén wegdeel: een bmesh met UV-laag; vlakken met materiaal en UV per hoek."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, mat, uvs=None, up=None):
        """pts = 3D-punten; uvs = één (u, v) per punt, anders wereld-UV (bovenvlak) of langs de muur."""
        if up is not None:
            # zorg dat de normaal de goede kant op wijst
            a, b, c = (np.array(p) for p in pts[:3])
            n = np.cross(b - a, c - a)
            if len(pts) > 3 and np.linalg.norm(n) < 1e-9:
                n = np.cross(b - a, np.array(pts[3]) - a)
            if np.dot(n, up) < 0:
                pts = pts[::-1]
                uvs = uvs[::-1] if uvs else None
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = MI[mat.name]
        s = WORLD.get(mat.name, 1.0)
        for i, lp in enumerate(f.loops):
            if uvs:
                lp[self.uv].uv = uvs[i]
            else:
                p = lp.vert.co
                lp[self.uv].uv = (p.x / s, p.y / s)
        return f

    def top(self, pts2, z, mat):
        """Horizontaal vlak (veelhoek, mag hol zijn) op hoogte z, normaal omhoog."""
        a = sum(pts2[i][0] * pts2[(i + 1) % len(pts2)][1] - pts2[(i + 1) % len(pts2)][0] * pts2[i][1] for i in range(len(pts2)))
        if a < 0:
            pts2 = pts2[::-1]
        return self.face([(x, y, z) for x, y in pts2], mat)

    def wall(self, p0, p1, z0, z1, mat, inside):
        """Staande rand van p0 naar p1, normaal weg van het punt inside."""
        d = np.array(p1) - np.array(p0)
        n = np.array([d[1], -d[0], 0.0])
        mid = (np.array(p0) + np.array(p1)) / 2
        if np.dot(n[:2], np.array(inside) - mid) > 0:
            p0, p1 = p1, p0
        L = float(np.linalg.norm(d))
        pts = [(p0[0], p0[1], z0), (p1[0], p1[1], z0), (p1[0], p1[1], z1), (p0[0], p0[1], z1)]
        uvs = [(0, z0), (L, z0), (L, z1), (0, z1)]
        return self.face(pts, mat, uvs)

    def quad_uv(self, pts2, z, mat, uvs):
        a = sum(pts2[i][0] * pts2[(i + 1) % 4][1] - pts2[(i + 1) % 4][0] * pts2[i][1] for i in range(4))
        if a < 0:
            pts2, uvs = pts2[::-1], uvs[::-1]
        return self.face([(x, y, z) for x, y in pts2], mat, uvs)

    def obj(self, loc):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in MATS:
            me.materials.append(m)
        o = bpy.data.objects.new(self.name, me)
        o.location = (loc[0], loc[1], 0)
        scene.collection.objects.link(o)
        return o


def rot(p, k):
    """Draai een punt k kwartslagen tegen de klok in (gezien van boven)."""
    x, y = p
    for _ in range(k % 4):
        x, y = -y, x
    return (x, y)


def R(pts, k):
    return [rot(p, k) for p in pts]


def arc(c, r, a0, a1, n):
    return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def strip(s, k, inner=2.0, rand=True):
    """Stoep langs de westkant (gedraaid met k) van x = -C tot x = -inner, met stoeprand aan de wegkant."""
    band = [(-inner - BW, -C), (-inner, -C), (-inner, C), (-inner - BW, C)]
    tegel = [(-C, -C), (-inner - BW, -C), (-inner - BW, C), (-C, C)]
    s.top(R(band, k), SW, BAND)
    s.top(R(tegel, k), SW, STOEP)
    mid = rot((-(C + inner) / 2, 0), k)
    s.wall(rot((-inner, -C), k), rot((-inner, C), k), 0, SW, BAND, mid)        # stoeprand
    s.wall(rot((-C, -C), k), rot((-C, C), k), 0, SW, BAND, mid)                # achterkant (naar de gebouwen)
    for y in (-C, C):                                                         # kopse kanten (doodlopend)
        s.wall(rot((-C, y), k), rot((-inner, y), k), 0, SW, BAND, mid)


def hoek(s, k, r=1.0, n=6):
    """Ronde stoephoek in de noordoosthoek (gedraaid met k) tussen twee open zijden."""
    c = (C, C)
    buiten = arc(c, r, 180, 270, n)
    binnen = arc(c, r - BW, 180, 270, n)
    for i in range(n):
        s.top(R([buiten[i], buiten[i + 1], binnen[i + 1], binnen[i]], k), SW, BAND)
        s.wall(rot(buiten[i], k), rot(buiten[i + 1], k), 0, SW, BAND, rot(c, k))
    s.top(R([c] + binnen, k), SW, STOEP)
    mid = rot((C - r / 2, C - r / 2), k)
    s.wall(rot((C - r, C), k), rot((C, C), k), 0, SW, BAND, mid)
    s.wall(rot((C, C - r), k), rot((C, C), k), 0, SW, BAND, mid)


def buitenbocht(s, k, r=5.0, n=12):
    """Buitenkant van een bocht: alles in de cel buiten straal r rond de noordoosthoek."""
    c = (C, C)
    buiten = arc(c, r, 180, 270, n)
    rand = arc(c, r + BW, 180, 270, n)
    for i in range(n):
        s.top(R([buiten[i], buiten[i + 1], rand[i + 1], rand[i]], k), SW, BAND)
        s.wall(rot(buiten[i], k), rot(buiten[i + 1], k), 0, SW, BAND, rot((-C, -C), k))
    s.top(R(rand + [(C, -C), (-C, -C), (-C, C)], k), SW, STOEP)
    inside = rot((-C + 0.3, -C + 0.3), k)
    for a, b in (((-C, C), (-C, -C)), ((-C, -C), (C, -C)), ((-C, C), (-C + 1, C)), ((C, -C), (C, -C + 1))):
        s.wall(rot(a, k), rot(b, k), 0, SW, BAND, inside)


def asfalt(s, mat=ASFALT, w=C):
    s.top([(-w, -C), (w, -C), (w, C), (-w, C)], ASF, mat)


def streep(s, x0, y0, x1, y1, z=ASF + DET):
    """Rechthoekige verfstreep."""
    s.quad_uv([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z, VERF, [(0, 0), (1, 0), (1, (y1 - y0) / 1.5), (0, (y1 - y0) / 1.5)])


def boogstreep(s, c, r, a0, a1, w=0.12, n=4, z=ASF + DET):
    o = arc(c, r + w / 2, a0, a1, n)
    i = arc(c, r - w / 2, a0, a1, n)
    for j in range(n):
        s.quad_uv([o[j], o[j + 1], i[j + 1], i[j]], z, VERF, [(0, j / n), (0, (j + 1) / n), (1, (j + 1) / n), (1, j / n)])


def putdeksel(s, x, y, r=0.33, n=12, z=ASF + DET):
    pts = arc((x, y), r, 0, 360, n)[:-1]
    for j in range(n):
        a, b = pts[j], pts[(j + 1) % n]
        uv = lambda p: (0.5 + (p[0] - x) / (2 * r), 0.5 + (p[1] - y) / (2 * r))
        s.face([(x, y, z), (a[0], a[1], z), (b[0], b[1], z)], IJZER, [uv((x, y)), uv(a), uv(b)], up=(0, 0, 1))


def kolk(s, x, y, along_y=True, z=ASF + DET):
    """Kolkrooster tegen de stoeprand (0,5 x 0,25 m)."""
    hx, hy = (0.13, 0.25) if along_y else (0.25, 0.13)
    uvs = [(0, 0), (1, 0), (1, 1), (0, 1)] if not along_y else [(0, 1), (0, 0), (1, 0), (1, 1)]
    s.quad_uv([(x - hx, y - hy), (x + hx, y - hy), (x + hx, y + hy), (x - hx, y + hy)], z, ROOSTER, uvs)


def dashes_ns(s):
    for y0 in (-2.25, 0.75):
        streep(s, -0.06, y0, 0.06, y0 + 1.5)


# ---------- wegdelen ----------
objs = []
plek = {"Recht": (0, 0), "Bocht": (7, 0), "TStuk": (14, 0), "Kruis": (21, 0), "Steeg": (0, -7), "Zebra": (7, -7), "Stoep": (14, -7),
        "Plein": (24, -10), "Fontein": (24, -10)}

s = Stuk("Recht")
asfalt(s)
strip(s, 0)
strip(s, 2)
dashes_ns(s)
putdeksel(s, 1.0, 0.0)
kolk(s, 1.87, -1.6)
kolk(s, -1.87, 1.6)
objs.append(s.obj(plek["Recht"]))

s = Stuk("Bocht")
asfalt(s)
buitenbocht(s, 0)
hoek(s, 0)
boogstreep(s, (C, C), 3.0, 180 + 0.75 / 3 * 180 / math.pi, 180 + 2.0 / 3 * 180 / math.pi)
boogstreep(s, (C, C), 3.0, 180 + 2.71 / 3 * 180 / math.pi, 180 + 3.96 / 3 * 180 / math.pi)
kolk(s, -1.0, -1.6, False)
objs.append(s.obj(plek["Bocht"]))

s = Stuk("TStuk")
asfalt(s)
strip(s, 0)
hoek(s, 0)
hoek(s, 3)
putdeksel(s, 0.3, 0.0)
kolk(s, -1.87, -1.4)
objs.append(s.obj(plek["TStuk"]))

s = Stuk("Kruis")
asfalt(s)
for k in range(4):
    hoek(s, k)
putdeksel(s, 0.0, 0.0, 0.38)
objs.append(s.obj(plek["Kruis"]))

s = Stuk("Steeg")
s.top([(-1, -C), (1, -C), (1, C), (-1, C)], ASF, KEIEN)
strip(s, 0, 1.0)
strip(s, 2, 1.0)
putdeksel(s, 0.0, 1.2, 0.3)
objs.append(s.obj(plek["Steeg"]))

s = Stuk("Zebra")
asfalt(s)
strip(s, 0)
strip(s, 2)
for x in (-1.6, -0.8, 0.0, 0.8, 1.6):
    streep(s, x - 0.21, -1.25, x + 0.21, 1.25)
kolk(s, 1.87, -2.2)
objs.append(s.obj(plek["Zebra"]))

s = Stuk("Stoep")
s.top([(-C, -C), (C, -C), (C, C), (-C, C)], SW, STOEP)
for k in range(4):
    a, b = rot((-C, -C), k), rot((C, -C), k)
    s.wall(a, b, 0, SW, BAND, (0, 0))
objs.append(s.obj(plek["Stoep"]))

# plein: keien, stenen rand van 0,5 m, stenen cirkel om de fontein
P, PR = 6.0, 5.5
s = Stuk("Plein")
n = 32
for i in range(n):
    a0, a1 = 360 * i / n, 360 * (i + 1) / n

    def sq(a):
        c, si = math.cos(math.radians(a)), math.sin(math.radians(a))
        t = PR / max(abs(c), abs(si))
        return (t * c, t * si)

    def cp(a, r):
        return (r * math.cos(math.radians(a)), r * math.sin(math.radians(a)))

    s.top([cp(a0, 3.4), cp(a1, 3.4), sq(a1), sq(a0)], SW, KEIEN)
    s.top([cp(a0, 3.0), cp(a1, 3.0), cp(a1, 3.4), cp(a0, 3.4)], SW, STEEN)
    s.top([(0, 0), cp(a0, 3.0), cp(a1, 3.0)], SW, KEIEN)
for k in range(4):
    s.top(R([(-P, -P), (P, -P), (PR, -PR), (-PR, -PR)], k), SW, STEEN)
    s.wall(rot((-P, -P), k), rot((P, -P), k), 0, SW, STEEN, (0, 0))
objs.append(s.obj(plek["Plein"]))

# fontein: ronde bak met water, zuil met schaal
s = Stuk("Fontein")
n = 16
B0, B1, BH, WZ = 1.9, 1.65, SW + 0.5, SW + 0.4
o = arc((0, 0), B0, 0, 360, n)
i_ = arc((0, 0), B1, 0, 360, n)
for j in range(n):
    s.wall(o[j], o[j + 1], SW, BH, STEEN, (0, 0))
    s.wall(i_[j], i_[j + 1], WZ, BH, STEEN, (B0 * 3 * math.cos(math.radians(360 * (j + .5) / n)), B0 * 3 * math.sin(math.radians(360 * (j + .5) / n))))
    s.top([o[j], o[j + 1], i_[j + 1], i_[j]], BH, STEEN)
    s.top([(0, 0), i_[j], i_[j + 1]], WZ, WATER)


def ring_cyl(r0, r1, z0, z1, segs, mat, cap=False):
    a = arc((0, 0), r0, 0, 360, segs)
    b = arc((0, 0), r1, 0, 360, segs)
    for j in range(segs):
        L = 2 * math.pi * r0 / segs
        p = [(a[j][0], a[j][1], z0), (a[j + 1][0], a[j + 1][1], z0), (b[j + 1][0], b[j + 1][1], z1), (b[j][0], b[j][1], z1)]
        mid = ((a[j][0] + b[j + 1][0]) / 2, (a[j][1] + b[j + 1][1]) / 2, 0)
        s.face(p, mat, [(0, z0), (L, z0), (L, z1), (0, z1)], up=mid)
    if cap:
        s.top(b[:-1], z1, mat)


ring_cyl(0.32, 0.26, WZ, 1.5, 8, STEEN)
ring_cyl(0.26, 0.75, 1.5, 1.72, 10, STEEN)
s.top(arc((0, 0), 0.75, 0, 360, 10)[:-1], 1.72, WATER)
ring_cyl(0.12, 0.08, 1.72, 2.1, 6, STEEN)
ring_cyl(0.08, 0.16, 2.1, 2.22, 6, STEEN, True)
objs.append(s.obj(plek["Fontein"]))

# ---------- afwerking ----------
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "straat.glb"), export_format="GLB", export_apply=True, export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "straat.blend"))
tris = {}
for o in objs:
    o.data.calc_loop_triangles()
    tris[o.name] = len(o.data.loop_triangles)
print("TRIS", tris, "TOTAAL", sum(tris.values()))
