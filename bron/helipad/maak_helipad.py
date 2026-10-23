"""Helikopterplatform voor Bloedjungle: een betonnen plaat met een schacht van 9 x 9 m, twee stalen luiken die op
hydraulische zuigers omhoog klappen en een lift die de helikopter uit de grond omhoog brengt.
Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van de schacht op maaiveld. De voorkant van de helikopter is +Y (wordt -Z in Godot).
Gebruik: python3 maak_helipad.py <uitmap> [apache.blend]  ->  helipad.glb (voor het spel), helipad.blend, helipad_show.glb (met Apache erop, voor de viewer)

Hiërarchie: Helipad > Romp (alles wat stilstaat), LuikL/LuikR (om hun scharnier), ZuigerL1.. (basis + stang, volgen het luik),
              Lift (platform met H en ringen, beweegt van -3 m naar 0), ZwaaiA/ZwaaiB (draaiende lampen), lampen.
Animaties: Open, Dicht (4,5 s), Show-loop (alles achter elkaar, voor de viewer)."""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
rng = np.random.default_rng(3)


# ---------- texturen ----------
def noise(size, scale, seed, wrap=True):
    n = size // scale
    g = np.random.default_rng(seed).random((n + 1, n + 1))
    if wrap:
        g[n, :] = g[0, :]
        g[:, n] = g[:, 0]
    y, x = np.mgrid[0:size, 0:size] / scale
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
    b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def sm(v, e0, e1):
    return np.clip((v - e0) / (e1 - e0), 0, 1)[..., None]


def save_img(name, img, size):
    im = bpy.data.images.new(name, size, size)
    rgba = np.concatenate([np.clip(img, 0, 1), np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, name + ".png")
    im.file_format = "PNG"
    im.save()
    im.pack()
    return im



def mat(name, color, rough=0.8, metal=0.0, image=None, emit=None, strength=0.0):
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


def beton_image(size=512):
    """Vlekkerig beton met scheuren, olievlekken en vuil."""
    img = np.array([0.5, 0.49, 0.45]) * (0.85 + 0.3 * noise(size, 32, 21)[..., None])
    img = img * (0.92 + 0.16 * noise(size, 4, 22)[..., None])
    vlek = sm(noise(size, 64, 23), 0.55, 0.75) * 0.35
    img = img * (1 - vlek) + np.array([0.25, 0.23, 0.2]) * vlek
    olie = sm(noise(size, 64, 24) * 0.7 + noise(size, 8, 25) * 0.3, 0.68, 0.74) * 0.55
    img = img * (1 - olie) + np.array([0.1, 0.1, 0.1]) * olie
    scheur = sm(0.012 - np.abs(noise(size, 32, 26) - 0.5), 0, 0.012) * 0.6
    img = img * (1 - scheur)
    return save_img("helipad_beton", img, size)


def plaat_image(size=512):
    """Olijfgroen stalen luik met paneelnaden, roest en afgebladderde verf."""
    olive = np.array([0.27, 0.3, 0.19])
    img = olive * (0.86 + 0.28 * noise(size, 32, 31)[..., None])
    yy, xx = np.mgrid[0:size, 0:size]
    naad = ((xx % 128) < 2) | ((yy % 128) < 2)
    img[naad] *= 0.7
    nagel = (((xx % 128) - 10) ** 2 + ((yy % 128) - 10) ** 2) < 6
    img[nagel] *= 1.25
    roest = sm(noise(size, 16, 32) * 0.6 + noise(size, 4, 33) * 0.4, 0.66, 0.74) * 0.6
    img = img * (1 - roest) + np.array([0.34, 0.19, 0.1]) * roest
    chip = sm(noise(size, 4, 34), 0.8, 0.84) * 0.5
    img = img * (1 - chip) + np.array([0.4, 0.34, 0.26]) * chip
    return save_img("helipad_plaat", np.clip(img, 0, 1), size)



def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def empty(name, parent=None, loc=(0, 0, 0)):
    e = link(bpy.data.objects.new(name, None), parent)
    e.location = loc
    return e


def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(40))
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


def cyl(name, r1, r2, depth, material, axis="Z", segs=12, parent=None, loc=(0, 0, 0), smooth=True, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    o = mesh_obj(name, bm, material, parent, loc, smooth)
    o.rotation_euler = rot
    return o


def sphere(name, r, material, parent=None, loc=(0, 0, 0), scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return mesh_obj(name, bm, material, parent, loc, True)


def torus(name, major, minor, material, parent, loc, rot=(0, 0, 0), segs=14, msegs=5):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segs, minor_segments=msegs,
                                     location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    for c in o.users_collection:
        c.objects.unlink(o)
    link(o, parent)
    o.data.materials.append(material)
    return o


def join(target, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target




# ---------- materialen ----------
BETON = mat("Beton", (0.5, 0.49, 0.45), 0.95, 0.0, beton_image())
BETONDONKER = mat("BetonDonker", (0.3, 0.29, 0.27), 0.95)
LUIK = mat("Luik", (0.27, 0.3, 0.19), 0.55, 0.45, plaat_image())
STAAL = mat("Staal", (0.38, 0.39, 0.4), 0.4, 0.9)
CHROOM = mat("Chroom", (0.75, 0.76, 0.78), 0.2, 1.0)
DONKER = mat("Donker", (0.1, 0.1, 0.1), 0.6, 0.4)
ZWART = mat("Zwart", (0.04, 0.04, 0.04), 0.7)
GEEL = mat("Geel", (0.85, 0.66, 0.08), 0.6)
WIT = mat("Wit", (0.84, 0.84, 0.78), 0.7)
RODE = mat("Rood", (0.6, 0.08, 0.05), 0.5)
OLIJF = mat("Olijf", (0.28, 0.3, 0.19), 0.7, 0.1)
VAAT_ROEST = mat("VaatRoest", (0.42, 0.22, 0.1), 0.8, 0.3)
VAAT_GROEN = mat("VaatGroen", (0.24, 0.3, 0.17), 0.6, 0.3)
ZAND = mat("Zandzak", (0.5, 0.43, 0.27), 0.95)
SLANG = mat("Slang", (0.12, 0.12, 0.1), 0.8)
SCHACHTLAMP = mat("Schachtlamp", (0.95, 0.9, 0.7), 0.3, emit=(1.0, 0.9, 0.65), strength=4.0)
RANDLAMP = mat("Randlamp", (1.0, 0.1, 0.05), 0.3, emit=(1.0, 0.12, 0.05), strength=3.5)
ZWAAILENS = mat("Zwaailens", (1.0, 0.45, 0.05), 0.2, emit=(1.0, 0.4, 0.04), strength=4.0)
SCHERM = mat("Scherm", (0.2, 0.9, 0.35), 0.3, emit=(0.2, 1.0, 0.35), strength=2.0)
SOK = mat("Windzak", (0.85, 0.35, 0.08), 0.8)

# ---------- afmetingen ----------
SH = 4.5          # halve breedte van de schacht (9 x 9 m)
AP = 6.4          # halve breedte van de betonplaat rondom (12,8 x 12,8 m)
DEPTH = 3.0       # de lift zakt tot -3 m (bovenkant)
LIFT_W = 4.2      # halve breedte van het liftplatform (ruim 0,3 m lucht langs de wand)
LUIK_H0 = math.radians(103)   # hoek van een open luik (iets naar buiten leunend)
FPS = 30

root = empty("Helipad")
stat = []


def S(o):
    stat.append(o)
    return o


# ---------- betonplaat met gat ----------
S(box("PlaatN", (2 * AP, AP - SH, 0.3), BETON, root, (0, (AP + SH) / 2, -0.15)))
S(box("PlaatZ", (2 * AP, AP - SH, 0.3), BETON, root, (0, -(AP + SH) / 2, -0.15)))
S(box("PlaatW", (AP - SH, 2 * SH, 0.3), BETON, root, (-(AP + SH) / 2, 0, -0.15)))
S(box("PlaatO", (AP - SH, 2 * SH, 0.3), BETON, root, ((AP + SH) / 2, 0, -0.15)))
# lage rand rondom met afgeschuinde hoeken en dilatatievoegen
for nm, size, loc in (("RandN", (2 * AP + 0.5, 0.25, 0.14), (0, AP + 0.12, -0.03)), ("RandZ", (2 * AP + 0.5, 0.25, 0.14), (0, -AP - 0.12, -0.03)),
                      ("RandW", (0.25, 2 * AP, 0.14), (-AP - 0.12, 0, -0.03)), ("RandO", (0.25, 2 * AP, 0.14), (AP + 0.12, 0, -0.03))):
    S(box(nm, size, BETONDONKER, root, loc))
for k in (-3, 3):
    S(box(f"VoegX{k}", (2 * AP, 0.03, 0.01), ZWART, root, (0, k, 0.002)))
    S(box(f"VoegY{k}", (0.03, 2 * AP, 0.01), ZWART, root, (k, 0, 0.002)))

# ---------- gele en zwarte waarschuwingsrand langs de schacht ----------
geel_delen, zwart_delen = [], []
SEG = 0.45
for side in range(4):
    n = int(2 * (SH + 0.45) / SEG)
    for i in range(n):
        c = -(SH + 0.45) + SEG * (i + 0.5)
        for ring in (SH + 0.2,):
            if side == 0:
                size, loc = (SEG, 0.4, 0.012), (c, ring, 0.006)
            elif side == 1:
                size, loc = (SEG, 0.4, 0.012), (c, -ring, 0.006)
            elif side == 2:
                size, loc = (0.4, SEG, 0.012), (ring, c, 0.006)
            else:
                size, loc = (0.4, SEG, 0.012), (-ring, c, 0.006)
            o = box(f"Streep{side}{i}", size, GEEL if i % 2 == 0 else ZWART, root, loc, (0, 0, 0))
            (geel_delen if i % 2 == 0 else zwart_delen).append(o)
S(join(geel_delen[0], geel_delen[1:]))
S(join(zwart_delen[0], zwart_delen[1:]))
geel_delen[0].name = "RandGeel"
zwart_delen[0].name = "RandZwart"

# ---------- schacht: wanden, vloer, leidingen, trap, lampen ----------
WALL_BOT = -DEPTH - 0.6
S(box("SchachtVloer", (2 * SH + 0.6, 2 * SH + 0.6, 0.3), BETONDONKER, root, (0, 0, WALL_BOT - 0.15)))
for nm, size, loc in (("SchachtN", (2 * SH + 0.6, 0.3, -WALL_BOT - 0.3), (0, SH + 0.15, (WALL_BOT - 0.3) / 2)),
                      ("SchachtZ", (2 * SH + 0.6, 0.3, -WALL_BOT - 0.3), (0, -SH - 0.15, (WALL_BOT - 0.3) / 2)),
                      ("SchachtW", (0.3, 2 * SH, -WALL_BOT - 0.3), (-SH - 0.15, 0, (WALL_BOT - 0.3) / 2)),
                      ("SchachtO", (0.3, 2 * SH, -WALL_BOT - 0.3), (SH + 0.15, 0, (WALL_BOT - 0.3) / 2))):
    S(box(nm, size, BETONDONKER, root, loc))
# horizontale betonlijsten en kabelgoten op de wanden
for zz in (-1.0, -2.0):
    for sx in (-1, 1):
        S(box(f"LijstX{sx}{zz}", (0.06, 2 * SH, 0.1), BETON, root, (sx * (SH - 0.03), 0, zz)))
    for sy in (-1, 1):
        S(box(f"LijstY{sy}{zz}", (2 * SH, 0.06, 0.1), BETON, root, (0, sy * (SH - 0.03), zz)))
S(box("Kabelgoot", (0.12, 2 * SH - 0.6, 0.14), DONKER, root, (SH - 0.08, 0, -0.9)))
for k in range(8):
    S(box(f"Kabelbeugel{k}", (0.14, 0.05, 0.2), STAAL, root, (SH - 0.08, -SH + 0.6 + k * 1.1, -0.9)))
# gele hydraulische leiding langs de achterwand met flenzen
S(cyl("Leiding", 0.07, 0.07, 2 * SH - 0.8, GEEL, "X", 10, root, (0, SH - 0.14, -1.55)))
for k in range(6):
    S(cyl(f"Flens{k}", 0.1, 0.1, 0.06, STAAL, "X", 10, root, (-SH + 1.0 + k * 1.5, SH - 0.14, -1.55)))
S(cyl("LeidingStandpijp", 0.07, 0.07, 1.6, GEEL, "Z", 10, root, (SH - 0.14, SH - 0.14, -2.3)))
# brandweerhaspel en gele leuning aan de zijwand
S(cyl("Haspel", 0.4, 0.4, 0.22, RODE, "Y", 14, root, (-SH + 0.2, 2.5, -1.4)))
S(cyl("HaspelNaaf", 0.1, 0.1, 0.28, STAAL, "Y", 8, root, (-SH + 0.2, 2.5, -1.4)))
# ladder in de zuidwand
for k in range(10):
    S(box(f"Sport{k}", (0.5, 0.04, 0.04), STAAL, root, (-2.0, -SH + 0.1, -0.3 - k * 0.32)))
for sx in (-2.25, -1.75):
    S(box(f"Ladderstijl{sx}", (0.05, 0.05, 3.2), STAAL, root, (sx, -SH + 0.1, -1.8)))
# lampen in de schacht: kooi + emissieve lens
LAMPEN = []
for k, (lx, ly) in enumerate(((-SH + 0.15, -2.0), (-SH + 0.15, 2.0), (SH - 0.15, -2.0), (SH - 0.15, 2.0))):
    S(box(f"LampKooi{k}", (0.14, 0.34, 0.2), ZWART, root, (lx, ly, -1.2)))
    S(box(f"LampLens{k}", (0.1, 0.26, 0.14), SCHACHTLAMP, root, (lx + (0.03 if lx < 0 else -0.03), ly, -1.2)))
    LAMPEN.append((lx, ly))
for k, (lx, ly) in enumerate(((-SH + 0.15, 0), (SH - 0.15, 0))):
    lamp = bpy.data.lights.new(f"SchachtLicht{k}", "POINT")
    lamp.energy = 1200
    lamp.shadow_soft_size = 0.3
    lamp.color = (1.0, 0.9, 0.7)
    lo = link(bpy.data.objects.new(f"SchachtLicht{k}", lamp), root)
    lo.location = (lx * 0.6, ly, -1.0)

# ---------- hydraulische kolommen onder de lift (vaste huls op de vloer) ----------
KOL = [(-2.9, -2.9), (2.9, -2.9), (-2.9, 2.9), (2.9, 2.9)]
for k, (kx, ky) in enumerate(KOL):
    S(cyl(f"Huls{k}", 0.3, 0.3, 1.6, STAAL, "Z", 14, root, (kx, ky, WALL_BOT + 0.8)))
    S(cyl(f"HulsRing{k}", 0.34, 0.34, 0.1, DONKER, "Z", 14, root, (kx, ky, WALL_BOT + 1.55)))
    S(box(f"Voet{k}", (0.9, 0.9, 0.12), STAAL, root, (kx, ky, WALL_BOT + 0.06)))

# ---------- de lift ----------
lift = empty("Lift", root, (0, 0, -DEPTH))
LIFT_TOP = 0.0
liftdelen = []
liftdelen.append(box("LiftPlaat", (2 * LIFT_W, 2 * LIFT_W, 0.4), BETONDONKER, lift, (0, 0, -0.2)))
liftdelen.append(box("LiftRand", (2 * LIFT_W + 0.12, 2 * LIFT_W + 0.12, 0.06), STAAL, lift, (0, 0, -0.03)))
# helikopterring en H in wit, op een donker vlak
ring_out = cyl("RingBuiten", 3.5, 3.5, 0.012, WIT, "Z", 40, lift, (0, 0, 0.006), smooth=False)
ring_in = cyl("RingBinnen", 3.15, 3.15, 0.016, BETONDONKER, "Z", 40, lift, (0, 0, 0.008), smooth=False)
H_ = [box("H_L", (0.35, 3.0, 0.02), WIT, lift, (-0.85, 0, 0.012)), box("H_R", (0.35, 3.0, 0.02), WIT, lift, (0.85, 0, 0.012)),
      box("H_M", (1.35, 0.35, 0.02), WIT, lift, (0, 0, 0.012))]
liftdelen += [ring_out, ring_in] + H_
# gele hoekmarkeringen en rode randlampen op het liftplatform
for sx in (-1, 1):
    for sy in (-1, 1):
        liftdelen.append(box(f"Hoekstreep{sx}{sy}a", (1.1, 0.16, 0.02), GEEL, lift, (sx * (LIFT_W - 0.65), sy * (LIFT_W - 0.14), 0.012)))
        liftdelen.append(box(f"Hoekstreep{sx}{sy}b", (0.16, 1.1, 0.02), GEEL, lift, (sx * (LIFT_W - 0.14), sy * (LIFT_W - 0.65), 0.012)))
for k, (lx, ly) in enumerate(((0, LIFT_W - 0.3), (0, -LIFT_W + 0.3), (LIFT_W - 0.3, 0), (-LIFT_W + 0.3, 0))):
    liftdelen.append(cyl(f"Randlamp{k}", 0.12, 0.12, 0.05, RANDLAMP, "Z", 10, lift, (lx, ly, 0.02)))
# vastzetogen en blokken voor de skids
for k, (lx, ly) in enumerate(((-2.3, 2.6), (2.3, 2.6), (-2.3, -2.6), (2.3, -2.6))):
    liftdelen.append(torus(f"Oog{k}", 0.12, 0.025, STAAL, lift, (lx, ly, 0.03), segs=10))
for k, sx in enumerate((-1.4, 1.4)):
    for j, ly in enumerate((-1.4, 1.2)):
        liftdelen.append(box(f"Blok{k}{j}", (0.3, 0.2, 0.14), ZWART, lift, (sx, ly, 0.07)))
# zandzakken en wiggen op de lift rand voor sfeer: rij stootbalken
for sx in (-1, 1):
    liftdelen.append(box(f"Stoot{sx}", (0.1, 2 * LIFT_W, 0.14), STAAL, lift, (sx * (LIFT_W + 0.04), 0, -0.08)))
# onderkant: dwarsbalken en stangen aan de kolommen
for k, (kx, ky) in enumerate(KOL):
    liftdelen.append(cyl(f"Stang{k}", 0.2, 0.2, 1.7, CHROOM, "Z", 14, lift, (kx, ky, -0.4 - 0.85)))
for ky in (-2.9, 0, 2.9):
    liftdelen.append(box(f"Balk{ky}", (2 * LIFT_W - 0.4, 0.3, 0.3), STAAL, lift, (0, ky, -0.55)))
for kk, parts in enumerate((liftdelen,)):
    pass
liftmesh = join(liftdelen[0], liftdelen[1:])
liftmesh.name = "LiftMesh"

# ---------- luiken met scharnier, versteviging en gele streep ----------
def maak_luik(naam, sx):
    hinge = empty(naam, root, (sx * SH, 0, 0.15))
    hinge.rotation_mode = "XYZ"
    delen = []
    delen.append(box(naam + "Plaat", (SH, 2 * SH, 0.3), LUIK, hinge, (-sx * SH / 2, 0, 0)))
    # opstaande randen en ribben aan de bovenkant
    delen.append(box(naam + "RandBuiten", (0.14, 2 * SH, 0.12), STAAL, hinge, (-sx * 0.07, 0, 0.18)))
    delen.append(box(naam + "RandBinnen", (0.18, 2 * SH, 0.14), STAAL, hinge, (-sx * (SH - 0.09), 0, 0.19)))
    for k in range(5):
        delen.append(box(naam + f"Rib{k}", (SH - 0.4, 0.1, 0.07), STAAL, hinge, (-sx * SH / 2, -SH + 0.9 + k * (2 * SH - 1.8) / 4, 0.17)))
    # gele chevrons langs de binnenrand (wijzen naar de sluitlijn)
    for k in range(8):
        y = -SH + 0.6 + k * (2 * SH - 1.2) / 7
        delen.append(box(naam + f"Chev{k}", (0.12, 0.7, 0.012), GEEL, hinge, (-sx * (SH - 0.55), y, 0.156), (0, 0, math.radians(35) * sx)))
    # Handvat, hijsogen en een rood-wit nummerbord
    delen.append(box(naam + "Bord", (0.9, 0.5, 0.012), WIT, hinge, (-sx * SH / 2, 0, 0.156)))
    delen.append(box(naam + "BordStreep", (0.9, 0.08, 0.014), RODE, hinge, (-sx * SH / 2, 0, 0.16)))
    for k, y in enumerate((-2.8, 2.8)):
        delen.append(torus(naam + f"Oog{k}", 0.13, 0.03, STAAL, hinge, (-sx * 1.2, y, 0.2), segs=10))
    # onderkant: balken
    for k in range(4):
        delen.append(box(naam + f"Spant{k}", (SH - 0.2, 0.18, 0.2), STAAL, hinge, (-sx * SH / 2, -SH + 0.7 + k * (2 * SH - 1.4) / 3, -0.2)))
    delen.append(cyl(naam + "Scharnier", 0.14, 0.14, 2 * SH, DONKER, "Y", 12, hinge, (0, 0, 0)))
    m = join(delen[0], delen[1:])
    m.name = naam + "Mesh"
    return hinge


luikL = maak_luik("LuikL", -1)
luikR = maak_luik("LuikR", 1)


# ---------- zuigers: een vaste cilinder aan de wand en een stang naar het luik ----------
def maak_zuiger(naam, sx, y):
    base = empty(naam + "Basis", root, (sx * (SH - 0.12), y, -1.2))
    cyl_ = cyl(naam + "Cilinder", 0.11, 0.11, 1.0, STAAL, "Z", 12, base, (0, 0, 0.5))
    rod = empty(naam + "Stang", root, base.location)
    rod_m = cyl(naam + "StangMesh", 0.065, 0.065, 1.0, CHROOM, "Z", 10, rod, (0, 0, 0.5))
    for o in (base, rod):
        o.rotation_mode = "QUATERNION"
    S(box(naam + "Console", (0.18, 0.4, 0.3), STAAL, root, (sx * (SH - 0.06), y, -1.2)))
    return base, rod


ZUIGERS = {}
for nm, sx in (("L", -1), ("R", 1)):
    for k, y in enumerate((-2.4, 2.4)):
        ZUIGERS[(nm, y)] = (sx, y) + maak_zuiger(f"Zuiger{nm}{k + 1}", sx, y)
ATTACH_X = 2.2    # afstand van het scharnier tot waar de stang aan het luik zit


def luik_hoek(k):
    return LUIK_H0 * k


def attach_world(sx, y, hoek):
    """Aanzetpunt van de stang (onderkant van het luik) na draaiing om het scharnier."""
    lx = -sx * ATTACH_X
    lz = -0.2
    th = sx * hoek * (-1.0 if sx < 0 else 1.0)   # L draait negatief om Y, R positief
    th = -hoek if sx < 0 else hoek
    wx = lx * math.cos(th) + lz * math.sin(th)
    wz = -lx * math.sin(th) + lz * math.cos(th)
    return Vector((sx * SH + wx, y, 0.15 + wz))


# ---------- lampen, windzak, bedieningskast, vaten ----------
def zwaailamp(naam, loc):
    S(cyl(naam + "Paal", 0.07, 0.07, 1.4, STAAL, "Z", 8, root, (loc[0], loc[1], 0.7)))
    S(cyl(naam + "Voet", 0.28, 0.28, 0.1, STAAL, "Z", 12, root, (loc[0], loc[1], 0.05)))
    S(cyl(naam + "Sokkel", 0.16, 0.16, 0.12, ZWART, "Z", 12, root, (loc[0], loc[1], 1.46)))
    e = empty(naam, root, (loc[0], loc[1], 1.6))
    cyl(naam + "Kap", 0.13, 0.13, 0.22, ZWAAILENS, "Z", 12, e, (0, 0, 0.0))
    box(naam + "Reflector", (0.04, 0.22, 0.14), STAAL, e, (0.0, 0.0, 0.0))
    spot = bpy.data.lights.new(naam + "Licht", "SPOT")
    spot.energy = 900
    spot.spot_size = math.radians(40)
    spot.color = (1.0, 0.55, 0.15)
    so = link(bpy.data.objects.new(naam + "Licht", spot), e)
    so.rotation_euler = (math.radians(90), 0, 0)
    return e


zwA = zwaailamp("ZwaaiA", (-AP + 0.5, -AP + 0.5))
zwB = zwaailamp("ZwaaiB", (AP - 0.5, -AP + 0.5))

# windzak op een paal
S(cyl("WindPaal", 0.05, 0.05, 4.2, STAAL, "Z", 8, root, (AP - 0.6, AP - 0.6, 2.1)))
S(cyl("WindVoet", 0.2, 0.2, 0.1, STAAL, "Z", 10, root, (AP - 0.6, AP - 0.6, 0.05)))
S(torus("WindRing", 0.28, 0.02, STAAL, root, (AP - 0.6 - 0.28, AP - 0.6, 4.1), rot=(0, math.radians(90), 0)))
for k in range(5):
    r = 0.26 - 0.03 * k
    S(cyl(f"Windzak{k}", r, r - 0.03, 0.22, SOK if k % 2 == 0 else WIT, "X", 12, root, (AP - 0.6 - 0.28 - 0.24 - 0.22 * k, AP - 0.6, 4.1 - 0.02 * k)))

# floodlightmast
S(cyl("MastPaal", 0.09, 0.07, 6.0, STAAL, "Z", 8, root, (-AP + 0.6, AP - 0.6, 3.0)))
S(cyl("MastVoet", 0.3, 0.3, 0.12, STAAL, "Z", 12, root, (-AP + 0.6, AP - 0.6, 0.06)))
S(box("MastBalk", (1.0, 0.1, 0.1), STAAL, root, (-AP + 0.6, AP - 0.6, 6.0)))
for k, dx in enumerate((-0.4, 0.4)):
    S(box(f"MastLamp{k}", (0.34, 0.12, 0.26), ZWART, root, (-AP + 0.6 + dx, AP - 0.6 - 0.1, 5.85), (math.radians(20), 0, 0)))
    S(box(f"MastLens{k}", (0.28, 0.02, 0.2), SCHACHTLAMP, root, (-AP + 0.6 + dx, AP - 0.6 - 0.17, 5.84), (math.radians(20), 0, 0)))
fl = bpy.data.lights.new("MastSchijnwerper", "SPOT")
fl.energy = 6000
fl.spot_size = math.radians(70)
fl.spot_blend = 0.5
fl.color = (1.0, 0.95, 0.8)
flo = link(bpy.data.objects.new("MastSchijnwerper", fl), root)
flo.location = (-AP + 0.6, AP - 0.9, 5.8)
flo.rotation_euler = (math.radians(25), 0, math.radians(-20))

# bedieningskast met scherm, antenne en noodstop
S(box("KastVoet", (1.0, 0.7, 0.25), BETON, root, (AP - 1.0, -AP + 1.2, 0.12)))
S(box("Kast", (0.9, 0.6, 1.3), OLIJF, root, (AP - 1.0, -AP + 1.2, 0.9)))
S(box("KastDak", (1.0, 0.7, 0.08), STAAL, root, (AP - 1.0, -AP + 1.2, 1.58)))
S(box("KastScherm", (0.5, 0.02, 0.32), SCHERM, root, (AP - 1.0, -AP + 1.2 - 0.31, 1.15)))
S(box("KastRand", (0.58, 0.02, 0.4), ZWART, root, (AP - 1.0, -AP + 1.2 - 0.305, 1.15)))
S(cyl("Noodstop", 0.07, 0.07, 0.05, RODE, "Y", 12, root, (AP - 1.3, -AP + 1.2 - 0.32, 0.8)))
S(box("KastKnoppenRij", (0.5, 0.02, 0.1), ZWART, root, (AP - 1.0, -AP + 1.2 - 0.31, 0.88)))
S(cyl("KastAntenne", 0.015, 0.012, 1.4, ZWART, "Z", 6, root, (AP - 0.62, -AP + 1.0, 2.2)))
# kabelslang van de kast naar de schacht
for k in range(6):
    S(box(f"Kabel{k}", (0.06, 0.5, 0.05), SLANG, root, (AP - 1.0 - k * 0.1, -AP + 1.9 + k * 0.45, 0.03), (0, 0, math.radians(-15 * k))))

# olievaten, jerrycans en zandzakken bij de plaat
for k, (vx, vy, m) in enumerate(((-AP + 0.7, -2.5, VAAT_ROEST), (-AP + 1.4, -2.9, VAAT_GROEN), (-AP + 0.8, -3.3, VAAT_ROEST), (-AP + 0.3 + 1.1, -3.5, VAAT_GROEN))):
    S(cyl(f"Vat{k}", 0.3, 0.3, 0.9, m, "Z", 14, root, (vx, vy, 0.45)))
    S(cyl(f"VatRing{k}", 0.31, 0.31, 0.05, STAAL, "Z", 14, root, (vx, vy, 0.62)))
    S(cyl(f"VatRing2{k}", 0.31, 0.31, 0.05, STAAL, "Z", 14, root, (vx, vy, 0.28)))
for k in range(2):
    for j in range(6):
        S(box(f"Zak{k}{j}", (0.7, 0.36, 0.2), ZAND, root, (-AP + 0.45 + (0.35 if k else 0), 1.0 + j * 0.38 + k * 0.2, 0.1 + 0.2 * k), (0, 0, math.radians(90))))

# ---------- vaste delen samenvoegen tot de Romp ----------
romp_delen = [o for o in stat if o.type == "MESH" and o.name in bpy.data.objects]
by_mat = {}
for o in romp_delen:
    by_mat.setdefault(o.data.materials[0].name if o.data.materials else "", []).append(o)
for mname, items in by_mat.items():
    if len(items) > 1:
        join(items[0], items[1:])
    items[0].name = "Romp_" + mname
romp = empty("Romp", root)
for o in list(root.children):
    if o.type == "MESH" and o.name.startswith("Romp_"):
        o.parent = romp

# ---------- animatie ----------
def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


ANIM = [luikL, luikR, lift] + [x for v in ZUIGERS.values() for x in v[2:]] + [zwA, zwB]


def pose_state(f_luik, f_lift, tzwaai=None):
    """f_luik, f_lift 0..1 -> zet alle bewegende delen."""
    hoek = luik_hoek(f_luik)
    luikL.rotation_euler = (0, -hoek, 0)
    luikR.rotation_euler = (0, hoek, 0)
    lift.location = (0, 0, -DEPTH * (1.0 - f_lift))
    for (nm, y), (sx, yy, base, rod) in ZUIGERS.items():
        a = attach_world(sx, yy, hoek)
        p0 = base.location.copy()
        d = a - p0
        quat = d.normalized().to_track_quat("Z", "Y")
        base.rotation_quaternion = quat
        rod.rotation_quaternion = quat
        rod.scale = (1, 1, d.length)
        rod.location = p0
    if tzwaai is not None:
        zwA.rotation_euler = (0, 0, tzwaai * math.tau)
        zwB.rotation_euler = (0, 0, -tzwaai * math.tau + 1.0)


def clip(naam, duur, fn):
    frames = int(round(duur * FPS))
    for o in ANIM:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new(f"{naam}_{o.name}")
    for f in range(frames + 1):
        t = f / FPS
        pose_state(*fn(t))
        for o in ANIM:
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_quaternion" if o.rotation_mode == "QUATERNION" else "rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    for o in ANIM:
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 0, a)
        st.name = naam
        o.animation_data.action = None
    pose_state(0, 0, 0)


OPEN_T = 4.5
clip("Open", OPEN_T, lambda t: (ease(t / 1.9), ease((t - 1.4) / 3.0)))
clip("Dicht", OPEN_T, lambda t: (1.0 - ease((t - 2.6) / 1.9), 1.0 - ease(t / 3.0)))


def show(t):
    # 0-4,5 open; 4,5-9 open en blijven staan (heli draait); 9-13,5 dicht
    if t < OPEN_T:
        return ease(t / 1.9), ease((t - 1.4) / 3.0), t / 1.0
    if t < 9.0:
        return 1.0, 1.0, t / 1.0
    u = t - 9.0
    return 1.0 - ease((u - 2.6) / 1.9), 1.0 - ease(u / 3.0), t / 1.0


clip("Show-loop", 13.5, show)
scene.frame_start, scene.frame_end = 0, 405


def exporteer(naam):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, naam), export_format="GLB", export_apply=True,
                              export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW",
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_optimize_animation_size=False)


exporteer("helipad.glb")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "helipad.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("TRIS", tris)

# ---------- versie voor de viewer: de Apache staat op de lift en start zijn rotor tijdens het omhoog komen ----------
if len(sys.argv) > 2:
    SCHAAL = 0.45
    with bpy.data.libraries.load(os.path.abspath(sys.argv[2])) as (src, dst):
        dst.objects = [n for n in ("Apache", "Body", "RompMesh", "Rotor", "RotorMesh", "Staartrotor", "StaartrotorMesh") if n in src.objects]
    for o in dst.objects:
        o.animation_data_clear()
        scene.collection.objects.link(o)
    ap, body, rump, rotor, rotm, staart = (bpy.data.objects[n] for n in ("Apache", "Body", "RompMesh", "Rotor", "RotorMesh", "Staartrotor"))
    body.rotation_euler = (0, 0, 0)   # apache_anim.blend bewaart de stand van de laatste clip (scheef)
    bpy.context.view_layer.update()
    zmin = min((rump.matrix_world @ Vector(c)).z for c in rump.bound_box) - body.location.z
    body.location.z = -zmin
    ap.parent = lift
    ap.scale = (SCHAAL,) * 3
    for o in (ap, body, rotor, staart):
        o.rotation_mode = "XYZ"
    # rotor draait mee in de clip Show-loop: eerst langzaam, dan snel
    for o in (rotor, staart):
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new("Show-loop_" + o.name)
    r_ang = s_ang = 0.0
    for f in range(int(13.5 * FPS) + 1):
        t = f / FPS
        speed = ease((t - 1.0) / 4.0) if t < 9.0 else 1.0 - ease((t - 9.0) / 3.0)
        r_ang += speed * 4.0 * math.tau / FPS
        s_ang += speed * 12.0 * math.tau / FPS
        rotor.rotation_euler = (0, 0, r_ang)
        staart.rotation_euler = (s_ang, 0, 0)
        rotor.keyframe_insert("rotation_euler", frame=f)
        staart.keyframe_insert("rotation_euler", frame=f)
    for o in (rotor, staart):
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = "Show-loop"
        st = tr.strips.new("Show-loop", 0, a)
        st.name = "Show-loop"
        o.animation_data.action = None
    exporteer("helipad_show.glb")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "helipad_show.blend"))
