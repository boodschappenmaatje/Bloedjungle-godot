"""Aanvalsstraaljager voor de luchtsteun (Bloedjungle, VQ2): tweemotorig grondaanvalstoestel met rechte vleugels
(in de lijn van de A-10), vier napalmbussen onder de vleugels en echte Blender-clips.
Gebruikt voor de killstreak NAPALM-AANVAL: het toestel scheert laag over een strook en laat de bussen vallen.

Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van de romp, voorkant aan +Y (wordt -Z in Godot).
Gebruik:  python3 maak_straaljager.py <uitmap> [--render]   ->  straaljager.glb, straaljager.blend, texturen (PNG) in <uitmap>

Knopen in de GLB (Straaljager = wortel):
  Body (leeg; de clips kantelen en rollen dit) met daarin:
    Romp, Kap (glas), MotorL, MotorR, Staart (stabilisator + kielen), Vleugels, Kanon (7 lopen), Pylonen,
    AileronL, AileronR (scharnieren om de X-as), Naverbrander_L/R (gloed, rustschaal 1),
    Bom1..Bom4 (napalmbussen onder de vleugels: het spel kopieert ze en laat ze vallen).
Clips: Vliegen-loop (naverbrander, rolroeren, lichte deining), Bocht (rol 30 graden en terug), Aanval (neus 6 graden omlaag
en weer vlak: de aanvalsduik boven de strook).
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath([a for a in ARGS if not a.startswith("--")][0])
RENDER = "--render" in ARGS
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


def lak_textures(naam, kleuren, camo, size=1024, seed=1):
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
    img *= (0.90 + 0.18 * var)[..., None]
    h = np.zeros((size, size))
    # plaatnaden elke 1,0 x 1,3 m (4 m = 1024 px, dus 256 px per meter)
    naad = (((x % 256) < 2) | ((x % 256) > 253)) | (((y % 333) < 2) | ((y % 333) > 330))
    h -= naad * 0.6
    img[naad] *= 0.72
    # klinknagelrijen langs de naden
    for off in (10, 246):
        rij = ((x % 256) == off) & ((y % 14) < 3)
        h += rij * 0.5
        rij2 = ((y % 333) == off + 10) & ((x % 14) < 3)
        h += rij2 * 0.5
        img[rij | rij2] *= 1.12
    # afgesleten verf op de randen van de naden: lichter metaal
    slijt = sm(fbm(size, 24, seed + 20) * (naad | ((x % 256) < 6)), 0.30, 0.45)
    img = img * (1 - slijt[..., None] * 0.7) + np.array([0.46, 0.46, 0.44]) * slijt[..., None] * 0.7
    # vuil en uitlaatroet: strepen in de lengterichting (v), mat
    streep = fbm(size, 8, seed + 30)
    roet = sm(noise(size, 64, seed + 40), 0.55, 0.9) * (0.4 + 0.6 * streep)
    img *= (1 - 0.35 * roet)[..., None]
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


# ============================================================ materialen
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


BOVEN = pbr("Boven", lak_textures("jet_boven", [(0.22, 0.25, 0.15), (0.30, 0.31, 0.22), (0.14, 0.17, 0.11)], True, seed=11))
ONDER = pbr("Onder", lak_textures("jet_onder", [(0.60, 0.62, 0.58)], False, seed=21))
STAAL = pbr("Staal", metaal_textures("jet_staal", (0.30, 0.30, 0.29)))
DONKER = pbr("Donker", metaal_textures("jet_donker", (0.07, 0.07, 0.07), ruw=0.5, metaal=0.6, seed=80))
BUS = pbr("Napalmbus", lak_textures("jet_bus", [(0.36, 0.37, 0.30)], False, seed=31))
BAND = pbr("Oranjeband", None, (0.80, 0.30, 0.05), 0.5, 0.0)
GLAS = pbr("Glas", None, (0.05, 0.09, 0.10), 0.05, 0.5)
GLOED = pbr("Naverbrander", None, (1.0, 0.45, 0.12), 0.4, 0.0, emit=(1.0, 0.45, 0.12), strength=3.0)


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
root = leeg("Straaljager")
body = leeg("Body", root)

# -- romp: slank, cockpit voor, motorstaart achter (A-10-achtig, 16,4 m)
romp = loft("Romp", [
    (8.0, 0.20, 0.20, -0.18, 2.4),
    (7.2, 0.80, 0.80, -0.14, 2.3),
    (6.0, 1.30, 1.30, -0.02, 2.4),
    (4.5, 1.60, 1.55, 0.10, 2.5),
    (2.0, 1.75, 1.60, 0.14, 2.6),
    (-1.0, 1.70, 1.55, 0.20, 2.6),
    (-4.0, 1.45, 1.40, 0.34, 2.5),
    (-6.6, 0.95, 1.05, 0.52, 2.4),
    (-7.8, 0.45, 0.55, 0.62, 2.2),
], BOVEN, ONDER, body)

# cockpitkap: glasbel met stalen kader
kap = loft("Kap", [
    (6.1, 0.55, 0.30, 0.56, 2.2),
    (5.3, 1.00, 0.72, 0.62, 2.2),
    (4.2, 1.10, 0.80, 0.68, 2.2),
    (3.2, 0.95, 0.55, 0.66, 2.2),
    (2.7, 0.60, 0.20, 0.60, 2.2),
], GLAS, None, body)
doos("KapRand", (1.06, 0.05, 0.05), STAAL, body, (0, 4.75, 0.98))
doos("KapRand2", (1.12, 0.05, 0.05), STAAL, body, (0, 3.50, 1.02))

# neus: kanon met zeven lopen
kanon = leeg("Kanon", body, (0, 0, 0))
cyl("KanonHuis", 0.34, 2.6, DONKER, kanon, (0, 7.2, -0.42), "y", 14)
for i in range(7):
    a = i / 7 * math.tau
    cyl(f"Loop{i}", 0.055, 3.0, STAAL, kanon, (math.cos(a) * 0.20, 8.3, -0.42 + math.sin(a) * 0.20), "y", 6)
cyl("KanonMond", 0.30, 0.10, DONKER, kanon, (0, 8.5, -0.42), "y", 14)

# motoren op de romp, met inlaatring en uitlaat
for zijde, tag in ((-1, "L"), (1, "R")):
    mx = zijde * 1.55
    mot = loft(f"Motor{tag}", [
        (-0.2, 1.10, 1.10, 1.02, 2.0, mx),
        (-1.0, 1.28, 1.28, 1.05, 2.0, mx),
        (-4.5, 1.28, 1.28, 1.08, 2.0, mx),
        (-6.6, 1.02, 1.02, 1.10, 2.0, mx),
    ], BOVEN, ONDER, body, segs=18)
    cyl(f"Inlaat{tag}", 0.58, 0.18, STAAL, body, (mx, -0.15, 1.02), "y", 18, 0.6)
    cyl(f"InlaatGat{tag}", 0.45, 0.20, DONKER, body, (mx, -0.12, 1.02), "y", 18)
    cyl(f"Uitlaat{tag}", 0.50, 0.9, DONKER, body, (mx, -6.9, 1.10), "y", 18, 0.42)
    gl = cyl(f"Naverbrander_{tag}", 0.40, 0.08, GLOED, body, (mx, -7.38, 1.10), "y", 16)
    # pylon tussen romp en motor
    doos(f"Motorsteun{tag}", (0.75, 3.6, 0.18), BOVEN, body, (zijde * 1.05, -3.2, 0.52))

# vleugels: rechte vleugel met lichte taper; voorrand recht, achterrand loopt iets schuin
VL = []
for zijde in (-1, 1):
    secties = [(zijde * x, y0, k, d, z) for (x, y0, k, d, z) in [
        (0.8, 1.9, 4.3, 0.62, 0.05),
        (3.0, 1.8, 3.9, 0.52, 0.02),
        (5.4, 1.5, 3.3, 0.40, 0.02),
        (7.6, 1.2, 2.7, 0.30, 0.10),
        (8.6, 1.0, 2.3, 0.22, 0.20),
    ]]
    VL.append(vleugel("Vleugel" + ("L" if zijde < 0 else "R"), secties, 0.0, 0.72, BOVEN, ONDER, body))
    # flap tussen romp en rolroer
    fl = [(zijde * x, y0, k, d, z) for (x, y0, k, d, z) in [(0.8, 1.9, 4.3, 0.62, 0.05), (3.0, 1.8, 3.9, 0.52, 0.02), (4.6, 1.6, 3.5, 0.44, 0.02)]]
    vleugel("Flap" + ("L" if zijde < 0 else "R"), fl, 0.72, 1.0, BOVEN, ONDER, body)
    # rolroer: scharnier op c = 0,72 (hier de oorsprong), draait om de X-as
    ail = [(0.0, 0.0, 0.28 * k, d * 0.45, 0.0) for (x, y0, k, d, z) in [(4.6, 1.6, 3.5, 0.44, 0.02), (8.6, 1.0, 2.3, 0.22, 0.2)]]
    # (x, y0, koorde, dikte, z) in lokale ruimte; de vlakken worden hieronder naar de juiste plek geschoven
    a0 = (zijde * 4.6, 1.6 - 0.72 * 3.5, 0.28 * 3.5, 0.20, 0.02)
    a1 = (zijde * 8.6, 1.0 - 0.72 * 2.3, 0.28 * 2.3, 0.12, 0.20)
    o = vleugel("Aileron" + ("L" if zijde < 0 else "R"), [a0, a1], 0.0, 1.0, BOVEN, ONDER, body)
    o.location = (0, 0, 0)
    # draaipunt: zet de oorsprong op de scharnierlijn (voorrand van het rolroer) en bewaar de vorm
    gem = Vector((zijde * 6.6, (a0[1] + a1[1]) / 2, (a0[4] + a1[4]) / 2))
    me = o.data
    for v in me.vertices:
        v.co -= gem
    o.location = gem

# staart: stabilisator met twee kielen aan de uiteinden
for zijde in (-1, 1):
    sec = [(zijde * x, y0, k, d, z) for (x, y0, k, d, z) in [(0.4, -6.2, 2.0, 0.22, 1.0), (3.4, -6.7, 1.5, 0.16, 1.05)]]
    vleugel("Stabilisator" + ("L" if zijde < 0 else "R"), sec, 0.0, 1.0, BOVEN, ONDER, body)
    # kiel: verticale plaat (koorde langs Y, hoogte langs Z)
    bm = bmesh.new()
    kx = zijde * 3.35
    pts = [(-5.5, 1.0), (-7.3, 1.0), (-7.0, 3.3), (-5.9, 3.3)]
    for dx in (-0.07, 0.07):
        for (y, z) in pts:
            bm.verts.new((kx + dx, y, z))
    v = list(bm.verts)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([v[i], v[j], v[j + 4], v[i + 4]])
    bm.faces.new(v[:4])
    bm.faces.new(list(reversed(v[4:])))
    mesh_obj("Kiel" + ("L" if zijde < 0 else "R"), bm, BOVEN, ONDER, body, smooth=False)

# pylonen, bussen en bandjes
PYL = []
for k, (x, y) in enumerate([(-4.4, 0.5), (-2.4, 0.5), (2.4, 0.5), (4.4, 0.5)]):
    zz = -0.33
    doos(f"Pyloon{k+1}", (0.16, 1.4, 0.38), STAAL, body, (x, y, zz))
    bus = leeg(f"Bom{k+1}", body, (x, y, zz - 0.52))
    cyl(f"BusRomp{k+1}", 0.30, 2.6, BUS, bus, (0, 0, 0), "y", 14)
    cyl(f"BusNeus{k+1}", 0.30, 0.55, BUS, bus, (0, 1.57, 0), "y", 14, 0.06)
    cyl(f"BusAchter{k+1}", 0.30, 0.45, BUS, bus, (0, -1.50, 0), "y", 14, 0.16)
    for yy in (0.85, 0.55):
        cyl(f"Band{k+1}_{yy}", 0.312, 0.10, BAND, bus, (0, yy, 0), "y", 14)
    cyl(f"Beugel{k+1}", 0.315, 0.06, STAAL, bus, (0, 0.2, 0), "y", 14)
    for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):   # staartvinnen
        b = doos(f"Vin{k+1}_{a:.1f}", (0.03, 0.55, 0.30), STAAL, bus, (math.sin(a) * 0.30, -1.55, math.cos(a) * 0.30))
        b.rotation_euler = (0, a, 0)
    # lont/ontsteker bovenop de neus
    cyl(f"Lont{k+1}", 0.05, 0.12, DONKER, bus, (0, 1.72, 0), "y", 8)

# positielichten op de vleugeltips
for zijde, col in ((-1, (0.9, 0.1, 0.05)), (1, (0.1, 0.8, 0.2))):
    cyl("Tiplicht" + ("L" if zijde < 0 else "R"), 0.07, 0.10, pbr("Tiplicht" + str(zijde), None, col, 0.3, 0.0, emit=col, strength=2.0), body, (zijde * 8.65, 0.3, 0.22), "x", 8)


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


NAV = [o for o in ALLE if o.name.startswith("Naverbrander_")]
AIL = {o.name: o for o in ALLE if o.name.startswith("Aileron")}
for o in [body] + NAV + list(AIL.values()):
    o.rotation_mode = "XYZ"
AIL_BASIS = {n: o.location.copy() for n, o in AIL.items()}
DOELEN = [body] + NAV + list(AIL.values())


def vliegen(t, pitch=0.0, roll=0.0, dz=0.0, ail=0.0):
    """Standaardpose: naverbrander flikkert, rolroeren tegengesteld, romp deint licht."""
    stand = {body: {"rot": (pitch + sin(t, 2.0, hoek(0.5)), sin(t, 2.0, hoek(0.8), 1.0) * 0 + roll + sin(t, 4.0, hoek(0.9)), 0.0),
                    "loc": (0, 0, dz + sin(t, 2.0, 0.04))}}
    for n, o in AIL.items():
        richting = 1.0 if n.endswith("R") else -1.0
        stand[o] = {"rot": (hoek(-4) + ail * richting + sin(t, 2.0, hoek(2.0), 0.7 * richting), 0.0, 0.0)}
    for i, o in enumerate(NAV):
        f = 1.0 + 0.18 * math.sin(math.tau * t * 6.0 + i * 1.3)
        stand[o] = {"scale": (f, 1.0 + 0.5 * (f - 1.0), f)}
    return stand


zet_actie("Vliegen-loop", 60, lambda t: vliegen(t), DOELEN)
zet_actie("Bocht", 90, lambda t: vliegen(t, hoek(-2), hoek(30) * math.sin(math.pi * min(t / 3.0, 1.0)) ** 0.8,
                                         0.0, hoek(10) * math.sin(math.pi * min(t / 3.0, 1.0))), DOELEN)
zet_actie("Aanval", 90, lambda t: vliegen(t, hoek(-6) * math.sin(math.pi * min(t / 3.0, 1.0)), 0.0,
                                          -0.4 * math.sin(math.pi * min(t / 3.0, 1.0)), 0.0), DOELEN)
for o in DOELEN:
    o.rotation_euler = (0, 0, 0)
    o.scale = (1, 1, 1)
body.location = (0, 0, 0)
for n, o in AIL.items():
    o.location = AIL_BASIS[n]
    o.rotation_euler = (0, 0, 0)
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
print("STRAALJAGER driehoeken", tris, "materialen", len(bpy.data.materials))

if RENDER:
    exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "render.py")).read())
