"""Benzinestation voor de stad achter de brug (Bloedjungle): een klein tankstation uit de jaren veertig met een
roomwit winkeltje (toko met kassa, rekken, koeling en een opslag achterin), een luifel op vier betonnen kolommen,
twee pompeilanden met elk twee ouderwetse pompen met een glazen bol, olievaten, banden en een prijsbord op een paal.
Alles kan kapot: de muren van het winkeltje en de kolommen van de luifel zijn losse stukken met een hele en een kapotte
versie, het dak heeft een kapotte versie, en het winkeltje en de luifel storten elk apart in ('RuineWinkel',
'RuineLuifel'). De pompen en vaten (XPomp*, XVat*) ontploffen in het spel en hebben een uitgebrande versie.
Blender: voorkant aan -Y (wordt +Z in Godot), Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van het geheel.
Gebruik: python3 maak_benzine.py <uitmap>  ->  benzine.glb, benzine.blend  (bouwfuncties gedeeld met maak_winkel.py)

Hiërarchie (namen die het spel gebruikt):
  Benzinestation
    Begane       Fundering, muurstukken M0* en P0 (binnenmuur naar de opslag), DeurVoor, DeurAchter, DeurBinnen0,
                 Inrichting0, Licht0
    Dak          Dak_heel / Dak_kapot (plat dak met naambord TOKO BENSIN)
    Luifel       LuifelDak (luifel met rand, letters, lampen en het prijsbord), kolommen K0..K3, LuifelLicht
    Pompen       Eilanden, XPomp0..3 (XPompN_heel / XPompN_kapot)
    Buiten       XVat0..2 (olievaten), Spullen (banden, compressor, jerrycans, stoep)
    Puin         PuinGroot, PuinKlein, Brok0..3 (sjablonen voor sloop)
    Ruine        RuineWinkel, RuineLuifel (verborgen tot het winkeltje of de luifel instort)
  Sloopstuk X: leeg knooppunt met kinderen X_heel en X_kapot. Deuren: het knooppunt is het scharnier.
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

# ---------- maten (ook gebruikt door de gedeelde hulpfuncties) ----------
T = 0.25                 # muurdikte
F0 = 0.2                 # vloer winkeltje
TOP = 3.4                # bovenkant muren (onderkant dakvloer)
LEVELS = (F0,)

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
    """Verschoten roomwitte kalkpleister. v = hoogte / 6,4 m (v = 0 is de grond), u herhaalt elke 3,2 m.
    Vuil en mos onderaan, regenstrepen onder de daklijst en de verdiepingsband, plekken waar de pleister eraf is."""
    v = 1 - np.mgrid[0:size, 0:size][0] / size
    v = v[..., None]
    basis = np.array([0.84, 0.8, 0.68])
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
    return save_img("benzine_pleister", img, size)


def binnen_image(size=256):
    """Binnenmuur: roomwitte kalk boven een rode lambrisering (v = hoogte / 3,2 m)."""
    v = (1 - np.mgrid[0:size, 0:size][0] / size)[..., None]
    boven = np.array([0.86, 0.83, 0.7])
    onder = np.array([0.62, 0.2, 0.14])
    img = np.where(v < 0.36, onder, boven) * (0.92 + 0.12 * noise(size, 32, 21)[..., None])
    lijn = (np.abs(v - 0.36) < 0.008)
    img = np.where(lijn, np.array([0.3, 0.32, 0.26]), img)
    vlek = sm(noise(size, 16, 22) * 0.6 + noise(size, 64, 23) * 0.4, 0.6, 0.75) * 0.2
    img = img * (1 - vlek) + np.array([0.5, 0.45, 0.32]) * vlek
    return save_img("benzine_binnen", img, size)


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
    return save_img("benzine_baksteen", img, size)


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
    return save_img("benzine_dakpan", img, size)


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
    return save_img("benzine_tegels", img, size)


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
    return save_img("benzine_planken", img, size)


def luik_image(size=256):
    """Groene lamellen van de luiken en deuren: 20 lamellen per 1,6 m, verf bladdert."""
    y = np.mgrid[0:size, 0:size][0] / size
    f = (y * 20) % 1.0
    groen = np.array([0.22, 0.4, 0.3])
    img = groen * (0.6 + 0.5 * f)[..., None] * (0.9 + 0.2 * noise(size, 16, 71)[..., None])
    kaal = sm(noise(size, 8, 72) * 0.5 + noise(size, 32, 73) * 0.5, 0.64, 0.68)
    img = img * (1 - kaal) + np.array([0.42, 0.33, 0.24]) * kaal
    return save_img("benzine_luik", img, size)


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


PLEISTER = mat("Pleister", (0.84, 0.8, 0.68), 0.95, image=pleister_image())
BINNEN = mat("Binnen", (0.86, 0.83, 0.7), 0.9, image=binnen_image())
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
                uv = (uv[0], (c.z - max([l for l in LEVELS if c.z > l - 0.01] or [F0])) if c.z > 0 else c.z)
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
        if kind == "etalage":
            # winkelruit: dun ijzeren kozijn, groot glas met een roede, betonnen onderdorpel
            det.append(box("k", (w, 0.08, 0.08), IJZER, seg, (cx, yo + 0.06, zb + 0.04)))
            det.append(box("k", (w, 0.08, 0.08), IJZER, seg, (cx, yo + 0.06, zb + h - 0.04)))
            for sx in (-1, 0, 1):
                det.append(box("k", (0.06, 0.08, h), IJZER, seg, (cx + sx * (w / 2 - 0.03), yo + 0.06, zb + h / 2)))
            det.append(box("k", (w, 0.05, 0.04), IJZER, seg, (cx, yo + 0.06, zb + h * 0.78)))
            det.append(box("g", (w - 0.08, 0.02, h - 0.08), GLAS, seg, (cx, yo + 0.07, zb + h / 2)))
            det.append(box("v", (w + 0.1, 0.22, 0.08), BETON, seg, (cx, yo - 0.02, zb - 0.04)))
            continue
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

def add_to_heel(seg, objs):
    """Extra details (in de coördinaten van het muurstuk) bij de hele versie voegen: ze verdwijnen mee als de muur kapot gaat."""
    heel = [c for c in seg.children if c.name.endswith("_heel")][0]
    nm = heel.name
    join(heel, objs)
    heel.name = nm


def tekst(name, body, size, material, parent, loc, rot=(math.pi / 2, 0, 0), extrude=0.02):
    """Letters als mesh (Blender-tekst omgezet)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    o = link(bpy.data.objects.new(name, cu), parent)
    o.location = loc
    o.rotation_euler = rot
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    m = link(bpy.data.objects.new(name, me), parent)
    m.matrix_world = o.matrix_world.copy()
    bpy.data.objects.remove(o, do_unlink=True)
    me.materials.clear()
    me.materials.append(material)
    return m


UVS["Pleister"] = (3.2, 3.8)


def asfalt_image(size=512):
    """Betonplaten onder de luifel: vlakken van 3 m met naden, olievlekken en bandensporen."""
    y, x = np.mgrid[0:size, 0:size] / size
    img = np.array([0.5, 0.49, 0.46]) * (0.85 + 0.2 * noise(size, 32, 101)[..., None] + 0.06 * noise(size, 4, 102)[..., None])
    naad = ((x % 0.5) < 0.006) | ((y % 0.5) < 0.006)
    img = np.where(naad[..., None], np.array([0.25, 0.24, 0.22]), img)
    olie = sm(noise(size, 64, 103) * 0.7 + noise(size, 16, 104) * 0.3, 0.6, 0.7) * 0.7
    img = img * (1 - olie) + np.array([0.12, 0.11, 0.1]) * olie
    return save_img("benzine_beton", img, size)


BAND = mat("Band", (0.66, 0.12, 0.09), 0.55)
VLOERBETON = mat("Vloerbeton", (0.5, 0.49, 0.46), 0.9, image=asfalt_image())
UVS["Vloerbeton"] = (6.0, 6.0)
POMPROOD = mat("Pomprood", (0.72, 0.1, 0.07), 0.45, 0.2)
CREME = mat("Creme", (0.9, 0.86, 0.72), 0.5)
GLOBE = mat("Globe", (0.95, 0.92, 0.82), 0.2, emit=(1.0, 0.92, 0.75), strength=0.6)
RUBBER = mat("Rubber", (0.05, 0.05, 0.05), 0.7)
VERKOOLD = mat("Verkoold", (0.07, 0.06, 0.055), 0.95)
GEEL = mat("Geel", (0.85, 0.66, 0.12), 0.7)
OLIEVAT = mat("Olievat", (0.15, 0.32, 0.5), 0.55, 0.3)
BORD = mat("Bord", (0.66, 0.12, 0.09), 0.6)
LETTER = mat("Letter", (0.95, 0.92, 0.82), 0.5)
DOOS = mat("Doos", (0.62, 0.48, 0.3), 0.9)
BLIK = mat("Blik", (0.75, 0.3, 0.18), 0.4, 0.6)
BLIK2 = mat("Blik2", (0.2, 0.42, 0.25), 0.4, 0.6)
FLES = mat("Fles", (0.3, 0.5, 0.25), 0.1, 0.2)
ROEST = mat("Roest", (0.42, 0.24, 0.14), 0.8, 0.4)
PAPIER = mat("Papier", (0.9, 0.86, 0.74), 0.9)

# ---------- maten ----------
# (T, F0 en LEVELS staan ook in de gedeelde hulpfuncties: wereld-UV en muurstukken)
XS0, XS1 = -3.5, 3.5        # winkeltje: x
YS0, YS1 = 0.0, 5.2         # winkeltje: y (voorgevel bij y = 0, onder de luifel)
XI0, XI1 = XS0 + T, XS1 - T
YI0, YI1 = YS0 + T, YS1 - T
PY = 3.8                    # binnenmuur tussen winkel en opslag
LX, LY0, LY1 = 4.8, -5.4, -0.3   # luifel: x -4,8..4,8, y -5,4..-0,3
LZ = 4.2                    # onderkant luifel
KX, KY = 3.4, (-0.9, -4.8)  # kolommen
EI_X, EI_Y0, EI_Y1, EI_H = 1.6, -4.4, -1.3, 0.18   # pompeilanden op x = ±1,6
POMP_Y = (-3.6, -2.1)
DOOR_H = 2.3

root = empty("Benzinestation")
beg = empty("Begane", root)
dak = empty("Dak", root)
luifel = empty("Luifel", root)
pompen = empty("Pompen", root)
buiten = empty("Buiten", root)
puin = empty("Puin", root)
ruine = empty("Ruine", root)


def gevel(side, segs):
    """side: 'V' voor (-y), 'A' achter (+y), 'W' west (-x), 'O' oost (+x). segs: (begin, eind, [openingen in gebouwcoördinaten])."""
    H = TOP - F0
    n = len(segs)
    out = []
    for i, (a, b, ops) in enumerate(segs):
        mid = (a + b) / 2
        if side == "V":
            center, angle = (mid, YS0 + T / 2), 0.0
            loc = [(cx - mid, w, zb, h, k) for (cx, w, zb, h, k) in ops]
        elif side == "A":
            center, angle = (mid, YS1 - T / 2), math.pi
            loc = [(mid - cx, w, zb, h, k) for (cx, w, zb, h, k) in ops]
        elif side == "W":
            center, angle = (XS0 + T / 2, mid), -math.pi / 2
            loc = [(mid - cy, w, zb, h, k) for (cy, w, zb, h, k) in ops]
        else:
            center, angle = (XS1 - T / 2, mid), math.pi / 2
            loc = [(cy - mid, w, zb, h, k) for (cy, w, zb, h, k) in ops]
        out.append(wall_segment(f"M0{side}{i}", beg, center, angle, b - a, H, F0, loc, ends=(i > 0, i < n - 1),
                                cornice=True, seed=ord(side) * 31 + i * 7 + 900))
    return out


def etalage(cx, w=2.0):
    return (cx, w, 0.75, 1.85, "etalage")


SIDES = [(YI0, 2.6), (2.6, YI1)]
gevel("V", [(XS0, -1.0, [etalage(-2.25, 2.0)]), (-1.0, 1.0, [(0.0, 1.3, 0.0, DOOR_H, "deur")]), (1.0, XS1, [etalage(2.25, 2.0)])])
gevel("A", [(XS0, -1.0, [(-2.25, 1.0, 1.3, 0.8, "raam")]), (-1.0, 1.0, [(0.0, 0.95, 0.0, 2.2, "deur")]), (1.0, XS1, [])])
gevel("W", [(SIDES[0][0], SIDES[0][1], [etalage(1.4, 1.6)]), (SIDES[1][0], SIDES[1][1], [])])
gevel("O", [(SIDES[0][0], SIDES[0][1], [(1.4, 1.0, 1.3, 0.8, "raam")]), (SIDES[1][0], SIDES[1][1], [(3.9, 0.9, 1.3, 0.8, "raam")])])

TI = 0.14
wall_segment("P0", beg, (0.0, PY), 0.0, XI1 - XI0, TOP - F0, F0, [(-2.2, 1.1, 0.0, 2.2, "deur")], inner=BINNEN, outer=BINNEN,
             thick=TI, seed=21)

# fundering, tegelvloer, stoep rond de winkel en de betonvloer onder de luifel
fund = [box("Fund", (XS1 - XS0 - 0.02, YS1 - YS0 - 0.02, F0), BETON, beg, (0, (YS0 + YS1) / 2, F0 / 2)),
        box("Vloer0", (XI1 - XI0, YI1 - YI0, 0.02), TEGELS, beg, (0, (YS0 + YS1) / 2, F0 + 0.01)),
        box("Drempel", (1.5, 0.5, 0.1), BETON, beg, (0, YS0 - 0.25, 0.05)),
        box("StoepA", (1.4, 0.6, 0.12), BETON, beg, (0, YS1 + 0.3, 0.06))]
fundering = join(fund[0], fund[1:])
fundering.name = "Fundering"

pl = box("Plaat", (2 * LX + 0.4, LY1 - LY0 + 0.6, 0.04), VLOERBETON, pompen, (0, (LY0 + LY1) / 2, 0.02))
eil = [pl]
for sx in (-1, 1):
    x = sx * EI_X
    eil.append(box("eiland", (0.9, EI_Y1 - EI_Y0, EI_H), BETON, pompen, (x, (EI_Y0 + EI_Y1) / 2, EI_H / 2)))
    for y in (EI_Y0, EI_Y1):   # geel-zwart geverfde kopse kanten
        eil.append(box("kop", (0.92, 0.25, EI_H + 0.01), GEEL, pompen, (x, y + (0.12 if y == EI_Y0 else -0.12), EI_H / 2)))
    # stootpaal aan beide kanten van het eiland
    for y in (EI_Y0 + 0.2, EI_Y1 - 0.2):
        eil.append(cyl("paal", 0.07, 0.07, 0.8, GEEL, "Z", 8, pompen, (x, y, EI_H + 0.4)))
    eil.append(box("emmer", (0.25, 0.25, 0.3), ZINK, pompen, (x + 0.2, -2.85, EI_H + 0.15)))
    eil.append(box("oliekan", (0.18, 0.1, 0.25), BLIK, pompen, (x - 0.22, -2.85, EI_H + 0.125)))
join(eil[0], eil[1:]).name = "Eilanden"


# ---------- pompen: elke pomp is een sloopstuk XPompN met XPompN_heel en XPompN_kapot ----------
def pomp(name, x, y, face):
    """Ouderwetse benzinepomp met een glazen bol, een wijzerplaat aan beide kanten en een slang in de houder.
    face = 1: de slang hangt aan de +x-kant (naar de auto die daar staat)."""
    seg = empty(name, pompen, (x, y, EI_H), (0, 0, 0))
    h = []
    h.append(box("sokkel", (0.52, 0.44, 0.1), DONKER, seg, (0, 0, 0.05)))
    h.append(box("lijf", (0.44, 0.36, 1.2), POMPROOD, seg, (0, 0, 0.7)))
    for z in (0.36, 1.28):
        h.append(box("bies", (0.46, 0.38, 0.04), ZINK, seg, (0, 0, z)))
    for sx in (-1, 1):
        h.append(cyl("wijzer", 0.14, 0.14, 0.02, EMAILLE, "X", 16, seg, (sx * 0.225, 0, 1.0)))
        h.append(cyl("rand", 0.155, 0.155, 0.015, ZINK, "X", 16, seg, (sx * 0.221, 0, 1.0)))
        h.append(box("naald", (0.01, 0.015, 0.11), DONKER, seg, (sx * 0.237, 0.02, 1.03), (0.5, 0, 0)))
        h.append(box("deurtje", (0.01, 0.26, 0.5), POMPROOD, seg, (sx * 0.225, 0, 0.62)))
        h.append(box("greep", (0.02, 0.08, 0.02), ZINK, seg, (sx * 0.235, 0.08, 0.7)))
    h.append(box("kop", (0.48, 0.4, 0.22), CREME, seg, (0, 0, 1.41)))
    h.append(cyl("hals", 0.08, 0.1, 0.1, ZINK, "Z", 10, seg, (0, 0, 1.56)))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=0.19)
    h.append(mesh_obj("bol", bm, GLOBE, seg, (0, 0, 1.78), smooth=True))
    h.append(cyl("bolband", 0.195, 0.195, 0.09, POMPROOD, "Z", 14, seg, (0, 0, 1.78)))
    # slang: van de zijkant omlaag in een boog en terug naar het pistool in de houder
    sx = face
    p0, p1, p2 = Vector((sx * 0.22, 0.1, 1.15)), Vector((sx * 0.62, 0.02, -0.1)), Vector((sx * 0.27, -0.1, 0.84))
    pts = [p0.lerp(p1, t).lerp(p1.lerp(p2, t), t) for t in np.linspace(0, 1, 9)]   # doorhangende boog (Bézier)
    for a, b in zip(pts, pts[1:]):
        d = b - a
        c = cyl("slang", 0.025, 0.025, d.length, RUBBER, "Z", 6, seg, tuple((a + b) / 2))
        c.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        h.append(c)
    h.append(box("houder", (0.06, 0.12, 0.1), ZINK, seg, (sx * 0.24, -0.1, 0.86)))
    h.append(box("pistool", (0.05, 0.2, 0.06), ZINK, seg, (sx * 0.27, -0.12, 0.92), (0.4, 0, 0)))
    heel = join(h[0], h[1:])
    heel.name = name + "_heel"
    # uitgebrand: verkoold, opengescheurd lijf dat scheef staat, kop en bol liggen ernaast, slang gesmolten
    k = []
    k.append(box("sokkel", (0.52, 0.44, 0.1), DONKER, seg, (0, 0, 0.05)))
    lijf = box("lijf", (0.44, 0.36, 0.95), VERKOOLD, seg, (0, 0, 0.55))
    cut(lijf, [cutter_jagged((0.0, 0, 1.0), 0.35, "Y", 0.6, 7000 + int(x * 10 + y), 9, VERKOOLD, 0.8),
               cutter_jagged((0.0, 0, 0.6), 0.15, "X", 0.6, 7100 + int(x * 10 + y), 7, ROEST)])
    lijf.rotation_euler = (0.12, -0.18 * face, 0)
    k.append(lijf)
    for j in range(3):
        k.append(box("plaat", (0.3, 0.02, 0.25), ROEST, seg, (face * (0.35 + 0.1 * j), 0.25 - j * 0.2, 0.05 + j * 0.03),
                     (1.4, 0.2 * j, 0.5 * j)))
    k.append(box("kop", (0.48, 0.4, 0.22), VERKOOLD, seg, (-face * 0.45, 0.25, 0.11), (0.2, 0.4, 0.6)))
    k.append(cyl("slang", 0.03, 0.03, 0.7, RUBBER, "X", 6, seg, (face * 0.35, -0.3, 0.02), rot=(0, 0, 0.5)))
    kapot = join(k[0], k[1:])
    kapot.name = name + "_kapot"
    return seg


n = 0
for sx in (-1, 1):
    for y in POMP_Y:
        pomp(f"XPomp{n}", sx * EI_X, y, sx)
        n += 1


def vat(name, x, y, rot, parent):
    """Olievat (ook een sloopstuk: ontploft als het geraakt wordt)."""
    seg = empty(name, parent, (x, y, 0), (0, 0, rot))
    h = [cyl("vat", 0.29, 0.29, 0.88, OLIEVAT, "Z", 14, seg, (0, 0, 0.44))]
    for z in (0.3, 0.6):
        h.append(cyl("ring", 0.3, 0.3, 0.03, ROEST, "Z", 14, seg, (0, 0, z)))
    h.append(cyl("deksel", 0.27, 0.27, 0.02, ZINK, "Z", 14, seg, (0, 0, 0.885)))
    h.append(cyl("dop", 0.04, 0.04, 0.03, ZINK, "Z", 6, seg, (0.15, 0, 0.9)))
    h.append(box("label", (0.3, 0.01, 0.2), PAPIER, seg, (0, -0.29, 0.45)))
    heel = join(h[0], h[1:])
    heel.name = name + "_heel"
    k = cyl("vat", 0.3, 0.33, 0.5, VERKOOLD, "Z", 14, seg, (0, 0, 0.25))
    cut(k, [cutter_jagged((0.0, 0, 0.55), 0.3, "Y", 0.8, 7300 + int(x * 10), 9, ROEST)])
    k2 = box("flap", (0.3, 0.02, 0.3), ROEST, seg, (0.2, 0.3, 0.45), (0.8, 0.3, 0.6))
    kapot = join(k, [k2])
    kapot.name = name + "_kapot"
    return seg


vat("XVat0", 4.05, 0.7, 0.3, buiten)
vat("XVat1", 4.1, 1.35, 1.1, buiten)
vat("XVat2", 4.62, 1.0, 2.0, buiten)
bu = []
for k in range(4):   # stapel oude banden
    bu.append(cyl("band", 0.34, 0.34, 0.22, RUBBER, "Z", 14, buiten, (4.15, 3.3, 0.11 + k * 0.22)))
    bu.append(cyl("velg", 0.18, 0.18, 0.23, DONKER, "Z", 10, buiten, (4.15, 3.3, 0.11 + k * 0.22)))
bu.append(cyl("band", 0.34, 0.34, 0.22, RUBBER, "Y", 14, buiten, (4.2, 4.2, 0.34), rot=(0, 0, 0.3)))
# luchtpomp (compressor) aan de westkant
bu.append(box("compressor", (0.5, 0.7, 0.55), POMPROOD, buiten, (-4.1, 0.9, 0.3)))
bu.append(cyl("ketel", 0.18, 0.18, 0.65, ROEST, "Y", 12, buiten, (-4.1, 0.9, 0.75)))
bu.append(cyl("slang", 0.02, 0.02, 1.0, RUBBER, "Z", 6, buiten, (-4.1, 0.45, 0.5), rot=(0.4, 0, 0)))
# jerrycans en een stoep langs de voorgevel
for k in range(3):
    bu.append(box("jerrycan", (0.18, 0.36, 0.47), (GEEL, POMPROOD, BLIK2)[k], buiten, (-3.75, 2.2 + k * 0.42, 0.24)))
bu.append(box("Stoep", (XS1 - XS0 + 0.4, 0.8, 0.14), BETON, buiten, (0, YS0 - 0.4, 0.07)))
join(bu[0], bu[1:]).name = "Spullen"


# ---------- luifel op vier kolommen ----------
def kolom(name, x, y):
    """Betonnen kolom met een geel-zwarte voet. Lokaal -y wijst naar buiten (van het midden van de luifel af)."""
    cy = (LY0 + LY1) / 2
    rot = math.atan2(x, -(y - cy))
    seg = empty(name, luifel, (x, y, 0), (0, 0, rot))
    h = [box("kolom", (0.32, 0.32, LZ), BETON, seg, (0, 0, LZ / 2)),
         box("voet", (0.42, 0.42, 0.5), GEEL, seg, (0, 0, 0.25)),
         box("streep", (0.43, 0.43, 0.08), DONKER, seg, (0, 0, 0.3)),
         box("kap", (0.44, 0.44, 0.12), BETON, seg, (0, 0, LZ - 0.06))]
    heel = join(h[0], h[1:])
    heel.name = name + "_heel"
    seed = int(abs(x) * 10 + abs(y) * 3)
    k = box("kolom", (0.32, 0.32, LZ), BETON, seg, (0, 0, LZ / 2))
    cut(k, [cutter_jagged((0.2, 0, 1.6), 0.3, "Y", 0.6, 7500 + seed, 9, BETON, 1.4),
            cutter_jagged((-0.22, 0, 2.7), 0.25, "Y", 0.6, 7600 + seed, 8, BETON, 1.6)])
    kk = [box("voet", (0.42, 0.42, 0.5), GEEL, seg, (0, 0, 0.25)), box("kap", (0.44, 0.44, 0.12), BETON, seg, (0, 0, LZ - 0.06))]
    for j in range(4):   # betonijzer in de happen
        kk.append(cyl("ijzer", 0.012, 0.012, 0.6, ROEST, "Z", 4, seg, (-0.1 + j * 0.07, 0.1 - j * 0.05, 1.6 + (j % 2) * 1.1),
                      rot=(0.15 * j, 0.1, 0)))
    kapot = join(k, kk)
    kapot.name = name + "_kapot"
    return seg


n = 0
for sx in (-1, 1):
    for y in KY:
        kolom(f"K{n}", sx * KX, y)
        n += 1

ld = []
LD = 0.25
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1)
bmesh.ops.scale(bm, vec=(2 * LX, LY1 - LY0, LD), verts=bm.verts)
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, (LY0 + LY1) / 2, LZ + LD / 2))
plaat = mesh_obj("LuifelDak", bm, None, luifel)
set_materials(plaat, [BETON, PLAFOND, BETON])
for p in plaat.data.polygons:
    p.material_index = 0 if p.normal.z > 0.5 else (1 if p.normal.z < -0.5 else 2)
ld.append(plaat)
BH = 0.55
for (cx, cy, sx, sy) in ((0, LY0 - 0.04, 2 * LX + 0.16, 0.08), (0, LY1 + 0.04, 2 * LX + 0.16, 0.08),
                         (-LX - 0.04, (LY0 + LY1) / 2, 0.08, LY1 - LY0), (LX + 0.04, (LY0 + LY1) / 2, 0.08, LY1 - LY0)):
    ld.append(box("band", (sx, sy, BH), BAND, luifel, (cx, cy, LZ + LD - BH / 2 + 0.12)))
    for z in (LZ + LD + 0.09, LZ + LD - BH + 0.15):   # witte bies boven en onder
        ld.append(box("bies", (sx + 0.02, sy + 0.02, 0.06), CREME, luifel, (cx, cy, z)))
ld.append(tekst("Naam", "BENSIN", 0.36, LETTER, luifel, (-1.4, LY0 - 0.09, LZ + 0.22)))
ld.append(tekst("Naam", "OLIE", 0.36, LETTER, luifel, (2.6, LY0 - 0.09, LZ + 0.22)))
ld.append(tekst("Naam", "BENSIN", 0.36, LETTER, luifel, (LX + 0.09, -2.85, LZ + 0.22), rot=(math.pi / 2, 0, math.pi / 2)))
ld.append(tekst("Naam", "BENSIN", 0.36, LETTER, luifel, (-LX - 0.09, -2.85, LZ + 0.22), rot=(math.pi / 2, 0, -math.pi / 2)))
for sx in (-1, 1):   # lampen onder de luifel, boven de eilanden
    for y in (-3.9, -1.8):
        ld.append(box("lamp", (0.3, 0.9, 0.06), LAMPGLAS, luifel, (sx * EI_X, y, LZ - 0.03)))
# prijsbord op een paal op de hoek bij de straat
PX, PY_ = -LX + 0.2, LY0 - 0.6
ld.append(cyl("paal", 0.08, 0.08, 5.6, ZINK, "Z", 8, luifel, (PX, PY_, 2.8)))
ld.append(box("bord", (1.5, 0.12, 1.2), BAND, luifel, (PX, PY_, 5.0)))
ld.append(box("bordrand", (1.6, 0.1, 1.3), CREME, luifel, (PX, PY_ + 0.02, 5.0)))
ld.append(tekst("Prijs", "BENSIN", 0.28, LETTER, luifel, (PX, PY_ - 0.07, 5.3)))
ld.append(tekst("Prijs", "12 c", 0.32, LETTER, luifel, (PX, PY_ - 0.07, 4.82)))
dakluifel = join(ld[0], ld[1:])
dakluifel.name = "LuifelDak"
lp = bpy.data.lights.new("LuifelLicht", "POINT")
lp.energy = 3.0
lp.color = (1.0, 0.9, 0.7)
o = link(bpy.data.objects.new("LuifelLicht", lp), luifel)
o.location = (0, -2.85, LZ - 0.4)


# ---------- deuren ----------
def deur(name, parent, hinge, width, height, angle, mat_paneel, sx=1, glas=False):
    h = empty(name, parent, hinge, (0, 0, angle))
    parts = [box(name + "Blad", (width - 0.04, 0.05, height - 0.02), mat_paneel, h, (sx * width / 2, 0, height / 2))]
    if glas:
        parts.append(box("ruit", (width - 0.2, 0.06, height * 0.62), GLAS, h, (sx * width / 2, 0, height * 0.58)))
        parts.append(box("bord", (0.36, 0.07, 0.14), PAPIER, h, (sx * width / 2, 0, height * 0.58)))
    else:
        for (pz, ph) in ((0.25, 0.75), (1.15, 0.85)):
            parts.append(box("paneel", (width - 0.3, 0.07, ph), HOUT, h, (sx * width / 2, 0, pz + ph / 2)))
    parts.append(cyl("knop", 0.035, 0.035, 0.14, IJZER, "Y", 8, h, (sx * (width - 0.12), 0, 1.05)))
    join(parts[0], parts[1:])
    parts[0].name = name + "Blad"
    return h


deur("DeurVoor", beg, (-0.63, YS0 + T / 2, F0), 1.26, DOOR_H, 0.0, POMPROOD, glas=True)
deur("DeurAchter", beg, (0.45, YS1 - T / 2, F0), 0.9, 2.2, math.pi, HOUTLICHT)
deur("DeurBinnen0", beg, (-2.2 - 0.53, PY, F0), 1.06, 2.2, 0.0, HOUTLICHT)


# ---------- inrichting: toonbank met kassa, rekken, koeling, opslag ----------
def stelling(lst, parent, x, y, z, w, d, h, rot, seed):
    """Winkelrek met planken vol oliekannen, blikken, flessen en dozen."""
    r = np.random.default_rng(seed)
    c, s = math.cos(rot), math.sin(rot)

    def p(dx, dy):
        return (x + dx * c - dy * s, y + dx * s + dy * c)
    for sx in (-1, 1):
        lst.append(box("staander", (0.05, d, h), IJZER, parent, (*p(sx * (w / 2 - 0.025), 0), z + h / 2), (0, 0, rot)))
    for k in range(4):
        zk = z + 0.15 + k * (h - 0.25) / 3
        lst.append(box("plank", (w, d, 0.03), HOUT, parent, (*p(0, 0), zk), (0, 0, rot)))
        if k == 3:
            continue
        xx = -w / 2 + 0.12
        while xx < w / 2 - 0.15:
            soort = r.integers(0, 4)
            if soort == 0:
                bw = r.uniform(0.2, 0.35)
                lst.append(box("doos", (bw, d * 0.8, r.uniform(0.15, 0.3)), DOOS, parent, (*p(xx + bw / 2, 0), zk + 0.12), (0, 0, rot)))
                xx += bw + 0.03
            elif soort == 1:
                lst.append(box("oliekan", (0.18, 0.1, 0.26), (BLIK, BLIK2, GEEL)[r.integers(0, 3)], parent, (*p(xx + 0.09, 0), zk + 0.145),
                               (0, 0, rot)))
                xx += 0.22
            else:
                m = (BLIK, FLES)[soort - 2]
                hh = 0.28 if m is FLES else 0.12
                for j in range(3):
                    lst.append(cyl("blik", 0.045, 0.045 if m is not FLES else 0.025, hh, m, "Z", 6, parent,
                                   (*p(xx + 0.05, -d / 3 + j * d / 3), zk + 0.015 + hh / 2)))
                xx += 0.12


inr = []
# toonbank langs de oostkant, de kassa vooraan bij de deur
inr.append(box("Toonbank", (0.7, 2.0, 1.0), HOUT, beg, (2.05, 1.9, F0 + 0.5)))
inr.append(box("Toonblad", (0.8, 2.1, 0.05), HOUTLICHT, beg, (2.05, 1.9, F0 + 1.02)))
inr.append(box("Toonfront", (0.02, 1.9, 0.8), POMPROOD, beg, (1.69, 1.9, F0 + 0.5)))
inr.append(box("Kassa", (0.42, 0.38, 0.22), ZINK, beg, (2.1, 1.25, F0 + 1.16)))
inr.append(box("KassaKop", (0.36, 0.2, 0.16), ZINK, beg, (2.1, 1.35, F0 + 1.33), (0.4, 0, 0)))
for k in range(6):
    inr.append(cyl("toets", 0.022, 0.022, 0.03, EMAILLE, "Z", 6, beg, (1.98 + (k % 3) * 0.08, 1.12 + (k // 3) * 0.07, F0 + 1.28)))
inr.append(box("KassaLade", (0.4, 0.3, 0.07), HOUT, beg, (2.1, 1.25, F0 + 1.01)))
inr.append(cyl("Slinger", 0.02, 0.02, 0.18, IJZER, "X", 6, beg, (2.35, 1.25, F0 + 1.2)))
inr.append(box("Kranten", (0.4, 0.3, 0.06), PAPIER, beg, (2.05, 2.5, F0 + 1.08)))
inr.append(box("Snoeppot", (0.18, 0.18, 0.22), GLAS, beg, (2.05, 2.0, F0 + 1.15)))
inr.append(box("Kruk", (0.3, 0.3, 0.7), HOUT, beg, (2.75, 1.6, F0 + 0.35)))
# sigarettenrek achter de toonbank
inr.append(box("Rekje", (0.25, 1.4, 1.0), HOUT, beg, (XI1 - 0.13, 1.9, F0 + 1.5)))
for k in range(5):
    inr.append(box("pakjes", (0.2, 1.3, 0.08), (BLIK, BLIK2, PAPIER, BORD, GEEL)[k], beg, (XI1 - 0.15, 1.9, F0 + 1.1 + k * 0.18)))
# dubbel rek in het midden, rek langs de westmuur
stelling(inr, beg, -0.6, 2.0, F0, 2.0, 0.42, 1.6, 0.0, 31)
stelling(inr, beg, -0.6, 2.45, F0, 2.0, 0.42, 1.6, math.pi, 32)
stelling(inr, beg, XI0 + 0.25, 1.6, F0, 2.0, 0.45, 2.0, -math.pi / 2, 33)
# koeling tegen de binnenmuur
inr.append(box("Koeling", (1.2, 0.6, 1.9), EMAILLE, beg, (0.9, 3.45, F0 + 0.95)))
inr.append(box("KoelRuit", (1.0, 0.02, 1.4), GLAS, beg, (0.9, 3.14, F0 + 1.05)))
inr.append(box("KoelBord", (1.2, 0.04, 0.25), BORD, beg, (0.9, 3.14, F0 + 1.95)))
for k in range(4):
    for j in range(6):
        inr.append(cyl("Fles", 0.035, 0.03, 0.25, FLES if (k + j) % 2 else BLIK, "Z", 6, beg, (0.5 + j * 0.15, 3.3, F0 + 0.45 + k * 0.38)))
# klok, kalender en een plafondventilator
inr.append(cyl("Klok", 0.18, 0.18, 0.03, EMAILLE, "Y", 16, beg, (-1.5, PY - TI / 2 - 0.02, 2.6)))
inr.append(box("Kalender", (0.4, 0.02, 0.55), PAPIER, beg, (2.6, PY - TI / 2 - 0.02, 1.8)))
inr.append(box("Poster", (0.7, 0.02, 0.5), BORD, beg, (-2.6, YI1 - 0.01, 2.0)))
inr.append(cyl("Ventilator", 0.12, 0.12, 0.15, IJZER, "Z", 8, beg, (0.0, 1.8, TOP - 0.35)))
for k in range(3):
    a = k / 3 * math.tau
    inr.append(box("Wiek", (0.6, 0.12, 0.015), HOUT, beg, (0.35 * math.cos(a), 1.8 + 0.35 * math.sin(a), TOP - 0.42), (0, 0, a)))
# opslag achterin: kisten, vaten, banden, gereedschap
for k, (x, y, s) in enumerate(((2.7, 4.5, 0.6), (2.0, 4.55, 0.5), (2.7, 4.5, 0.45))):
    inr.append(box(f"Kist{k}", (s, s, s), HOUT, beg, (x, y, F0 + s / 2 + (0.6 if k == 2 else 0))))
for k in range(2):
    inr.append(cyl("Vat", 0.29, 0.29, 0.88, ROEST, "Z", 12, beg, (-0.8 + k * 0.65, 4.5, F0 + 0.44)))
inr.append(box("Werkbank", (1.2, 0.5, 0.85), HOUT, beg, (0.9, 4.6, F0 + 0.425)))
inr.append(box("Bankschroef", (0.15, 0.2, 0.15), IJZER, beg, (0.5, 4.5, F0 + 0.92)))
for k in range(3):
    inr.append(box("Jerrycan", (0.18, 0.36, 0.47), GEEL, beg, (-2.9 + k * 0.25, 4.6, F0 + 0.24)))
inrichting = join(inr[0], inr[1:])
inrichting.name = "Inrichting0"

l = bpy.data.lights.new("Licht0", "POINT")
l.energy = 1.5
l.color = (1.0, 0.85, 0.6)
o = link(bpy.data.objects.new("Licht0", l), beg)
o.location = (0.0, 1.8, TOP - 0.7)


# ---------- dak: plat met een opstaande rand en het naambord aan de voorkant ----------
RT = 0.25
ZD = TOP + RT


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


def dak_stuk(name, kapot):
    d = []
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(XS1 - XS0 + 0.2, YS1 - YS0 + 0.2, RT), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, (YS0 + YS1) / 2, TOP + RT / 2))
    plaat = mesh_obj(name, bm, None, dak)
    set_materials(plaat, [BETON, PLAFOND, BETON, BAKSTEEN])
    for p in plaat.data.polygons:
        p.material_index = 0 if p.normal.z > 0.5 else (1 if p.normal.z < -0.5 else 2)
    if kapot:
        cut(plaat, [cutter_jagged((-0.8, 2.2, TOP + RT / 2), 1.6, "Z", 2.0, 188, 13, BAKSTEEN, 0.85),
                    cutter_jagged((2.2, 4.0, TOP + RT / 2), 0.7, "Z", 2.0, 189, 9, BAKSTEEN)])
    for nm, (cx, cy, sx, sy, hh) in (("a", (0, YS1, XS1 - XS0 + 0.2, 0.18, 0.35)), ("w", (XS0, 2.6, 0.18, 5.4, 0.35)),
                                     ("o", (XS1, 2.6, 0.18, 5.4, 0.35))):
        bw = box("rand", (sx, sy, hh), PLEISTER, dak, (cx, cy, ZD + hh / 2))
        set_materials(bw, [PLEISTER, BAKSTEEN])
        if kapot and nm == "o":
            cut(bw, [cutter_box((0.6, 1.4, 1.0), (cx, 3.5, ZD + hh), BAKSTEEN)])
        d.append(bw)
    # naambord boven de voorgevel
    bord = box("bord", (XS1 - XS0 + 0.2, 0.16, 0.95), BAND, dak, (0, YS0 - 0.02, ZD + 0.35))
    if kapot:
        cut(bord, [cutter_jagged((1.6, YS0, ZD + 0.85), 0.8, "Y", 1.0, 191, 9, BAKSTEEN)])
        drop_floating(bord, ZD - 0.2)
    d.append(bord)
    d.append(tekst("Naam", "TOKO  BENSIN", 0.42, LETTER, dak, (-0.9 if kapot else 0.0, YS0 - 0.11, ZD + 0.36)))
    d.append(box("kroon", (XS1 - XS0 + 0.3, 0.22, 0.12), CREME, dak, (0, YS0 - 0.06, TOP + 0.06)))
    # watervat, ontluchting en een radioantenne
    tx, ty = -2.2, 4.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            d.append(box("poot", (0.06, 0.06, 0.6), IJZER, dak, (tx + sx * 0.4, ty + sy * 0.4, ZD + 0.3)))
    if not kapot:
        d.append(cyl("tank", 0.5, 0.5, 0.9, ZINK, "Z", 12, dak, (tx, ty, ZD + 1.05)))
    else:
        d.append(cyl("tank", 0.5, 0.5, 0.9, ZINK, "X", 12, dak, (tx + 1.0, ty - 0.6, ZD + 0.5), rot=(0.2, 0, 0.7)))
    d.append(cyl("pijp", 0.05, 0.05, 1.4, ZINK, "Z", 6, dak, (2.8, 4.6, ZD + 0.7)))
    d.append(cyl("kap", 0.1, 0.02, 0.12, ZINK, "Z", 6, dak, (2.8, 4.6, ZD + 1.45)))
    if kapot:
        for k in range(5):
            d.append(brok("brok", (0.4, 0.35, 0.25), 1700 + k, dak, (-0.8 + rng.uniform(-1.2, 1.2), 2.2 + rng.uniform(-1.2, 1.2), TOP - 0.1),
                          BETON))
    o = join(plaat, d)
    o.name = name
    return o


dak_stuk("Dak_heel", False)
dak_stuk("Dak_kapot", True)


# ---------- puin (sjablonen) ----------
def hoop(name, R, Hh, n, seed, parent=puin, at=(0, 0, 0), extra=True):
    r = np.random.default_rng(seed)
    parts = []
    for k in range(n):
        a = r.uniform(0, math.tau)
        d = R * math.sqrt(r.uniform(0, 1))
        z = Hh * (1 - (d / R) ** 2) * r.uniform(0.5, 1.0)
        s = r.uniform(0.3, 0.75) * (R / 1.4) ** 0.5
        parts.append(brok("b", (s, s * r.uniform(0.6, 1.2), s * 0.6), seed * 100 + k, parent,
                          (at[0] + d * math.cos(a), at[1] + d * math.sin(a), at[2] + z)))
    if extra:
        parts.append(box("balk", (0.12, R * 1.5, 0.12), HOUT, parent, (at[0] + 0.2, at[1], at[2] + Hh * 0.5), (0.3, 0.1, r.uniform(0, 3))))
        parts.append(box("muurstuk", (0.9 * R, 0.25, 0.6 * R), PLEISTER, parent, (at[0] - 0.3 * R, at[1] + 0.2, at[2] + Hh * 0.35),
                         (1.1, 0.2, r.uniform(0, 3))))
    o = join(parts[0], parts[1:])
    o.name = name
    return o


hoop("PuinGroot", 1.5, 0.9, 42, 5)
hoop("PuinKlein", 0.8, 0.5, 16, 6)
for k in range(4):
    brok(f"Brok{k}", (0.25 + 0.1 * k, 0.2 + 0.08 * k, 0.15 + 0.05 * k), 900 + k, puin, (k * 0.8 - 1.2, 8.0, 0.1),
         [PLEISTER, BAKSTEEN, BETON, BAKSTEEN][k])

# ---------- ruïnes: het winkeltje en de luifel storten elk apart in ----------
rr = np.random.default_rng(321)
ru = [hoop("berg", 3.4, 1.6, 55, 31, ruine, (0, 2.6, 0), extra=False)]
for k, (x, y, z, rx, ry, sx, sy) in enumerate(((-0.6, 2.4, 0.9, 0.16, -0.12, 5.0, 3.6), (1.4, 3.2, 1.3, -0.25, 0.2, 3.0, 2.4))):
    ru.append(box("plaat", (sx, sy, 0.22), BETON, ruine, (x, y, z), (rx, ry, rr.uniform(-0.3, 0.3))))
for k, (x, y, w, h, ang) in enumerate(((-2.8, YS0 + 0.12, 1.4, 2.4, 0.0), (XS1 - 0.12, 1.2, 1.8, 1.6, math.pi / 2),
                                       (XS0 + 0.12, 4.2, 1.6, 2.8, math.pi / 2), (1.6, YS1 - 0.12, 2.0, 1.3, 0.0),
                                       (2.6, YS0 + 0.12, 1.0, 1.0, 0.0))):
    st = box("rest", (w, 0.25, h), PLEISTER, ruine, (x, y, h / 2), (rr.uniform(-0.08, 0.08), 0, ang))
    set_materials(st, [PLEISTER, BAKSTEEN])
    cut(st, [cutter_jagged((0, 0, h * 0.5 + 0.5), max(w, 1.0) * 0.6, "Y", 0.6, 4000 + k, 9, BAKSTEEN, 1.2)])
    drop_floating(st)
    ru.append(st)
for k in range(8):
    ru.append(cyl("ijzer", 0.012, 0.012, rr.uniform(0.8, 1.6), ROEST, "Z", 4, ruine,
                  (rr.uniform(-2.5, 2.5), rr.uniform(0.8, 4.4), rr.uniform(1.2, 2.0)), rot=tuple(rr.uniform(-0.9, 0.9, 3))))
ru.append(box("bordrest", (3.0, 0.12, 0.9), BAND, ruine, (0.6, YS0 - 0.5, 0.35), (1.25, 0, -0.15)))
ru.append(box("koelingrest", (1.2, 1.9, 0.6), EMAILLE, ruine, (1.6, 1.0, 0.3), (0, 0.2, 0.4)))
ru.append(box("kassarest", (0.42, 0.38, 0.22), ZINK, ruine, (2.9, 0.5, 0.15), (0.3, 0.5, 0.8)))
ru.append(cyl("tankrest", 0.5, 0.5, 0.9, ZINK, "X", 12, ruine, (-2.4, 4.2, 1.7), rot=(0.3, 0.2, 0.4)))
join(ru[0], ru[1:]).name = "RuineWinkel"

lu = []
# de luifel is in twee stukken op de grond geklapt, de kolommen geknakt, het prijsbord omgevallen
for sx in (-1, 1):
    lu.append(box("luifelhelft", (LX - 0.3, LY1 - LY0 - 0.4, 0.25), BETON, ruine, (sx * (LX * 0.5 + 0.9), (LY0 + LY1) / 2, 1.05),
                  (0.05 * sx, -0.32 * sx, rr.uniform(-0.06, 0.06))))
    lu.append(box("bandrest", (LX - 0.2, 0.08, 0.55), BAND, ruine, (sx * (LX * 0.5 + 0.9), LY0 + 0.1, 1.0), (0.05, -0.32 * sx, 0)))
    for y in KY:
        lu.append(box("kolomstomp", (0.32, 0.32, 1.3), BETON, ruine, (sx * KX, y, 0.65), (rr.uniform(-0.2, 0.2), rr.uniform(-0.2, 0.2), 0)))
        lu.append(box("voet", (0.42, 0.42, 0.5), GEEL, ruine, (sx * KX, y, 0.25)))
lu.append(hoop("brokken", 1.4, 0.6, 18, 41, ruine, (-3.6, -3.0, 0.0), extra=False))
lu.append(hoop("brokken", 1.2, 0.5, 14, 42, ruine, (3.7, -1.6, 0.0), extra=False))
lu.append(cyl("paal", 0.08, 0.08, 5.6, ZINK, "X", 8, ruine, (PX + 2.6, PY_ - 0.3, 0.1), rot=(0, 0, 0.15)))
lu.append(box("bord", (1.5, 0.12, 1.2), BAND, ruine, (PX + 5.4, PY_ - 0.7, 0.2), (1.4, 0, 0.15)))
join(lu[0], lu[1:]).name = "RuineLuifel"

# ---------- afwerking ----------
bpy.context.view_layer.update()
for o in list(scene.objects):
    if o.type == "MESH":
        bad = [p for p in o.data.polygons if p.material_index >= len(o.data.materials)]
        if bad:
            print("MATFOUT", o.name, len(bad), [m.name for m in o.data.materials])
        world_uv(o)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "benzine.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "benzine.blend"))
tris = {}
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        top = o
        while top.parent and top.parent.name not in ("Benzinestation",):
            top = top.parent
        key = "kapot" if o.name.endswith("_kapot") else top.name
        tris[key] = tris.get(key, 0) + len(o.data.loop_triangles)
print("TRIS", tris, "OBJECTEN", len([o for o in scene.objects if o.type == "MESH"]))
