"""Woonhuis voor de stad achter de brug (Bloedjungle): koloniaal stadshuis van 2 verdiepingen met gepleisterde muren,
pannendak, groene luiken, balkon, binnenkant met trap, deuren, meubels en een tuin achter.
Alles kan kapot: elke muur bestaat uit losse stukken van ongeveer 2 m per verdieping, elk met een hele en een kapotte versie.
Blender: voorkant aan -Y (wordt +Z in Godot), Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van het huis op de grond.
Huis 8 x 7 m (x -4..4, y -3,5..3,5), tuin tot y = 10.
Gebruik: python3 maak_woonhuis.py <uitmap>  ->  woonhuis.glb, woonhuis.blend

Hiërarchie (namen die het spel gebruikt):
  Woonhuis
    Begane      Fundering, Trap, Inrichting0, muurstukken M0_*, binnenmuur P0, DeurVoor, DeurAchter, DeurBinnen0, Buitenlamp
    Verdieping  Vloer1 (Vloer1_heel / Vloer1_kapot = ingezakt), muurstukken M1_*, binnenmuur P1, DeurBinnen1, Inrichting1, Balkon
    Dak         Dak_heel / Dak_kapot (met gat)
    Tuin        TuinSpul, tuinmuurstukken T_*
    Puin        PuinGroot, PuinKlein, Brok0..3 (sjablonen voor sloop, verborgen in het spel)
  Muurstuk X: leeg knooppunt met kinderen X_heel en X_kapot (gat met baksteen in de breuk, zonder kozijn).
  Deuren: het knooppunt is het scharnier (draai om de hoogte-as).
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector, Euler

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rng = np.random.default_rng(7)

# ---------- maten ----------
W, D = 8.0, 7.0          # buitenmaat huis
T = 0.25                 # muurdikte
F0 = 0.3                 # vloer begane grond
F1 = 3.2                 # vloer verdieping (bovenkant)
TOP = 6.0                # bovenkant muren
SLAB = 0.25              # dikte verdiepingsvloer
XI0, XI1 = -W / 2 + T, W / 2 - T      # binnenkant
YI0, YI1 = -D / 2 + T, D / 2 - T
STAIR_X0, STAIR_X1 = XI0, XI0 + 1.0   # trap langs de westmuur
STAIR_Y0 = -1.8                       # onderste trede
NSTEP = 15
STEP_D = 0.27
STAIR_Y1 = STAIR_Y0 + NSTEP * STEP_D  # 2.25: daar begint de overloop
HOLE_Y0 = -1.2                        # trapgat in de verdiepingsvloer
TUIN_Y = 10.0


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


def pleister_image(size=512):
    """Okergele kalkpleister. v = hoogte / 6,4 m (v = 0 is de grond), u herhaalt elke 3,2 m.
    Vuil en mos onderaan, regenstrepen onder de daklijst en de verdiepingsband, plekken waar de pleister eraf is."""
    v = 1 - np.mgrid[0:size, 0:size][0] / size
    v = v[..., None]
    basis = np.array([0.80, 0.68, 0.46])
    img = basis * (0.9 + 0.16 * noise(size, 64, 1)[..., None] + 0.06 * noise(size, 8, 2)[..., None])
    # regenstrepen: lange verticale ruis, sterk vlak onder de daklijst (v=0.94) en onder de band (v=0.5)
    streep = noise(size, 8, 3, 128)[..., None]
    onder_dak = np.clip(1 - (0.94 - v) / 0.35, 0, 1) * (v < 0.94)
    onder_band = np.clip(1 - (0.49 - v) / 0.25, 0, 1) * (v < 0.49)
    s = np.clip((streep - 0.45) * 2.5, 0, 1) * np.maximum(onder_dak, onder_band * 0.8)
    img = img * (1 - 0.35 * s)
    # opspattend vuil en groen mos onderaan
    vuil = np.clip(1 - v / 0.09, 0, 1) * (0.6 + 0.4 * noise(size, 16, 4)[..., None])
    img = img * (1 - 0.55 * vuil) + np.array([0.24, 0.24, 0.14]) * 0.55 * vuil
    mos = sm(noise(size, 32, 5) - v[..., 0] * 2.5, 0.5, 0.6) * 0.6
    img = img * (1 - mos) + np.array([0.26, 0.32, 0.14]) * mos
    # afgebladderde plekken met baksteen eronder
    gat = noise(size, 64, 6) * 0.7 + noise(size, 8, 7) * 0.3
    rand = sm(gat, 0.72, 0.74) * 0.5
    img = img * (1 - rand) + np.array([0.45, 0.38, 0.26]) * rand
    steen = sm(gat, 0.75, 0.76)
    bv = np.mgrid[0:size, 0:size][0] % 10 < 1
    steen_kleur = np.where(bv[..., None], np.array([0.6, 0.55, 0.45]), np.array([0.56, 0.27, 0.16]))
    img = img * (1 - steen) + steen_kleur * steen
    return save_img("woonhuis_pleister", img, size)


def binnen_image(size=256):
    """Binnenmuur: lichtgroene kalk boven een donkerder lambrisering (v = hoogte / 3,2 m)."""
    v = (1 - np.mgrid[0:size, 0:size][0] / size)[..., None]
    boven = np.array([0.72, 0.78, 0.66])
    onder = np.array([0.42, 0.52, 0.44])
    img = np.where(v < 0.36, onder, boven) * (0.92 + 0.12 * noise(size, 32, 21)[..., None])
    lijn = (np.abs(v - 0.36) < 0.008)
    img = np.where(lijn, np.array([0.3, 0.32, 0.26]), img)
    vlek = sm(noise(size, 16, 22) * 0.6 + noise(size, 64, 23) * 0.4, 0.6, 0.75) * 0.2
    img = img * (1 - vlek) + np.array([0.5, 0.45, 0.32]) * vlek
    return save_img("woonhuis_binnen", img, size)


def baksteen_image(size=512):
    """Baksteen, 6 stenen x 20 lagen per 1,5 m (steen 25 x 7,5 cm), halfsteens verband."""
    y, x = np.mgrid[0:size, 0:size] / size
    rij = np.floor(y * 20).astype(int)
    xs = x * 6 + (rij % 2) * 0.5
    kol = np.floor(xs).astype(int)
    fx, fy = xs - kol, y * 20 - rij
    voeg = (fx < 0.06) | (fy < 0.12)
    r = np.random.default_rng(31).random((21, 8))
    t = r[rij % 20, kol % 6]
    kleur = np.array([0.55, 0.25, 0.14]) * (0.75 + 0.45 * t[..., None])
    kleur = kleur * (0.9 + 0.2 * noise(size, 8, 32)[..., None])
    img = np.where(voeg[..., None], np.array([0.55, 0.52, 0.46]) * (0.8 + 0.2 * noise(size, 4, 33)[..., None]), kleur)
    stof = sm(noise(size, 64, 34), 0.55, 0.8) * 0.35
    img = img * (1 - stof) + np.array([0.6, 0.58, 0.52]) * stof
    return save_img("woonhuis_baksteen", img, size)


def dakpan_image(size=512):
    """Terracotta holle pannen: 6 pannen breed x 4 rijen per 1,2 m. v loopt naar de nok."""
    y, x = np.mgrid[0:size, 0:size] / size
    v = 1 - y
    rij = np.floor(v * 4).astype(int)
    fv = v * 4 - rij
    xs = x * 6 + (rij % 2) * 0.5
    kol = np.floor(xs).astype(int)
    fx = xs - kol
    r = np.random.default_rng(41).random((5, 8))
    t = r[rij % 4, kol % 6]
    kleur = np.array([0.66, 0.3, 0.17]) * (0.72 + 0.4 * t[..., None])
    rond = (0.62 + 0.5 * np.sin(fx * math.pi))[..., None]       # holle pan: licht in het midden
    schaduw = (0.55 + 0.45 * np.clip(fv / 0.25, 0, 1))[..., None]  # onderrand van de pan erboven
    img = kleur * rond * schaduw
    gleuf = (fx < 0.04)[..., None]
    img = np.where(gleuf, img * 0.45, img)
    mos = sm(noise(size, 32, 42) * 0.7 + noise(size, 8, 43) * 0.3, 0.62, 0.72) * 0.6
    img = img * (1 - mos) + np.array([0.2, 0.22, 0.12]) * mos
    vuil = sm(noise(size, 64, 44), 0.5, 0.9) * 0.3
    img = img * (1 - vuil) + np.array([0.2, 0.15, 0.12]) * vuil
    return save_img("woonhuis_dakpan", img, size)


def tegels_image(size=512):
    """Cementtegels begane grond: 4 x 4 tegels van 30 cm per 1,2 m, rood en oker in een ruit."""
    y, x = np.mgrid[0:size, 0:size] / size
    tx, ty = np.floor(x * 4).astype(int), np.floor(y * 4).astype(int)
    fx, fy = x * 4 - tx, y * 4 - ty
    rood = np.array([0.55, 0.24, 0.16])
    oker = np.array([0.78, 0.62, 0.38])
    ruit = (np.abs(fx - 0.5) + np.abs(fy - 0.5)) < 0.36
    kleur = np.where(((tx + ty) % 2 == 0)[..., None], rood, oker)
    kleur = np.where(ruit[..., None], np.where(((tx + ty) % 2 == 0)[..., None], oker, rood), kleur)
    img = kleur * (0.85 + 0.2 * noise(size, 16, 51)[..., None])
    voeg = (fx < 0.02) | (fy < 0.02)
    img = np.where(voeg[..., None], np.array([0.4, 0.38, 0.34]), img)
    vuil = sm(noise(size, 64, 52), 0.55, 0.85) * 0.4
    img = img * (1 - vuil) + np.array([0.3, 0.26, 0.2]) * vuil
    return save_img("woonhuis_tegels", img, size)


def planken_image(size=512):
    """Houten planken (verdieping): 8 planken van 15 cm per 1,2 m, met naden."""
    y, x = np.mgrid[0:size, 0:size] / size
    rij = np.floor(y * 8).astype(int)
    fy = y * 8 - rij
    r = np.random.default_rng(61).random((9, 4))
    naad_x = (x + r[rij % 8, 0]) % 1.0
    t = r[rij % 8, 1]
    nerf = noise(size, 64, 62, 4)[..., None]
    kleur = np.array([0.5, 0.33, 0.2]) * (0.7 + 0.35 * t[..., None]) * (0.85 + 0.3 * nerf)
    img = np.where(((fy < 0.05) | (naad_x < 0.006))[..., None], np.array([0.15, 0.1, 0.06]), kleur)
    return save_img("woonhuis_planken", img, size)


def luik_image(size=256):
    """Groene lamellen van de luiken en deuren: 20 lamellen per 1,6 m, verf bladdert."""
    y = np.mgrid[0:size, 0:size][0] / size
    f = (y * 20) % 1.0
    groen = np.array([0.22, 0.4, 0.3])
    img = groen * (0.6 + 0.5 * f)[..., None] * (0.9 + 0.2 * noise(size, 16, 71)[..., None])
    kaal = sm(noise(size, 8, 72) * 0.5 + noise(size, 32, 73) * 0.5, 0.64, 0.68)
    img = img * (1 - kaal) + np.array([0.42, 0.33, 0.24]) * kaal
    return save_img("woonhuis_luik", img, size)


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


PLEISTER = mat("Pleister", (0.8, 0.68, 0.46), 0.95, image=pleister_image())
BINNEN = mat("Binnen", (0.72, 0.78, 0.66), 0.9, image=binnen_image())
BAKSTEEN = mat("Baksteen", (0.55, 0.25, 0.14), 0.95, image=baksteen_image())
DAKPAN = mat("Dakpan", (0.66, 0.3, 0.17), 0.8, image=dakpan_image())
TEGELS = mat("Tegels", (0.6, 0.4, 0.25), 0.6, image=tegels_image())
PLANKEN = mat("Planken", (0.5, 0.33, 0.2), 0.75, image=planken_image())
LUIK = mat("Luik", (0.22, 0.4, 0.3), 0.7, image=luik_image())
PLAFOND = mat("Plafond", (0.86, 0.85, 0.78), 0.95)
BETON = mat("Beton", (0.55, 0.53, 0.48), 0.95)
KOZIJN = mat("Kozijn", (0.86, 0.84, 0.76), 0.6)
GLAS = mat("Glas", (0.16, 0.22, 0.24), 0.05, 0.3)
HOUT = mat("Hout", (0.42, 0.27, 0.15), 0.8)
HOUTLICHT = mat("HoutLicht", (0.62, 0.45, 0.28), 0.75)
IJZER = mat("IJzer", (0.12, 0.12, 0.11), 0.5, 0.7)
ZINK = mat("Zink", (0.5, 0.52, 0.52), 0.45, 0.6)
STOF = mat("Stof", (0.66, 0.2, 0.16), 0.95)
STOF2 = mat("Stof2", (0.25, 0.36, 0.55), 0.95)
STOF3 = mat("Stof3", (0.85, 0.8, 0.62), 0.95)
MATRAS = mat("Matras", (0.84, 0.82, 0.74), 0.95)
AARDE = mat("Aarde", (0.25, 0.18, 0.11), 1.0)
GRAS = mat("Gras", (0.3, 0.38, 0.16), 1.0)
BLAD = mat("Blad", (0.26, 0.45, 0.16), 0.7)
VAT = mat("Vat", (0.16, 0.34, 0.6), 0.5)
EMAILLE = mat("Emaille", (0.88, 0.88, 0.84), 0.3)
DONKER = mat("Donker", (0.08, 0.08, 0.08), 0.6)
LAMPGLAS = mat("LampGlas", (1.0, 0.85, 0.55), 0.3, emit=(1.0, 0.8, 0.45), strength=4.0)

# per materiaal: schaal (u, v) van de wereld-UV in meters per herhaling
UVS = {"Pleister": (3.2, 6.4), "Binnen": (3.2, 3.2), "Baksteen": (1.5, 1.5), "Tegels": (1.2, 1.2), "Planken": (1.2, 1.2),
       "Luik": (1.6, 1.6), "Dakpan": (1.2, 1.2)}


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
                uv = (uv[0], (c.z - (F1 if c.z > F1 - 0.01 else F0)) if c.z > 0 else c.z)
            uvl.data[li].uv = (uv[0] / su, uv[1] / sv)


def set_materials(o, mats):
    o.data.materials.clear()
    for m in mats:
        o.data.materials.append(m)


# ---------- muurstukken ----------
def wall_segment(name, parent, center, angle, L, H, z0, openings, inner=BINNEN, outer=PLEISTER, ends=(False, False),
                 thick=T, band=False, cornice=False, seed=0, kapot_extra=None):
    """Een stuk muur met een hele en een kapotte versie.
    Lokaal: x langs de muur (-L/2..L/2), -y = buitenkant, z = 0..H. openings: lijst (cx, breedte, onder, hoogte, soort)
    met soort 'raam', 'deur' of 'balkon' (deur zonder drempel). ends: welke kopse kanten baksteen zijn (aansluiting op een buurstuk)."""
    seg = empty(name, parent, (center[0], center[1], z0), (0, 0, angle))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(L, thick, H), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, H / 2))
    heel = mesh_obj(name + "_heel", bm, None, seg)
    mats = [outer] + ([inner] if inner is not outer else []) + [BAKSTEEN]
    set_materials(heel, mats)
    i_out, i_in, i_steen = 0, mats.index(inner), len(mats) - 1
    cutters = [cutter_box((w, thick + 0.4, h), (cx, 0, zb + h / 2), outer) for (cx, w, zb, h, kind) in openings]
    if cutters:
        cut(heel, cutters)
    # materiaal per vlak: buiten, binnen, kopse kant tegen een buurstuk = baksteen
    for p in heel.data.polygons:
        n = p.normal
        c = p.center
        if n.y < -0.5:
            p.material_index = i_out
        elif n.y > 0.5:
            p.material_index = i_in
        elif abs(n.x) > 0.5 and abs(abs(c.x) - L / 2) < 0.01 and ends[0 if c.x < 0 else 1]:
            p.material_index = i_steen
        else:
            p.material_index = i_out
    # de kapotte versie: zelfde muur met een grillig gat (vaak door de bovenrand), zonder kozijnen
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
        kc.append(cutter_jagged((r.uniform(-L * 0.4, L * 0.4), 0, r.uniform(0.6, H * 0.6)), r.uniform(0.2, 0.38), "Y",
                                thick + 0.4, 3000 + seed, 8))
    cut(kapot, kc)
    drop_floating(kapot)
    kapot.hide_render = False
    # details van de hele muur: kozijnen, glas, luiken, vensterbank, banden
    det = []
    yo = -thick / 2
    for (cx, w, zb, h, kind) in openings:
        f = 0.07
        if kind == "raam":
            det.append(box("k", (w, 0.09, f), KOZIJN, seg, (cx, yo + 0.07, zb + f / 2)))
            det.append(box("k", (w, 0.09, f), KOZIJN, seg, (cx, yo + 0.07, zb + h - f / 2)))
            det.append(box("k", (f, 0.09, h), KOZIJN, seg, (cx - w / 2 + f / 2, yo + 0.07, zb + h / 2)))
            det.append(box("k", (f, 0.09, h), KOZIJN, seg, (cx + w / 2 - f / 2, yo + 0.07, zb + h / 2)))
            det.append(box("k", (0.05, 0.06, h), KOZIJN, seg, (cx, yo + 0.07, zb + h / 2)))
            det.append(box("k", (w, 0.05, 0.05), KOZIJN, seg, (cx, yo + 0.07, zb + h * 0.62)))
            det.append(box("g", (w - 0.1, 0.02, h - 0.1), GLAS, seg, (cx, yo + 0.08, zb + h / 2)))
            det.append(box("v", (w + 0.16, 0.16, 0.06), BETON, seg, (cx, yo - 0.04, zb - 0.03)))
            # luiken open tegen de gevel, soms scheef of half dicht
            for sx in (-1, 1):
                hoek = 0.0 if r.random() < 0.75 else r.uniform(0.3, 1.2) * sx
                piv = (cx + sx * w / 2, yo - 0.04, zb + h / 2)
                lk = box("l", (w / 2, 0.035, h), LUIK, seg, (piv[0] + sx * w / 4 + sx * 0.03, piv[1], piv[2]))
                if hoek:
                    lk.location = (piv[0] + sx * (w / 4) * math.cos(hoek), piv[1] - (w / 4) * abs(math.sin(hoek)), piv[2])
                    lk.rotation_euler = (0, 0, hoek)
                det.append(lk)
        else:
            det.append(box("k", (0.08, 0.1, h), KOZIJN if kind == "balkon" else HOUT, seg, (cx - w / 2 + 0.04, yo + 0.07, zb + h / 2)))
            det.append(box("k", (0.08, 0.1, h), KOZIJN if kind == "balkon" else HOUT, seg, (cx + w / 2 - 0.04, yo + 0.07, zb + h / 2)))
            det.append(box("k", (w, 0.1, 0.08), KOZIJN if kind == "balkon" else HOUT, seg, (cx, yo + 0.07, zb + h - 0.04)))
            if kind == "balkon":
                # openslaande glasdeuren, open naar binnen gedraaid
                for sx in (-1, 1):
                    gd = box("gd", (w / 2 - 0.06, 0.04, h - 0.1), KOZIJN, seg, (cx + sx * (w / 2 - 0.06), yo + 0.06 + w / 4, zb + h / 2),
                             (0, 0, sx * math.radians(80)))
                    det.append(gd)
            # bovenlicht/latei in pleister met sierrand
            det.append(box("lat", (w + 0.3, 0.06, 0.16), KOZIJN, seg, (cx, yo - 0.02, zb + h + 0.1)))
    if band:     # verdiepingsband net onder de verdiepingsvloer
        det.append(box("band", (L, 0.08, 0.18), KOZIJN, seg, (0, yo - 0.03, H - 0.1)))
    if cornice:  # kroonlijst onder het dak
        det.append(box("kroon", (L, 0.14, 0.12), KOZIJN, seg, (0, yo - 0.05, H - 0.2)))
        det.append(box("kroon", (L, 0.22, 0.08), KOZIJN, seg, (0, yo - 0.07, H - 0.07)))
    if outer is PLEISTER and z0 < 0.01:  # plint, onderbroken bij deuren
        stukken = [(-L / 2, L / 2)]
        for (cx, w, zb, h, kind) in openings:
            if kind == "deur":
                stukken = [q for (a, b) in stukken for q in ((a, min(b, cx - w / 2)), (max(a, cx + w / 2), b)) if q[1] - q[0] > 0.02]
        for (a, b) in stukken:
            det.append(box("plint", (b - a, 0.05, 0.4), BETON, seg, ((a + b) / 2, yo - 0.02, 0.2)))
    if kapot_extra:
        kapot_extra(seg, kapot, r)
    if det:
        join(heel, det)
    heel.name = name + "_heel"
    return seg


# ---------- huis ----------
root = empty("Woonhuis")
beg = empty("Begane", root)
ver = empty("Verdieping", root)
dak = empty("Dak", root)
tuin = empty("Tuin", root)
puin = empty("Puin", root)

WIN_H0, WIN_H1 = 1.25, 1.4          # raam: hoogte en borstwering op de begane grond
WIN_HU, WIN_BU = 1.4, 0.95          # verdieping
DOOR_H = 2.3


def raam(cx, w=1.0, verd=0):
    return (cx, w, (F0 + 0.95) if verd == 0 else WIN_BU, WIN_H0 if verd == 0 else WIN_HU, "raam")


def gevel(prefix, parent, side, verd, segs):
    """side: 'V' voor (-y), 'A' achter (+y), 'W' west (-x), 'O' oost (+x). segs: lijst (begin, eind, [openingen in huiscoördinaten])."""
    z0 = 0.0 if verd == 0 else F1
    H = F1 if verd == 0 else TOP - F1
    out = []
    n = len(segs)
    for i, (a, b, ops) in enumerate(segs):
        L = b - a
        mid = (a + b) / 2
        if side == "V":
            center, angle = (mid, -D / 2 + T / 2), 0.0
            loc = [(cx - mid, w, zb, h, k) for (cx, w, zb, h, k) in ops]
        elif side == "A":
            center, angle = (mid, D / 2 - T / 2), math.pi
            loc = [(mid - cx, w, zb, h, k) for (cx, w, zb, h, k) in ops]
        elif side == "W":
            center, angle = (-W / 2 + T / 2, mid), -math.pi / 2
            loc = [(mid - cy, w, zb, h, k) for (cy, w, zb, h, k) in ops]
        else:
            center, angle = (W / 2 - T / 2, mid), math.pi / 2
            loc = [(cy - mid, w, zb, h, k) for (cy, w, zb, h, k) in ops]
        ends = (i > 0, i < n - 1)
        # bij de voor- en achtergevel lopen de buitenste stukken door tot de hoek; zijgevels liggen ertussen
        out.append(wall_segment(f"{prefix}{side}{i}", parent, center, angle, L, H, z0, loc, ends=ends,
                                band=(verd == 0), cornice=(verd == 1), seed=ord(side) * 31 + i * 7 + (100 if prefix == "M1" else 0)))
    return out


hy0, hy1 = -D / 2 + T, D / 2 - T
side_cuts = [hy0, -1.08, 1.08, hy1]
# begane grond
gevel("M0", beg, "V", 0, [(-4, -2, [raam(-3.0)]), (-2, 0, [raam(-1.0, 1.1)]),
                          (0, 2, [(1.0, 1.3, 0.0, F0 + DOOR_H, "deur")]), (2, 4, [raam(3.0)])])
gevel("M0", beg, "A", 0, [(-4, -2, []), (-2, 0, [raam(-1.0)]), (0, 2, [(1.0, 1.2, 0.0, F0 + DOOR_H, "deur")]), (2, 4, [raam(3.0, 1.1)])])
gevel("M0", beg, "W", 0, [(side_cuts[0], side_cuts[1], [raam(-2.17, 0.9)]), (side_cuts[1], side_cuts[2], []),
                          (side_cuts[2], side_cuts[3], [])])
gevel("M0", beg, "O", 0, [(side_cuts[0], side_cuts[1], [raam(-2.17)]), (side_cuts[1], side_cuts[2], []),
                          (side_cuts[2], side_cuts[3], [raam(2.17)])])
# verdieping
gevel("M1", ver, "V", 1, [(-4, -2, [raam(-3.0, 1.0, 1)]), (-2, 0, [raam(-1.0, 1.0, 1)]),
                          (0, 2, [(1.0, 1.0, 0.0, 2.25, "balkon")]), (2, 4, [raam(3.0, 1.0, 1)])])
gevel("M1", ver, "A", 1, [(-4, -2, [raam(-3.0, 0.9, 1)]), (-2, 0, [raam(-1.0, 1.0, 1)]), (0, 2, []), (2, 4, [raam(3.0, 1.0, 1)])])
gevel("M1", ver, "W", 1, [(side_cuts[0], side_cuts[1], []), (side_cuts[1], side_cuts[2], [raam(0.0, 1.0, 1)]),
                          (side_cuts[2], side_cuts[3], [])])
gevel("M1", ver, "O", 1, [(side_cuts[0], side_cuts[1], [raam(-2.17, 1.0, 1)]), (side_cuts[1], side_cuts[2], []),
                          (side_cuts[2], side_cuts[3], [raam(2.17, 1.0, 1)])])

# binnenmuren: P0 scheidt de keuken (achter-oost) van de woonkamer, P1 de twee slaapkamers boven
TI = 0.14
p0x0, p0x1 = 0.0, XI1
wall_segment("P0", beg, ((p0x0 + p0x1) / 2, 0.6), 0.0, p0x1 - p0x0, F1 - SLAB - F0, F0,
             [(2.4 - (p0x0 + p0x1) / 2, 1.1, 0.0, 2.15, "deur")], inner=BINNEN, outer=BINNEN, thick=TI, seed=11)
p1x0, p1x1 = STAIR_X1 + 0.1, XI1
wall_segment("P1", ver, ((p1x0 + p1x1) / 2, 0.5), 0.0, p1x1 - p1x0, TOP - F1, F1,
             [(-1.6 - (p1x0 + p1x1) / 2, 1.1, 0.0, 2.15, "deur")], inner=BINNEN, outer=BINNEN, thick=TI, seed=12)

# fundering, vloer en stoepen
fund = []
fund.append(box("Fund", (W - 0.02, D - 0.02, F0), BETON, beg, (0, 0, F0 / 2)))
fund.append(box("Vloer0", (XI1 - XI0, YI1 - YI0, 0.02), TEGELS, beg, (0, 0, F0 + 0.01)))
fund.append(box("StoepV", (1.9, 0.6, 0.16), BETON, beg, (1.0, -D / 2 - 0.3, 0.08)))
fund.append(box("StoepV2", (1.6, 0.3, 0.1), BETON, beg, (1.0, -D / 2 - 0.15, 0.21)))
fund.append(box("StoepA", (1.5, 0.6, 0.16), BETON, beg, (1.0, D / 2 + 0.3, 0.08)))
fundering = join(fund[0], fund[1:])
fundering.name = "Fundering"

# trap: massieve treden langs de westmuur, met leuning aan de open kant
tr = []
rise = (F1 - F0) / NSTEP
for k in range(NSTEP):
    z1 = F0 + rise * (k + 1)
    y0 = STAIR_Y0 + k * STEP_D
    tr.append(box("trede", (STAIR_X1 - STAIR_X0, STEP_D, z1 - F0), HOUTLICHT, beg,
                  ((STAIR_X0 + STAIR_X1) / 2, y0 + STEP_D / 2, F0 + (z1 - F0) / 2)))
    tr.append(box("neus", (STAIR_X1 - STAIR_X0, 0.03, 0.03), HOUT, beg, ((STAIR_X0 + STAIR_X1) / 2, y0 + 0.01, z1 - 0.015)))
# zijwang van de trap (pleister aan de kant van de kamer)
bm = bmesh.new()
pts = [(STAIR_Y0, F0), (STAIR_Y1, F1), (STAIR_Y1, F0)]
vs0 = [bm.verts.new((STAIR_X1 + 0.005, y, z)) for (y, z) in pts]
bm.faces.new(vs0)
wang = mesh_obj("wang", bm, BINNEN, beg)
tr.append(wang)
rail_len = math.hypot(STAIR_Y1 - STAIR_Y0, F1 - F0)
pitch = math.atan2(F1 - F0, STAIR_Y1 - STAIR_Y0)
tr.append(box("leuning", (0.06, rail_len, 0.06), HOUT, beg, (STAIR_X1 - 0.05, (STAIR_Y0 + STAIR_Y1) / 2, (F0 + F1) / 2 + 0.95),
              (pitch, 0, 0)))
for k in range(0, NSTEP, 3):
    yk = STAIR_Y0 + k * STEP_D + 0.1
    zk = F0 + rise * k
    tr.append(box("spijl", (0.05, 0.05, 0.95), HOUT, beg, (STAIR_X1 - 0.05, yk, zk + 0.475 + rise)))
trap = join(tr[0], tr[1:])
trap.name = "Trap"

# verdiepingsvloer met trapgat; de kapotte versie is in het midden gebroken en de oosthelft hangt schuin naar beneden
vloer1 = empty("Vloer1", ver)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1)
bmesh.ops.scale(bm, vec=(XI1 - XI0, YI1 - YI0, SLAB), verts=bm.verts)
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, F1 - SLAB / 2))
v1 = mesh_obj("Vloer1_heel", bm, None, vloer1)
set_materials(v1, [PLANKEN, PLAFOND, BETON, BAKSTEEN])
cut(v1, [cutter_box((STAIR_X1 - STAIR_X0 + 0.1, STAIR_Y1 - HOLE_Y0, 1.0), ((STAIR_X0 + STAIR_X1) / 2 - 0.05, (HOLE_Y0 + STAIR_Y1) / 2, F1), BETON)])
for p in v1.data.polygons:
    p.material_index = 0 if p.normal.z > 0.5 else (1 if p.normal.z < -0.5 else 2)
v1k = v1.copy()
v1k.data = v1.data.copy()
v1k.name = v1k.data.name = "Vloer1_kapot"
link(v1k, vloer1)
# breuklijn: grillige strook over de hele diepte rond x = 0,6
bm = bmesh.new()
r = np.random.default_rng(77)
ys = np.linspace(YI0 - 0.3, YI1 + 0.3, 12)
left = [bm.verts.new((0.45 + r.uniform(-0.25, 0.1), y, F1 - 1)) for y in ys]
right = [bm.verts.new((0.75 + r.uniform(-0.1, 0.25), y, F1 - 1)) for y in ys]
geo = left + list(reversed(right))
f = bm.faces.new(geo)
ext = bmesh.ops.extrude_face_region(bm, geom=[f])
bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=(0, 0, 2))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("cutter")
bm.to_mesh(me)
bm.free()
me.materials.append(BETON)
cut(v1k, [bpy.data.objects.new("cutter", me)])
# oostdeel losmaken en om de oostmuur naar beneden laten hangen
bm = bmesh.new()
bm.from_mesh(v1k.data)
oost = [v for v in bm.verts if v.co.x > 0.55]
hinge = Vector((XI1, 0, F1 - SLAB))
bmesh.ops.rotate(bm, verts=oost, cent=hinge, matrix=Matrix.Rotation(math.radians(-38), 3, "Y"))
bm.to_mesh(v1k.data)
bm.free()

# reling rond het trapgat en de overloop
inr1 = []
for (a, b) in (((STAIR_X1 + 0.03, HOLE_Y0), (STAIR_X1 + 0.03, STAIR_Y1 - 0.05)), ((STAIR_X0, HOLE_Y0 - 0.03), (STAIR_X1 + 0.03, HOLE_Y0 - 0.03))):
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    L = (b - a).length
    mid = (a + b) / 2
    horiz = abs(b.x - a.x) > abs(b.y - a.y)
    inr1.append(box("rel", (L if horiz else 0.06, 0.06 if horiz else L, 0.06), HOUT, ver, (mid.x, mid.y, F1 + 0.95)))
    n = max(2, int(L / 0.45))
    for k in range(n + 1):
        p = a + (b - a) * (k / n)
        inr1.append(box("spijl", (0.04, 0.04, 0.95), HOUT, ver, (p.x, p.y, F1 + 0.475)))

# ---------- deuren (knooppunt = scharnier) ----------
def deur(name, parent, hinge, width, height, angle, mat_paneel, sx=1):
    """Deur die om 'hinge' draait; het blad loopt vanaf het scharnier in lokale +x (of -x bij sx=-1)."""
    h = empty(name, parent, hinge, (0, 0, angle))
    parts = [box(name + "Blad", (width - 0.04, 0.05, height - 0.02), mat_paneel, h, (sx * width / 2, 0, height / 2))]
    for (pz, ph) in ((0.25, 0.75), (1.15, 0.85)):
        parts.append(box("paneel", (width - 0.3, 0.07, ph), HOUT, h, (sx * width / 2, 0, pz + ph / 2)))
    parts.append(cyl("knop", 0.035, 0.035, 0.14, IJZER, "Y", 8, h, (sx * (width - 0.12), 0, 1.05)))
    join(parts[0], parts[1:])
    parts[0].name = name + "Blad"
    return h


deur("DeurVoor", beg, (1.0 - 0.57, -D / 2 + T / 2, F0), 1.14, DOOR_H, 0.0, LUIK)
deur("DeurAchter", beg, (1.0 + 0.52, D / 2 - T / 2, F0), 1.04, DOOR_H, math.pi, HOUTLICHT)
deur("DeurBinnen0", beg, (2.4 - 0.47, 0.6, F0), 0.94, 2.15, 0.0, HOUTLICHT)
deur("DeurBinnen1", ver, (-1.6 - 0.47, 0.5, F1), 0.94, 2.15, 0.0, HOUTLICHT)

# ---------- balkon ----------
bk = []
BY0 = -D / 2 - 0.95
bk.append(box("BalkonVloer", (2.2, 0.95, 0.14), BETON, ver, (1.0, -D / 2 - 0.475, F1 - 0.07)))
for sx in (-1, 1):
    bk.append(box("console", (0.12, 0.6, 0.3), BETON, ver, (1.0 + sx * 0.9, -D / 2 - 0.3, F1 - 0.29)))
bk.append(box("hek", (2.2, 0.05, 0.05), IJZER, ver, (1.0, BY0 + 0.03, F1 + 1.0)))
for sx in (-1, 1):
    bk.append(box("hek", (0.05, 0.95, 0.05), IJZER, ver, (1.0 + sx * 1.08, -D / 2 - 0.475, F1 + 1.0)))
for k in range(12):
    x = 1.0 - 1.05 + k * (2.1 / 11)
    bk.append(box("spijl", (0.025, 0.025, 1.0), IJZER, ver, (x, BY0 + 0.03, F1 + 0.5)))
for k in range(1, 5):
    for sx in (-1, 1):
        bk.append(box("spijl", (0.025, 0.025, 1.0), IJZER, ver, (1.0 + sx * 1.08, BY0 + k * 0.19, F1 + 0.5)))
bk.append(cyl("pot", 0.16, 0.12, 0.28, BAKSTEEN, "Z", 10, ver, (0.2, BY0 + 0.3, F1 + 0.14)))
for k in range(5):
    a = k / 5 * math.tau
    bk.append(box("blad", (0.06, 0.35, 0.02), BLAD, ver, (0.2 + 0.12 * math.cos(a), BY0 + 0.3 + 0.12 * math.sin(a), F1 + 0.42),
                  (0.7, 0, a + math.pi / 2)))
balkon = join(bk[0], bk[1:])
balkon.name = "Balkon"

# buitenlamp naast de voordeur
bl = [box("LampVoet", (0.14, 0.12, 0.2), IJZER, beg, (1.85, -D / 2 - 0.06, 2.35)),
      cyl("LampKap", 0.12, 0.06, 0.12, IJZER, "Z", 8, beg, (1.85, -D / 2 - 0.2, 2.62)),
      cyl("LampBol", 0.07, 0.07, 0.14, LAMPGLAS, "Z", 8, beg, (1.85, -D / 2 - 0.2, 2.5))]
join(bl[0], bl[1:]).name = "Buitenlamp"
lp = bpy.data.lights.new("BuitenLicht", "POINT")
lp.energy = 2.0
lp.color = (1.0, 0.78, 0.45)
lp.shadow_soft_size = 0.1
o = link(bpy.data.objects.new("BuitenLicht", lp), beg)
o.location = (1.85, -D / 2 - 0.35, 2.4)

# ---------- inrichting ----------
inr0 = []


def tafel(lst, parent, x, y, z, w, d, h=0.76, m=HOUT):
    lst.append(box("blad", (w, d, 0.05), m, parent, (x, y, z + h - 0.025)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            lst.append(box("poot", (0.05, 0.05, h - 0.05), m, parent, (x + sx * (w / 2 - 0.06), y + sy * (d / 2 - 0.06), z + (h - 0.05) / 2)))


def stoel(lst, parent, x, y, z, rot):
    c, s = math.cos(rot), math.sin(rot)
    def p(dx, dy):
        return (x + dx * c - dy * s, y + dx * s + dy * c)
    lst.append(box("zit", (0.42, 0.42, 0.05), HOUTLICHT, parent, (*p(0, 0), z + 0.45), (0, 0, rot)))
    lst.append(box("rug", (0.42, 0.04, 0.45), HOUTLICHT, parent, (*p(0, 0.2), z + 0.7), (0, 0, rot)))
    for dx in (-0.18, 0.18):
        for dy in (-0.18, 0.18):
            lst.append(box("poot", (0.04, 0.04, 0.45), HOUT, parent, (*p(dx, dy), z + 0.225)))


# woonkamer: eettafel, bank, kast, kleed
tafel(inr0, beg, -1.2, -1.5, F0, 1.4, 0.8)
for (dx, dy, rt) in ((-0.4, -0.55, math.pi), (0.4, -0.55, math.pi), (-0.4, 0.55, 0), (0.4, 0.55, 0)):
    stoel(inr0, beg, -1.2 + dx, -1.5 + dy, F0, rt)
inr0.append(box("Kleed", (2.2, 1.6, 0.01), STOF, beg, (-1.2, -1.5, F0 + 0.025)))
inr0.append(box("BankZit", (0.8, 1.9, 0.42), STOF2, beg, (XI1 - 0.45, -1.4, F0 + 0.21)))
inr0.append(box("BankRug", (0.22, 1.9, 0.5), STOF2, beg, (XI1 - 0.12, -1.4, F0 + 0.6)))
for sy in (-1, 1):
    inr0.append(box("BankArm", (0.8, 0.18, 0.62), STOF2, beg, (XI1 - 0.45, -1.4 + sy * 0.95, F0 + 0.31)))
for k in range(2):
    inr0.append(box("Kussen", (0.6, 0.8, 0.12), STOF3, beg, (XI1 - 0.5, -1.85 + k * 0.9, F0 + 0.48)))
tafel(inr0, beg, XI1 - 1.35, -1.4, F0, 0.6, 1.0, 0.42, HOUTLICHT)
inr0.append(box("Dressoir", (1.4, 0.45, 0.9), HOUT, beg, (-1.2, 0.6 - 0.3 + 0.05, F0 + 0.45)))
inr0.append(box("Radio", (0.4, 0.2, 0.25), HOUTLICHT, beg, (-1.0, 0.4, F0 + 1.03)))
inr0.append(box("Fotolijst", (0.25, 0.03, 0.3), DONKER, beg, (-1.6, 0.48, F0 + 1.05)))
# hoek onder de trapopgang: kisten en zakken (buit)
for k, (x, y, s) in enumerate(((-2.3, 2.6, 0.55), (-1.75, 2.75, 0.45), (-2.2, 2.3, 0.35))):
    inr0.append(box(f"Kist{k}", (s, s, s), HOUT, beg, (x, y, F0 + s / 2 + (0.55 if k == 2 else 0))))
inr0.append(box("Zak", (0.5, 0.35, 0.3), STOF3, beg, (-1.3, 2.9, F0 + 0.15)))
# keuken: aanrecht langs de achtermuur, fornuis, gootsteen, koelkast, keukentafel
inr0.append(box("Aanrecht", (1.6, 0.6, 0.86), HOUTLICHT, beg, (XI1 - 0.8 - 0.05, YI1 - 0.3, F0 + 0.43)))
inr0.append(box("Werkblad", (1.65, 0.64, 0.05), BETON, beg, (XI1 - 0.8 - 0.05, YI1 - 0.32, F0 + 0.885)))
inr0.append(box("Gootsteen", (0.5, 0.4, 0.08), EMAILLE, beg, (XI1 - 1.2, YI1 - 0.32, F0 + 0.9)))
inr0.append(box("Fornuis", (0.6, 0.6, 0.9), EMAILLE, beg, (XI1 - 0.3, 1.6, F0 + 0.45)))
for k in range(4):
    inr0.append(cyl("Pit", 0.09, 0.09, 0.02, DONKER, "Z", 8, beg, (XI1 - 0.45 + (k % 2) * 0.28, 1.45 + (k // 2) * 0.28, F0 + 0.91)))
inr0.append(box("Koelkast", (0.65, 0.65, 1.6), EMAILLE, beg, (XI1 - 0.33, 0.6 + 0.07 + 0.33 + 0.05, F0 + 0.8)))
tafel(inr0, beg, 1.0, 1.9, F0, 0.9, 0.8, m=HOUTLICHT)
stoel(inr0, beg, 0.75, 1.35, F0, math.pi)
stoel(inr0, beg, 1.25, 2.45, F0, 0.0)
inr0.append(cyl("Pan", 0.14, 0.14, 0.12, ZINK, "Z", 10, beg, (XI1 - 0.45, 1.45, F0 + 0.98)))
# plafondlamp
inr0.append(cyl("Lampkap0", 0.25, 0.08, 0.14, EMAILLE, "Z", 10, beg, (-1.2, -1.5, F1 - SLAB - 0.5)))
inr0.append(cyl("Snoer0", 0.01, 0.01, 0.4, DONKER, "Z", 4, beg, (-1.2, -1.5, F1 - SLAB - 0.2)))
inrichting0 = join(inr0[0], inr0[1:])
inrichting0.name = "Inrichting0"

# verdieping: voorkamer met tweepersoonsbed en kast, achterkamer met twee bedden en een kist (inr1 bevat al de reling)
B = F1


def bed(lst, x, y, w, l, rot=0.0):
    lst.append(box("bedframe", (w, l, 0.35), HOUT, ver, (x, y, B + 0.175), (0, 0, rot)))
    lst.append(box("matras", (w - 0.08, l - 0.1, 0.16), MATRAS, ver, (x, y, B + 0.43), (0, 0, rot)))
    dy = (l / 2 - 0.3)
    c, s = math.cos(rot), math.sin(rot)
    lst.append(box("kussen", (w - 0.3, 0.35, 0.1), STOF3, ver, (x - s * dy, y + c * dy, B + 0.56), (0, 0, rot)))
    lst.append(box("deken", (w - 0.04, l * 0.55, 0.06), STOF, ver, (x + s * l * 0.18, y - c * l * 0.18, B + 0.53), (0, 0, rot)))
    lst.append(box("hoofdeind", (w, 0.06, 0.9), HOUT, ver, (x - s * (l / 2), y + c * (l / 2), B + 0.45), (0, 0, rot)))


bed(inr1, XI1 - 0.85, -2.05, 1.5, 2.0, math.pi / 2)
inr1.append(box("Kast", (1.2, 0.55, 2.0), HOUT, ver, (0.9, 0.5 - 0.35, B + 1.0)))
inr1.append(box("Kastdeur", (0.02, 0.01, 1.8), DONKER, ver, (0.9, 0.5 - 0.63, B + 1.0)))
tafel(inr1, ver, -1.6, -2.7, B, 0.9, 0.5, m=HOUTLICHT)
stoel(inr1, ver, -1.6, -2.15, B, 0.0)
inr1.append(box("Kleed1", (1.8, 1.2, 0.01), STOF2, ver, (1.5, -1.6, B + 0.01)))
bed(inr1, 0.2, 2.2, 0.9, 1.9, 0.0)
bed(inr1, 2.6, 2.2, 0.9, 1.9, 0.0)
inr1.append(box("Kist1", (0.8, 0.45, 0.45), HOUT, ver, (1.4, 3.0, B + 0.225)))
inr1.append(cyl("Lampkap1", 0.22, 0.08, 0.12, EMAILLE, "Z", 10, ver, (1.2, -1.5, TOP - 0.4)))
inrichting1 = join(inr1[0], inr1[1:])
inrichting1.name = "Inrichting1"

for nm, pos in (("Licht0", (-1.2, -1.5, F1 - SLAB - 0.7)), ("Licht1", (1.2, -1.5, TOP - 0.6))):
    l = bpy.data.lights.new(nm, "POINT")
    l.energy = 1.5
    l.color = (1.0, 0.85, 0.6)
    o = link(bpy.data.objects.new(nm, l), beg if nm == "Licht0" else ver)
    o.location = pos

# ---------- dak ----------
EAVE = 0.4
ex0, ex1, ey0, ey1 = -W / 2 - EAVE, W / 2 + EAVE, -D / 2 - EAVE, D / 2 + EAVE
ZE = TOP - 0.12          # onderkant dakrand
RISE = 2.1
run = (ey1 - ey0) / 2
ZR = ZE + RISE
rx = (ex1 - ex0) / 2 - run    # halve noklengte
PITCH = math.atan2(RISE, run)


def dak_mesh(name, parent):
    bm = bmesh.new()
    c = [bm.verts.new(p) for p in ((ex0, ey0, ZE), (ex1, ey0, ZE), (ex1, ey1, ZE), (ex0, ey1, ZE))]
    r0, r1 = bm.verts.new((-rx, 0, ZR)), bm.verts.new((rx, 0, ZR))
    bm.faces.new([c[0], c[1], r1, r0])   # voor
    bm.faces.new([c[2], c[3], r0, r1])   # achter
    bm.faces.new([c[1], c[2], r1])       # oost
    bm.faces.new([c[3], c[0], r0])       # west
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = mesh_obj(name, bm, DAKPAN, parent)
    o.data.materials.append(HOUT)
    sol = o.modifiers.new("dikte", "SOLIDIFY")
    sol.thickness = 0.14
    sol.offset = -1
    sol.material_offset = 1
    sol.material_offset_rim = 1
    bake(o)
    return o


def dak_uv(o):
    me = o.data
    uvl = me.uv_layers[0] if me.uv_layers else me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        if me.materials[poly.material_index].name != "Dakpan":
            continue
        n = poly.normal
        h = Vector((n.x, n.y, 0))
        if h.length < 1e-4:
            continue
        h.normalize()
        t = Vector((-h.y, h.x, 0))
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            u = p.dot(t)
            v = (-Vector((p.x, p.y, 0)).dot(h)) / math.cos(PITCH)
            uvl.data[li].uv = (u / 1.2, v / 1.2)


dakroot = dak
dh = []
dh.append(dak_mesh("Dak_heel", dakroot))
# plafond van de verdieping
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
bmesh.ops.scale(bm, vec=(XI1 - XI0, YI1 - YI0, 1), verts=bm.verts)
bmesh.ops.reverse_faces(bm, faces=bm.faces)
dh.append(mesh_obj("plafond", bm, PLAFOND, dakroot, (0, 0, TOP - 0.02)))
# nokvorst en hoekkepers
def ruggen(lst, parent):
    nok = cyl("nok", 0.09, 0.09, 2 * rx + 0.2, DAKPAN, "X", 8, parent, (0, 0, ZR + 0.06))
    lst.append(nok)
    for (cx, cy) in ((ex0, ey0), (ex1, ey0), (ex1, ey1), (ex0, ey1)):
        a = Vector((cx, cy, ZE + 0.02))
        b = Vector((rx if cx > 0 else -rx, 0, ZR + 0.04))
        mid = (a + b) / 2
        L = (b - a).length
        k = cyl("kepervorst", 0.07, 0.07, L, DAKPAN, "Z", 6, parent, mid)
        k.rotation_mode = "QUATERNION"
        k.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
        lst.append(k)
    # dakgoten voor en achter, regenpijpen op de hoeken
    for sy in (ey0, ey1):
        lst.append(cyl("goot", 0.07, 0.07, ex1 - ex0, ZINK, "X", 8, parent, (0, sy + (0.05 if sy < 0 else -0.05), ZE - 0.05)))
    for sx in (-W / 2 - 0.08, W / 2 + 0.08):
        for sy in (-D / 2 - 0.06,):
            lst.append(cyl("pijp", 0.045, 0.045, ZE, ZINK, "Z", 6, parent, (sx, sy, ZE / 2)))
            lst.append(cyl("pijpbocht", 0.045, 0.045, 0.4, ZINK, "Y", 6, parent, (sx, sy - 0.2, ZE - 0.05)))
    # schoorsteen en antenne
    lst.append(box("schoorsteen", (0.6, 0.5, 1.6), BAKSTEEN, parent, (2.2, 1.4, ZR - 0.3)))
    lst.append(box("schoorkap", (0.75, 0.65, 0.08), BETON, parent, (2.2, 1.4, ZR + 0.54)))
    lst.append(cyl("antenne", 0.02, 0.02, 1.6, IJZER, "Z", 5, parent, (-1.0, 0.2, ZR + 0.8)))
    for k in range(3):
        lst.append(box("antdwars", (0.04, 0.9 - 0.2 * k, 0.03), IJZER, parent, (-1.0, 0.2, ZR + 1.0 + 0.25 * k)))


ruggen(dh, dakroot)
dak_heel = join(dh[0], dh[1:])
dak_heel.name = "Dak_heel"

# kapot dak: zelfde dak met een groot gat in de voorkant en gebroken sparren
dk = [dak_mesh("Dak_kapot", dakroot)]
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
bmesh.ops.scale(bm, vec=(XI1 - XI0, YI1 - YI0, 1), verts=bm.verts)
bmesh.ops.reverse_faces(bm, faces=bm.faces)
dk.append(mesh_obj("plafond", bm, PLAFOND, dakroot, (0, 0, TOP - 0.02)))
dak_kapot = join(dk[0], dk[1:])
dak_kapot.name = "Dak_kapot"
HX, HY = -1.2, -1.6
cut(dak_kapot, [cutter_jagged((HX, HY, ZE + 1.0), 1.5, "Z", 6.0, 88, 13, BAKSTEEN, 0.85),
                cutter_jagged((2.6, 2.2, ZE + 1.0), 0.6, "Z", 6.0, 89, 9, BAKSTEEN)])
for p in dak_kapot.data.polygons:   # breukranden in het hout van de sparren, niet baksteen
    if dak_kapot.data.materials[p.material_index].name == "Baksteen":
        p.material_index = list(dak_kapot.data.materials).index(bpy.data.materials["Hout"]) if "Hout" in [m.name for m in dak_kapot.data.materials] else p.material_index
ks = []
ruggen(ks, dakroot)
for k, dx in enumerate((-0.7, 0.0, 0.7)):
    yy = HY
    zz = ZE + (yy - ey0) * math.tan(PITCH) - 0.2
    L = 2.6 if k != 1 else 1.4
    sp = box(f"spar{k}", (0.1, L, 0.14), HOUT, dakroot, (HX + dx, yy + (0.0 if k != 1 else 0.6), zz), (PITCH, 0, 0))
    if k == 1:
        sp.rotation_euler = (PITCH - 0.5, 0.15, 0)
    ks.append(sp)
for k in range(5):  # losse pannen op het plafond
    ks.append(box(f"pan{k}", (0.22, 0.32, 0.05), DAKPAN, dakroot, (HX + rng.uniform(-1, 1), HY + rng.uniform(-1, 1), TOP + 0.03),
                  (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, 3))))
join(dak_kapot, ks)
dak_kapot.name = "Dak_kapot"
# het plafond in de kapotte versie heeft ook een gat
dak_uv(dak_heel)
dak_uv(dak_kapot)

# ---------- puin (sjablonen) ----------
def brok(name, size, seed, parent, loc=(0, 0, 0), material=None):
    r = np.random.default_rng(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
    for v in bm.verts:
        v.co = Vector((v.co.x * r.uniform(0.7, 1.3), v.co.y * r.uniform(0.7, 1.3), v.co.z * r.uniform(0.5, 1.0)))
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    m = material or [PLEISTER, BAKSTEEN, BAKSTEEN, BETON][r.integers(0, 4)]
    o = mesh_obj(name, bm, m, parent, loc)
    o.rotation_euler = tuple(r.uniform(0, math.tau, 3))
    return o


def hoop(name, R, Hh, n, seed):
    r = np.random.default_rng(seed)
    parts = []
    for k in range(n):
        a = r.uniform(0, math.tau)
        d = R * math.sqrt(r.uniform(0, 1))
        z = Hh * (1 - (d / R) ** 2) * r.uniform(0.5, 1.0)
        s = r.uniform(0.3, 0.75) * (R / 1.4) ** 0.5
        parts.append(brok("b", (s, s * r.uniform(0.6, 1.2), s * 0.6), seed * 100 + k, puin, (d * math.cos(a), d * math.sin(a), z)))
    # een paar balken en een stuk muur met pleister
    parts.append(box("balk", (0.12, R * 1.5, 0.12), HOUT, puin, (0.2, 0, Hh * 0.5), (0.3, 0.1, r.uniform(0, 3))))
    parts.append(box("muurstuk", (0.9 * R, 0.25, 0.6 * R), PLEISTER, puin, (-0.3 * R, 0.2, Hh * 0.35), (1.1, 0.2, r.uniform(0, 3))))
    o = join(parts[0], parts[1:])
    o.name = name
    return o


hoop("PuinGroot", 1.5, 0.9, 42, 5)
hoop("PuinKlein", 0.8, 0.5, 16, 6)
for k in range(4):
    brok(f"Brok{k}", (0.25 + 0.1 * k, 0.2 + 0.08 * k, 0.15 + 0.05 * k), 900 + k, puin, (k * 0.8 - 1.2, 3.0, 0.1),
         [PLEISTER, BAKSTEEN, BETON, BAKSTEEN][k])

# ---------- tuin achter ----------
ts = []
ts.append(box("TuinGrond", (W - 0.2, TUIN_Y - D / 2, 0.03), GRAS, tuin, (0, (D / 2 + TUIN_Y) / 2, 0.015)))
ts.append(box("Pad", (1.0, TUIN_Y - D / 2 - 0.2, 0.035), BETON, tuin, (1.0, (D / 2 + TUIN_Y) / 2, 0.02)))
# moestuin
ts.append(box("Moestuin", (2.4, 1.2, 0.2), HOUT, tuin, (-2.3, 8.6, 0.1)))
ts.append(box("Aarde", (2.3, 1.1, 0.04), AARDE, tuin, (-2.3, 8.6, 0.2)))
for k in range(10):
    ts.append(cyl("plant", 0.12, 0.0, 0.3, BLAD, "Z", 5, tuin, (-3.3 + (k % 5) * 0.5, 8.35 + (k // 5) * 0.5, 0.36)))
# waslijn
for x in (-3.2, 0.2):
    ts.append(cyl("paal", 0.04, 0.04, 2.0, HOUT, "Z", 6, tuin, (x, 6.2, 1.0)))
ts.append(cyl("lijn", 0.008, 0.008, 3.4, STOF3, "X", 4, tuin, (-1.5, 6.2, 1.9)))
for k, (x, m) in enumerate(((-2.6, STOF3), (-1.9, STOF2), (-1.1, STOF), (-0.5, STOF3))):
    ts.append(box("was", (0.5, 0.02, 0.6 + 0.1 * (k % 2)), m, tuin, (x, 6.2, 1.55 - 0.05 * (k % 2))))
# regenton, brandhout, bananenplant, emmer
ts.append(cyl("Ton", 0.3, 0.3, 0.85, VAT, "Z", 12, tuin, (3.3, 4.1, 0.43)))
ts.append(cyl("Tondeksel", 0.31, 0.31, 0.03, DONKER, "Z", 12, tuin, (3.3, 4.1, 0.87)))
for k in range(9):
    ts.append(cyl("hout", 0.08, 0.08, 0.6, HOUT, "X", 6, tuin, (3.1, 9.2 + (k % 3) * 0.17 - 0.17, 0.08 + (k // 3) * 0.15)))
ts.append(cyl("emmer", 0.13, 0.11, 0.25, ZINK, "Z", 8, tuin, (2.4, 4.0, 0.13)))
ts.append(cyl("stam", 0.1, 0.08, 1.8, HOUT, "Z", 6, tuin, (2.8, 7.0, 0.9)))
for k in range(6):
    a = k / 6 * math.tau
    ts.append(box("bananenblad", (0.3, 1.1, 0.02), BLAD, tuin, (2.8 + 0.45 * math.cos(a), 7.0 + 0.45 * math.sin(a), 1.95),
                  (0.6, 0, a - math.pi / 2)))
tuinspul = join(ts[0], ts[1:])
tuinspul.name = "TuinSpul"
# tuinmuur: laag gepleisterd muurtje met poortje achter in het midden
TM_H, TM_T = 1.1, 0.2


def kap(seg, kapot, r):
    pass


tm = [("TW", (-W / 2 + TM_T / 2, (D / 2 + TUIN_Y) / 2), -math.pi / 2, TUIN_Y - D / 2),
      ("TO", (W / 2 - TM_T / 2, (D / 2 + TUIN_Y) / 2), math.pi / 2, TUIN_Y - D / 2)]
for (nm, c, ang, L) in tm:
    n = 3
    for i in range(n):
        f0 = -L / 2 + L * i / n
        f1 = -L / 2 + L * (i + 1) / n
        mid = (f0 + f1) / 2
        if nm == "TW":
            cc = (c[0], c[1] - mid)
        else:
            cc = (c[0], c[1] + mid)
        wall_segment(f"T_{nm}{i}", tuin, cc, ang, f1 - f0, TM_H, 0.0, [], inner=PLEISTER, outer=PLEISTER,
                     ends=(i > 0, i < n - 1), thick=TM_T, seed=40 + i + (10 if nm == "TO" else 0))
for i, (a, b) in enumerate(((-W / 2, -1.7), (-1.7, 0.4), (1.6, W / 2))):
    wall_segment(f"T_A{i}", tuin, ((a + b) / 2, TUIN_Y - TM_T / 2), math.pi, b - a, TM_H, 0.0, [], inner=PLEISTER, outer=PLEISTER,
                 ends=(i == 1, i == 0), thick=TM_T, seed=60 + i)
for x in (0.4, 1.6):
    box("poortpaal", (0.3, 0.3, 1.4), PLEISTER, tuin, (x + (0.15 if x < 1 else -0.15), TUIN_Y - TM_T / 2, 0.7))
for o in [o for o in tuin.children if o.name.startswith("poortpaal")]:
    o.name = "Poortpaal"
join(tuinspul, [o for o in tuin.children if o.name.startswith("Poortpaal")])
tuinspul.name = "TuinSpul"

# ---------- afwerking ----------
bpy.context.view_layer.update()
for o in list(scene.objects):
    if o.type == "MESH":
        bad = [p for p in o.data.polygons if p.material_index >= len(o.data.materials)]
        if bad:
            print("MATFOUT", o.name, len(bad), [m.name for m in o.data.materials])
        world_uv(o)
dak_uv(dak_heel)
dak_uv(dak_kapot)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "woonhuis.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "woonhuis.blend"))
tris = {}
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        key = "kapot" if o.name.endswith("_kapot") else ("puin" if o.parent and o.parent.name == "Puin" else "heel")
        tris[key] = tris.get(key, 0) + len(o.data.loop_triangles)
print("TRIS", tris, "OBJECTEN", len([o for o in scene.objects if o.type == "MESH"]))
