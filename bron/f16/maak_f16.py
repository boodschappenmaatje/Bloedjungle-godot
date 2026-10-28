"""F-16C Fighting Falcon voor Bloedjungle (High Quality Showcase + VQ2): vervangt de napalm-straaljager (assets/straaljager.glb).
Specificatie: modellen/f16/ASSET_DESIGN_SPEC.md (projectmap). Echte USAF-kleuren: twee tinten grijs (Gunship Grey, FS 36118 boven / lichter onder),
gouden kap, donkere radoom, AIM-9 aan de vleugeltips, AIM-120 onder de vleugels en vier napalmbussen (Bom1..Bom4, gameplaycontract).

Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van de romp, voorkant aan +Y (wordt -Z in Godot). Lengte ~15,6 m, spanwijdte ~9,9 m.
Gebruik:  blender --background --python maak_f16.py -- <uitmap> [--2k] [--usdz]
  -> straaljager.glb (game), straaljager.blend (bron), texturen (PNG), met --usdz ook f16.usdz (Quick Look: alle clips achter elkaar)

Knopen in de GLB (Straaljager = wortel; zelfde contract als de oude straaljager):
  Body (leeg; de clips kantelen en rollen dit) met o.a. Romp, Neus, Kap, Inlaat, VleugelL/R, FlaperonL/R, StabilisatorL/R, Kiel,
  Naverbrander, Bom1..Bom4 (napalmbussen: het spel kopieert ze en laat ze vallen), AIM120_L/R, AIM9_L/R, GearNeus, GearL, GearR.
Clips: Vliegen-loop (2 s), Bocht (3 s), Aanval (3 s), Rol (2 s, volle rol), Landingsgestel (2,4 s: uit, vast, in).
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath([a for a in ARGS if not a.startswith("--")][0])
RENDER = "--render" in ARGS
TEX = 2048 if "--2k" in ARGS else 1024   # 2K = Showcase-bron, 1K = Godot-gameversie
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
FPS = 30
scene.render.fps = FPS


# ============================================================ texturen (numpy)
def noise(size, scale, seed):
    n = max(size // scale, 1)
    g = np.random.default_rng(seed).random((n + 1, n + 1))
    g[n, :] = g[0, :]
    g[:, n] = g[:, 0]
    scale = size / n   # past precies n keer in de tegel: de textuur herhaalt naadloos
    y, x = np.mgrid[0:size, 0:size]
    x, y = x / scale, y / scale
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


def sm(v, a, b):
    return np.clip((v - a) / (b - a), 0, 1)


def save_img(name, arr, non_color=False):
    h, w = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, axis=2)
    im = bpy.data.images.new(name, w, h)
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1))], axis=2)[::-1]
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


def lak_textures(naam, kleuren, camo, size=1024, seed=1, vlek=0.18, roet_k=0.35):
    """Tegel van 4 x 4 m: camouflagevlekken (of effen), plaatnaden met klinknagels, vuil, afgesleten verf.
    Geeft albedo, normal en ORM (occlusion/roughness/metallic) terug."""
    y, x = np.mgrid[0:size, 0:size]
    base = fbm(size, 128, seed)
    var = fbm(size, 32, seed + 10)
    if camo:
        a = sm(fbm(size, 512, seed + 3), 0.46, 0.50)   # harde vlekken
        b = sm(fbm(size, 256, seed + 5), 0.52, 0.56)
        img = np.zeros((size, size, 3)) + np.array(kleuren[0])
        img = img * (1 - a[..., None]) + np.array(kleuren[1]) * a[..., None]
        img = img * (1 - b[..., None]) + np.array(kleuren[2]) * b[..., None]
    else:
        img = np.zeros((size, size, 3)) + np.array(kleuren[0])
    img *= (1.0 - vlek / 2 + vlek * var)[..., None]
    h = np.zeros((size, size))
    # plaatnaden elke 1,0 x 1,3 m (4 m = 1024 px, dus 256 px per meter)
    s = max(size // 1024, 1)   # 1 of 2: constantes in pixels voor een tegel van 1024; 2K schaalt mee zodat naden even groot blijven
    naad = (((x % (256 * s)) < 2 * s) | ((x % (256 * s)) > 254 * s - 1)) | (((y % (333 * s)) < 2 * s) | ((y % (333 * s)) > 331 * s - 1))
    h -= naad * 0.6
    img[naad] *= 0.72
    # klinknagelrijen langs de naden
    for off in (10 * s, 246 * s):
        rij = ((x % (256 * s)) // s == off // s) & ((y % (14 * s)) < 3 * s)
        h += rij * 0.5
        rij2 = ((y % (333 * s)) // s == (off + 10 * s) // s) & ((x % (14 * s)) < 3 * s)
        h += rij2 * 0.5
        img[rij | rij2] *= 1.12
    # afgesleten verf op de randen van de naden: lichter metaal
    slijt = sm(fbm(size, 24 * s, seed + 20) * (naad | ((x % (256 * s)) < 6 * s)), 0.30, 0.45)
    img = img * (1 - slijt[..., None] * 0.7) + np.array([0.46, 0.46, 0.44]) * slijt[..., None] * 0.7
    # vuil en uitlaatroet: strepen in de lengterichting (v), mat
    streep = fbm(size, 8, seed + 30)
    roet = sm(noise(size, 64, seed + 40), 0.55, 0.9) * (0.4 + 0.6 * streep)
    img *= (1 - roet_k * roet)[..., None]
    h += (fbm(size, 6, seed + 50) - 0.5) * 0.35
    rough = np.clip(0.52 + 0.22 * fbm(size, 32, seed + 60) + 0.25 * slijt + 0.15 * roet, 0, 1)
    metal = np.clip(slijt * 0.9, 0, 1)
    orm = np.stack([np.ones((size, size)) * 0.95, rough, metal], axis=2)
    return (save_img(naam + "_albedo", np.clip(img, 0, 1)), save_img(naam + "_normal", normal_from_height(h, 2.2), True),
            save_img(naam + "_orm", orm, True))


def metaal_textures(naam, kleur, size=512, seed=70, ruw=0.45, metaal=0.85):
    h = fbm(size, 16, seed) * 0.5 + fbm(size, 4, seed + 1) * 0.5
    krassen = sm(noise(size, 3, seed + 2), 0.7, 1.0)
    img = np.zeros((size, size, 3)) + np.array(kleur)
    img *= (0.85 + 0.3 * fbm(size, 32, seed + 3))[..., None]
    img *= (1 - 0.3 * sm(fbm(size, 64, seed + 4), 0.55, 0.9))[..., None]
    orm = np.stack([np.ones((size, size)) * 0.9, np.clip(ruw + 0.25 * h + 0.2 * krassen, 0, 1), np.ones((size, size)) * metaal], axis=2)
    return (save_img(naam + "_albedo", np.clip(img, 0, 1)), save_img(naam + "_normal", normal_from_height(h * 0.6 + krassen * 0.2, 1.4), True),
            save_img(naam + "_orm", orm, True))


def pbr(naam, tex=None, color=(1, 1, 1), rough=0.6, metal=0.0, emit=None, strength=0.0, alpha=None):
    m = bpy.data.materials.new(naam)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if tex:
        alb, nor, orm = tex
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = alb
        nt.links.new(t.outputs["Color"], p.inputs["Base Color"])
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = nor
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.8
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
        o = nt.nodes.new("ShaderNodeTexImage")
        o.image = orm
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(o.outputs["Color"], sep.inputs[0])
        nt.links.new(sep.outputs["Green"], p.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], p.inputs["Metallic"])
    if emit is not None:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha is not None:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m


# ============================================================ materialen (echte USAF-grijstinten, sRGB)
BOVEN = pbr("Boven", lak_textures("jet_boven", [(0.33, 0.35, 0.37)], False, size=TEX, seed=11, vlek=0.07, roet_k=0.16))    # FS 36118 Gunship Grey
ONDER = pbr("Onder", lak_textures("jet_onder", [(0.50, 0.52, 0.54)], False, size=TEX, seed=21, vlek=0.07, roet_k=0.16))    # lichter grijs onderzijde
STAAL = pbr("Staal", metaal_textures("jet_staal", (0.30, 0.30, 0.29), size=TEX // 2))
DONKER = pbr("Donker", metaal_textures("jet_donker", (0.07, 0.07, 0.07), size=TEX // 2, ruw=0.5, metaal=0.6, seed=80))
RAKET = pbr("Raket", lak_textures("jet_raket", [(0.74, 0.75, 0.72)], False, size=TEX // 2, seed=41))
BUS = pbr("Napalmbus", lak_textures("jet_bus", [(0.36, 0.37, 0.30)], False, size=TEX // 2, seed=31))
RADOOM = pbr("Radoom", None, (0.20, 0.19, 0.17), 0.45, 0.0)
BAND = pbr("Oranjeband", None, (0.80, 0.30, 0.05), 0.5, 0.0)
GEEL = pbr("Geelband", None, (0.85, 0.65, 0.05), 0.5, 0.0)
GLAS = pbr("Glas", None, (0.30, 0.23, 0.08), 0.06, 0.8)    # gouden F-16-kap
GLOED = pbr("Naverbrander", None, (1.0, 0.45, 0.12), 0.4, 0.0, emit=(1.0, 0.45, 0.12), strength=2.2, alpha=0.55)      # middelste laag: halfdoorzichtig oranje
FLAMRAND = pbr("FlamRand", None, (0.9, 0.12, 0.03), 0.5, 0.0, emit=(0.9, 0.12, 0.03), strength=1.0, alpha=0.35)   # buitenste laag: doorzichtig rood
FLAMKERN = pbr("FlamKern", None, (1.0, 0.92, 0.72), 0.4, 0.0, emit=(1.0, 0.85, 0.55), strength=2.6)               # hete kern: geelwit
FLAMBLAUW = pbr("FlamBlauw", None, (0.55, 0.70, 1.0), 0.4, 0.0, emit=(0.45, 0.62, 1.0), strength=3.0)            # blauwe basis bij de nozzle
DIAMANT = pbr("Diamant", None, (1.0, 1.0, 1.0), 0.4, 0.0, emit=(1.0, 0.97, 0.9), strength=5.0)                    # schokdiamanten


# ============================================================ bouwstenen
ALLE = []


def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    ALLE.append(obj)
    return obj


def leeg(naam, parent=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(naam, None)
    o.location = loc
    return link(o, parent)


def uv_box(me, tegel=4.0):
    """Metrische boxprojectie per vlak (dominante normaalas), zodat naden en nagels overal even groot zijn."""
    uv = me.uv_layers.new(name="UV")
    for f in me.polygons:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in f.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uvv = (p.y, p.z)
            elif ax == 1:
                uvv = (p.x, p.z)
            else:
                uvv = (p.x, p.y)
            uv.data[li].uv = (uvv[0] / tegel, uvv[1] / tegel)


def mesh_obj(naam, bm, mat_boven, mat_onder=None, parent=None, loc=(0, 0, 0), smooth=True, sharp=40):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(naam)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat_boven)
    if mat_onder:
        me.materials.append(mat_onder)
        for f in me.polygons:
            f.material_index = 1 if f.normal.z < -0.25 else 0
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(sharp))
    uv_box(me)
    o = bpy.data.objects.new(naam, me)
    o.location = loc
    return link(o, parent)


def loft(naam, secties, mat, onder=None, parent=None, loc=(0, 0, 0), segs=16, dicht=(True, True)):
    """secties: (y, breedte, hoogte, z_midden, rondheid[, x_midden]); rondheid 2 = ellips, hoger = hoekiger."""
    bm = bmesh.new()
    ringen = []
    for s in secties:
        y, w, h, zc, p = s[:5]
        xc = s[5] if len(s) > 5 else 0.0
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs + math.pi / segs
            c, sn = math.cos(a), math.sin(a)
            ring.append(bm.verts.new((xc + w / 2 * math.copysign(abs(c) ** (2 / p), c), y, zc + h / 2 * math.copysign(abs(sn) ** (2 / p), sn))))
        ringen.append(ring)
    for r0, r1 in zip(ringen, ringen[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new([r0[i], r0[j], r1[j], r1[i]])
    if dicht[0]:
        bm.faces.new(ringen[0])
    if dicht[1]:
        bm.faces.new(list(reversed(ringen[-1])))
    return mesh_obj(naam, bm, mat, onder, parent, loc)


def cyl(naam, r, lengte, mat, parent=None, loc=(0, 0, 0), as_="y", segs=12, r2=None):
    """Cilinder (of kegel als r2 gezet is) langs een as; oorsprong in het midden."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=lengte)
    if as_ == "y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    elif as_ == "x":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    return mesh_obj(naam, bm, mat, None, parent, loc, smooth=True)


def doos(naam, maat, mat, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, verts=bm.verts, vec=maat)
    o = mesh_obj(naam, bm, mat, None, parent, loc, smooth=False)
    o.rotation_euler = rot
    return o


def profiel(c):
    """Halve dikte van een symmetrisch profiel (0..1 over de koorde), relatief aan de maximale dikte (=1)."""
    return 5 * (0.2969 * math.sqrt(c) - 0.1260 * c - 0.3516 * c * c + 0.2843 * c ** 3 - 0.1015 * c ** 4) / 0.0594 * 0.5


def vleugel(naam, secties, c0, c1, mat, onder, parent=None, loc=(0, 0, 0), n=7):
    """Vleugelstuk tussen koordefracties c0 (voor) en c1 (achter).
    secties: (x, y_voorrand, koorde, dikte, z). Dikte is de maximale dikte in meters."""
    bm = bmesh.new()
    cs = [c0 + (c1 - c0) * i / n for i in range(n + 1)]
    ringen = []
    for (x, y0, koorde, dikte, z) in secties:
        ring = []
        for c in cs:                                  # bovenkant, voor naar achter
            ring.append(bm.verts.new((x, y0 - c * koorde, z + profiel(c) * dikte * 0.5 + 0.02 * dikte * (1 - c))))
        for c in reversed(cs):                        # onderkant, achter naar voor
            ring.append(bm.verts.new((x, y0 - c * koorde, z - profiel(c) * dikte * 0.5 * 0.9 + 0.02 * dikte * (1 - c))))
        ringen.append(ring)
    m = len(ringen[0])
    for r0, r1 in zip(ringen, ringen[1:]):
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new([r0[i], r0[j], r1[j], r1[i]])
    bm.faces.new(ringen[0])
    bm.faces.new(list(reversed(ringen[-1])))
    return mesh_obj(naam, bm, mat, onder, parent, loc, sharp=60)


# ============================================================ het toestel
def verfijn(sec, per=3):
    """Catmull-Rom tussen de stuurdoorsneden, zodat de romp glad loopt zonder veel handwerk."""
    out = []
    n = len(sec)
    for i in range(n - 1):
        p0, p1, p2, p3 = sec[max(i - 1, 0)], sec[i], sec[i + 1], sec[min(i + 2, n - 1)]
        for k in range(per):
            t = k / per
            out.append(tuple(0.5 * ((2 * a1) + (-a0 + a2) * t + (2 * a0 - 5 * a1 + 4 * a2 - a3) * t * t + (-a0 + 3 * a1 - 3 * a2 + a3) * t ** 3)
                             for a0, a1, a2, a3 in zip(p0, p1, p2, p3)))
    out.append(sec[-1])
    return out


def pivot_vleugel(naam, secties, c0, c1, mat, onder, parent, gem):
    """Vleugelstuk waarvan de oorsprong op de scharnier `gem` ligt (draait om de X-as)."""
    o = vleugel(naam, secties, c0, c1, mat, onder, parent)
    gem = Vector(gem)
    for v in o.data.vertices:
        v.co -= gem
    o.location = gem
    o.rotation_mode = "XYZ"
    return o


root = leeg("Straaljager")
body = leeg("Body", root)

# -- romp (F-16C: gemengde vleugel-romp, kin-inlaat, enkele motor) en radoom
romp = loft("Romp", verfijn([
    (5.4, 1.10, 1.00, 0.10, 2.4),
    (4.0, 1.45, 1.20, 0.12, 2.5),
    (2.0, 1.80, 1.35, 0.12, 2.7),
    (-1.0, 2.00, 1.45, 0.14, 3.0),
    (-4.0, 1.85, 1.40, 0.25, 2.8),
    (-6.4, 1.40, 1.20, 0.35, 2.4),
    (-7.3, 1.15, 1.05, 0.35, 2.2),
]), BOVEN, ONDER, body, segs=28)
loft("Neus", verfijn([
    (7.45, 0.10, 0.10, 0.07, 2.2),
    (7.0, 0.50, 0.50, 0.07, 2.2),
    (6.2, 0.88, 0.84, 0.09, 2.3),
    (5.3, 1.10, 1.00, 0.10, 2.4),
], 2), RADOOM, None, body, segs=24)
cyl("Pitot", 0.018, 0.9, STAAL, body, (0, 7.85, 0.07), "y", 6, 0.008)

# -- kap (goud glas), kaprand en schietstoel/hoofdsteun, rugspine
loft("Kap", verfijn([
    (4.7, 0.50, 0.20, 0.77, 2.2),
    (4.1, 0.95, 0.60, 0.95, 2.2),
    (3.1, 1.05, 0.72, 1.00, 2.2),
    (1.9, 0.90, 0.55, 0.98, 2.2),
    (0.9, 0.55, 0.25, 0.92, 2.2),
    (0.4, 0.30, 0.10, 0.90, 2.2),
], 2), GLAS, None, body, segs=20)
doos("KapRand", (1.00, 0.05, 0.05), STAAL, body, (0, 4.45, 1.02))
doos("KapRand2", (1.08, 0.05, 0.05), STAAL, body, (0, 1.75, 1.18 - 0.2))
doos("Hoofdsteun", (0.34, 0.30, 0.45), DONKER, body, (0, 2.0, 0.95))
loft("Rug", verfijn([
    (0.4, 0.30, 0.20, 0.88, 2.3),
    (-1.0, 0.80, 0.35, 0.95, 2.4),
    (-3.0, 0.85, 0.40, 1.05, 2.4),
    (-5.5, 0.50, 0.25, 1.05, 2.3),
], 2), BOVEN, None, body, segs=16)

# -- kin-inlaat onder de romp met donkere inlaatopening
loft("Inlaat", verfijn([
    (2.30, 1.15, 0.80, -0.75, 3.2),
    (1.60, 1.50, 0.90, -0.72, 3.2),
    (0.20, 1.75, 1.00, -0.62, 3.0),
], 2), BOVEN, ONDER, body, segs=20)
loft("InlaatGat", [(2.34, 0.98, 0.62, -0.75, 3.2), (2.20, 0.98, 0.62, -0.75, 3.2)], DONKER, None, body, segs=20)

# -- uitlaat met naverbrander
cyl("UitlaatRing", 0.66, 0.30, STAAL, body, (0, -7.35, 0.35), "y", 20)
cyl("UitlaatKern", 0.50, 0.60, DONKER, body, (0, -7.75, 0.35), "y", 20, 0.46)
# nozzle: 16 petalen die om hun scharnier (tangentiele as) open en dicht gaan met de gasstand
NOZ = leeg("Nozzle", body, (0, -7.50, 0.35))
PETALEN = []
for i in range(16):
    a = i / 16 * math.tau
    pv = leeg(f"NozzleP{i}", NOZ, (math.sin(a) * 0.60, 0, math.cos(a) * 0.60))
    pv.rotation_mode = "XYZ"
    pv.rotation_euler = (0, a, 0)
    doos(f"Petaal{i}", (0.235, 0.85, 0.03), DONKER if i % 2 else STAAL, pv, (0, -0.425, 0))
    PETALEN.append((pv, a))
# gelaagde nabrandervlam met schokdiamanten (wortel Naverbrander schaalt met de gasstand; lengte langs -Y)
FLAM = leeg("Naverbrander", body, (0, -8.30, 0.35))
cyl("FlamRand", 0.58, 3.8, FLAMRAND, FLAM, (0, -1.90, 0), "y", 16, 0.04)
cyl("FlamBuiten", 0.46, 3.1, GLOED, FLAM, (0, -1.55, 0), "y", 16, 0.03)
cyl("FlamKernKegel", 0.22, 2.3, FLAMKERN, FLAM, (0, -1.15, 0), "y", 14, 0.02)
cyl("FlamBlauwKegel", 0.20, 0.8, FLAMBLAUW, FLAM, (0, -0.40, 0), "y", 14, 0.16)
DIAM = []
for k in range(5):
    yy = -(0.50 + 0.44 * k)
    r = 0.30 - 0.035 * k
    d = leeg(f"Naverbrander_Diamant{k}", FLAM, (0, yy, 0))
    cyl(f"DiamantA{k}", r, 0.30, DIAMANT, d, (0, 0.15, 0), "y", 10, 0.01)
    cyl(f"DiamantB{k}", r, 0.30, DIAMANT, d, (0, -0.15, 0), "y", 10, 0.01)
    DIAM.append(d)

# -- vleugels: afgeknotte delta (voorrand 40 graden), strakes, flaperons
X0, X1 = 0.9, 4.7


def wsec(x):
    """(x, y_voorrand, koorde, dikte, z) op halve overspanning x."""
    t = (x - X0) / (X1 - X0)
    return (x, 1.3 - 2.7 * t, 4.8 - 3.4 * t, 0.40 - 0.28 * t, -0.12 + 0.05 * t)


def wz_onder(x):
    s = wsec(x)
    return s[4] - 0.45 * s[3]


for zijde in (-1, 1):
    tag = "L" if zijde < 0 else "R"
    mir = lambda s: (zijde * s[0],) + tuple(s[1:])
    vleugel("Vleugel" + tag, [mir(wsec(x)) for x in (0.8, 2.0, 3.3, 4.7)], 0.0, 0.72, BOVEN, ONDER, body)
    vleugel("Achterrand" + tag, [mir(wsec(x)) for x in (3.9, 4.7)], 0.72, 1.0, BOVEN, ONDER, body)
    vleugel("Strake" + tag, [(zijde * 0.75, 4.3, 5.9, 0.14, 0.05), (zijde * 1.55, 1.6, 2.7, 0.08, 0.06)], 0.0, 1.0, BOVEN, ONDER, body)
    fl = [mir(wsec(x)) for x in (0.8, 2.3, 3.9)]
    hy = sum(s[1] - 0.72 * s[2] for s in fl) / len(fl)
    pivot_vleugel("Flaperon" + tag, fl, 0.72, 1.0, BOVEN, ONDER, body, (zijde * 2.35, hy, sum(s[4] for s in fl) / len(fl)))
    # stabilator (geheel draaiend)
    st = [(zijde * 0.9, -4.4, 2.8, 0.20, 0.05), (zijde * 3.0, -6.0, 1.1, 0.09, 0.08)]
    sy = (-4.4 - 0.4 * 2.8 - 6.0 - 0.4 * 1.1) / 2
    pivot_vleugel("Stabilisator" + tag, st, 0.0, 1.0, BOVEN, ONDER, body, (zijde * 1.95, sy, 0.065))
    # buikvin
    doos("Buikvin" + tag, (0.05, 1.9, 0.7), BOVEN, body, (zijde * 0.8, -5.6, -0.82), (0, math.radians(20 * zijde), 0))
    # vleugeltip: rail en AIM-9
    doos("Rail" + tag, (0.05, 1.6, 0.05), STAAL, body, (zijde * 4.78, -1.9, -0.08))

# -- verticale staart met rolroerrand en positielicht
bm = bmesh.new()
pts = [(-2.8, 0.9), (-7.2, 0.9), (-7.35, 4.2), (-5.4, 4.2)]
for dx in (-0.07, 0.07):
    for (y, z) in pts:
        bm.verts.new((dx, y, z))
v = list(bm.verts)
for i in range(4):
    j = (i + 1) % 4
    bm.faces.new([v[i], v[j], v[j + 4], v[i + 4]])
bm.faces.new(v[:4])
bm.faces.new(list(reversed(v[4:])))
mesh_obj("Kiel", bm, BOVEN, ONDER, body, smooth=False)
doos("Kieltop", (0.18, 1.9, 0.12), STAAL, body, (0, -6.35, 4.24))
cyl("Staartlicht", 0.05, 0.12, pbr("Staartlicht", None, (0.95, 0.95, 0.9), 0.3, 0.0, emit=(0.95, 0.95, 0.9), strength=2.0), body, (0, -7.4, 3.2), "y", 8)


# -- extra detail: klepdeuren landingsgestel, kaprand en spanten, antennes, vleugelwortel-kuip
doos("Antenne", (0.03, 0.4, 0.30), DONKER, body, (0, -4.0, 1.30))
doos("DeurNeus", (0.62, 0.9, 0.04), ONDER, body, (0, 3.45, -0.49))
for zijde in (-1, 1):
    doos("DeurHoofd" + ("L" if zijde < 0 else "R"), (0.55, 1.4, 0.04), ONDER, body, (zijde * 0.55, -0.6, -0.58))
    doos("Luchtrem" + ("L" if zijde < 0 else "R"), (0.05, 1.1, 0.35), STAAL, body, (zijde * 0.62, -5.9, 0.35))
cyl("HUD", 0.02, 0.5, DONKER, body, (0, 4.2, 1.02), "x", 6)
doos("Spiegel", (0.5, 0.05, 0.05), DONKER, body, (0, 4.28, 1.22))


# -- wapens: AIM-9 (tip), AIM-120 (onder de vleugel), 4 napalmbussen
def raket(naam, r, lengte, parent, loc, vin_span, geel=False):
    n = leeg(naam, parent, loc)
    cyl(naam + "Romp", r, lengte * 0.82, RAKET, n, (0, -lengte * 0.09, 0), "y", 10)
    cyl(naam + "Neus", r, lengte * 0.18, RAKET, n, (0, lengte * 0.41, 0), "y", 10, r * 0.12)
    cyl(naam + "Zoeker", r * 0.55, lengte * 0.04, DONKER, n, (0, lengte * 0.50, 0), "y", 8)
    if geel:
        cyl(naam + "Band", r * 1.03, lengte * 0.03, GEEL, n, (0, lengte * 0.20, 0), "y", 10)
    for k in range(4):
        a = k * math.pi / 2
        for (yy, spn, kd) in ((-lengte * 0.46, vin_span, lengte * 0.12), (lengte * 0.18, vin_span * 0.55, lengte * 0.07)):
            f = doos(f"{naam}Vin{k}_{yy:.1f}", (0.015, kd, spn), RAKET, n, (math.sin(a) * (r + spn / 2 - 0.01), yy, math.cos(a) * (r + spn / 2 - 0.01)))
            f.rotation_euler = (0, a, 0)
    return n


for zijde in (-1, 1):
    tag = "L" if zijde < 0 else "R"
    x = zijde * 4.05
    zu = wz_onder(4.05)
    doos("PyloonA" + tag, (0.12, 1.5, 0.30), STAAL, body, (x, -1.2, zu - 0.12))
    raket("AIM120_" + tag, 0.09, 3.65, body, (x, -1.2, zu - 0.30 - 0.09), 0.33)
    raket("AIM9_" + tag, 0.065, 2.9, body, (zijde * 4.86, -1.55, -0.08), 0.22, geel=True)

BUSX = {1: -2.9, 2: -1.6, 3: 1.6, 4: 2.9}
for k, x in BUSX.items():
    s = wsec(abs(x))
    zu = wz_onder(abs(x))
    yc = s[1] - 0.40 * s[2]
    doos(f"Pyloon{k}", (0.14, 1.7, 0.30), STAAL, body, (x, yc, zu - 0.12))
    bus = leeg(f"Bom{k}", body, (x, yc, zu - 0.30 - 0.27))
    cyl(f"BusRomp{k}", 0.27, 2.2, BUS, bus, (0, 0, 0), "y", 12)
    cyl(f"BusNeus{k}", 0.27, 0.45, BUS, bus, (0, 1.32, 0), "y", 12, 0.05)
    cyl(f"BusAchter{k}", 0.27, 0.40, BUS, bus, (0, -1.28, 0), "y", 12, 0.14)
    for yy in (0.70, 0.45):
        cyl(f"Band{k}_{yy}", 0.282, 0.09, BAND, bus, (0, yy, 0), "y", 12)
    for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
        b = doos(f"Vin{k}_{a:.1f}", (0.03, 0.50, 0.26), STAAL, bus, (math.sin(a) * 0.27, -1.33, math.cos(a) * 0.27))
        b.rotation_euler = (0, a, 0)

# -- positielichten op de vleugeltips en landingsgestel (ingeklapt in rust)
for zijde, col in ((-1, (0.9, 0.1, 0.05)), (1, (0.1, 0.8, 0.2))):
    cyl("Tiplicht" + ("L" if zijde < 0 else "R"), 0.05, 0.10, pbr("Tiplicht" + str(zijde), None, col, 0.3, 0.0, emit=col, strength=2.0), body, (zijde * 4.88, -0.15, -0.08), "x", 8)

GEAR = []
gn = leeg("GearNeus", body, (0, 3.7, -0.15))
cyl("NeusPoot", 0.05, 1.15, STAAL, gn, (0, 0, -0.575), "z", 8)
cyl("NeusWiel", 0.30, 0.20, DONKER, gn, (0, 0, -1.15), "x", 16)
cyl("NeusVork", 0.04, 0.34, STAAL, gn, (0, 0, -1.05), "x", 6)
GEAR.append((gn, (-math.pi / 2, 0, 0)))
for zijde in (-1, 1):
    tag = "L" if zijde < 0 else "R"
    g = leeg("Gear" + tag, body, (zijde * 0.9, -0.6, -0.15))
    cyl("HoofdPoot" + tag, 0.07, 1.25, STAAL, g, (0, 0, -0.625), "z", 8)
    cyl("HoofdWiel" + tag, 0.36, 0.30, DONKER, g, (zijde * 0.0, 0, -1.25), "x", 18)
    cyl("HoofdVering" + tag, 0.05, 0.6, STAAL, g, (zijde * 0.1, 0.15, -0.5), "z", 6)
    GEAR.append((g, (0, zijde * math.pi / 2, 0)))
for g, rust in GEAR:
    g.rotation_mode = "XYZ"
    g.rotation_euler = rust
body_rust = {g: rust for g, rust in GEAR}


# ============================================================ animaties
def hoek(graden):
    return math.radians(graden)


def zet_actie(clip, frames, pose, doelen):
    """pose(t) -> {object: {'rot': (x,y,z), 'loc': (x,y,z), 'scale': (x,y,z)}}; t in seconden."""
    acts = {}
    for o in doelen:
        o.animation_data_create()
        a = bpy.data.actions.new(f"{clip}_{o.name}")
        o.animation_data.action = a
        acts[o] = a
    for f in range(frames + 1):
        t = f / FPS
        stand = pose(t)
        for o, w in stand.items():
            if "rot" in w:
                o.rotation_euler = w["rot"]
                o.keyframe_insert("rotation_euler", frame=f)
            if "loc" in w:
                o.location = w["loc"]
                o.keyframe_insert("location", frame=f)
            if "scale" in w:
                o.scale = w["scale"]
                o.keyframe_insert("scale", frame=f)
    for o, a in acts.items():
        fcs = []
        for layer in getattr(a, "layers", []):
            for strip in layer.strips:
                for bag in strip.channelbags:
                    fcs.extend(bag.fcurves)
        fcs.extend(getattr(a, "fcurves", []))
        for fc in fcs:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
        tr = o.animation_data.nla_tracks.new()
        tr.name = clip
        st = tr.strips.new(clip, 0, a)
        st.name = clip
        o.animation_data.action = None


def sin(t, periode, amp, fase=0.0):
    return amp * math.sin(math.tau * t / periode + fase)


NAV = [o for o in ALLE if o.name == "Naverbrander"]
FLAP = {o.name: o for o in ALLE if o.name.startswith("Flaperon")}
STAB = {o.name: o for o in ALLE if o.name.startswith("Stabilisator")}
GEARO = [g for g, _ in GEAR]
for o in [body] + NAV + list(FLAP.values()) + list(STAB.values()):
    o.rotation_mode = "XYZ"
LOC0 = {o: o.location.copy() for o in list(FLAP.values()) + list(STAB.values())}
DOELEN = [body] + NAV + DIAM + [p for p, _ in PETALEN] + list(FLAP.values()) + list(STAB.values())
for o in DIAM + [p for p, _ in PETALEN]:
    o.rotation_mode = "XYZ"


def smooth(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3 - 2 * u)


def vliegen(t, pitch=0.0, roll=0.0, dz=0.0, ail=0.0, gas=0.85, flare=0.0):
    """Standaardpose: romp deint licht, flaperons/stabilators bewegen licht en de motor staat op een gasstand.
    gas 0 = stationair (nozzle dicht, geen vlam), ~0,5 = militair vermogen, 1 = volle nabrander (lange vlam, nozzle wijd open).
    flare = korte opflakkering bij het inschakelen (extra lengte)."""
    stand = {body: {"rot": (pitch + sin(t, 2.0, hoek(0.5)), roll + sin(t, 4.0, hoek(0.9)), 0.0),
                    "loc": (0, 0, dz + sin(t, 2.0, 0.04))}}
    for n, o in FLAP.items():
        richting = 1.0 if n.endswith("R") else -1.0
        stand[o] = {"rot": (ail * richting + sin(t, 2.0, hoek(2.0), 0.7 * richting), 0.0, 0.0)}
    for n, o in STAB.items():
        richting = 1.0 if n.endswith("R") else -1.0
        stand[o] = {"rot": (hoek(-1) + sin(t, 2.0, hoek(1.2), 0.3) + 0.5 * ail * richting, 0.0, 0.0)}
    # nozzle: dicht bij stationair/militair, wijd open in nabrander
    open_graden = -3.0 + 11.0 * gas
    for i, (pv, ang) in enumerate(PETALEN):
        stand[pv] = {"rot": (-hoek(open_graden + 0.6 * math.sin(math.tau * t * 4.0 + i * 0.7)), ang, 0.0)}
    # vlam: pas zichtbaar boven ~0,45 gas; flikkering met hele periodes per 2 s zodat de lus naadloos sluit
    aan = smooth((gas - 0.45) / 0.15)
    flik = 1.0 + 0.07 * math.sin(math.tau * t * 6.0) + 0.04 * math.sin(math.tau * t * 11.0 + 1.0)
    lengte = max(0.001, aan * (0.35 + 0.65 * min(gas, 1.0)) * flik * (1.0 + 0.35 * flare))
    breedte = max(0.001, aan * (0.6 + 0.4 * min(gas, 1.0)) * (1.0 + 0.04 * math.sin(math.tau * t * 8.0)))
    for o in NAV:
        stand[o] = {"scale": (breedte, lengte, breedte)}
    # schokdiamanten: pulseren in tegenfase, nemen af in grootte bij lage gas
    for k, d in enumerate(DIAM):
        f = max(0.001, aan * (0.55 + 0.45 * gas) * (1.0 + 0.22 * math.sin(math.tau * t * 4.0 + k * 1.1)))
        stand[d] = {"scale": (f, f * (1.0 + 0.3 * math.sin(math.tau * t * 6.0 + k)), f)}
    return stand


def gear_pose(t):
    stand = vliegen(t, gas=0.30)   # naderen: stationair/laag vermogen, geen nabrander
    u = smooth(t / 0.9) if t < 1.5 else 1.0 - smooth((t - 1.5) / 0.9)   # 0 = ingeklapt, 1 = uitgeklapt
    for g, rust in GEAR:
        stand[g] = {"rot": tuple(r * (1 - u) for r in rust)}
    return stand


def bump(t, midden, breedte):
    return math.exp(-((t - midden) / breedte) ** 2)


zet_actie("Vliegen-loop", 60, lambda t: vliegen(t, gas=0.85), DOELEN)
zet_actie("Bocht", 90, lambda t: vliegen(t, hoek(-2), hoek(30) * math.sin(math.pi * min(t / 3.0, 1.0)) ** 0.8,
                                         0.0, hoek(10) * math.sin(math.pi * min(t / 3.0, 1.0)), gas=0.85), DOELEN)
zet_actie("Aanval", 90, lambda t: vliegen(t, hoek(-6) * math.sin(math.pi * min(t / 3.0, 1.0)), 0.0,
                                          -0.4 * math.sin(math.pi * min(t / 3.0, 1.0)), 0.0,
                                          gas=0.85 + 0.15 * math.sin(math.pi * min(t / 1.5, 1.0)), flare=bump(t, 0.4, 0.2)), DOELEN)
zet_actie("Rol", 60, lambda t: vliegen(t, 0.0, math.tau * smooth(t / 2.0), 0.0, hoek(18) * math.sin(math.pi * min(t / 2.0, 1.0)), gas=1.0), DOELEN)
zet_actie("Landingsgestel", 72, gear_pose, DOELEN + GEARO)
for o in DOELEN:
    o.rotation_euler = (0, 0, 0)
    o.scale = (1, 1, 1)
body.location = (0, 0, 0)
for o, l in LOC0.items():
    o.location = l
for g, rust in GEAR:
    g.rotation_euler = rust
for pv, ang in PETALEN:
    pv.rotation_euler = (-hoek(-3.0 + 11.0 * 0.85), ang, 0)
_rust = vliegen(0.0, gas=0.85)   # rustpose = begin van Vliegen-loop (vlam op reisstand)
for o in NAV + DIAM:
    o.scale = _rust[o]["scale"]
scene.frame_start, scene.frame_end = 0, 90


# ============================================================ export
bpy.ops.object.select_all(action="DESELECT")
for o in ALLE:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "straaljager.glb"), export_format="GLB", export_apply=False, export_yup=True,
                          use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_frame_range=False, export_image_format="JPEG", export_jpeg_quality=88, export_lights=False, export_cameras=False)
bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "straaljager.blend"))
tris = 0
for o in ALLE:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("F16 driehoeken", tris, "materialen", len(bpy.data.materials), "tex", TEX)

# ============================================================ USDZ-preview (iPhone Bestanden-app / Quick Look)
if "--usdz" in ARGS:
    # Quick Look speelt één tijdlijn: de vijf clips komen achter elkaar (de NLA-sporen staan nu allemaal op frame 0).
    volgorde = [("Vliegen-loop", 60), ("Rol", 60), ("Bocht", 90), ("Aanval", 90), ("Landingsgestel", 72)]
    start = 0
    for naam, lengte in volgorde:
        for o in ALLE:
            ad = o.animation_data
            if ad:
                for tr in ad.nla_tracks:
                    if tr.name == naam:
                        tr.strips[0].frame_start_ui = start
                        tr.strips[0].extrapolation = "HOLD" if o in GEARO else "NOTHING"   # NOTHING: anders houdt het bovenste spoor zijn eerste beeld vast over alle clips; het landingsgestel blijft ingeklapt buiten zijn eigen clip
        start += lengte + 10
    scene.frame_start, scene.frame_end = 0, start - 10
    scene.render.fps = FPS
    bpy.ops.wm.usd_export(filepath=os.path.join(OUT, "f16.usdz"), selected_objects_only=False, export_animation=True,
                          export_materials=True, generate_preview_surface=True, export_textures=True, overwrite_textures=True,
                          evaluation_mode="RENDER")
    print("F16 USDZ geschreven")

# JPEG-kopieen (als laatste: het opslaan wijzigt het bestandsformaat van de beelden) voor assets/ (zelfde naamgeving als bij de oude straaljager: straaljager_<naam>.jpg)
os.makedirs(os.path.join(OUT, "assets_jpg"), exist_ok=True)
for im in list(bpy.data.images):
    if im.name.startswith("jet_"):
        im.file_format = "JPEG"
        im.filepath_raw = os.path.join(OUT, "assets_jpg", "straaljager_" + im.name + ".jpg")
        im.save()
