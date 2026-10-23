"""Motorpool (garage) voor Bloedjungle: legerhangar van golfplaat met rolpoort, camonet, zandzakken, antenne,
olievaten, banden, takel, werkbank en een bord MOTORPOOL.
Blender: de deur zit aan -Y (wordt +Z in Godot), Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van het terrein
(x van -3,9 tot 3,9, y van -4,3 tot 4,3). Het gebouw zelf loopt van x -3,9 tot 2,5; rechts ligt een erf met vaten en banden.
Gebruik: python3 maak_garage.py <uitmap>  ->  garage.glb, garage.blend

Hiërarchie: Garage > Romp (alles wat stilstaat), Deur (rolpoort), Zwaai > ZwaaiKap (draaiende kap van het waarschuwingslicht),
              Kraan > Arm > Haak (takel), lampen DeurLampL/R (spot), ZwaaiLicht, BinnenLamp.
Animaties: Open, Dicht (rolpoort omhoog/omlaag, 2 s), Show-loop (alles tegelijk, voor de viewer)."""
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


def plaat_image(size=512):
    """Olijfgroene golfplaat: v loopt van de grond (0) naar boven (1); vuil onderaan, roestkleurige strepen, afgebladderde verf."""
    olive = np.array([0.30, 0.33, 0.20])
    yy = np.mgrid[0:size, 0:size][0] / size  # 0 boven? (image-y); we draaien later zodat v=0 onderaan
    v = 1 - yy
    img = olive * (0.88 + 0.24 * noise(size, 32, 1)[..., None])
    streak = noise(size, 4, 2) * 0.5 + noise(size, 64, 3) * 0.5
    streep = sm(streak + (v - 0.5) * 0.1, 0.58, 0.8) * 0.5 * sm(1 - v, 0, 0.7)
    img = img * (1 - streep) + np.array([0.36, 0.2, 0.1]) * streep
    vuil = sm(0.34 - v, 0, 0.34) * (0.5 + 0.5 * noise(size, 16, 4)[..., None])
    img = img * (1 - 0.7 * vuil) + np.array([0.24, 0.19, 0.12]) * 0.7 * vuil
    chip = sm(noise(size, 4, 5) + (noise(size, 2, 6) - 0.5) * 0.3, 0.78, 0.83) * 0.55
    img = img * (1 - chip) + np.array([0.34, 0.24, 0.17]) * chip
    return save_img("garage_plaat", img, size)


def camo_image(size=512):
    olive = np.array([0.29, 0.31, 0.19])
    donker = np.array([0.13, 0.17, 0.09])
    zwart = np.array([0.05, 0.06, 0.04])
    zand = np.array([0.45, 0.4, 0.26])
    a = noise(size, 64, 11) * 0.65 + noise(size, 32, 12) * 0.35
    b = noise(size, 64, 13) * 0.65 + noise(size, 16, 14) * 0.35
    img = olive * (0.9 + 0.2 * noise(size, 8, 15)[..., None])
    img = img * (1 - sm(b, 0.58, 0.62)) + zand * sm(b, 0.58, 0.62)
    img = img * (1 - sm(a, 0.52, 0.56)) + donker * sm(a, 0.52, 0.56)
    img = img * (1 - sm(a, 0.64, 0.68)) + zwart * sm(a, 0.64, 0.68)
    # gaten van het net: donkere ruimte tussen de bladeren
    gat = sm(noise(size, 16, 16) * 0.6 + noise(size, 4, 17) * 0.4, 0.62, 0.66)
    img = img * (1 - gat * 0.85) + zwart * gat * 0.85
    return save_img("garage_camo", img, size)


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


PLAAT = mat("Plaat", (0.3, 0.33, 0.2), 0.55, 0.35, plaat_image())
CAMO = mat("Camonet", (0.29, 0.31, 0.19), 0.95, 0.0, camo_image())
BETON = mat("Beton", (0.5, 0.49, 0.45), 0.95)
BETONDONKER = mat("BetonDonker", (0.33, 0.32, 0.29), 0.95)
STAAL = mat("Staal", (0.38, 0.39, 0.4), 0.4, 0.9)
DONKER = mat("Donker", (0.1, 0.1, 0.1), 0.6, 0.4)
ZWART = mat("Zwart", (0.04, 0.04, 0.04), 0.7)
DAK = mat("Dak", (0.17, 0.18, 0.16), 0.9)
GEEL = mat("Geel", (0.85, 0.66, 0.08), 0.6)
WIT = mat("Wit", (0.84, 0.84, 0.78), 0.7)
RODE = mat("Rood", (0.6, 0.08, 0.05), 0.5)
HOUT = mat("Hout", (0.4, 0.27, 0.15), 0.85)
OLIJF = mat("Olijf", (0.28, 0.3, 0.19), 0.7, 0.1)
ZAND = mat("Zandzak", (0.5, 0.43, 0.27), 0.95)
VAAT_ROEST = mat("VaatRoest", (0.42, 0.22, 0.1), 0.8, 0.3)
VAAT_GEEL = mat("VaatGeel", (0.7, 0.55, 0.12), 0.7, 0.2)
BAND = mat("Band", (0.06, 0.06, 0.055), 0.95)
DEURLAMP = mat("Deurlamp", (0.95, 0.8, 0.4), 0.3, emit=(1.0, 0.8, 0.35), strength=5.0)
ZWAAILENS = mat("Zwaailens", (1.0, 0.45, 0.05), 0.2, emit=(1.0, 0.4, 0.04), strength=4.0)
BINNENLAMP = mat("Binnenlamp", (0.95, 0.9, 0.7), 0.3, emit=(1.0, 0.9, 0.65), strength=4.0)
GLAS = mat("Glas", (0.12, 0.16, 0.16), 0.05, 0.4)


# ---------- hulpfuncties ----------
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


def golf_paneel(name, p0, p1, z0, z1, rib=0.14, amp=0.035, parent=None, normaal=-1):
    """Golfplaat tussen twee punten (x,y) op de grond; golven lopen verticaal. UV: u = lengte/3,2, v = hoogte/3,2."""
    a, b = Vector(p0), Vector(p1)
    L = (b - a).length
    n = max(2, int(round(L / rib * 2)))
    d = (b - a).normalized()
    nrm = Vector((-d.y, d.x)) * normaal
    bm = bmesh.new()
    uv_layer = None
    cols = []
    for i in range(n + 1):
        t = i / n
        off = amp * (1 if i % 2 else -1)
        p = a + d * L * t + nrm * off
        cols.append((bm.verts.new((p.x, p.y, z0)), bm.verts.new((p.x, p.y, z1)), L * t))
    faces = []
    for i in range(n):
        f = bm.faces.new([cols[i][0], cols[i + 1][0], cols[i + 1][1], cols[i][1]])
        faces.append((f, cols[i][2], cols[i + 1][2]))
    bm.normal_update()
    uv = bm.loops.layers.uv.new("UVMap")
    for f, u0, u1 in faces:
        for l in f.loops:
            vz = l.vert.co.z
            l[uv].uv = ((u0 if l.vert in (f.verts[0], f.verts[3]) else u1) / 3.2 + 0.37 * (a.x + a.y), vz / 3.2)
    o = mesh_obj(name, bm, PLAAT, parent)
    return o


# ---------- afmetingen ----------
X0, X1 = -3.9, 2.5      # gebouw links/rechts
YF, YB = -4.2, 4.2      # voorkant (deur) / achterkant
H = 3.2                 # wandhoogte
DC = (X0 + X1) / 2      # midden van de deur (x)
DW = 5.9                # deurbreedte (breed genoeg voor de tank)
GS = 0.66               # het gebouw wordt in de breedte en diepte hierop geschaald (kleiner in het spel)
GSH = 0.92              # in de hoogte minder, zodat tank en jeep er nog onderdoor passen
DH = 2.7                # deurhoogte
root = empty("Garage")
root.scale = (GS, GS, GSH)
LOS = set()
stat = []  # delen van de romp


def S(o):
    stat.append(o)
    return o


# fundering en vloer
for nm, size, loc in (("FundL", (0.3, 8.9, 0.34), (X0 - 0.1, 0, 0.17)), ("FundR", (0.3, 8.9, 0.34), (X1 + 0.1, 0, 0.17)),
                      ("FundA", (6.8, 0.3, 0.34), (DC, YB + 0.1, 0.17))):
    S(box(nm, size, BETON, root, loc))
S(box("FundVL", (0.3, 0.3, 0.34), BETON, root, (X0 + 0.1, YF - 0.1, 0.17)))
S(box("FundVR", (0.3, 0.3, 0.34), BETON, root, (X1 - 0.1, YF - 0.1, 0.17)))
S(box("Vloer", (X1 - X0, YB - YF, 0.12), BETONDONKER, root, (DC, 0, 0.06)))
S(box("Drempel", (DW, 0.5, 0.14), BETON, root, (DC, YF - 0.2, 0.07)))
S(box("Erf", (1.4, 8.6, 0.08), BETONDONKER, root, (3.2, 0, 0.04)))
# olievlek op de vloer
S(box("Olievlek", (1.6, 1.1, 0.004), ZWART, root, (DC + 0.5, -1.4, 0.123)))
# wanden van golfplaat
S(golf_paneel("WandL", (X0, YF), (X0, YB), 0.3, H, parent=root, normaal=1))
S(golf_paneel("WandR", (X1, YF), (X1, YB), 0.3, H, parent=root, normaal=-1))
S(golf_paneel("WandA", (X0, YB), (X1, YB), 0.3, H, parent=root, normaal=1))
S(golf_paneel("WandVL", (X0, YF), (DC - DW / 2, YF), 0.3, H, parent=root, normaal=1))
S(golf_paneel("WandVR", (DC + DW / 2, YF), (X1, YF), 0.3, H, parent=root, normaal=1))
S(golf_paneel("Latei", (DC - DW / 2, YF), (DC + DW / 2, YF), DH, H, parent=root, normaal=1))
# hoekpalen, deurposten en dakbalken
for sx, sy in ((X0, YF), (X1, YF), (X0, YB), (X1, YB)):
    S(box(f"Hoek{sx}{sy}", (0.18, 0.18, H), STAAL, root, (sx, sy, H / 2)))
for dx in (-DW / 2, DW / 2):
    S(box(f"Post{dx}", (0.22, 0.26, DH + 0.05), STAAL, root, (DC + dx, YF, (DH + 0.05) / 2 + 0.05)))
S(box("Dakrand", (X1 - X0 + 0.5, 0.2, 0.14), STAAL, root, (DC, YF - 0.1, H + 0.08)))
# dak met opstaande rand en ribben; licht aflopend naar voren
S(box("Dakplaat", (X1 - X0 + 0.5, YB - YF + 0.5, 0.14), DAK, root, (DC, 0, H + 0.07)))
for sx in (-1, 1):
    S(box(f"Dakrib{sx}", (0.1, YB - YF + 0.5, 0.1), STAAL, root, (DC + sx * (X1 - X0) / 2.0 - sx * 0.0, 0, H + 0.19)))
for i in range(7):
    y = YF + 0.5 + i * 1.2
    S(box(f"Daklat{i}", (X1 - X0 + 0.4, 0.07, 0.07), STAAL, root, (DC, y, H + 0.18)))
# dakventilatoren
for k, (vx, vy) in enumerate(((X0 + 1.1, 1.0), (X1 - 1.1, 1.0))):
    S(cyl(f"Ventilator{k}", 0.3, 0.3, 0.2, STAAL, "Z", 12, root, (vx, vy, H + 0.28)))
    S(cyl(f"VentilatorKap{k}", 0.38, 0.05, 0.22, STAAL, "Z", 12, root, (vx, vy, H + 0.48)))
# antenne met tuidraden
S(cyl("AntenneVoet", 0.12, 0.12, 0.2, STAAL, "Z", 8, root, (X0 + 0.6, YB - 0.6, H + 0.24)))
S(cyl("Antenne", 0.025, 0.012, 3.2, ZWART, "Z", 6, root, (X0 + 0.6, YB - 0.6, H + 1.9)))
for k in range(3):
    S(box(f"Antennedwars{k}", (0.9 - 0.2 * k, 0.025, 0.025), ZWART, root, (X0 + 0.6, YB - 0.6, H + 1.3 + 0.55 * k)))
S(box("AntenneWimpel", (0.32, 0.01, 0.2), RODE, root, (X0 + 0.78, YB - 0.6, H + 3.4)))
# camonet: onregelmatig hangend over de achterste helft van het dak, met touwen aan de rand
nx, ny = 22, 22
x_a, x_b, y_a, y_b = X0 - 0.3, X1 + 0.2, 0.3, YB + 0.4
bm = bmesh.new()
grid = []
uvl = bm.loops.layers.uv.new("UVMap")
for j in range(ny + 1):
    row = []
    for i in range(nx + 1):
        u, v = i / nx, j / ny
        x = x_a + (x_b - x_a) * u
        y = y_a + (y_b - y_a) * v
        z = H + 0.4 - 0.1 * math.sin(u * math.pi) * math.sin(v * math.pi) + 0.035 * math.sin(u * 18 + v * 7) * math.sin(v * 11)
        # de voorrand zakt scheef omlaag en de randen hangen
        z -= 0.22 * (1 - v) ** 3 + 0.18 * (abs(u - 0.5) * 2) ** 4
        row.append(bm.verts.new((x, y, z)))
    grid.append(row)
for j in range(ny):
    for i in range(nx):
        f = bm.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x / 3.2, l.vert.co.y / 3.2)
net = S(mesh_obj("Camonet", bm, CAMO, root, smooth=True))
for k, (px, py) in enumerate(((X0 - 0.3, 0.6), (X1 + 0.2, 0.6), (X0 - 0.3, YB + 0.3), (X1 + 0.2, YB + 0.3))):
    S(cyl(f"Netpaal{k}", 0.03, 0.03, 0.6, ZWART, "Z", 6, root, (px, py, H + 0.3)))
# bord MOTORPOOL boven de deur en geschilderde tekst op het dak
S(box("Bord", (3.6, 0.07, 0.42), WIT, root, (DC, YF - 0.2, H - 0.25)))
S(box("BordRand", (3.7, 0.05, 0.5), DONKER, root, (DC, YF - 0.17, H - 0.25)))


def tekst(naam, txt, size, material, loc, rot, extrude=0.012):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    t = bpy.context.active_object
    t.data.body = txt
    t.data.size = size
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.extrude = extrude
    t.name = naam
    bpy.ops.object.convert(target="MESH")
    t = bpy.context.active_object
    t.data.materials.append(material)
    for c in t.users_collection:
        c.objects.unlink(t)
    link(t, root)
    return t


S(tekst("BordTekst", "MOTORPOOL", 0.32, DONKER, (DC, YF - 0.255, H - 0.25), (math.pi / 2, 0, 0)))
S(tekst("DakTekst", "MOTORPOOL", 0.62, WIT, (DC - 0.6, -2.7, H + 0.222), (0, 0, 0)))
S(tekst("DakNummer", "07", 0.9, WIT, (DC - 0.6, -0.9, H + 0.222), (0, 0, 0)))
# ster op het dak
bm = bmesh.new()
vs = []
for i in range(10):
    a = math.pi / 2 + i * math.pi / 5
    rr = 0.55 if i % 2 == 0 else 0.22
    vs.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, 0)))
bm.faces.new(vs)
S(mesh_obj("DakSter", bm, WIT, root, (X1 - 0.75, -1.5, H + 0.226)))
# lampen boven de deur: gele kooilampen links en rechts, plus waarschuwingslicht rechts
for sx, nm in ((-1, "L"), (1, "R")):
    lx = DC + sx * (DW / 2 + 0.12)
    S(box(f"Lampsteun{nm}", (0.06, 0.4, 0.06), STAAL, root, (lx, YF - 0.2, H - 0.25)))
    S(cyl(f"Lampkop{nm}", 0.11, 0.11, 0.2, STAAL, "Y", 10, root, (lx, YF - 0.5, H - 0.25)))
    lamp = cyl(f"DeurlampMesh{nm}", 0.09, 0.09, 0.05, DEURLAMP, "Y", 10, root, (lx, YF - 0.63, H - 0.25))
    S(lamp)
    S(torus(f"Lampkooi{nm}", 0.13, 0.01, STAAL, root, (lx, YF - 0.65, H - 0.25), (math.pi / 2, 0, 0), 10, 4))
# kooi/beugel van het waarschuwingslicht
bx = DC + DW / 2 + 0.12
S(box("ZwaaiSteun", (0.06, 0.5, 0.06), STAAL, root, (bx, YF - 0.25, H + 0.35)))
S(cyl("ZwaaiVoet", 0.14, 0.14, 0.08, ZWART, "Z", 10, root, (bx, YF - 0.5, H + 0.4)))
S(cyl("ZwaaiLens", 0.1, 0.1, 0.2, ZWAAILENS, "Z", 12, root, (bx, YF - 0.5, H + 0.54)))
zwaai = empty("Zwaai", root, (bx, YF - 0.5, H + 0.54))
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=False, segments=10, radius1=0.125, radius2=0.125, depth=0.2)
bm.faces.ensure_lookup_table()
# halve cilinder als schaduwkap: verwijder de helft van de vlakken
kill = [f for f in bm.faces if f.calc_center_median().x < -0.01]
bmesh.ops.delete(bm, geom=kill, context="FACES")
kap = mesh_obj("ZwaaiKap", bm, ZWART, zwaai, smooth=True)
LOS.update({"Zwaai", "ZwaaiKap"})
# brandblusser en elektrakast naast de deur
S(cyl("Blusser", 0.06, 0.06, 0.32, RODE, "Z", 10, root, (DC - DW / 2 - 0.12, YF - 0.12, 1.1)))
S(box("Blusserbeugel", (0.14, 0.05, 0.06), STAAL, root, (DC - DW / 2 - 0.12, YF - 0.12, 1.2)))
S(box("Elektrakast", (0.2, 0.14, 0.45), STAAL, root, (DC + DW / 2 + 0.12, YF - 0.1, 1.3)))
S(box("ElektrakastDeur", (0.16, 0.02, 0.4), OLIJF, root, (DC + DW / 2 + 0.12, YF - 0.185, 1.3)))
# zandzakken: een smalle stapel voor elke deurpost (de opening blijft vrij voor tank en jeep) en rijen langs de linkerwand
for layer in range(2):
    for i in range(3):
        S(sphere(f"Zakzij{layer}{i}", 0.5, ZAND, root, (X0 - 0.55 - layer * 0.1, -3.2 + i * 0.85 + (layer % 2) * 0.4, 0.2 + layer * 0.28), (0.36, 0.9, 0.36)))
# regenpijp en kabelgoot aan de linkerkant
S(cyl("Regenpijp", 0.045, 0.045, H, STAAL, "Z", 8, root, (X0 - 0.08, YB - 0.4, H / 2)))
S(cyl("Pijpbocht", 0.045, 0.045, 0.3, STAAL, "Y", 8, root, (X0 - 0.08, YB - 0.25, 0.3)))
# ladder tegen de linkerwand naar het dak
for sy in (-1, 1):
    S(box(f"LadderStijl{sy}", (0.05, 0.05, H + 0.3), STAAL, root, (X0 - 0.18, -1.0 + sy * 0.22, (H + 0.3) / 2)))
for k in range(10):
    S(box(f"Sport{k}", (0.04, 0.44, 0.04), STAAL, root, (X0 - 0.18, -1.0, 0.3 + k * 0.3)))
# binnenin: werkbank, rek met jerrycans, olievat, hanglamp en banden
S(box("Werkbank", (0.7, 2.0, 0.08), HOUT, root, (X0 + 0.55, 2.3, 0.95)))
for sy in (-1, 1):
    for sx in (-1, 1):
        S(box(f"Bankpoot{sx}{sy}", (0.06, 0.06, 0.9), STAAL, root, (X0 + 0.55 + sx * 0.3, 2.3 + sy * 0.9, 0.5)))
S(box("Bankplank", (0.7, 2.0, 0.05), HOUT, root, (X0 + 0.55, 2.3, 0.35)))
S(box("Bankschroef", (0.18, 0.2, 0.16), STAAL, root, (X0 + 0.5, 1.6, 1.07)))
S(box("Gereedschapskist", (0.3, 0.55, 0.28), RODE, root, (X0 + 0.55, 2.8, 1.13)))
S(box("Hamer", (0.04, 0.3, 0.03), HOUT, root, (X0 + 0.6, 2.05, 1.0), (0, 0, 0.3)))
S(box("Moersleutel", (0.03, 0.34, 0.02), STAAL, root, (X0 + 0.45, 2.3, 1.0), (0, 0, -0.2)))
for k in range(3):
    S(box(f"Rekplank{k}", (0.5, 2.4, 0.04), STAAL, root, (X1 - 0.35, 2.8, 0.5 + k * 0.7)))
    for j in range(4):
        S(box(f"Rekcan{k}{j}", (0.28, 0.17, 0.34), OLIJF if (j + k) % 2 else VAAT_GEEL, root, (X1 - 0.35, 1.9 + j * 0.62, 0.7 + k * 0.7)))
for sy in (-1, 1):
    S(box(f"Rekstijl{sy}", (0.06, 0.06, 2.2), STAAL, root, (X1 - 0.1, 2.8 + sy * 1.2, 1.1)))
S(cyl("Binnenvat", 0.28, 0.28, 0.85, VAAT_ROEST, "Z", 14, root, (X0 + 0.5, YB - 0.55, 0.55)))
S(cyl("Hanglampsnoer", 0.01, 0.01, 0.5, ZWART, "Z", 5, root, (DC, 0.3, H - 0.25)))
S(cyl("Hanglamp", 0.25, 0.1, 0.12, STAAL, "Z", 12, root, (DC, 0.3, H - 0.55)))
S(cyl("HanglampGloei", 0.07, 0.07, 0.04, BINNENLAMP, "Z", 10, root, (DC, 0.3, H - 0.62)))
# erf rechts: olievaten, banden, jerrycans en een takel
vaten = [(2.95, -3.3, VAAT_ROEST), (3.55, -3.0, OLIJF), (3.2, -2.35, VAAT_GEEL), (3.6, -1.95, VAAT_ROEST), (2.95, 3.2, OLIJF), (3.5, 3.5, VAAT_ROEST)]
for k, (vx, vy, vm) in enumerate(vaten):
    S(cyl(f"Vat{k}", 0.28, 0.28, 0.85, vm, "Z", 14, root, (vx, vy, 0.5)))
    for dz in (-0.25, 0.0, 0.25):
        S(torus(f"Vatring{k}_{dz}", 0.285, 0.014, STAAL, root, (vx, vy, 0.5 + dz), segs=14, msegs=4))
    S(cyl(f"Vatdop{k}", 0.05, 0.05, 0.03, ZWART, "Z", 8, root, (vx + 0.1, vy + 0.1, 0.94)))
# liggend vat en gestapelde banden
S(cyl("LiggendVat", 0.28, 0.28, 0.85, VAAT_GEEL, "Y", 14, root, (3.3, -0.2, 0.34)))
for k in range(4):
    S(torus(f"Band{k}", 0.3, 0.12, BAND, root, (3.3, 0.9, 0.12 + k * 0.23), segs=14, msegs=7))
S(torus("BandStaand", 0.3, 0.12, BAND, root, (3.65, 1.7, 0.42), (math.pi / 2, 0, 0.5), 14, 7))
S(torus("BandStaand2", 0.3, 0.12, BAND, root, (3.1, 2.2, 0.32), (0.4, 0.9, 0.3), 14, 7))
# takelmast: pilaar + draaiende arm met haak
S(cyl("KraanVoet", 0.2, 0.22, 0.12, BETON, "Z", 10, root, (3.4, -0.9, 0.08)))
S(cyl("KraanPilaar", 0.07, 0.07, 3.3, STAAL, "Z", 10, root, (3.4, -0.9, 1.75)))
kraan = empty("Kraan", root, (3.4, -0.9, 3.3))
kraan.rotation_euler = (0, 0, -math.pi / 2)
arm = empty("Arm", kraan)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1)
bmesh.ops.scale(bm, vec=(1.7, 0.1, 0.12), verts=bm.verts)
bmesh.ops.translate(bm, verts=bm.verts, vec=(-0.8, 0, 0))
armmesh = mesh_obj("ArmMesh", bm, GEEL, arm)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1)
bmesh.ops.scale(bm, vec=(1.2, 0.05, 0.05), verts=bm.verts)
bmesh.ops.translate(bm, verts=bm.verts, vec=(-0.7, 0, -0.45))
bmesh.ops.rotate(bm, verts=bm.verts, cent=(-0.7, 0, -0.45), matrix=Matrix.Rotation(0.35, 3, "Y"))
steun = mesh_obj("ArmSteun", bm, STAAL, arm)
haak = empty("Haak", arm, (-1.55, 0, -0.06))
cyl("Kabel", 0.012, 0.012, 1.6, ZWART, "Z", 5, haak, (0, 0, -0.8))
blok = box("Katrol", (0.1, 0.1, 0.16), GEEL, haak, (0, 0, -1.6))
torus("Haakbocht", 0.07, 0.014, STAAL, haak, (0, 0, -1.74), (math.pi / 2, 0, 0), 10, 4)
LOS.update({"Kraan", "Arm", "ArmMesh", "ArmSteun", "Haak", "Kabel", "Katrol", "Haakbocht"})
armparts = [armmesh, steun]
join(armmesh, [steun])
armmesh.name = "ArmMesh"
haakparts = [o for o in haak.children if o.type == "MESH"]
join(haakparts[0], haakparts[1:])
haakparts[0].name = "HaakMesh"
LOS.add("HaakMesh")
# --- rolpoort: planken die bij het openen opgerold worden (schaal omhoog naar de bovenkant) ---
deur = empty("Deur", root, (DC, YF + 0.1, DH))
bm = bmesh.new()
nsl = 14
sh = DH / nsl
for k in range(nsl):
    zc = -sh * (k + 0.5)
    r = bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(DW - 0.04, 0.06, sh * 0.92), verts=r["verts"])
    bmesh.ops.translate(bm, verts=r["verts"], vec=(0, 0, zc))
    r2 = bmesh.ops.create_cube(bm, size=1)  # kleine rand per plank voor reliëf
    bmesh.ops.scale(bm, vec=(DW - 0.04, 0.025, sh * 0.2), verts=r2["verts"])
    bmesh.ops.translate(bm, verts=r2["verts"], vec=(0, -0.04, zc + sh * 0.3))
deurmesh = mesh_obj("DeurMesh", bm, PLAAT, deur)
# gele/zwarte waarschuwingsbalk onderaan
for k in range(18):
    box(f"Streep{k}", (0.26, 0.075, 0.2), GEEL if k % 2 == 0 else ZWART, deur, (-DW / 2 + 0.17 + k * 0.255, 0.0, -DH + 0.14))
box("DeurGreep", (0.5, 0.05, 0.04), STAAL, deur, (DW / 2 - 0.6, -0.06, -DH + 0.5))
LOS.add("Deur")
for o in list(deur.children):
    LOS.add(o.name)
deurparts = [o for o in deur.children if o.type == "MESH"]
join(deurparts[0], deurparts[1:])
deurparts[0].name = "DeurMesh"
# rolpoortkast (trommel) boven de deur, binnen
S(cyl("Trommel", 0.2, 0.2, DW, STAAL, "X", 14, root, (DC, YF + 0.35, DH + 0.2)))
# ---------- lampen voor het spel ----------
for sx, nm in ((-1, "L"), (1, "R")):
    sp = bpy.data.lights.new(f"DeurLamp{nm}", "SPOT")
    sp.energy = 8.0
    sp.spot_size = math.radians(80)
    sp.spot_blend = 0.6
    sp.color = (1.0, 0.82, 0.5)
    o = link(bpy.data.objects.new(sp.name, sp), root)
    o.location = (DC + sx * (DW / 2 + 0.12), YF - 0.7, H - 0.3)
    o.rotation_euler = (-math.radians(70), 0, 0)
    LOS.add(o.name)
zl = bpy.data.lights.new("ZwaaiLicht", "POINT")
zl.energy = 3.0
zl.color = (1.0, 0.45, 0.08)
zl.shadow_soft_size = 0.1
o = link(bpy.data.objects.new("ZwaaiLicht", zl), root)
o.location = (bx, YF - 0.6, H + 0.6)
LOS.add(o.name)
bl = bpy.data.lights.new("BinnenLamp", "POINT")
bl.energy = 2.5
bl.color = (1.0, 0.9, 0.7)
o = link(bpy.data.objects.new("BinnenLamp", bl), root)
o.location = (DC, 0.3, H - 0.7)
LOS.add("BinnenLamp")

# ---------- UV (wereldruimte) voor delen zonder eigen UV ----------
bpy.context.view_layer.update()
for o in list(scene.objects):
    if o.type == "MESH" and not o.data.uv_layers:
        me = o.data
        mw = o.matrix_world
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            n = mw.to_3x3() @ poly.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for li in poly.loop_indices:
                c = mw @ me.vertices[me.loops[li].vertex_index].co
                uv = (c.y, c.z) if ax == 0 else ((c.x, c.z) if ax == 1 else (c.x, c.y))
                uvl.data[li].uv = (uv[0] / 1.6, uv[1] / 1.6)

# romp samenvoegen
bpy.ops.object.select_all(action="DESELECT")
romp = stat[0]
for o in stat:
    if o.type == "MESH":
        o.select_set(True)
bpy.context.view_layer.objects.active = romp
bpy.ops.object.convert(target="MESH")
join(romp, [o for o in stat if o != romp and o.type == "MESH"])
romp.name = romp.data.name = "Romp"
bpy.ops.object.select_all(action="DESELECT")
romp.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ---------- animaties ----------
FPS = 30


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


ANIM = [deur, zwaai, kraan, arm, haak]


def clip(naam, duur, pose):
    """pose(t) -> dict objectnaam -> (location, rotation, scale) overrides."""
    frames = int(round(duur * FPS))
    for o in ANIM:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new(f"{naam}_{o.name}")
    basis = {o: (o.location.copy(), o.rotation_euler.copy(), o.scale.copy()) for o in ANIM}
    for f in range(frames + 1):
        t = f / FPS
        p = pose(t)
        for o in ANIM:
            loc, rot, scl = basis[o]
            ov = p.get(o.name, {})
            o.location = ov.get("loc", loc)
            o.rotation_euler = ov.get("rot", rot)
            o.scale = ov.get("scale", scl)
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    for o in ANIM:
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 0, a)
        st.name = naam
        o.animation_data.action = None
        o.location, o.rotation_euler, o.scale = basis[o]


DEUR_Z0 = deur.location.z
ROL = 0.1  # schaal van de opgerolde poort


def deur_pose(k, t):
    """k = 0 dicht, 1 open. Schalen rond de bovenkant (oorsprong), met een klein schokje."""
    sc = 1.0 - (1.0 - ROL) * k
    schok = 0.006 * math.sin(t * 80) * (1 if 0.02 < k < 0.98 else 0)
    return {"Deur": {"scale": (1, 1, sc), "loc": (DC + schok, YF + 0.1, DEUR_Z0)}}


def zwaai_pose(t, aan=True):
    return {"Zwaai": {"rot": (0, 0, (t / 1.0) * math.tau)}} if aan else {}


def kraan_pose(t):
    return {"Arm": {"rot": (0, 0, math.radians(14) * math.sin(t * math.tau / 8.0))},
            "Haak": {"rot": (math.radians(4) * math.sin(t * math.tau / 2.0 + 1), math.radians(3) * math.sin(t * math.tau / 3.0), 0)}}


clip("Open", 2.0, lambda t: deur_pose(ease(t / 2.0), t))
clip("Dicht", 2.0, lambda t: deur_pose(1.0 - ease(t / 2.0), t))


def show(t):
    k = ease(t / 2.0) if t < 3.0 else (1.0 if t < 6.0 else 1.0 - ease((t - 6.0) / 2.0))
    p = deur_pose(k, t)
    p.update(zwaai_pose(t, 0.0 < t < 8.0 and not (3.0 < t < 6.0)))
    p.update(kraan_pose(t))
    return p


clip("Show-loop", 8.0, show)
scene.frame_start, scene.frame_end = 0, 240
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "garage.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_lights=True, export_import_convert_lighting_mode="RAW",
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_optimize_animation_size=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "garage.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("TRIS", tris)
