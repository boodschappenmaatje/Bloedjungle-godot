"""Straatmeubilair voor de stad achter de brug (Bloedjungle): lantaarn, bankje, bushokje, prullenbak, hek, zandzakken, puin,
boom, struik en vier nieuwe dingen: brandkraan, vuilcontainer, verkeersbord en stoplicht. Met eigen texturen (klein, voor de iPhone).
Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden op de grond, voorkant aan -Y (wordt +Z in Godot).
Gebruik: python3 maak_straatmeubilair.py <uitmap>  ->  straatmeubilair.glb, straatmeubilair.blend

Elk ding is één object met één mesh en een vlak per materiaal; het spel (Stad._prop) pakt de mesh bij naam en zet er zelf de
botsvorm omheen. Objecten: Lantaarn, Bankje, Bushokje, Prullenbak, Hek, Zandzakken, Puin, Boom, Struik, Brandkraan, Container,
Bord, Stoplicht. De lamp van de lantaarn heeft een emissief materiaal ('LampGlas') dat het spel 's avonds aan kan zetten.
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector, Euler

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- texturen ----------
def noise(size, scale, seed, sy=None):
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


def kleur(c):
    return np.array(c)[None, None, :]


def save_img(name, img, non_color=False):
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


def hout_image(size=256):
    """Verweerd hout: lange nerf, vergrijsd, donkere kwasten (1 herhaling = 1 m)."""
    n = noise(size, 4, 1, 128)
    img = kleur((0.46, 0.34, 0.22)) * (0.7 + 0.5 * n[..., None]) * (0.9 + 0.2 * noise(size, 16, 2, 64)[..., None])
    grijs = sm(noise(size, 32, 3, 128), 0.45, 0.8) * 0.5
    img = img * (1 - grijs[..., None]) + kleur((0.5, 0.47, 0.42)) * grijs[..., None]
    kwast = sm(noise(size, 32, 4, 128), 0.7, 0.95)
    img = img * (1 - 0.25 * kwast[..., None])
    y = np.mgrid[0:size, 0:size][0]
    img = np.where(((y % (size // 4)) < 2)[..., None], img * 0.45, img)   # voegen tussen planken
    return save_img("sm_hout", img)


def bast_image(size=256):
    """Boombast: verticale groeven, bruingrijs, mos aan één kant."""
    n = noise(size, 8, 11, 128)
    img = kleur((0.36, 0.28, 0.2)) * (0.55 + 0.7 * n[..., None]) * (0.85 + 0.3 * noise(size, 32, 12)[..., None])
    mos = sm(noise(size, 32, 13), 0.55, 0.75) * 0.5
    img = img * (1 - mos[..., None]) + kleur((0.2, 0.3, 0.12)) * mos[..., None]
    return save_img("sm_bast", img)


def blad_image(size=256):
    """Bladerdak: donker- en lichtgroene vlekken met gele plekken (jungle)."""
    n = noise(size, 8, 21) * 0.5 + noise(size, 32, 22) * 0.5
    img = kleur((0.09, 0.22, 0.08)) * (0.7 + 0.9 * n[..., None])
    licht = sm(noise(size, 16, 23), 0.55, 0.8) * 0.5
    img = img * (1 - licht[..., None]) + kleur((0.26, 0.4, 0.11)) * licht[..., None]
    geel = sm(noise(size, 32, 24), 0.7, 0.85) * 0.3
    img = img * (1 - geel[..., None]) + kleur((0.5, 0.48, 0.15)) * geel[..., None]
    return save_img("sm_blad", img)


def metaal_image(size=256):
    """Donkergroen gelakt staal: verf die loslaat, roest eronder, vuil onderaan (v = hoogte / 1 m)."""
    v = (1 - np.mgrid[0:size, 0:size][0] / size)[..., None]
    img = kleur((0.17, 0.25, 0.19)) * (0.8 + 0.3 * noise(size, 32, 31)[..., None])
    kaal = sm(noise(size, 16, 32) * 0.6 + noise(size, 4, 33) * 0.4, 0.68, 0.76)
    img = img * (1 - kaal[..., None]) + kleur((0.34, 0.18, 0.09)) * kaal[..., None]
    streep = sm(noise(size, 4, 34, 128), 0.6, 0.85) * (v[..., 0] < 0.5) * 0.4
    img = img * (1 - streep[..., None]) + kleur((0.3, 0.17, 0.09)) * streep[..., None]
    vuil = np.clip(1 - v / 0.2, 0, 1) * 0.4
    img = img * (1 - vuil) + kleur((0.15, 0.13, 0.1)) * vuil
    return save_img("sm_metaal", img)


def zak_image(size=128):
    """Jute zandzak: weefsel in twee richtingen, zand dat doorschemert."""
    y, x = np.mgrid[0:size, 0:size]
    weef = 0.75 + 0.25 * (((x // 2) + (y // 2)) % 2)
    img = kleur((0.55, 0.47, 0.3)) * (weef * (0.8 + 0.4 * noise(size, 16, 41)))[..., None]
    vlek = sm(noise(size, 32, 42), 0.55, 0.8) * 0.4
    img = img * (1 - vlek[..., None]) + kleur((0.3, 0.26, 0.17)) * vlek[..., None]
    return save_img("sm_zak", img)


def beton_image(size=256):
    """Gebroken beton en baksteen: grijs met grove korrel, roestvlekken."""
    n = noise(size, 4, 51) * 0.5 + noise(size, 32, 52) * 0.5
    img = kleur((0.42, 0.4, 0.37)) * (0.6 + 0.8 * n[..., None])
    steen = sm(noise(size, 64, 53), 0.64, 0.7)
    img = img * (1 - steen[..., None]) + kleur((0.45, 0.22, 0.14)) * (0.7 + 0.5 * n[..., None]) * steen[..., None]
    roest = sm(noise(size, 16, 54), 0.7, 0.85) * 0.4
    img = img * (1 - roest[..., None]) + kleur((0.4, 0.22, 0.12)) * roest[..., None]
    return save_img("sm_beton", img)


def bord_image(size=128):
    """Verkeersbord: wit met rode rand en witte balk (verboden in te rijden), vuil en deuken."""
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size * 2 - 1
    r = np.sqrt(x * x + y * y)
    img = np.where((r < 0.82)[..., None], kleur((0.75, 0.12, 0.1)), kleur((0.82, 0.82, 0.78)))
    img = np.where(((r < 0.82) & (np.abs(y) < 0.14) & (np.abs(x) < 0.6))[..., None], kleur((0.88, 0.87, 0.82)), img)
    img = np.where((r > 0.97)[..., None], kleur((0.45, 0.45, 0.43)), img)
    vuil = sm(noise(size, 16, 61) * 0.6 + noise(size, 4, 62) * 0.4, 0.55, 0.8) * 0.5
    img = img * (1 - vuil[..., None]) + kleur((0.35, 0.32, 0.25)) * vuil[..., None]
    return save_img("sm_bord", img)


def mat(name, color, rough=0.85, metal=0.0, image=None, emit=None, strength=0.0):
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
    return m


HOUT = mat("Hout", (0.46, 0.34, 0.22), 0.85, image=hout_image())
BAST = mat("Bast", (0.36, 0.28, 0.2), 1.0, image=bast_image())
BLAD = mat("Blad", (0.2, 0.4, 0.14), 0.8, image=blad_image())
METAAL = mat("Metaal", (0.17, 0.25, 0.19), 0.6, 0.3, image=metaal_image())
ZAK = mat("Zak", (0.55, 0.47, 0.3), 1.0, image=zak_image())
BETON = mat("Beton", (0.5, 0.48, 0.44), 0.95, image=beton_image())
BORD = mat("Bord", (0.8, 0.8, 0.78), 0.5, image=bord_image())
ZWART = mat("Zwart", (0.1, 0.1, 0.1), 0.6, 0.4)
IJZER = mat("IJzer", (0.14, 0.14, 0.13), 0.5, 0.7)
GLAS = mat("Glas", (0.4, 0.55, 0.55), 0.05, 0.2)
LAMPGLAS = mat("LampGlas", (1.0, 0.85, 0.55), 0.3, emit=(1.0, 0.8, 0.45), strength=3.0)
ROOD = mat("Rood", (0.7, 0.1, 0.08), 0.5)
GROEN = mat("Groen", (0.1, 0.5, 0.15), 0.5)
ORANJE = mat("Oranje", (0.85, 0.5, 0.1), 0.5)
ROEST = mat("Roest", (0.35, 0.18, 0.1), 0.9, 0.3)
MATS = [HOUT, BAST, BLAD, METAAL, ZAK, BETON, BORD, ZWART, IJZER, GLAS, LAMPGLAS, ROOD, GROEN, ORANJE, ROEST]
MI = {m.name: i for i, m in enumerate(MATS)}
SCHAAL = {"Hout": 1.0, "Bast": 1.0, "Blad": 2.0, "Metaal": 1.0, "Zak": 0.5, "Beton": 1.0, "Bord": 1.0}   # meters per herhaling


# ---------- bouwstenen ----------
class Ding:
    """Eén straatding: alle delen in één bmesh; per deel materiaal en een eigen UV (dozen: per vlak, cilinders: rondom)."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _fin(self, geom_faces, mat, m, cyl=None):
        s = SCHAAL.get(mat.name, 1.0)
        for f in geom_faces:
            f.material_index = MI[mat.name]
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for lp in f.loops:
                p = lp.vert.co
                if cyl is not None and ax != 2:
                    a = math.atan2(p.y, p.x)
                    uv = (a * cyl / s, p.z / s)
                elif ax == 0:
                    uv = (p.y / s, p.z / s)
                elif ax == 1:
                    uv = (p.x / s, p.z / s)
                else:
                    uv = (p.x / s, p.y / s)
                lp[self.uv].uv = uv
        bmesh.ops.transform(self.bm, matrix=m, verts=list({v for f in geom_faces for v in f.verts}))

    def box(self, c, size, mat, rot=(0, 0, 0)):
        r = bmesh.ops.create_cube(self.bm, size=1)
        bmesh.ops.scale(self.bm, vec=size, verts=r["verts"])
        fs = list({f for v in r["verts"] for f in v.link_faces})
        m = Matrix.Translation(c) @ Euler(rot).to_matrix().to_4x4()
        self._fin(fs, mat, m)
        return self

    def cyl(self, c, r0, r1, h, mat, segs=10, rot=(0, 0, 0), cap=True):
        """Kegelstomp: straal r0 onder, r1 boven; c = midden van het onderste vlak."""
        r = bmesh.ops.create_cone(self.bm, cap_ends=cap, segments=segs, radius1=r0, radius2=r1, depth=h)
        bmesh.ops.translate(self.bm, vec=(0, 0, h / 2), verts=r["verts"])
        fs = list({f for v in r["verts"] for f in v.link_faces})
        m = Matrix.Translation(c) @ Euler(rot).to_matrix().to_4x4()
        self._fin(fs, mat, m, cyl=(r0 + r1) / 2)
        return self

    def blob(self, c, rad, mat, squash=1.0, seed=0, sub=1, jit=0.18):
        """Onregelmatige bol (bladerdak, struik, zandzak, brok)."""
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=1.0)
        rng = np.random.default_rng(seed)
        for v in r["verts"]:
            v.co = v.co * (1 + rng.uniform(-jit, jit))
        bmesh.ops.scale(self.bm, vec=(rad[0], rad[1], rad[2] * squash) if isinstance(rad, tuple) else (rad, rad, rad * squash), verts=r["verts"])
        fs = list({f for v in r["verts"] for f in v.link_faces})
        self._fin(fs, mat, Matrix.Translation(c))
        return self

    def tube(self, pts, radii, mat, sides=7):
        """Buis langs een lijn van punten met per punt een straal (waterstraal, boog). Gladde schaduw, dichte uiteinden."""
        rings = []
        for i, c in enumerate(pts):
            c = Vector(c)
            d = (Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
            a_ = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
            u = d.cross(a_).normalized()
            v = d.cross(u).normalized()
            ring = []
            for k in range(sides):
                t = 2 * math.pi * k / sides
                ring.append(self.bm.verts.new(c + (u * math.cos(t) + v * math.sin(t)) * radii[i]))
            rings.append(ring)
        fs = []
        for i in range(len(rings) - 1):
            for k in range(sides):
                f = self.bm.faces.new([rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]])
                fs.append(f)
        fs.append(self.bm.faces.new(rings[0][::-1]))
        fs.append(self.bm.faces.new(rings[-1]))
        for f in fs:
            f.material_index = MI[mat.name]
        return self

    def obj(self, loc, smooth=False):
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in MATS:
            me.materials.append(m)
        for p in me.polygons:
            p.use_smooth = smooth
        o = bpy.data.objects.new(self.name, me)
        o.location = (loc[0], loc[1], 0)
        scene.collection.objects.link(o)
        return o


objs = []
rng = np.random.default_rng(5)

# ---------- lantaarn: gietijzeren paal met sierring, bocht en lampkap (voorkant = -Y) ----------
d = Ding("Lantaarn")
d.cyl((0, 0, 0), 0.2, 0.15, 0.35, IJZER, 8)
d.cyl((0, 0, 0.35), 0.1, 0.075, 3.5, METAAL, 8)
d.cyl((0, 0, 0.35), 0.13, 0.13, 0.08, IJZER, 8)
d.cyl((0, 0, 1.7), 0.095, 0.095, 0.06, IJZER, 8)
d.cyl((0, 0, 3.8), 0.09, 0.07, 0.12, IJZER, 8)
d.box((0, -0.15, 3.95), (0.09, 0.45, 0.08), IJZER, (0.25, 0, 0))
d.box((0, -0.55, 4.0), (0.09, 0.5, 0.08), IJZER)
d.box((0, -0.7, 3.9), (0.34, 0.5, 0.05), IJZER)          # kap boven
d.box((0, -0.7, 3.78), (0.28, 0.42, 0.18), LAMPGLAS)
d.box((0, -0.7, 3.67), (0.34, 0.5, 0.04), IJZER)         # kap onder
objs.append(d.obj((0, 0)))

# ---------- bankje: houten latten op gietijzeren zijkanten met leuning ----------
d = Ding("Bankje")
for i in range(4):
    d.box((0, -0.12 + i * 0.1, 0.45), (1.8, 0.085, 0.04), HOUT)
for i in range(3):
    d.box((0, 0.22, 0.62 + i * 0.1), (1.8, 0.035, 0.08), HOUT)
d.box((0, 0.22, 0.7), (1.78, 0.02, 0.3), HOUT).box((0, 0.2, 0.3), (1.8, 0.06, 0.04), IJZER)
for sx in (-0.8, 0.8):
    d.box((sx, 0.0, 0.2), (0.07, 0.5, 0.4), IJZER)
    d.box((sx, 0.2, 0.62), (0.07, 0.05, 0.5), IJZER, (-0.1, 0, 0))
    d.box((sx, -0.1, 0.62), (0.07, 0.4, 0.04), IJZER)
objs.append(d.obj((3, 0)))

# ---------- bushokje: dak, glazen achterwand en zijkant, reclamepaneel, bank ----------
d = Ding("Bushokje")
for sx in (-1.55, 1.55):
    d.box((sx, 0.55, 1.1), (0.1, 0.1, 2.2), METAAL)
d.box((0, 0.6, 1.1), (3.1, 0.03, 2.2), GLAS)
d.box((-1.55, 0.0, 1.1), (0.03, 1.1, 2.2), GLAS)
d.box((0, 0.1, 2.24), (3.5, 1.4, 0.1), METAAL)
d.box((0, 0.1, 2.32), (3.5, 1.4, 0.04), IJZER)
d.box((1.0, 0.57, 1.2), (1.1, 0.05, 1.5), ZWART)          # reclamepaneel met kader
d.box((1.0, 0.54, 1.2), (0.96, 0.03, 1.36), ORANJE)
d.box((0.4, 0.2, 0.46), (2.0, 0.4, 0.06), HOUT)
d.box((0.4, 0.4, 0.8), (2.0, 0.05, 0.6), HOUT)
for sx in (-0.5, 1.3):
    d.box((sx, 0.2, 0.23), (0.06, 0.4, 0.46), IJZER)
d.box((-1.4, -0.1, 1.1), (0.08, 0.08, 2.2), IJZER)       # paal met haltebord
d.cyl((-1.5, -0.55, 0), 0.04, 0.04, 2.9, METAAL, 6)
d.cyl((-1.5, -0.55, 2.55), 0.3, 0.3, 0.04, ORANJE, 12, (math.pi / 2, 0, 0))
objs.append(d.obj((7, 0)))

# ---------- prullenbak: groene stalen ton met rand en deksel ----------
d = Ding("Prullenbak")
d.cyl((0, 0, 0.03), 0.24, 0.27, 0.8, METAAL, 10)
d.cyl((0, 0, 0.03), 0.27, 0.27, 0.05, IJZER, 10)
d.cyl((0, 0, 0.55), 0.28, 0.28, 0.04, IJZER, 10)
d.cyl((0, 0, 0.83), 0.3, 0.26, 0.07, IJZER, 10)
d.cyl((0, 0, 0.86), 0.2, 0.2, 0.01, ZWART, 10)
d.box((0, 0, 0.0), (0.12, 0.5, 0.06), IJZER)
objs.append(d.obj((9, 0)))

# ---------- hek: houten palen met kap en twee liggers, pootjes ----------
d = Ding("Hek")
for x in (-1.4, 0.0, 1.4):
    d.box((x, 0, 0.6), (0.1, 0.1, 1.2), HOUT)
    d.box((x, 0, 1.22), (0.14, 0.14, 0.04), HOUT)
for z in (0.45, 0.9):
    d.box((0, 0.06, z), (3.0, 0.04, 0.09), HOUT)
for x in (-0.7, 0.7):
    d.box((x, 0.06, 0.68), (0.07, 0.03, 0.9), HOUT)
objs.append(d.obj((11, 0)))

# ---------- zandzakken: drie lagen, verspringend, elk een eigen vorm ----------
d = Ding("Zandzakken")
sd = 0
for laag in range(3):
    n = 4 if laag % 2 == 0 else 3
    for i in range(n):
        x = (i - (n - 1) / 2) * 0.78 + rng.uniform(-0.03, 0.03)
        sd += 1
        d.blob((x, rng.uniform(-0.04, 0.04), 0.15 + laag * 0.27), (0.44, 0.24, 0.2), ZAK, 1.0, sd, 1, 0.06)
objs.append(d.obj((13, 0)))

# ---------- puin: gebroken platen, brokken en betonijzer ----------
d = Ding("Puin")
for i, (x, y, z, sx, sy, sz, rx, ry, rz) in enumerate((
        (0, 0, 0.2, 1.6, 1.1, 0.4, 0.1, 0.0, 0.3), (0.4, -0.3, 0.55, 0.9, 0.8, 0.3, -0.2, 0.2, 1.0),
        (-0.6, 0.5, 0.15, 1.1, 0.7, 0.3, 0.0, 0.15, -0.5), (0.7, 0.6, 0.2, 0.5, 0.5, 0.4, 0.3, 0.1, 0.6))):
    d.box((x, y, z), (sx, sy, sz), BETON, (rx, ry, rz))
for i in range(6):
    d.blob((rng.uniform(-0.9, 0.9), rng.uniform(-0.8, 0.8), 0.12), (0.18, 0.15, 0.12), BETON, 1.0, 70 + i, 1, 0.3)
for i in range(4):
    d.cyl((rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.4), 0.4), 0.012, 0.012, rng.uniform(0.5, 0.9), ROEST, 4, (rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0))
objs.append(d.obj((15, 0)))

# ---------- boom: stam met wortelaanzet, twee takken, vier bladerkronen ----------
d = Ding("Boom")
d.cyl((0, 0, 0), 0.48, 0.3, 0.7, BAST, 8)
d.cyl((0, 0, 0.6), 0.3, 0.2, 3.6, BAST, 8)
d.cyl((0.1, 0, 3.0), 0.09, 0.05, 1.6, BAST, 5, (0.0, 0.7, 0))
d.cyl((-0.1, 0, 3.4), 0.08, 0.05, 1.4, BAST, 5, (0.3, -0.6, 0))
for i, (x, y, z, r) in enumerate(((0, 0, 5.2, 1.6), (1.1, 0.2, 4.4, 1.2), (-0.9, -0.5, 4.8, 1.3), (0.2, 0.9, 5.9, 1.1))):
    d.blob((x, y, z), r, BLAD, 0.8, 200 + i, 1, 0.22)
objs.append(d.obj((18, 0)))

# ---------- struik ----------
d = Ding("Struik")
for i, (x, y, z, r) in enumerate(((0, 0, 0.5, 0.75), (0.6, 0.2, 0.4, 0.5), (-0.5, -0.3, 0.4, 0.55))):
    d.blob((x, y, z), r, BLAD, 0.7, 300 + i, 1, 0.25)
objs.append(d.obj((21, 0)))

# ---------- vuilcontainer: groene bak met ribben, deksel en wieltjes ----------
d = Ding("Container")
d.box((0, 0, 0.65), (1.8, 0.85, 0.85), METAAL)
d.box((0, 0, 1.12), (1.9, 0.95, 0.07), IJZER, (0.04, 0, 0))
d.box((0, 0.4, 1.0), (1.86, 0.06, 0.14), IJZER)
for x in (-0.6, 0.0, 0.6):
    d.box((x, -0.435, 0.65), (0.07, 0.03, 0.85), IJZER)
d.box((0, -0.4, 0.7), (1.2, 0.02, 0.3), BORD)
for sx in (-0.75, 0.75):
    for sy in (-0.3, 0.3):
        d.cyl((sx, sy, 0.0), 0.1, 0.1, 0.07, ZWART, 8, (0, math.pi / 2, 0))
d.box((0, -0.5, 1.1), (1.0, 0.08, 0.05), IJZER)   # handgreep
objs.append(d.obj((27, 0)))

# ---------- verkeersbord: paal met rond bord ----------
d = Ding("Bord")
d.cyl((0, 0, 0), 0.04, 0.04, 2.5, METAAL, 6)
d.cyl((0, -0.05, 2.05), 0.34, 0.34, 0.03, BORD, 16, (math.pi / 2, 0, 0))
d.cyl((0, -0.03, 2.05), 0.36, 0.36, 0.02, IJZER, 16, (math.pi / 2, 0, 0))
d.box((0, 0.0, 1.95), (0.1, 0.04, 0.05), IJZER)
objs.append(d.obj((29, 0)))

# ---------- stoplicht: paal met kast, drie lampen en een klein overkapje ----------
d = Ding("Stoplicht")
d.cyl((0, 0, 0), 0.1, 0.06, 3.0, METAAL, 8)
d.box((0, -0.1, 3.2), (0.3, 0.2, 0.9), ZWART)
d.box((0, -0.22, 3.51), (0.3, 0.25, 0.04), ZWART)
d.box((0, -0.22, 3.2), (0.3, 0.25, 0.04), ZWART)
d.box((0, -0.22, 2.89), (0.3, 0.25, 0.04), ZWART)
for z, m in ((3.5, ROOD), (3.2, ORANJE), (2.9, GROEN)):
    d.cyl((0, -0.2, z), 0.09, 0.09, 0.03, m, 10, (math.pi / 2, 0, 0))
objs.append(d.obj((31, 0)))

# ---------- brandkraan met animatie: romp, dop die eraf knalt en een straal van 3 m hoog ----------
WATER = mat("Water", (0.78, 0.9, 0.96), 0.04)
WATER.surface_render_method = "BLENDED"
WATER.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.5
SCHUIM = mat("Schuim", (0.95, 0.98, 1.0), 0.15)
SCHUIM.surface_render_method = "BLENDED"
SCHUIM.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.32
FPS, T_LUS, N_LUS = 30, 1.5, 45          # een druppelcyclus duurt 1,5 s (45 beeldjes); de uitbarsting 3 s (twee cycli)
N_SPUIT = 90
ZN = 0.8                                  # hoogte van de opening waar het water uitkomt
MATS.append(WATER)
MATS.append(SCHUIM)
MI["Schuim"] = len(MATS) - 1
scene.render.fps = FPS
MI["Water"] = len(MATS) - 2

hyd_root = bpy.data.objects.new("Brandkraan", None)
scene.collection.objects.link(hyd_root)
hyd_root.location = (33, 0, 0)

d = Ding("Romp")
d.cyl((0, 0, 0), 0.18, 0.17, 0.05, IJZER, 10)                       # voetplaat met boutjes
for i in range(4):
    a_ = i * math.pi / 2 + 0.4
    d.cyl((0.14 * math.cos(a_), 0.14 * math.sin(a_), 0.05), 0.018, 0.018, 0.025, IJZER, 5)
d.cyl((0, 0, 0.05), 0.13, 0.11, 0.1, ROOD, 10)                      # onderstuk
d.cyl((0, 0, 0.15), 0.105, 0.095, 0.42, ROOD, 10)                   # romp
d.cyl((0, 0, 0.3), 0.115, 0.115, 0.035, IJZER, 10)                  # ring
d.cyl((0, 0, 0.56), 0.125, 0.115, 0.05, ROOD, 10)                   # bovenrand
d.cyl((0, 0, 0.61), 0.09, 0.09, 0.01, ZWART, 10)                    # opening als de dop weg is
for sx in (-1, 1):                                                  # twee zijuitgangen met dop
    d.cyl((sx * 0.08, 0, 0.4), 0.06, 0.06, 0.1, ROOD, 8, (0, sx * math.pi / 2, 0))
    d.cyl((sx * 0.17, 0, 0.4), 0.072, 0.072, 0.045, IJZER, 8, (0, sx * math.pi / 2, 0))
    d.cyl((sx * 0.215, 0, 0.4), 0.03, 0.03, 0.02, IJZER, 5, (0, sx * math.pi / 2, 0))
d.cyl((0, -0.08, 0.34), 0.085, 0.085, 0.1, ROOD, 10, (math.pi / 2, 0, 0))   # grote pompaansluiting voor
d.cyl((0, -0.17, 0.34), 0.1, 0.1, 0.05, IJZER, 10, (math.pi / 2, 0, 0))
d.cyl((0, -0.225, 0.34), 0.04, 0.04, 0.025, IJZER, 5, (math.pi / 2, 0, 0))
romp = d.obj((0, 0))

d = Ding("Dop")
d.cyl((0, 0, -0.04), 0.125, 0.12, 0.07, ROOD, 10)
d.blob((0, 0, 0.0), 0.11, ROOD, 0.85, 500, 1, 0.0)
d.cyl((0, 0, 0.08), 0.035, 0.03, 0.06, IJZER, 5)                    # vijfhoekige bedieningsmoer
dop = d.obj((0, 0))
dop.location = (0, 0, 0.66)

rg = np.random.default_rng(77)
G = 9.81
d = Ding("Straal")        # waterkolom in het midden met een krans van dunne bogen die naar buiten vallen (draait langzaam rond)
d.tube([(0, 0, z) for z in np.linspace(0, 2.15, 12)], [0.1 - 0.06 * (i / 11) ** 0.8 for i in range(12)], WATER, 9)
for k in range(10):
    a_ = 2 * math.pi * k / 10 + rg.uniform(-0.2, 0.2)
    v0, vh = rg.uniform(6.1, 6.65), rg.uniform(0.45, 1.25)
    fl = (v0 + math.sqrt(v0 ** 2 + 2 * G * (ZN - 0.1))) / G   # tot de boog de grond raakt
    pts, rad = [], []
    for i in range(16):
        t = fl * 0.97 * i / 15
        pts.append((vh * math.cos(a_) * t, vh * math.sin(a_) * t, v0 * t - 0.5 * G * t * t))
        rad.append(0.034 - 0.018 * i / 15)
    d.tube(pts, rad, SCHUIM, 6)
straal = d.obj((0, 0), smooth=True)
straal.location = (0, 0, ZN - 0.1)

# druppels: één gedeelde gladde mesh, 24 objecten met eigen baan
dr = Ding("Druppel")
dr.blob((0, 0, 0), (0.035, 0.035, 0.035), WATER, 1.35, 600, 1, 0.05)
dr.obj((0, 0), smooth=True)
druppel_mesh = bpy.context.scene.objects["Druppel"].data
bpy.data.objects.remove(bpy.context.scene.objects["Druppel"])
druppels = []
for i in range(24):
    o = bpy.data.objects.new("Druppel%02d" % i, druppel_mesh)
    scene.collection.objects.link(o)
    druppels.append({
        "o": o, "phi": (i + rg.uniform(-0.3, 0.3)) / 24, "v0": rg.uniform(5.6, 6.65), "vh": rg.uniform(0.2, 1.5),
        "ang": rg.uniform(0, 2 * math.pi), "sz": rg.uniform(0.6, 1.5)})
for e in (romp, dop, straal) + tuple(x["o"] for x in druppels):
    e.parent = hyd_root


def vlucht(x, tau):
    """Plek en zichtbaarheid van een druppel op tijd tau (s) in de lus."""
    t = (tau + x["phi"] * T_LUS) % T_LUS
    flight = (x["v0"] + math.sqrt(x["v0"] ** 2 + 2 * G * ZN)) / G
    if t > flight:
        return (0, 0, 0.02), 0.0
    z = ZN + x["v0"] * t - 0.5 * G * t * t
    return (x["vh"] * math.cos(x["ang"]) * t, x["vh"] * math.sin(x["ang"]) * t, max(z, 0.02)), x["sz"] * (1.0 if t > 0.03 else 0.0)


def dop_baan():
    """Dop schiet omhoog, tuimelt en stuitert tot hij stilligt (balistisch, per beeldje)."""
    pos, vel = np.array([0.0, 0.0, 0.66]), np.array([1.5, -1.0, 6.3])
    ang, om = np.zeros(3), np.array([9.0, 5.0, 7.0])
    keys = []
    sub = 6
    for f in range(N_SPUIT + 1):
        keys.append((tuple(pos), tuple(ang)))
        for _ in range(sub):
            h = 1 / FPS / sub
            vel[2] -= G * h
            pos = pos + vel * h
            ang = ang + om * h
            if pos[2] < 0.1 and vel[2] < 0:
                pos[2] = 0.1
                vel[2] = -vel[2] * 0.38
                vel[:2] *= 0.6
                om *= 0.6
                if abs(vel[2]) < 0.6:
                    vel[2] = 0
                    vel[:2] *= 0.8
                    om *= 0.7
    return keys


def zet_actie(obj, clip, frames, vals):
    """vals: lijst (loc, rot, scale) per beeldje; één NLA-strook met de naam van de clip (zo exporteert Blender er één animatie van)."""
    act = bpy.data.actions.new("%s_%s" % (clip, obj.name))
    obj.animation_data_create()
    obj.animation_data.action = act
    for f, (loc, rot, sc) in zip(frames, vals):
        obj.location, obj.rotation_euler, obj.scale = loc, rot, sc
        obj.keyframe_insert("location", frame=f)
        obj.keyframe_insert("rotation_euler", frame=f)
        obj.keyframe_insert("scale", frame=f)
    for fc in act.fcurves if hasattr(act, "fcurves") else []:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    tr = obj.animation_data.nla_tracks.new()
    tr.name = clip
    tr.strips.new(clip, 0, act)
    obj.animation_data.action = None


baan = dop_baan()
rust = (0, 0, 0)
for clip, n in (("Spuit", N_SPUIT), ("Spuiten-loop", N_LUS)):
    frames = list(range(n + 1))
    # dop
    if clip == "Spuit":
        zet_actie(dop, clip, frames, [(b[0], b[1], (1, 1, 1)) for b in baan[:n + 1]])
    else:
        zet_actie(dop, clip, frames, [(baan[-1][0], baan[-1][1], (1, 1, 1))] * (n + 1))
    # waterkolom: groeit in het begin, wiebelt daarna
    kol = []
    for f in frames:
        tau = f / FPS
        gro = min(1.0, (tau / 0.3)) ** 0.6 if clip == "Spuit" else 1.0
        w = 1.0 + 0.05 * math.sin(tau / T_LUS * 2 * math.pi * 4) + 0.03 * math.sin(tau / T_LUS * 2 * math.pi * 7)
        kol.append(((0, 0, ZN - 0.1), (0, 0, tau / T_LUS * 2 * math.pi), (w, 1.0 / w, max(gro, 0.001))))
    zet_actie(straal, clip, frames, kol)
    # druppels
    for x in druppels:
        vals = []
        for f in frames:
            tau = f / FPS
            loc, sz = vlucht(x, tau)
            if clip == "Spuit":
                emit = (T_LUS - x["phi"] * T_LUS) % T_LUS     # tijdstip waarop deze druppel voor het eerst de opening verlaat
                if tau < emit - 1e-6 and tau < T_LUS:
                    sz = 0.0
            vals.append((loc, rust, (sz, sz, sz)))
        zet_actie(x["o"], clip, frames, vals)

hyd_objs = [hyd_root, romp, dop, straal] + [x["o"] for x in druppels]

# ---------- afwerking ----------
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "straatmeubilair.glb"), export_format="GLB", export_apply=True, export_yup=True,
                          use_selection=True, export_animations=False)
bpy.ops.object.select_all(action="DESELECT")
hyd_root.location = (0, 0, 0)   # in het spel staat de kraan op de plek van het knooppunt
for o in hyd_objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "brandkraan.glb"), export_format="GLB", export_apply=True, export_yup=True,
                          use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_frame_range=False)
hyd_root.location = (33, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "straatmeubilair.blend"))
tris = {}
for o in objs:
    o.data.calc_loop_triangles()
    tris[o.name] = len(o.data.loop_triangles)
print("TRIS", tris, "TOTAAL", sum(tris.values()))
