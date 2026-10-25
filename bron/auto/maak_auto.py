"""Personenauto voor de stad (Bloedjungle, VQ2): sedan met echte PBR-texturen, onderdelen die los kunnen (deuren, motorkap,
kofferklep, wielen, ruiten), Blender-animaties en een schadevorm (shape key 'Deuk') plus een verkoold materiaal voor het wrak.

Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden op de grond, voorkant aan +Y (wordt -Z in Godot).
Gebruik:  python3 maak_auto.py <uitmap> [--render]   ->  auto.glb, auto.blend, texturen (PNG) in <uitmap>

Knopen in de GLB (Auto = wortel):
  Romp (shape key Deuk), Voorruit, Achterruit, DeurLV/RV/LA/RA (met eigen ruit en spiegel), Motorkap, Kofferklep,
  WisserL/WisserR, Wiel_LV/RV/LA/RA (band + velg), WrakRef (verborgen: draagt het verkoolde materiaal),
  Licht* = verlichte lenzen (rustpositie schaal 0; het spel of een clip zet ze aan).
Clips: DeurenOpen, KapOpen, KofferOpen, Ruitenwissers-loop, Knipperen-loop, Alarm-loop (allemaal echte transform-tracks).
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector, Euler, Quaternion

ARGS = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath([a for a in ARGS if not a.startswith("--")][0])
RENDER = "--render" in ARGS
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
FPS = 30
scene.render.fps = FPS


# ============================================================ texturen (numpy, 1K voor de lak, 512 voor de rest)
def noise(size, scale, seed, sy=None):
    sy = sy or scale
    nx, ny = max(size // scale, 1), max(size // sy, 1)
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


def fbm(size, base, seed, octs=4):
    out, amp, tot = np.zeros((size, size)), 1.0, 0.0
    for i in range(octs):
        out += amp * noise(size, max(base >> i, 2), seed + i)
        tot += amp
        amp *= 0.5
    return out / tot


def sm(v, e0, e1):
    return np.clip((v - e0) / (e1 - e0), 0, 1)


def save_img(name, arr, non_color=False):
    size = arr.shape[0]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, axis=2)
    im = bpy.data.images.new(name, size, size)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, name + ".png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im


def normal_from_height(h, strength):
    gy, gx = np.gradient(h)
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def scratches(size, seed, count, length):
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size))
    for _ in range(count):
        x, y = rng.random() * size, rng.random() * size
        a = rng.normal(0.0, 0.5) if rng.random() < 0.7 else rng.random() * math.pi
        for t in range(int(length * (0.4 + rng.random()))):
            px, py = int(x + math.cos(a) * t) % size, int(y + math.sin(a) * t) % size
            img[py, px] = max(img[py, px], 0.5 + rng.random() * 0.5)
    return img


def lak_textures(size=1024):
    """Autolak: u = langs de auto, v = hoogte (onder = vuil). Licht neutraal; de tint komt uit het materiaal."""
    y, x = np.mgrid[0:size, 0:size]
    u, v = x / size, 1 - y / size           # v=0 onderkant (rij y=size-1 in beeld)
    n1, n2 = fbm(size, 128, 1), fbm(size, 32, 5)
    base = 0.86 - 0.08 * n1
    fade = sm(v, 0.75, 1.0) * 0.12 * fbm(size, 64, 8)               # zon-vervaging bovenop
    img = np.repeat((base - fade)[..., None], 3, axis=2)
    # vuil en modder onderin, met spatten bij de wielkasten
    wiel = sum(np.exp(-((u - c) / 0.06) ** 2) for c in (0.5 - 1.32 / 4.3, 0.5 + 1.30 / 4.3))
    mud = np.clip(sm(0.30 - v, 0, 0.30) * (0.6 + 0.8 * n2) + wiel * sm(0.5 - v, 0, 0.5) * n2 * 0.9, 0, 1)
    img = img * (1 - mud[..., None] * 0.75) + np.array([0.20, 0.15, 0.10])[None, None, :] * mud[..., None] * 0.75
    # regenstrepen
    streak = sm(noise(size, 2, 9, 256), 0.62, 0.9) * sm(v, 0.2, 0.9) * 0.18
    img = img * (1 - streak[..., None])
    # krassen en afgebladderde plekken (blank staal)
    sc = scratches(size, 3, 220, 70)
    chip = sm(fbm(size, 16, 12), 0.72, 0.8) * sm(0.45 - v, -0.1, 0.5)
    img = img * (1 - sc[..., None] * 0.35) + sc[..., None] * 0.12 * 0
    img = img * (1 - chip[..., None]) + np.array([0.45, 0.43, 0.41])[None, None, :] * chip[..., None]
    rust = sm(fbm(size, 32, 20), 0.66, 0.75) * sm(0.35 - v, 0, 0.3)
    img = img * (1 - rust[..., None] * 0.8) + np.array([0.42, 0.21, 0.10])[None, None, :] * rust[..., None] * 0.8
    h = 0.5 * fbm(size, 32, 30, 3) + 0.25 * fbm(size, 8, 31, 2) - 0.12 * sc + 0.2 * chip
    rough = 0.38 + 0.25 * n1 + 0.45 * mud + 0.3 * chip
    metal = np.clip(chip * 0.9 - 0.0, 0, 1)
    orm = np.stack([np.ones_like(rough), np.clip(rough, 0, 1), metal], axis=2)
    return (save_img("auto_lak", img), save_img("auto_lak_n", normal_from_height(h, 3.0), True),
            save_img("auto_lak_orm", orm, True))


def rubber_textures(size=512):
    """Band: u rond de band (herhaalt 3x), v over de breedte. Profielblokken in de hoogtekaart."""
    y, x = np.mgrid[0:size, 0:size]
    u, v = x / size * 3 % 1, y / size
    groef = (sm(np.abs(((u * 8) % 1) - 0.5), 0.0, 0.1) * 0 + np.where(np.abs(((u * 8 + v * 1.5) % 1) - 0.5) < 0.09, 0.0, 1.0))
    mid = np.where(np.abs(v - 0.5) < 0.04, 0.0, 1.0)
    h = 0.15 + 0.85 * np.minimum(groef, mid) * (0.9 + 0.1 * fbm(size, 8, 40))
    img = np.repeat(((0.075 + 0.05 * fbm(size, 16, 41)) * (0.7 + 0.3 * h))[..., None], 3, axis=2)
    dust = sm(fbm(size, 32, 42), 0.55, 0.8) * 0.5
    img = img * (1 - dust[..., None]) + np.array([0.22, 0.19, 0.15])[None, None, :] * dust[..., None] * 0.7
    orm = np.stack([np.ones_like(h) * 0.9, np.clip(0.85 - 0.2 * h + dust * 0.1, 0, 1), np.zeros_like(h)], axis=2)
    return (save_img("auto_rubber", img), save_img("auto_rubber_n", normal_from_height(h, 5.0), True),
            save_img("auto_rubber_orm", orm, True))


def wreck_textures(size=1024):
    """Uitgebrand wrak: roet, as en een beetje doorgebrande roest. Hergebruikt dezelfde UV-indeling als de lak."""
    y, x = np.mgrid[0:size, 0:size]
    v = 1 - y / size
    n1, n2, n3, fine = fbm(size, 128, 50), fbm(size, 32, 51), fbm(size, 8, 52), fbm(size, 4, 55, 2)
    base = (0.028 + 0.035 * n1) * (0.75 + 0.5 * fine)
    img = np.repeat(base[..., None], 3, axis=2)
    ash = sm(n2, 0.6, 0.85) * (0.2 + 0.5 * sm(v, 0.4, 1.0)) * 0.55
    img = img * (1 - ash[..., None]) + np.array([0.15, 0.145, 0.14])[None, None, :] * ash[..., None]
    rust = sm(fbm(size, 64, 53), 0.58, 0.8) * sm(0.6 - v, -0.2, 0.5) * 0.5
    img = img * (1 - rust[..., None]) + np.array([0.20, 0.09, 0.045])[None, None, :] * rust[..., None] * (0.6 + 0.8 * n3[..., None])
    bare = sm(fbm(size, 16, 54), 0.78, 0.88) * 0.6
    img = img * (1 - bare[..., None]) + np.array([0.075, 0.07, 0.065])[None, None, :] * bare[..., None]
    h = 0.4 * n3 + 0.3 * n2 + 0.3 * fine + 0.2 * rust
    rough = np.clip(0.8 + 0.2 * n2 - 0.3 * bare, 0, 1)
    orm = np.stack([np.ones_like(h) * 0.7, rough, bare * 0.4 + rust * 0.1], axis=2)
    return (save_img("auto_wrak", img), save_img("auto_wrak_n", normal_from_height(h, 3.0), True),
            save_img("auto_wrak_orm", orm, True))


def plain_textures(name, rgb, rough, metal, size=256, grain=0.12, seed=60):
    n = fbm(size, 32, seed)
    img = np.array(rgb)[None, None, :] * (1 - grain + 2 * grain * n[..., None])
    h = fbm(size, 8, seed + 1)
    orm = np.stack([np.ones_like(h), np.clip(rough + 0.2 * (n - 0.5), 0, 1), np.ones_like(h) * metal], axis=2)
    return save_img(name, img), save_img(name + "_n", normal_from_height(h, 1.5), True), save_img(name + "_orm", orm, True)


# ============================================================ materialen
def pbr(name, tex=None, color=(1, 1, 1), tint=None, rough=0.6, metal=0.0, emit=None, strength=0.0, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    L = nt.links
    if tex:
        alb, nor, orm = tex
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = alb
        if tint:
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            mix.inputs[7].default_value = (*[c ** 2.2 for c in tint], 1)
            L.new(t.outputs["Color"], mix.inputs[6])
            L.new(mix.outputs[2], p.inputs["Base Color"])
        else:
            L.new(t.outputs["Color"], p.inputs["Base Color"])
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = nor
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 1.0
        L.new(tn.outputs["Color"], nm.inputs["Color"])
        L.new(nm.outputs["Normal"], p.inputs["Normal"])
        to = nt.nodes.new("ShaderNodeTexImage")
        to.image = orm
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        L.new(to.outputs["Color"], sep.inputs[0])
        L.new(sep.outputs["Green"], p.inputs["Roughness"])
        L.new(sep.outputs["Blue"], p.inputs["Metallic"])
    else:
        p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha is not None:
        p.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


LAK_T = lak_textures()
RUB_T = rubber_textures()
WRAK_T = wreck_textures()
PLAST_T = plain_textures("auto_plastic", (0.07, 0.07, 0.07), 0.55, 0.0, seed=70)
CHR_T = plain_textures("auto_chroom", (0.62, 0.62, 0.6), 0.28, 1.0, seed=80)
BIN_T = plain_textures("auto_binnen", (0.05, 0.05, 0.045), 0.9, 0.0, seed=90)
VELG_T = plain_textures("auto_velg", (0.50, 0.50, 0.49), 0.38, 1.0, seed=100)

LAK = pbr("Lak", LAK_T, tint=(0.22, 0.30, 0.36))
RUBBER = pbr("Rubber", RUB_T)
PLASTIC = pbr("Plastic", PLAST_T)
CHROOM = pbr("Chroom", CHR_T)
BINNEN = pbr("Binnen", BIN_T)
VELG = pbr("Velg", VELG_T)
GLAS = pbr("Glas", color=(0.10, 0.16, 0.17), rough=0.04, metal=0.0, alpha=0.38)
LENS_KOP = pbr("LensKoplamp", color=(0.75, 0.78, 0.74), rough=0.08)
LENS_ACHTER = pbr("LensAchter", color=(0.35, 0.03, 0.025), rough=0.1)
LENS_KNIP = pbr("LensKnipper", color=(0.45, 0.22, 0.03), rough=0.1)
LICHT_KOP = pbr("LichtKoplamp", color=(1.0, 0.95, 0.8), emit=(1.0, 0.92, 0.7), strength=6.0)
LICHT_ACHTER = pbr("LichtAchter", color=(1.0, 0.1, 0.05), emit=(1.0, 0.08, 0.03), strength=4.0)
LICHT_KNIP = pbr("LichtKnipper", color=(1.0, 0.6, 0.1), emit=(1.0, 0.55, 0.05), strength=7.0)
WRAK = pbr("Verkoold", WRAK_T)
KENTEKEN = pbr("Kenteken", color=(0.85, 0.72, 0.15), rough=0.5)
MATS = [LAK, RUBBER, PLASTIC, CHROOM, BINNEN, VELG, GLAS, LENS_KOP, LENS_ACHTER, LENS_KNIP, LICHT_KOP, LICHT_ACHTER, LICHT_KNIP, WRAK, KENTEKEN]
MI = {m.name: i for i, m in enumerate(MATS)}
# meters per herhaling van de kleine texturen; de lak gebruikt een eigen indeling (heel de auto = 1 beeld)
TEGEL = {"Rubber": 1.0, "Plastic": 0.5, "Chroom": 0.5, "Binnen": 0.5, "Velg": 0.5}
L_AUTO = 4.4
H_AUTO = 1.55


# ============================================================ bouwstenen
class Deel:
    """Eén object: alle delen in één bmesh, per vlak een materiaal. Coördinaten in wereldmaat; pivot wordt bij het maken afgetrokken."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, mat, smooth=True):
        vs = [self.bm.verts.new(p) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = MI[mat.name]
        f.smooth = smooth
        return f

    def quad(self, a, b, c, d, mat):
        return self.face([a, b, c, d], mat)

    def box(self, c, s, mat, tilt=0.0):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz), (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        v = [(c[0] + p[0], c[1] + p[1], c[2] + p[2]) for p in v]
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)):
            self.face([v[i] for i in q], mat, smooth=False)

    def lathe(self, center, profile, segs, mat, axis="x", flip=False):
        """Draaivlak: profile = [(straal, afstand langs de as)]. axis x = wielas."""
        rings = []
        for r, a in profile:
            ring = []
            for i in range(segs):
                t = i / segs * math.tau
                if axis == "x":
                    p = (center[0] + a, center[1] + r * math.sin(t), center[2] + r * math.cos(t))
                else:
                    p = (center[0] + r * math.cos(t), center[1] + r * math.sin(t), center[2] + a)
                ring.append(self.bm.verts.new(p))
            rings.append(ring)
        for k in range(len(rings) - 1):
            for i in range(segs):
                j = (i + 1) % segs
                q = [rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]]
                if flip:
                    q = q[::-1]
                try:
                    f = self.bm.faces.new(q)
                    f.material_index = MI[mat.name]
                    f.smooth = True
                except ValueError:
                    pass

    def loft(self, rings, mat, cap_start=True, cap_end=True):
        n = len(rings[0])
        vr = [[self.bm.verts.new(p) for p in ring] for ring in rings]
        for k in range(len(vr) - 1):
            for i in range(n):
                j = (i + 1) % n
                try:
                    f = self.bm.faces.new([vr[k][i], vr[k + 1][i], vr[k + 1][j], vr[k][j]])
                    f.material_index = MI[mat.name]
                    f.smooth = True
                except ValueError:
                    pass
        for cap, ring, rev in ((cap_start, vr[0], True), (cap_end, vr[-1], False)):
            if cap:
                try:
                    f = self.bm.faces.new(ring[::-1] if rev else ring)
                    f.material_index = MI[mat.name]
                    f.smooth = False
                except ValueError:
                    pass

    def finish(self, pivot=(0, 0, 0), sharp=38.0):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=[-pivot[0], -pivot[1], -pivot[2]])
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(sharp):
                e.smooth = False
        for f in bm.faces:
            if f.material_index == MI["Lak"] or True:
                self._uv(f, pivot)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(self.name, me)
        for m in MATS:
            me.materials.append(m)
        scene.collection.objects.link(ob)
        ob.location = pivot
        return ob

    def _uv(self, f, pivot):
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        mat = MATS[f.material_index]
        for lp in f.loops:
            w = lp.vert.co + Vector(pivot)    # terug naar wereldmaat
            if mat.name in ("Lak", "Verkoold"):
                if ax == 0:
                    uv = (0.5 - w.y / L_AUTO, w.z / H_AUTO)
                elif ax == 2:
                    uv = (0.5 - w.y / L_AUTO, 0.66 + w.x * 0.14 * (1 if n.z > 0 else -1) + 0.2)
                else:
                    uv = (0.5 + w.x / L_AUTO * 1.4, w.z / H_AUTO)
            else:
                s = TEGEL.get(mat.name, 1.0)
                uv = (w.y / s, w.z / s) if ax == 0 else (w.x / s, w.z / s) if ax == 1 else (w.x / s, w.y / s)
                if mat.name == "Rubber":
                    uv = (math.atan2(lp.vert.co.y, lp.vert.co.z) / math.tau * 3, lp.vert.co.x / 0.25 + 0.5)
            lp[self.uv].uv = uv


def ring(y, hw, zb, zt, r, k=3):
    """Doorsnede van de romp: afgeronde rechthoek in het vlak x-z op positie y."""
    pts = []
    corners = [(hw - r, zb + r, -90, 0), (hw - r, zt - r, 0, 90), (-hw + r, zt - r, 90, 180), (-hw + r, zb + r, 180, 270)]
    for cx, cz, a0, a1 in corners:
        for i in range(k + 1):
            a = math.radians(a0 + (a1 - a0) * i / k)
            pts.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
    return pts


ST = [  # y, onder, boven, halve breedte, afronding
    (2.12, 0.36, 0.64, 0.74, 0.10),
    (2.04, 0.30, 0.72, 0.82, 0.12),
    (1.70, 0.25, 0.80, 0.89, 0.13),
    (1.20, 0.24, 0.90, 0.91, 0.13),
    (0.95, 0.24, 0.94, 0.91, 0.13),
    (0.30, 0.24, 0.955, 0.91, 0.12),
    (-1.40, 0.24, 0.965, 0.91, 0.12),
    (-1.80, 0.25, 0.985, 0.90, 0.12),
    (-2.02, 0.28, 0.955, 0.86, 0.12),
    (-2.12, 0.36, 0.86, 0.78, 0.10),
]


def top_z(y):
    for a, b in zip(ST, ST[1:]):
        if b[0] <= y <= a[0]:
            t = (a[0] - y) / (a[0] - b[0])
            return a[2] + (b[2] - a[2]) * t
    return ST[0][2]


WX, WYV, WYA, WR = 0.80, 1.32, -1.30, 0.335    # wielpositie (x, y voor, y achter) en straal

# ---------- Romp
romp = Deel("Romp")
rings = [ring(y, hw, zb, zt, r) for y, zb, zt, hw, r in ST]
romp.loft(rings, LAK)

# dak en cabine (vol, ruiten zijn opgelegd glas op donkere binnenkant)
CAB = [  # y, z-onder, z-boven, halve breedte onder, halve breedte boven
    (0.96, 0.94, 0.96, 0.84, 0.80),
    (0.40, 0.94, 1.40, 0.85, 0.72),
    (-0.10, 0.94, 1.43, 0.86, 0.69),
    (-1.00, 0.94, 1.425, 0.86, 0.69),
    (-1.60, 0.95, 1.05, 0.84, 0.78),
]
crings = []
for y, zb, zt, hb, ht in CAB:
    crings.append([(hb, y, zb), (ht + 0.02, y, zt - 0.025), (ht - 0.03, y, zt), (-ht + 0.03, y, zt), (-ht - 0.02, y, zt - 0.025), (-hb, y, zb)])
romp.loft(crings, LAK)


def cab_side(y, z):
    """x van de buitenkant van de cabine (rechts) op positie (y,z): lineair tussen de doorsneden."""
    for a, b in zip(CAB, CAB[1:]):
        if b[0] <= y <= a[0]:
            t = (a[0] - y) / (a[0] - b[0])
            zl = a[1] + (b[1] - a[1]) * t
            zt = a[2] + (b[2] - a[2]) * t
            hb = a[3] + (b[3] - a[3]) * t
            ht = a[4] + (b[4] - a[4]) * t
            return hb + (ht + 0.02 - hb) * np.clip((z - zl) / max(zt - 0.025 - zl, 1e-6), 0, 1)
    return 0.8


# donkere binnenkant onder de zijruiten (zichtbaar als de ruit er niet is)
RUIT_F = [(0.86, 0.34), (0.88, 0.40), (-0.33, 1.34), (-0.33, 1.045)]   # voordeurruit: (y, z) hoeken (voor-onder, voor-boven, achter-boven, achter-onder)
RUIT_F = [(0.80, 1.00), (0.44, 1.30), (-0.34, 1.37), (-0.34, 1.00)]
RUIT_A = [(-0.40, 1.00), (-0.40, 1.37), (-1.0, 1.395), (-1.30, 1.00)]


def side_patch(deel, pts, mat, off, s=1, n=8):
    """Ruit of donkere binnenkant op de zijkant van de cabine: een rooster, zodat het vlak de bolling van de cabine volgt."""
    a, b, c, d = [Vector(p) for p in pts]
    grid = []
    for i in range(n + 1):
        row = []
        for j in range(n + 1):
            u, v = i / n, j / n
            lo, hi = a.lerp(d, u), b.lerp(c, u)
            p = lo.lerp(hi, v)
            row.append((s * (cab_side(p.x, p.y) + off), p.x, p.y))
        grid.append(row)
    for i in range(n):
        for j in range(n):
            q = [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
            deel.quad(*(q if s > 0 else q[::-1]), mat)


for s in (1, -1):
    side_patch(romp, RUIT_F, BINNEN, 0.004, s)
    side_patch(romp, RUIT_A, BINNEN, 0.004, s)

# voor- en achterruit: donkere binnenkant onder het glas
WS = [(0.90, 1.005), (0.42, 1.365)]            # voorruit (y,z) onder- en bovenrand
AR = [(-1.52, 1.10), (-1.12, 1.35)]           # achterruit


def rand_x(y, z):
    return cab_side(y, z) - 0.02


def screen(deel, a, b, mat, off, wa=0.78, wb=0.66):
    n = Vector((0, -(b[1] - a[1]), (b[0] - a[0]))).normalized() if False else None
    d = Vector((0, b[0] - a[0], b[1] - a[1]))
    nrm = Vector((0, -d.z, d.y)).normalized()
    if nrm.z < 0:
        nrm = -nrm
    o = nrm * off
    p = [Vector((-wa, a[0], a[1])) + o, Vector((wa, a[0], a[1])) + o, Vector((wb, b[0], b[1])) + o, Vector((-wb, b[0], b[1])) + o]
    deel.quad(p[0], p[1], p[2], p[3], mat)


screen(romp, WS[0], WS[1], BINNEN, 0.004)
screen(romp, AR[0], AR[1], BINNEN, 0.004, 0.74, 0.62)
# schrapen: dakgootrand (dun chroom lijntje), A-stijl is lak

# neus: grille, koplampen (donker glas), bumpers
romp.box((0, 2.115, 0.50), (1.20, 0.07, 0.15), PLASTIC)                      # grille
for i in range(5):
    romp.box((0, 2.152, 0.43 + i * 0.03), (1.12, 0.012, 0.012), CHROOM)
romp.box((0, 2.14, 0.30), (1.62, 0.18, 0.12), PLASTIC)                      # voorbumper onder
romp.box((0, 2.09, 0.53), (1.58, 0.12, 0.07), CHROOM)                      # bumperstrip boven
romp.box((0, -2.10, 0.30), (1.62, 0.18, 0.12), PLASTIC)                     # achterbumper
romp.box((0, -2.09, 0.50), (1.56, 0.1, 0.05), CHROOM)
romp.box((0, -2.14, 0.40), (0.52, 0.02, 0.11), KENTEKEN)                    # kenteken achter
romp.box((0, 2.185, 0.36), (0.52, 0.02, 0.11), KENTEKEN)                    # kenteken voor
for s in (1, -1):
    romp.box((s * 0.60, 2.0, 0.60), (0.34, 0.10, 0.12), LENS_KOP)           # koplamp
    romp.box((s * 0.80, 2.00, 0.65), (0.10, 0.08, 0.09), LENS_KNIP)          # knipperlicht voor
    romp.box((s * 0.74, -2.0, 0.78), (0.28, 0.10, 0.16), LENS_ACHTER)       # achterlicht
    romp.box((s * 0.58, -2.07, 0.62), (0.10, 0.06, 0.07), LENS_KNIP)        # knipperlicht achter
    romp.box((s * 0.82, 1.45, 0.20), (0.06, 1.0, 0.07), PLASTIC)            # dorpel
    romp.box((s * 0.82, -0.9, 0.20), (0.06, 1.8, 0.07), PLASTIC)
romp.box((0, 0, 0.18), (1.5, 4.0, 0.06), PLASTIC)                             # onderplaat
# uitlaat
romp.lathe((0.45, -2.16, 0.27), [(0.04, 0.0), (0.042, 0.0), (0.042, 0.0)], 8, CHROOM, axis="z")
romp.lathe((0.45, -2.12, 0.26), [(0.045, -0.04), (0.05, 0.0), (0.045, 0.14)], 10, CHROOM, axis="x") if False else None
# wielkasten: donkere voering rond elk wiel (de boolean maakt de gaten)
KASTEN = [(s, y) for s in (1, -1) for y in (WYV, WYA)]

# motorruimte-details onder de kap zijn vlak; de kap ligt er direct op

romp_obj = romp.finish()
# boolean: wielgaten in de romp
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = romp_obj
for s, y in KASTEN:
    cut = bpy.data.objects.new("snijder", None)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=WR + 0.075, radius2=WR + 0.075, depth=0.62,
                          matrix=Matrix.Translation((0, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    me = bpy.data.meshes.new("snijder")
    bm.to_mesh(me)
    bm.free()
    cut = bpy.data.objects.new("snijder", me)
    scene.collection.objects.link(cut)
    cut.location = (s * (WX + 0.15), y, WR)
    mod = romp_obj.modifiers.new("gat", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cut
    mod.solver = "EXACT"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cut)

# voering van de wielkasten (open half-cilinder, donker) als losse vlakken in de romp
bm = bmesh.new()
bm.from_mesh(romp_obj.data)
uvl = bm.loops.layers.uv["UVMap"]
for s, y in KASTEN:
    prev = None
    segs = 14
    for i in range(segs + 1):
        a = math.radians(-8 + 196 * i / segs)    # alleen de bovenste halve ring
        cur = []
        for ax in (WX - 0.30, WX + 0.12):
            cur.append(bm.verts.new((s * ax, y + (WR + 0.06) * math.sin(a), WR + (WR + 0.06) * math.cos(a) * 0 + (WR + 0.06) * math.cos(a) * 1.0 - 0.0)))
        if prev:
            try:
                f = bm.faces.new([prev[0], prev[1], cur[1], cur[0]] if s > 0 else [prev[0], cur[0], cur[1], prev[1]])
                f.material_index = MI["Binnen"]
                for lp in f.loops:
                    lp[uvl].uv = (lp.vert.co.y, lp.vert.co.z)
            except ValueError:
                pass
        prev = cur
bm.to_mesh(romp_obj.data)
bm.free()
romp_obj.data.update()
# schaduwrand: laat de romp als één geheel zien
for p in romp_obj.data.polygons:
    p.use_smooth = p.use_smooth


# ---------- shape key Deuk (schade): botsingen op motorkap, dak, flank en achterkant
def deuk_kaart(co, nrm):
    """Verplaatsing van een punt door een paar vaste deuken (richting: tegen de normaal in)."""
    d = 0.0
    for (cx, cy, cz, r, diep) in ((0.25, 1.45, 0.88, 0.55, 0.075), (0.0, -0.3, 1.43, 0.50, 0.06), (-0.92, -0.7, 0.65, 0.45, 0.065),
                                  (0.55, -1.9, 0.80, 0.35, 0.05), (0.35, 2.12, 0.55, 0.40, 0.09), (0.92, 0.55, 0.70, 0.35, 0.05)):
        dist = math.sqrt((co.x - cx) ** 2 + (co.y - cy) ** 2 + (co.z - cz) ** 2)
        if dist < r:
            d += diep * (0.5 + 0.5 * math.cos(math.pi * dist / r)) ** 1.4
    return -nrm * d


romp_obj.shape_key_add(name="Basis")
sk = romp_obj.shape_key_add(name="Deuk")
me = romp_obj.data
me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
vn = {}
for lp in me.loops:
    vn[lp.vertex_index] = lp.normal if hasattr(lp, "normal") else me.vertices[lp.vertex_index].normal
for v in me.vertices:
    sk.data[v.index].co = v.co + deuk_kaart(v.co, vn.get(v.index, v.normal))
sk.value = 0.0


# ---------- Ruiten voor en achter
def glasdeel(name, a, b, wa, wb, thick=0.012):
    g = Deel(name)
    d = Vector((0, b[0] - a[0], b[1] - a[1]))
    nrm = Vector((0, -d.z, d.y)).normalized()
    if nrm.z < 0:
        nrm = -nrm
    o = nrm * 0.014
    p = [Vector((-wa, a[0], a[1])) + o, Vector((wa, a[0], a[1])) + o, Vector((wb, b[0], b[1])) + o, Vector((-wb, b[0], b[1])) + o]
    g.quad(p[0], p[1], p[2], p[3], GLAS)
    g.quad(p[3] + nrm * thick, p[2] + nrm * thick, p[1] + nrm * thick, p[0] + nrm * thick, GLAS) if False else None
    return g.finish()


voorruit = glasdeel("Voorruit", WS[0], WS[1], 0.77, 0.65)
achterruit = glasdeel("Achterruit", AR[0], AR[1], 0.73, 0.61)


# ---------- Deuren
def deur(naam, s, y0, y1, ruit, ruit_y_front_hinge=True):
    """Deur op de zijde s (+1 rechts). y0 = voorkant (scharnier), y1 = achterkant. ruit = lijst (y,z) hoeken van het glas."""
    d = Deel(naam)
    zb, zt = 0.30, 0.955
    cols, rows = 9, 4
    grid = []
    for i in range(cols + 1):
        y = y0 + (y1 - y0) * i / cols
        row = []
        for j in range(rows + 1):
            z = zb + (zt - zb) * j / rows
            bol = 0.016 * math.sin(math.pi * i / cols) * (0.5 + 0.5 * math.sin(math.pi * j / rows)) + 0.012
            row.append((s * (0.91 + bol), y, z))
        grid.append(row)
    for i in range(cols):
        for j in range(rows):
            a, b, c, e = grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]
            if s > 0:
                d.quad(a, e, c, b, LAK)
            else:
                d.quad(a, b, c, e, LAK)
    # randen: bovenkant (vlak) en voor-/achterkant
    for i in range(cols):
        for (ya, yb) in ((i, i + 1),):
            a, b = grid[ya][rows], grid[yb][rows]
            d.quad(a, b, (b[0] - s * 0.05, b[1], b[2] + 0.0), (a[0] - s * 0.05, a[1], a[2]), LAK)
    for i in (0, cols):
        for j in range(rows):
            a, b = grid[i][j], grid[i][j + 1]
            d.quad(a, (a[0] - s * 0.05, a[1], a[2]), (b[0] - s * 0.05, b[1], b[2]), b, LAK)
    # raamkader en glas
    side_patch(d, ruit, GLAS, 0.012, s)
    # chromen lijst onder het raam
    d.box((s * 0.935, (y0 + y1) / 2, 0.98), (0.03, abs(y1 - y0) * 0.97, 0.025), CHROOM)
    # deurgreep
    gy = y1 + (0.12 if y1 < y0 else -0.12)
    d.box((s * 0.945, gy, 0.86), (0.03, 0.17, 0.028), CHROOM)
    return d


DEUREN = {}
for naam, s, y0, y1, ruit, hy in (("DeurRV", 1, 0.86, -0.32, RUIT_F, 0.86), ("DeurLV", -1, 0.86, -0.32, RUIT_F, 0.86),
                                  ("DeurRA", 1, -0.36, -1.32, RUIT_A, -0.36), ("DeurLA", -1, -0.36, -1.32, RUIT_A, -0.36)):
    dd = deur(naam, s, y0, y1, ruit)
    if naam in ("DeurRV", "DeurLV"):
        # buitenspiegel
        dd.box((s * 1.02, y0 - 0.06, 1.06), (0.10, 0.07, 0.08), PLASTIC)
        dd.box((s * 0.96, y0 - 0.02, 1.04), (0.04, 0.03, 0.03), PLASTIC)
    ob = dd.finish(pivot=(s * 0.90, hy, 0.0))
    DEUREN[naam] = (ob, s)


# ---------- Motorkap en kofferklep
def paneel(naam, y0, y1, zhoog, w0, w1, pivot):
    d = Deel(naam)
    cols, rows = 8, 6
    g = []
    for i in range(cols + 1):
        y = y0 + (y1 - y0) * i / cols
        w = w0 + (w1 - w0) * i / cols
        row = []
        for j in range(rows + 1):
            x = -w + 2 * w * j / rows
            kruin = 0.018 * (1 - (x / w) ** 2)
            row.append((x, y, top_z(y) + 0.014 + kruin + zhoog))
        g.append(row)
    for i in range(cols):
        for j in range(rows):
            d.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j], LAK)
    # rand en onderkant
    for i in range(cols):
        for j in (0, rows):
            a, b = g[i][j], g[i + 1][j]
            lo = (a[0], a[1], a[2] - 0.035), (b[0], b[1], b[2] - 0.035)
            if j == 0:
                d.quad(a, lo[0], lo[1], b, LAK)
            else:
                d.quad(a, b, lo[1], lo[0], LAK)
    for i in (0, cols):
        for j in range(rows):
            a, b = g[i][j], g[i][j + 1]
            lo = (a[0], a[1], a[2] - 0.035), (b[0], b[1], b[2] - 0.035)
            if i == 0:
                d.quad(a, b, lo[1], lo[0], LAK)
            else:
                d.quad(a, lo[0], lo[1], b, LAK)
    for i in range(cols):
        for j in range(rows):
            a = [(p[0], p[1], p[2] - 0.035) for p in (g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])]
            d.quad(a[3], a[2], a[1], a[0], BINNEN)
    return d.finish(pivot=pivot)


kap = paneel("Motorkap", 0.96, 2.04, 0.0, 0.80, 0.70, (0, 0.96, top_z(0.96)))
klep = paneel("Kofferklep", -1.64, -2.04, 0.0, 0.78, 0.70, (0, -1.64, top_z(-1.64)))


# ---------- Ruitenwissers
def wisser(naam, x0):
    d = Deel(naam)
    arm = 0.56
    d.box((arm / 2, 0, 0.012), (arm, 0.014, 0.010), PLASTIC)
    d.box((arm * 0.62, 0, 0.022), (0.30, 0.012, 0.010), PLASTIC)
    d.box((0.0, 0, 0.02), (0.035, 0.035, 0.03), CHROOM)
    return d


nrm_ws = Vector((0, WS[1][0] - WS[0][0], WS[1][1] - WS[0][1]))
nrm_ws = Vector((0, -nrm_ws.z, nrm_ws.y)).normalized()
if nrm_ws.z < 0:
    nrm_ws = -nrm_ws
# basis: x-as langs het glas, y-as = omhoog langs de ruit, z-as = ruitnormaal
up_ws = Vector((0, WS[1][0] - WS[0][0], WS[1][1] - WS[0][1])).normalized()
ws_basis = Matrix(((1, 0, 0), (0, up_ws.y, nrm_ws.y), (0, up_ws.z, nrm_ws.z)))
wissers = []
for naam, x0 in (("WisserL", -0.52), ("WisserR", 0.06)):
    w = wisser(naam, x0).finish()
    w.rotation_mode = "QUATERNION"
    base_pos = Vector((x0, WS[0][0], WS[0][1])) + nrm_ws * 0.02 + up_ws * 0.03
    w.location = base_pos
    q0 = ws_basis.to_quaternion()
    w.rotation_quaternion = q0
    wissers.append((w, q0))


# ---------- Wielen
def wiel(naam, s, y):
    d = Deel(naam)
    c = (s * WX, y, WR)
    # band (draaivlak): straal, afstand langs de as (naar buiten = s)
    prof = [(0.20, 0.10), (0.255, 0.115), (0.305, 0.115), (0.335, 0.095), (0.338, 0.06), (0.338, -0.06), (0.335, -0.095), (0.305, -0.115),
            (0.255, -0.115), (0.20, -0.10)]
    d.lathe(c, [(r, s * a) for r, a in prof], 28, RUBBER, "x", flip=(s < 0))
    # velg: schotel
    vprof = [(0.20, 0.10 * s), (0.20, 0.07 * s), (0.17, 0.085 * s), (0.10, 0.075 * s), (0.04, 0.095 * s), (0.0, 0.095 * s)]
    d.lathe(c, vprof, 20, VELG, "x", flip=(s < 0))
    for i in range(5):                                    # spaken
        t = i / 5 * math.tau
        sp = Vector((0, math.sin(t), math.cos(t)))
        mid = sp * 0.115
        d.box((c[0] + s * 0.092, c[1] + mid.y, c[2] + mid.z), (0.012, 0.045 if abs(sp.y) > abs(sp.z) else 0.045, 0.045), VELG)
    d.lathe(c, [(0.035, 0.095 * s), (0.045, 0.108 * s), (0.015, 0.112 * s)], 8, CHROOM, "x", flip=(s < 0))
    # remschijf aan de binnenkant
    d.lathe(c, [(0.17, -0.09 * s), (0.17, -0.075 * s)], 20, PLASTIC, "x", flip=(s > 0))
    return d.finish(pivot=(s * WX, y, WR))


WIELEN = {"Wiel_RV": wiel("Wiel_RV", 1, WYV), "Wiel_LV": wiel("Wiel_LV", -1, WYV), "Wiel_RA": wiel("Wiel_RA", 1, WYA), "Wiel_LA": wiel("Wiel_LA", -1, WYA)}

# ---------- Verlichte lenzen (rustpositie: schaal ~0, aan = schaal 1)
LICHTEN = {}


def lens_obj(naam, mat, c, size):
    d = Deel(naam)
    d.box(c, size, mat)
    ob = d.finish(pivot=c)
    ob.scale = (0.001, 0.001, 0.001)
    return ob


for s, t in ((1, "R"), (-1, "L")):
    LICHTEN["LichtKop" + t] = lens_obj("LichtKop" + t, LICHT_KOP, (s * 0.60, 2.05, 0.60), (0.31, 0.07, 0.10))
    LICHTEN["LichtAchter" + t] = lens_obj("LichtAchter" + t, LICHT_ACHTER, (s * 0.74, -2.045, 0.78), (0.25, 0.05, 0.13))
    LICHTEN["LichtKnipV" + t] = lens_obj("LichtKnipV" + t, LICHT_KNIP, (s * 0.80, 2.045, 0.65), (0.09, 0.05, 0.08))
    LICHTEN["LichtKnipA" + t] = lens_obj("LichtKnipA" + t, LICHT_KNIP, (s * 0.58, -2.11, 0.62), (0.09, 0.04, 0.06))

# ---------- Referentie voor het wrakmateriaal (verborgen, 1 vlak)
wd = Deel("WrakRef")
wd.quad((-0.02, 0, -0.5), (0.02, 0, -0.5), (0.02, 0, -0.46), (-0.02, 0, -0.46), WRAK)
wrakref = wd.finish(pivot=(0, 0, -0.5))
wrakref.scale = (0.001, 0.001, 0.001)

# ---------- Hiërarchie
root = bpy.data.objects.new("Auto", None)
scene.collection.objects.link(root)
alle = [romp_obj, voorruit, achterruit, kap, klep, wrakref] + [d[0] for d in DEUREN.values()] + [w[0] for w in wissers] + list(WIELEN.values()) + list(LICHTEN.values())
for ob in alle:
    ob.parent = root
    ob.matrix_parent_inverse = Matrix.Identity(4)

# ============================================================ animaties (NLA-stroken, echte transform-tracks)
bpy.context.view_layer.update()


def zet_actie(obj, clip, frames, vals, quat=False):
    act = bpy.data.actions.new("%s_%s" % (clip, obj.name))
    obj.animation_data_create()
    obj.animation_data.action = act
    for f, (loc, rot, sc) in zip(frames, vals):
        obj.location = loc
        if quat:
            obj.rotation_mode = "QUATERNION"
            obj.rotation_quaternion = rot
        else:
            obj.rotation_mode = "XYZ"
            obj.rotation_euler = rot
        obj.scale = sc
        obj.keyframe_insert("location", frame=f)
        obj.keyframe_insert("rotation_quaternion" if quat else "rotation_euler", frame=f)
        obj.keyframe_insert("scale", frame=f)
    if hasattr(act, "fcurves"):
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER" if clip in ("DeurenOpen", "KapOpen", "KofferOpen") else "LINEAR"
    tr = obj.animation_data.nla_tracks.new()
    tr.name = clip
    tr.strips.new(clip, 0, act)
    obj.animation_data.action = None


def ease(t):
    return t * t * (3 - 2 * t)


def vals_rot(obj, f, n, axis_angle_fn):
    return None


def rust(obj):
    return tuple(obj.location), tuple(obj.rotation_euler), tuple(obj.scale)


# DeurenOpen: elke deur zwaait uit (met kleine vertraging per deur), 36 beeldjes, blijft open staan
N = 36
frames = list(range(N + 1))
for i, (naam, (ob, s)) in enumerate(DEUREN.items()):
    rest = rust(ob)
    delay = i * 3
    vals = []
    for f in frames:
        t = ease(min(max((f - delay) / 20.0, 0.0), 1.0))
        hoek = s * math.radians(66) * t
        over = 1.0 + 0.04 * math.sin(min(max((f - delay - 20) / 6.0, 0), 1) * math.pi)
        vals.append((rest[0], (0, 0, hoek * over), rest[2]))
    zet_actie(ob, "DeurenOpen", frames, vals)
# KapOpen
kr = rust(kap)
zet_actie(kap, "KapOpen", frames, [(kr[0], (math.radians(58) * ease(f / 24.0 if f < 24 else 1.0), 0, 0), kr[2]) for f in frames])
kk = rust(klep)
zet_actie(klep, "KofferOpen", frames, [(kk[0], (-math.radians(52) * ease(f / 24.0 if f < 24 else 1.0), 0, 0), kk[2]) for f in frames])
# Ruitenwissers (lus 1,2 s): heen en terug, twee wissers gelijk
NW = 36
fw = list(range(NW + 1))
for w, q0 in wissers:
    vals = []
    for f in fw:
        a = -math.radians(78) * (0.5 - 0.5 * math.cos(f / NW * math.tau))
        qs = Quaternion(Vector((0, 0, 1)), a)    # draai om de ruitnormaal (lokale z)
        vals.append((tuple(w.location), q0 @ qs, tuple(w.scale)))
    zet_actie(w, "Ruitenwissers-loop", fw, vals, quat=True)
# Knipperen: links en rechts afwisselend (lus 1,0 s); Alarm: alles tegelijk
NK = 30
fk = list(range(NK + 1))
AAN = (1, 1, 1)
UIT = (0.001, 0.001, 0.001)
for naam, ob in LICHTEN.items():
    if "Knip" not in naam:
        continue
    zijde = naam[-1]
    r0 = rust(ob)
    for clip in ("Knipperen-loop", "Alarm-loop"):
        vals = []
        for f in fk:
            fase = (f % NK) / NK
            aan = (fase < 0.5) if (clip == "Alarm-loop" or zijde == "L") else (False if clip == "Knipperen-loop" else False)
            if clip == "Knipperen-loop":
                aan = fase < 0.5 and zijde == "L"      # linksaf
            vals.append((r0[0], r0[1], AAN if aan else UIT))
        zet_actie(ob, clip, fk, vals)
# koplampen en achterlichten flikkeren mee in Alarm
for naam, ob in LICHTEN.items():
    if "Knip" in naam:
        continue
    r0 = rust(ob)
    vals = []
    for f in fk:
        fase = (f % NK) / NK
        vals.append((r0[0], r0[1], AAN if fase < 0.5 else UIT))
    zet_actie(ob, "Alarm-loop", fk, vals)

scene.frame_start, scene.frame_end = 0, 36

# ============================================================ export
bpy.ops.object.select_all(action="DESELECT")
for ob in alle + [root]:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "auto.glb"), export_format="GLB", export_apply=False, export_yup=True,
                          use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_frame_range=False, export_morph=True, export_morph_normal=False, export_image_format="JPEG", export_jpeg_quality=88, export_lights=False, export_cameras=False)
bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "auto.blend"))
tris = {}
tot = 0
for ob in alle:
    ob.data.calc_loop_triangles()
    tris[ob.name] = len(ob.data.loop_triangles)
    tot += tris[ob.name]
print("TRIS", tris, "TOTAAL", tot, "MATERIALEN", len(MATS))

# ============================================================ studiorenders (Cycles CPU, gamecamera = 58 graden)
if RENDER:
    scene.render.engine = "CYCLES"
    scene.cycles.samples = int(os.environ.get('SAMPLES', 48))
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.40, 0.45, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    vl = bpy.data.objects.new("zon", bpy.data.lights.new("zon", "SUN"))
    vl.data.energy = 4.0
    vl.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(vl)
    gr = bpy.data.objects.new("grond", bpy.data.meshes.new("grond"))
    bmg = bmesh.new()
    bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=30)
    bmg.to_mesh(gr.data)
    scene.collection.objects.link(gr)
    gm = pbr("grondmat", color=(0.18, 0.2, 0.12), rough=1.0)
    gr.data.materials.append(gm)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    def foto(naam, pos, target, lens=45):
        cam.data.lens = lens
        cam.location = pos
        d = Vector(target) - Vector(pos)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, naam)
        bpy.ops.render.render(write_still=True)

    foto("auto_schuin.png", (5.6, 5.8, 2.8), (0, 0, 0.7))
    if not os.environ.get("ONE"):
        foto("auto_boven.png", (0, -17, 24), (0, 0, 0.5), 38)
        foto("auto_achter.png", (-5.0, -5.6, 2.2), (0, 0, 0.7))
    # deuren open (frame 36)
    scene.frame_set(36)
