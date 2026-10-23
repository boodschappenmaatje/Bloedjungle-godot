"""Winkel met flat erboven voor de stad achter de brug (Bloedjungle): drie lagen (winkel + twee flats), plat dak met
borstwering, winkelpui met etalages, luifel en uithangbord, bordestrap binnen, balkon, binnenkant met inrichting.
Alles kan kapot, tot het hele gebouw in elkaar zakt: elke muur bestaat uit losse stukken met een hele en een kapotte
versie, beide verdiepingsvloeren en het dak hebben een kapotte versie, en 'Ruine' is het helemaal ingestorte gebouw.
Blender: voorkant aan -Y (wordt +Z in Godot), Z omhoog, 1 eenheid = 1 meter, oorsprong = midden op de grond. 9 x 8 m.
Gebruik: python3 maak_winkel.py <uitmap>  ->  winkel.glb, winkel.blend  (bouwfuncties gedeeld met maak_woonhuis.py)

Hiërarchie (namen die het spel gebruikt):
  Winkel
    Begane       Fundering, TrapA, Inrichting0, muurstukken M0*, binnenmuur P0, DeurVoor, DeurAchter, DeurBinnen0, Buitenlamp
    Verdieping   Vloer1 (Vloer1_heel / Vloer1_kapot), muurstukken M1*, P1, TrapB, DeurBinnen1, Inrichting1, Balkon
    Verdieping2  Vloer2 (heel / kapot), muurstukken M2*, P2, DeurBinnen2, Inrichting2
    Dak          Dak_heel / Dak_kapot (gat, kapotte borstwering, omgevallen watertank)
    Puin         PuinGroot, PuinKlein, Brok0..3 (sjablonen voor sloop)
    Ruine        RuineMesh: het hele gebouw ingestort (verborgen tot het instort)
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
rng = np.random.default_rng(7)

# ---------- maten ----------
W, D = 9.0, 8.0          # buitenmaat winkel
T = 0.25                 # muurdikte
F0 = 0.3                 # vloer begane grond
F1 = 3.8                 # vloer eerste verdieping (bovenkant), winkel is hoger
F2 = 6.8                 # vloer tweede verdieping
TOP = 9.6                # bovenkant muren (onderkant dakvloer)
LEVELS = (F0, F1, F2)
SLAB = 0.25              # dikte verdiepingsvloer
XI0, XI1 = -W / 2 + T, W / 2 - T      # binnenkant
YI0, YI1 = -D / 2 + T, D / 2 - T
# bordestrap langs de westmuur: trap A (winkel -> flat 1) loopt naar achter, trap B (flat 1 -> flat 2) ernaast terug naar voor
SA_X0, SA_X1 = XI0, XI0 + 1.0
SB_X0, SB_X1 = SA_X1, SA_X1 + 1.0
SA_Y0, SA_Y1 = -1.4, 2.6              # trap A: onderste trede bij y = -1,4, boven bij 2,6 (overloop 2,6..3,75)
SB_Y0, SB_Y1 = 2.6, -1.4              # trap B: onder bij 2,6, boven bij -1,4 (overloop voor)
NSTEP = 16
HOLE1 = (SA_X0, SA_X1, -1.0, SA_Y1)   # trapgat in vloer 1 (x0, x1, y0, y1)
HOLE2 = (SB_X0, SB_X1, SB_Y1, 2.2)    # trapgat in vloer 2


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
    """Verschoten mintgroene kalkpleister. v = hoogte / 6,4 m (v = 0 is de grond), u herhaalt elke 3,2 m.
    Vuil en mos onderaan, regenstrepen onder de daklijst en de verdiepingsband, plekken waar de pleister eraf is."""
    v = 1 - np.mgrid[0:size, 0:size][0] / size
    v = v[..., None]
    basis = np.array([0.66, 0.74, 0.70])
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
    return save_img("winkel_pleister", img, size)


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
    return save_img("winkel_binnen", img, size)


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
    return save_img("winkel_baksteen", img, size)


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
    return save_img("winkel_dakpan", img, size)


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
    return save_img("winkel_tegels", img, size)


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
    return save_img("winkel_planken", img, size)


def luik_image(size=256):
    """Groene lamellen van de luiken en deuren: 20 lamellen per 1,6 m, verf bladdert."""
    y = np.mgrid[0:size, 0:size][0] / size
    f = (y * 20) % 1.0
    groen = np.array([0.22, 0.4, 0.3])
    img = groen * (0.6 + 0.5 * f)[..., None] * (0.9 + 0.2 * noise(size, 16, 71)[..., None])
    kaal = sm(noise(size, 8, 72) * 0.5 + noise(size, 32, 73) * 0.5, 0.64, 0.68)
    img = img * (1 - kaal) + np.array([0.42, 0.33, 0.24]) * kaal
    return save_img("winkel_luik", img, size)


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


PLEISTER = mat("Pleister", (0.66, 0.74, 0.70), 0.95, image=pleister_image())
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


def luifel_image(size=256):
    """Gestreept zeil van de luifel: groen en vaal wit, 8 banen per 1,6 m, verkleurd en vuil."""
    x = np.mgrid[0:size, 0:size][1] / size
    baan = (np.floor(x * 4) % 2 == 0)[..., None]
    img = np.where(baan, np.array([0.2, 0.42, 0.3]), np.array([0.84, 0.82, 0.72]))
    img = img * (0.85 + 0.2 * noise(size, 32, 81)[..., None])
    vuil = sm(noise(size, 64, 82), 0.5, 0.85) * 0.35
    img = img * (1 - vuil) + np.array([0.3, 0.27, 0.2]) * vuil
    return save_img("winkel_luifel", img, size)


LUIFEL = mat("Luifel", (0.5, 0.6, 0.5), 0.9, image=luifel_image())
BORD = mat("Bord", (0.62, 0.14, 0.1), 0.6)
LETTER = mat("Letter", (0.95, 0.85, 0.45), 0.5)
DOOS = mat("Doos", (0.62, 0.48, 0.3), 0.9)
BLIK = mat("Blik", (0.75, 0.3, 0.18), 0.4, 0.6)
BLIK2 = mat("Blik2", (0.25, 0.45, 0.7), 0.4, 0.6)
FLES = mat("Fles", (0.3, 0.5, 0.25), 0.1, 0.2)
ROEST = mat("Roest", (0.42, 0.24, 0.14), 0.8, 0.4)
UVS["Luifel"] = (1.6, 1.6)
UVS["Pleister"] = (3.2, 9.6)

# ---------- gebouw ----------
root = empty("Winkel")
beg = empty("Begane", root)
ver = empty("Verdieping", root)
ver2 = empty("Verdieping2", root)
dak = empty("Dak", root)
puin = empty("Puin", root)
ruine = empty("Ruine", root)

WIN_B, WIN_H = 0.95, 1.45           # ramen van de flat: borstwering en hoogte
DOOR_H = 2.4


def raam(cx, w=1.0, verd=1):
    return (cx, w, WIN_B, WIN_H, "raam")


def gevel(prefix, parent, side, verd, segs):
    """side: 'V' voor (-y), 'A' achter (+y), 'W' west (-x), 'O' oost (+x). segs: lijst (begin, eind, [openingen in gebouwcoördinaten])."""
    z0 = LEVELS[verd]
    H = (LEVELS[verd + 1] if verd < 2 else TOP) - z0
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
        out.append(wall_segment(f"{prefix}{side}{i}", parent, center, angle, L, H, z0, loc, ends=ends,
                                band=(verd < 2), cornice=(verd == 2),
                                seed=ord(side) * 31 + i * 7 + 100 * verd + 500))
    return out


SIDE = [(-D / 2 + T, -1.33), (-1.33, 1.33), (1.33, D / 2 - T)]
FRONT = [(-4.5, -1.5), (-1.5, 1.5), (1.5, 4.5)]

# begane grond: winkelpui met twee etalages en de winkeldeur, achterdeur naar de steeg
voor0 = gevel("M0", beg, "V", 0, [(-4.5, -1.5, [(-3.0, 2.3, 0.7, 2.0, "etalage")]),
                                  (-1.5, 1.5, [(0.0, 1.4, 0.0, F0 + DOOR_H, "deur")]),
                                  (1.5, 4.5, [(3.0, 2.3, 0.7, 2.0, "etalage")])])
gevel("M0", beg, "A", 0, [(-4.5, -1.5, [(-2.2, 1.0, 0.0, F0 + 2.2, "deur")]), (-1.5, 1.5, []),
                          (1.5, 4.5, [(3.0, 1.0, F0 + 1.2, 1.0, "raam")])])
gevel("M0", beg, "W", 0, [(SIDE[0][0], SIDE[0][1], []), (SIDE[1][0], SIDE[1][1], []), (SIDE[2][0], SIDE[2][1], [])])
gevel("M0", beg, "O", 0, [(SIDE[0][0], SIDE[0][1], [(-2.67, 1.2, F0 + 1.0, 1.3, "raam")]), (SIDE[1][0], SIDE[1][1], []),
                          (SIDE[2][0], SIDE[2][1], [(2.67, 1.0, F0 + 1.2, 1.0, "raam")])])
# flat 1: balkon in het midden van de voorgevel
gevel("M1", ver, "V", 1, [(-4.5, -1.5, [raam(-3.0)]), (-1.5, 1.5, [(0.0, 1.1, 0.0, 2.3, "balkon")]), (1.5, 4.5, [raam(3.0)])])
gevel("M1", ver, "A", 1, [(-4.5, -1.5, [raam(-3.4, 0.8)]), (-1.5, 1.5, [raam(0.0)]), (1.5, 4.5, [raam(3.0)])])
gevel("M1", ver, "W", 1, [(SIDE[0][0], SIDE[0][1], [raam(-2.67, 0.8)]), (SIDE[1][0], SIDE[1][1], []), (SIDE[2][0], SIDE[2][1], [])])
gevel("M1", ver, "O", 1, [(SIDE[0][0], SIDE[0][1], [raam(-2.67)]), (SIDE[1][0], SIDE[1][1], [raam(0.0, 0.9)]),
                          (SIDE[2][0], SIDE[2][1], [raam(2.67)])])
# flat 2
gevel("M2", ver2, "V", 2, [(-4.5, -1.5, [raam(-3.0)]), (-1.5, 1.5, [raam(0.0, 1.2)]), (1.5, 4.5, [raam(3.0)])])
gevel("M2", ver2, "A", 2, [(-4.5, -1.5, [raam(-3.0, 0.8)]), (-1.5, 1.5, [raam(0.0)]), (1.5, 4.5, [raam(3.0)])])
gevel("M2", ver2, "W", 2, [(SIDE[0][0], SIDE[0][1], [raam(-2.67, 0.8)]), (SIDE[1][0], SIDE[1][1], []),
                           (SIDE[2][0], SIDE[2][1], [raam(2.67, 0.8)])])
gevel("M2", ver2, "O", 2, [(SIDE[0][0], SIDE[0][1], [raam(-2.67)]), (SIDE[1][0], SIDE[1][1], [raam(0.0, 0.9)]),
                           (SIDE[2][0], SIDE[2][1], [raam(2.67)])])

# luifel en uithangbord boven de winkelpui (horen bij de muurstukken: ze vallen mee als de gevel kapot gaat)
for seg, woord, (a, b) in zip(voor0, ("KOPI", "TOKO", "RIJST"), FRONT):
    L = b - a
    yo = -T / 2
    det = []
    dz = 1.35
    tilt = math.atan2(0.35, dz)
    det.append(box("luifel", (L, dz / math.cos(tilt), 0.04), LUIFEL, seg, (0, yo - dz / 2, 2.95 - 0.175), (tilt, 0, 0)))
    det.append(box("valrand", (L, 0.02, 0.22), LUIFEL, seg, (0, yo - dz, 2.6 - 0.11)))
    for sx in (-1, 1):   # schoren onder de luifel
        det.append(box("schoor", (0.04, 0.04, 1.0), IJZER, seg, (sx * (L / 2 - 0.2), yo - 0.6, 2.45), (-0.95, 0, 0)))
    det.append(box("bord", (L - 0.1, 0.08, 0.62), BORD, seg, (0, yo - 0.05, 3.32)))
    det.append(box("bordrand", (L - 0.02, 0.1, 0.05), LETTER, seg, (0, yo - 0.05, 3.62)))
    det.append(box("bordrand", (L - 0.02, 0.1, 0.05), LETTER, seg, (0, yo - 0.05, 3.02)))
    det.append(tekst("letters", woord, 0.42, LETTER, seg, (0, yo - 0.1, 3.32)))
    add_to_heel(seg, det)

# binnenmuren: P0 (magazijn achter de winkel), P1 en P2 (voor- en achterkamer van de flats)
TI = 0.14
wall_segment("P0", beg, ((-1.0 + XI1) / 2, 1.4), 0.0, XI1 + 1.0, F1 - SLAB - F0, F0,
             [(1.5 - (-1.0 + XI1) / 2, 1.1, 0.0, 2.2, "deur")], inner=BINNEN, outer=BINNEN, thick=TI, seed=11)
for nm, par, z0, z1 in (("P1", ver, F1, F2 - SLAB), ("P2", ver2, F2, TOP)):
    x0 = SB_X1 + 0.1
    wall_segment(nm, par, ((x0 + XI1) / 2, 0.3), 0.0, XI1 - x0, z1 - z0, z0,
                 [(1.2 - (x0 + XI1) / 2, 1.0, 0.0, 2.15, "deur")], inner=BINNEN, outer=BINNEN, thick=TI, seed=12 + int(z0))

# fundering, vloer en stoep
fund = []
fund.append(box("Fund", (W - 0.02, D - 0.02, F0), BETON, beg, (0, 0, F0 / 2)))
fund.append(box("Vloer0", (XI1 - XI0, YI1 - YI0, 0.02), TEGELS, beg, (0, 0, F0 + 0.01)))
fund.append(box("Stoep", (W + 0.4, 1.6, 0.18), BETON, beg, (0, -D / 2 - 0.8, 0.09)))
fund.append(box("Stoeprand", (W + 0.4, 0.15, 0.22), BETON, beg, (0, -D / 2 - 1.62, 0.11)))
fund.append(box("StoepA", (1.4, 0.6, 0.16), BETON, beg, (-2.2, D / 2 + 0.3, 0.08)))
fundering = join(fund[0], fund[1:])
fundering.name = "Fundering"


# ---------- trappen ----------
def trap(name, parent, x0, x1, y0, y1, z0, z1, wang_x, rail_x):
    """Massieve trap van (y0, z0) naar (y1, z1); wang (pleister) en leuning aan de open kant."""
    tr = []
    n = NSTEP
    rise = (z1 - z0) / n
    sd = (y1 - y0) / n
    for k in range(n):
        zt = z0 + rise * (k + 1)
        ya = y0 + k * sd
        tr.append(box("trede", (x1 - x0, abs(sd), zt - z0), HOUTLICHT, parent, ((x0 + x1) / 2, ya + sd / 2, z0 + (zt - z0) / 2)))
        tr.append(box("neus", (x1 - x0, 0.03, 0.03), HOUT, parent, ((x0 + x1) / 2, ya + 0.01 * (1 if sd > 0 else -1), zt - 0.015)))
    bm = bmesh.new()
    vs = [bm.verts.new((wang_x, y, z)) for (y, z) in ((y0, z0), (y1, z1), (y1, z0))]
    bm.faces.new(vs)
    tr.append(mesh_obj("wang", bm, BINNEN, parent))
    L = math.hypot(y1 - y0, z1 - z0)
    pitch = math.atan2(z1 - z0, y1 - y0)
    tr.append(box("leuning", (0.06, L, 0.06), HOUT, parent, (rail_x, (y0 + y1) / 2, (z0 + z1) / 2 + 0.95), (pitch, 0, 0)))
    for k in range(0, n, 3):
        yk = y0 + (k + 0.4) * sd
        zk = z0 + rise * (k + 1)
        tr.append(box("spijl", (0.05, 0.05, 0.95), HOUT, parent, (rail_x, yk, zk + 0.475)))
    o = join(tr[0], tr[1:])
    o.name = name
    return o


trap("TrapA", beg, SA_X0, SA_X1, SA_Y0, SA_Y1, F0, F1, SA_X1 + 0.005, SA_X1 - 0.05)
trap("TrapB", ver, SB_X0, SB_X1, SB_Y0, SB_Y1, F1, F2, SB_X1 + 0.005, SB_X1 - 0.05)


# ---------- verdiepingsvloeren: heel met trapgat, kapot gebroken met de oosthelft naar beneden ----------
def vloer(name, parent, ztop, hole, hinge_deg, seed):
    node = empty(name, parent)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(XI1 - XI0, YI1 - YI0, SLAB), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, ztop - SLAB / 2))
    v = mesh_obj(name + "_heel", bm, None, node)
    set_materials(v, [PLANKEN, PLAFOND, BETON, BAKSTEEN])
    hx0, hx1, hy0, hy1 = hole
    cut(v, [cutter_box((hx1 - hx0 + 0.02, hy1 - hy0, 1.0), ((hx0 + hx1) / 2, (hy0 + hy1) / 2, ztop), BETON)])
    for p in v.data.polygons:
        p.material_index = 0 if p.normal.z > 0.5 else (1 if p.normal.z < -0.5 else 2)
    vk = v.copy()
    vk.data = v.data.copy()
    vk.name = vk.data.name = name + "_kapot"
    link(vk, node)
    bm = bmesh.new()
    r = np.random.default_rng(seed)
    ys = np.linspace(YI0 - 0.3, YI1 + 0.3, 12)
    left = [bm.verts.new((0.35 + r.uniform(-0.25, 0.1), y, ztop - 1)) for y in ys]
    right = [bm.verts.new((0.65 + r.uniform(-0.1, 0.25), y, ztop - 1)) for y in ys]
    f = bm.faces.new(left + list(reversed(right)))
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)], vec=(0, 0, 2))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(BETON)
    cut(vk, [bpy.data.objects.new("cutter", me)])
    bm = bmesh.new()
    bm.from_mesh(vk.data)
    oost = [q for q in bm.verts if q.co.x > 0.5]
    west = [q for q in bm.verts if q.co.x <= 0.5]
    bmesh.ops.rotate(bm, verts=oost, cent=Vector((XI1, 0, ztop - SLAB)), matrix=Matrix.Rotation(math.radians(-hinge_deg), 3, "Y"))
    bmesh.ops.rotate(bm, verts=west, cent=Vector((XI0, 0, ztop - SLAB)), matrix=Matrix.Rotation(math.radians(hinge_deg * 0.4), 3, "Y"))
    bm.to_mesh(vk.data)
    bm.free()
    return node


vloer("Vloer1", ver, F1, HOLE1, 34, 77)
vloer("Vloer2", ver2, F2, HOLE2, 30, 78)


# reling rond de trapgaten
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


inr1, inr2 = [], []
reling(inr1, ver, F1, [((SA_X0, HOLE1[2] - 0.03), (SA_X1, HOLE1[2] - 0.03))])
reling(inr2, ver2, F2, [((SB_X1 + 0.03, HOLE2[2]), (SB_X1 + 0.03, HOLE2[3])), ((SB_X0, HOLE2[3] + 0.03), (SB_X1 + 0.03, HOLE2[3] + 0.03)),
                        ((SB_X0 - 0.03, HOLE2[2]), (SB_X0 - 0.03, HOLE2[3]))])
# muurtje tussen de twee trappen (boven vloer 1)
inr1.append(box("Trapmuur", (0.1, SB_Y0 - SB_Y1, F2 - F1 - SLAB), BINNEN, ver, (SB_X0 - 0.02, (SB_Y0 + SB_Y1) / 2, (F1 + F2 - SLAB) / 2)))


# ---------- deuren (knooppunt = scharnier) ----------
def deur(name, parent, hinge, width, height, angle, mat_paneel, sx=1, glas=False):
    h = empty(name, parent, hinge, (0, 0, angle))
    parts = [box(name + "Blad", (width - 0.04, 0.05, height - 0.02), mat_paneel, h, (sx * width / 2, 0, height / 2))]
    if glas:
        parts.append(box("ruit", (width - 0.3, 0.06, height * 0.55), GLAS, h, (sx * width / 2, 0, height * 0.6)))
        parts.append(box("bel", (0.1, 0.1, 0.1), ZINK, h, (sx * 0.1, 0.0, height + 0.1)))
    else:
        for (pz, ph) in ((0.25, 0.75), (1.15, 0.85)):
            parts.append(box("paneel", (width - 0.3, 0.07, ph), HOUT, h, (sx * width / 2, 0, pz + ph / 2)))
    parts.append(cyl("knop", 0.035, 0.035, 0.14, IJZER, "Y", 8, h, (sx * (width - 0.12), 0, 1.05)))
    join(parts[0], parts[1:])
    parts[0].name = name + "Blad"
    return h


deur("DeurVoor", beg, (-0.67, -D / 2 + T / 2, F0), 1.34, DOOR_H, 0.0, LUIK, glas=True)
deur("DeurAchter", beg, (-2.2 + 0.47, D / 2 - T / 2, F0), 0.94, 2.2, math.pi, HOUTLICHT)
deur("DeurBinnen0", beg, (1.5 - 0.52, 1.4, F0), 1.04, 2.2, 0.0, HOUTLICHT)
deur("DeurBinnen1", ver, (1.2 - 0.47, 0.3, F1), 0.94, 2.15, 0.0, HOUTLICHT)
deur("DeurBinnen2", ver2, (1.2 - 0.47, 0.3, F2), 0.94, 2.15, 0.0, HOUTLICHT)

# ---------- balkon flat 1 (x -1,1..1,1) ----------
bk = []
BY0 = -D / 2 - 0.9
bk.append(box("BalkonVloer", (2.2, 0.9, 0.14), BETON, ver, (0.0, -D / 2 - 0.45, F1 - 0.07)))
for sx in (-1, 1):
    bk.append(box("console", (0.12, 0.6, 0.3), BETON, ver, (sx * 0.9, -D / 2 - 0.3, F1 - 0.29)))
bk.append(box("hek", (2.2, 0.05, 0.05), IJZER, ver, (0.0, BY0 + 0.03, F1 + 1.0)))
for sx in (-1, 1):
    bk.append(box("hek", (0.05, 0.9, 0.05), IJZER, ver, (sx * 1.08, -D / 2 - 0.45, F1 + 1.0)))
for k in range(12):
    bk.append(box("spijl", (0.025, 0.025, 1.0), IJZER, ver, (-1.05 + k * (2.1 / 11), BY0 + 0.03, F1 + 0.5)))
for k in range(1, 5):
    for sx in (-1, 1):
        bk.append(box("spijl", (0.025, 0.025, 1.0), IJZER, ver, (sx * 1.08, BY0 + k * 0.18, F1 + 0.5)))
for k, x in enumerate((-0.7, 0.6)):
    bk.append(cyl("pot", 0.16, 0.12, 0.28, BAKSTEEN, "Z", 10, ver, (x, BY0 + 0.3, F1 + 0.14)))
    for j in range(5):
        a = j / 5 * math.tau + k
        bk.append(box("blad", (0.06, 0.35, 0.02), BLAD, ver, (x + 0.12 * math.cos(a), BY0 + 0.3 + 0.12 * math.sin(a), F1 + 0.42),
                      (0.7, 0, a + math.pi / 2)))
# was over het hek
bk.append(box("was", (0.6, 0.02, 0.5), STOF2, ver, (0.3, BY0 + 0.01, F1 + 0.78)))
join(bk[0], bk[1:]).name = "Balkon"

# lamp boven de winkeldeur
bl = [box("LampVoet", (0.14, 0.12, 0.2), IJZER, beg, (1.0, -D / 2 - 0.06, 2.85)),
      cyl("LampKap", 0.12, 0.06, 0.12, IJZER, "Z", 8, beg, (1.0, -D / 2 - 0.2, 2.62)),
      cyl("LampBol", 0.07, 0.07, 0.14, LAMPGLAS, "Z", 8, beg, (1.0, -D / 2 - 0.2, 2.5))]
join(bl[0], bl[1:]).name = "Buitenlamp"
lp = bpy.data.lights.new("BuitenLicht", "POINT")
lp.energy = 2.0
lp.color = (1.0, 0.78, 0.45)
o = link(bpy.data.objects.new("BuitenLicht", lp), beg)
o.location = (1.0, -D / 2 - 0.35, 2.4)


# ---------- inrichting ----------
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


def bed(lst, parent, B, x, y, w, l, rot=0.0):
    lst.append(box("bedframe", (w, l, 0.35), HOUT, parent, (x, y, B + 0.175), (0, 0, rot)))
    lst.append(box("matras", (w - 0.08, l - 0.1, 0.16), MATRAS, parent, (x, y, B + 0.43), (0, 0, rot)))
    dy = (l / 2 - 0.3)
    c, s = math.cos(rot), math.sin(rot)
    lst.append(box("kussen", (w - 0.3, 0.35, 0.1), STOF3, parent, (x - s * dy, y + c * dy, B + 0.56), (0, 0, rot)))
    lst.append(box("deken", (w - 0.04, l * 0.55, 0.06), STOF, parent, (x + s * l * 0.18, y - c * l * 0.18, B + 0.53), (0, 0, rot)))


def stelling(lst, parent, x, y, z, w, d, h, rot, seed):
    """Winkelrek met planken vol dozen, blikken en flessen."""
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
            else:
                m = (BLIK, BLIK2, FLES)[soort - 1]
                hh = 0.28 if m is FLES else 0.12
                for j in range(3):
                    lst.append(cyl("blik", 0.045, 0.045 if m is not FLES else 0.025, hh, m, "Z", 6, parent,
                                   (*p(xx + 0.05, -d / 3 + j * d / 3), zk + 0.015 + hh / 2)))
                xx += 0.12


inr0 = []
# toonbank met kassa, weegschaal en snoeppotten; achter de toonbank rekken langs de oostmuur
inr0.append(box("Toonbank", (0.7, 3.0, 1.0), HOUT, beg, (1.9, -0.9, F0 + 0.5)))
inr0.append(box("Toonblad", (0.8, 3.1, 0.05), HOUTLICHT, beg, (1.9, -0.9, F0 + 1.02)))
inr0.append(box("Kassa", (0.4, 0.35, 0.25), DONKER, beg, (1.9, -0.1, F0 + 1.17)))
inr0.append(box("Lade", (0.38, 0.3, 0.08), ZINK, beg, (1.75, -0.1, F0 + 1.08)))
inr0.append(box("Weegschaal", (0.3, 0.25, 0.08), ZINK, beg, (1.9, -1.6, F0 + 1.09)))
inr0.append(cyl("Schaal", 0.15, 0.17, 0.05, ZINK, "Z", 10, beg, (1.9, -1.6, F0 + 1.22)))
for k in range(3):
    inr0.append(cyl("Pot", 0.1, 0.1, 0.24, GLAS, "Z", 8, beg, (1.85, -2.2 + k * 0.25, F0 + 1.17)))
stelling(inr0, beg, XI1 - 0.25, -1.9, F0, 1.6, 0.4, 2.0, math.pi / 2, 1)
stelling(inr0, beg, XI1 - 0.25, 0.1, F0, 1.8, 0.4, 2.0, math.pi / 2, 2)
# midden in de winkel een vrijstaand rek en zakken rijst
stelling(inr0, beg, -0.6, -0.4, F0, 1.8, 0.45, 1.6, 0.0, 3)
for k in range(5):
    inr0.append(box("Rijstzak", (0.5, 0.35, 0.55), STOF3, beg, (-2.2 + (k % 3) * 0.55, -2.9 + (k // 3) * 0.45, F0 + 0.28 + (0.0 if k < 3 else 0.0))))
# koelkast met drank achter de etalage
inr0.append(box("Koeling", (0.7, 0.6, 1.8), EMAILLE, beg, (0.9, -3.3, F0 + 0.9)))
inr0.append(box("KoelRuit", (0.55, 0.02, 1.3), GLAS, beg, (0.9, -3.62 + 0.62, F0 + 1.0)))
for k in range(4):
    for j in range(4):
        inr0.append(cyl("Fles", 0.035, 0.03, 0.25, FLES if (k + j) % 2 else BLIK, "Z", 6, beg, (0.7 + j * 0.13, -3.05, F0 + 0.4 + k * 0.4)))
# kratten bier bij de deur, plafondventilator
for k in range(3):
    inr0.append(box("Krat", (0.45, 0.32, 0.3), BLIK2 if k % 2 else ROEST, beg, (-1.1, -3.3, F0 + 0.15 + k * 0.3)))
inr0.append(cyl("Ventilator", 0.12, 0.12, 0.15, IJZER, "Z", 8, beg, (0.2, -1.0, F1 - SLAB - 0.35)))
inr0.append(cyl("VentStang", 0.02, 0.02, 0.3, IJZER, "Z", 4, beg, (0.2, -1.0, F1 - SLAB - 0.15)))
for k in range(3):
    a = k / 3 * math.tau
    inr0.append(box("Wiek", (0.6, 0.12, 0.015), HOUT, beg, (0.2 + 0.35 * math.cos(a), -1.0 + 0.35 * math.sin(a), F1 - SLAB - 0.42), (0, 0, a)))
# magazijn achter: kisten, vaten en zakken (buit)
for k, (x, y, s) in enumerate(((3.6, 3.2, 0.6), (2.9, 3.3, 0.5), (3.6, 2.5, 0.5), (3.55, 3.2, 0.45))):
    inr0.append(box(f"Kist{k}", (s, s, s), HOUT, beg, (x, y, F0 + s / 2 + (0.6 if k == 3 else 0))))
for k in range(2):
    inr0.append(cyl("Vat", 0.3, 0.3, 0.9, ROEST, "Z", 10, beg, (0.0 + k * 0.65, 3.3, F0 + 0.45)))
for k in range(4):
    inr0.append(box("Zak", (0.55, 0.38, 0.32), STOF3, beg, (1.2 + (k % 2) * 0.6, 2.1 + (k // 2) * 0.1, F0 + 0.16 + (k // 2) * 0.3)))
inrichting0 = join(inr0[0], inr0[1:])
inrichting0.name = "Inrichting0"

# flat 1: voorkamer (bank, tafel, radio), achterkamer (bed, kast, keukentje)
B = F1
inr1.append(box("Kleed1", (2.0, 1.4, 0.01), STOF, ver, (1.4, -1.9, B + 0.01)))
inr1.append(box("BankZit", (0.8, 1.9, 0.42), STOF2, ver, (XI1 - 0.45, -1.8, B + 0.21)))
inr1.append(box("BankRug", (0.22, 1.9, 0.5), STOF2, ver, (XI1 - 0.12, -1.8, B + 0.6)))
tafel(inr1, ver, 1.6, -1.9, B, 1.0, 0.7, 0.45, HOUTLICHT)
tafel(inr1, ver, -1.0, -2.6, B, 1.2, 0.8)
stoel(inr1, ver, -1.4, -2.0, B, 0.0)
stoel(inr1, ver, -0.6, -2.0, B, 0.0)
inr1.append(box("Radio", (0.4, 0.2, 0.25), HOUTLICHT, ver, (-1.0, -2.8, B + 0.88)))
bed(inr1, ver, B, 2.9, 2.4, 1.4, 2.0, 0.0)
inr1.append(box("Kast", (1.0, 0.55, 2.0), HOUT, ver, (0.6, 3.4, B + 1.0)))
inr1.append(box("Aanrecht", (1.4, 0.6, 0.86), HOUTLICHT, ver, (-0.9, 3.4, B + 0.43)))
inr1.append(box("Werkblad", (1.45, 0.64, 0.05), BETON, ver, (-0.9, 3.38, B + 0.885)))
inr1.append(cyl("Pan", 0.14, 0.14, 0.12, ZINK, "Z", 10, ver, (-0.6, 3.35, B + 0.98)))
inr1.append(cyl("Lampkap1", 0.22, 0.08, 0.12, EMAILLE, "Z", 10, ver, (0.8, -1.5, F2 - SLAB - 0.4)))
inrichting1 = join(inr1[0], inr1[1:])
inrichting1.name = "Inrichting1"

# flat 2: voorkamer met matras op de grond en zandzakken bij het raam (uitkijkpost), achterkamer met bedden en was
B = F2
inr2.append(box("Matras2", (0.9, 1.9, 0.18), MATRAS, ver2, (2.6, -2.2, B + 0.09)))
inr2.append(box("Deken2", (0.86, 1.0, 0.04), STOF2, ver2, (2.6, -2.5, B + 0.2)))
tafel(inr2, ver2, 0.2, -1.6, B, 1.0, 0.7)
stoel(inr2, ver2, 0.2, -1.0, B, 0.0)
for k in range(4):
    inr2.append(box("Zandzak", (0.6, 0.32, 0.22), STOF3, ver2, (-0.3 + (k % 2) * 0.62, -3.35, B + 0.11 + (k // 2) * 0.22)))
for k, (x, y, s) in enumerate(((3.7, -0.4, 0.5), (3.7, 0.05, 0.4))):
    inr2.append(box(f"Munitiekist{k}", (s * 1.4, s, s * 0.7), HOUT, ver2, (x, y, B + s * 0.35)))
bed(inr2, ver2, B, 0.3, 2.6, 0.9, 1.9, 0.0)
bed(inr2, ver2, B, 2.6, 2.6, 0.9, 1.9, 0.0)
inr2.append(cyl("waslijn", 0.008, 0.008, 3.0, STOF3, "X", 4, ver2, (1.4, 1.3, B + 1.9)))
for k, (x, m) in enumerate(((0.4, STOF3), (1.0, STOF), (1.7, STOF2), (2.3, STOF3))):
    inr2.append(box("was", (0.45, 0.02, 0.55), m, ver2, (x, 1.3, B + 1.6)))
inrichting2 = join(inr2[0], inr2[1:])
inrichting2.name = "Inrichting2"

for nm, par, pos in (("Licht0", beg, (0.2, -1.0, F1 - SLAB - 0.7)), ("Licht1", ver, (0.8, -1.5, F2 - SLAB - 0.6)),
                     ("Licht2", ver2, (1.0, -1.0, TOP - 0.6))):
    l = bpy.data.lights.new(nm, "POINT")
    l.energy = 1.5
    l.color = (1.0, 0.85, 0.6)
    o = link(bpy.data.objects.new(nm, l), par)
    o.location = pos

# ---------- plat dak met borstwering, watertank en antenne ----------
RT = 0.3            # dikte dakvloer
PAR_H = 0.8         # borstwering boven de dakvloer
ZD = TOP + RT       # bovenkant dakvloer


def dak_stuk(name, kapot):
    d = []
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(W + 0.1, D + 0.1, RT), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, TOP + RT / 2))
    plaat = mesh_obj(name, bm, None, dak)
    set_materials(plaat, [BETON, PLAFOND, BETON, BAKSTEEN])
    for p in plaat.data.polygons:
        p.material_index = 0 if p.normal.z > 0.5 else (1 if p.normal.z < -0.5 else 2)
    if kapot:
        cut(plaat, [cutter_jagged((-0.6, -0.8, TOP + RT / 2), 2.0, "Z", 2.0, 88, 13, BAKSTEEN, 0.85),
                    cutter_jagged((2.8, 2.4, TOP + RT / 2), 0.8, "Z", 2.0, 89, 9, BAKSTEEN)])
    # borstwering: pleister, met kapotte stukken weg in de kapotte versie
    stukken = [("v", (0, -D / 2 + 0.1, W + 0.1, 0.2)), ("a", (0, D / 2 - 0.1, W + 0.1, 0.2)),
               ("w", (-W / 2 + 0.1, 0, 0.2, D - 0.3)), ("o", (W / 2 - 0.1, 0, 0.2, D - 0.3))]
    for nm, (cx, cy, sx, sy) in stukken:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=(sx, sy, PAR_H), verts=bm.verts)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(cx, cy, ZD + PAR_H / 2))
        bw = mesh_obj("bw", bm, None, dak)
        set_materials(bw, [PLEISTER, BAKSTEEN])
        if kapot and nm == "v":
            cut(bw, [cutter_jagged((-1.0, cy, ZD + PAR_H), 1.1, "Y", 1.0, 91, 9, BAKSTEEN)])
        elif kapot and nm == "o":
            cut(bw, [cutter_box((0.6, 1.6, 1.0), (cx, 1.2, ZD + PAR_H), BAKSTEEN)])
        d.append(bw)
        d.append(box("deklijst", (sx + 0.08, sy + 0.08, 0.06), BETON, dak, (cx, cy, ZD + PAR_H + 0.03)))
    # kroonlijst rond de dakvloer
    d.append(box("kroon", (W + 0.3, 0.2, 0.15), KOZIJN, dak, (0, -D / 2 - 0.05, TOP + 0.08)))
    # watertank op een stalen onderstel
    tx, ty = 2.6, 2.3
    for sx in (-1, 1):
        for sy in (-1, 1):
            d.append(box("poot", (0.08, 0.08, 1.2), IJZER, dak, (tx + sx * 0.6, ty + sy * 0.6, ZD + 0.6)))
    d.append(box("bord", (1.4, 1.4, 0.06), IJZER, dak, (tx, ty, ZD + 1.2)))
    if not kapot:
        d.append(cyl("tank", 0.7, 0.7, 1.3, ZINK, "Z", 14, dak, (tx, ty, ZD + 1.88)))
        d.append(cyl("tankdeksel", 0.72, 0.3, 0.2, ZINK, "Z", 14, dak, (tx, ty, ZD + 2.63)))
    else:
        tk = cyl("tank", 0.7, 0.7, 1.3, ZINK, "X", 14, dak, (tx - 1.2, ty - 0.4, ZD + 0.7), rot=(0.2, 0, 0.6))
        d.append(tk)
    d.append(cyl("pijp", 0.04, 0.04, 1.6, ZINK, "Z", 6, dak, (tx - 0.6, ty + 0.6, ZD + 0.4)))
    # dakluik, airco, antenne
    d.append(box("dakluik", (0.9, 0.9, 0.35), BETON, dak, (-3.0, 1.6, ZD + 0.17)))
    d.append(box("luikdeur", (0.85, 0.85, 0.05), IJZER, dak, (-3.0, 1.6, ZD + 0.37)))
    d.append(box("airco", (0.8, 0.5, 0.6), EMAILLE, dak, (0.4, 3.2, ZD + 0.3)))
    d.append(cyl("rooster", 0.2, 0.2, 0.02, DONKER, "Y", 10, dak, (0.4, 2.94, ZD + 0.32)))
    d.append(cyl("antenne", 0.02, 0.02, 2.4, IJZER, "Z", 5, dak, (-1.5, 2.8, ZD + 1.2)))
    for k in range(3):
        d.append(box("antdwars", (0.04, 1.0 - 0.2 * k, 0.03), IJZER, dak, (-1.5, 2.8, ZD + 1.6 + 0.3 * k)))
    if kapot:
        for k in range(6):
            d.append(brok("brok", (0.4, 0.35, 0.25), 700 + k, dak, (-0.6 + rng.uniform(-1.5, 1.5), -0.8 + rng.uniform(-1.5, 1.5), TOP - 0.1),
                          BETON))
    o = join(plaat, d)
    o.name = name
    return o


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
    brok(f"Brok{k}", (0.25 + 0.1 * k, 0.2 + 0.08 * k, 0.15 + 0.05 * k), 900 + k, puin, (k * 0.8 - 1.2, 3.0, 0.1),
         [PLEISTER, BAKSTEEN, BETON, BAKSTEEN][k])

# ---------- ruïne: het hele gebouw ingestort (verdiepingen als pannenkoeken op elkaar, muurresten, puin) ----------
rr = np.random.default_rng(321)
ru = []
# grote puinberg over het hele grondvlak
ru.append(hoop("berg", 4.6, 2.2, 70, 31, ruine, (0, 0, 0), extra=False))
# schuin opgestapelde vloerplaten
for k, (x, y, z, rx, ry, sx, sy) in enumerate(((-0.5, 0.3, 1.0, 0.18, -0.12, 6.5, 5.5), (0.8, -0.6, 1.7, -0.22, 0.15, 5.0, 4.6),
                                               (-1.2, 1.0, 2.3, 0.3, 0.25, 3.6, 3.2), (2.6, 1.8, 0.9, 0.05, -0.45, 3.0, 3.0))):
    pl = box("plaat", (sx, sy, 0.25), PLANKEN if k % 2 else BETON, ruine, (x, y, z), (rx, ry, rr.uniform(-0.3, 0.3)))
    ru.append(pl)
# muurresten op de hoeken en langs de gevels, met pleister buiten
for k, (x, y, w, h, ang) in enumerate(((-3.8, -3.85, 1.5, 3.4, 0.0), (-4.35, -2.6, 1.8, 2.6, math.pi / 2), (4.0, -3.85, 1.2, 1.9, 0.0),
                                       (4.35, 1.8, 2.6, 4.2, math.pi / 2), (-4.35, 3.0, 1.6, 1.4, math.pi / 2), (1.2, 3.85, 2.2, 1.2, 0.0),
                                       (-2.0, 3.85, 1.4, 2.8, 0.0), (0.4, -3.85, 1.0, 1.0, 0.0))):
    st = box("rest", (w, 0.25, h), PLEISTER, ruine, (x, y, h / 2), (rr.uniform(-0.08, 0.08), 0, ang))
    set_materials(st, [PLEISTER, BAKSTEEN])
    cut(st, [cutter_jagged((0, 0, h * 0.5 + 0.5), max(w, 1.0) * 0.6, "Y", 0.6, 4000 + k, 9, BAKSTEEN, 1.2)])
    drop_floating(st)
    ru.append(st)
# balken, betonijzer, de luifel en het bord liggen erbovenop
for k in range(7):
    ru.append(box("balk", (0.12, rr.uniform(1.5, 3.2), 0.14), HOUT, ruine,
                  (rr.uniform(-3.5, 3.5), rr.uniform(-3, 3), rr.uniform(1.2, 2.6)), tuple(rr.uniform(-0.6, 0.6, 3))))
for k in range(10):
    ru.append(cyl("ijzer", 0.012, 0.012, rr.uniform(0.8, 1.8), ROEST, "Z", 4, ruine,
                  (rr.uniform(-3, 3), rr.uniform(-3, 3), rr.uniform(1.8, 2.8)), rot=tuple(rr.uniform(-0.9, 0.9, 3))))
ru.append(box("luifelrest", (3.0, 1.3, 0.04), LUIFEL, ruine, (-2.0, -4.6, 0.5), (0.5, 0.1, 0.1)))
ru.append(box("bordrest", (2.8, 0.08, 0.62), BORD, ruine, (1.8, -4.4, 0.35), (1.2, 0, -0.2)))
ru.append(cyl("tankrest", 0.7, 0.7, 1.3, ZINK, "X", 14, ruine, (2.2, 2.0, 3.0), rot=(0.3, 0.2, 0.4)))
ru.append(box("stoep", (W + 0.4, 1.6, 0.18), BETON, ruine, (0, -D / 2 - 0.8, 0.09)))
ruin = join(ru[0], ru[1:])
ruin.name = "RuineMesh"

# ---------- afwerking ----------
bpy.context.view_layer.update()
for o in list(scene.objects):
    if o.type == "MESH":
        bad = [p for p in o.data.polygons if p.material_index >= len(o.data.materials)]
        if bad:
            print("MATFOUT", o.name, len(bad), [m.name for m in o.data.materials])
        world_uv(o)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "winkel.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "winkel.blend"))
tris = {}
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        top = o
        while top.parent and top.parent.name not in ("Winkel",):
            top = top.parent
        key = "kapot" if o.name.endswith("_kapot") else top.name
        tris[key] = tris.get(key, 0) + len(o.data.loop_triangles)
print("TRIS", tris, "OBJECTEN", len([o for o in scene.objects if o.type == "MESH"]))
