"""Low-poly tank voor Bloedjungle met losse wielen en rupsschakels plus animaties. Blender +Y = voorkant (wordt -Z in Godot), 1 eenheid = 1 meter."""
import math, sys, os
import bpy, bmesh
import numpy as np
from mathutils import Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------- camo-textuur ----------
def camo_image(size=256):
    rng = np.random.default_rng(7)
    def noise(scale):
        g = rng.random((size // scale + 2, size // scale + 2))
        y, x = np.mgrid[0:size, 0:size] / scale
        x0, y0 = x.astype(int), y.astype(int)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
        b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
        return a * (1 - fy) + b * fy
    n1 = noise(48) * 0.6 + noise(20) * 0.3 + noise(6) * 0.1
    n2 = noise(40) * 0.6 + noise(16) * 0.3 + noise(5) * 0.1
    base = np.array([0.30, 0.34, 0.18])   # olijfgroen (sRGB)
    dark = np.array([0.17, 0.20, 0.11])
    brown = np.array([0.36, 0.29, 0.18])
    img = np.tile(base, (size, size, 1))
    img[n1 > 0.58] = dark
    img[(n2 > 0.62) & (n1 <= 0.58)] = brown
    grain = (noise(2) - 0.5) * 0.06
    img = np.clip(img + grain[..., None], 0, 1)
    im = bpy.data.images.new("tank_camo", size, size)
    rgba = np.concatenate([img, np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, "tank_camo.png")
    im.file_format = "PNG"
    im.save()
    return im

def mat(name, color, rough=0.8, metal=0.0, image=None):
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
    return m

CAMO = mat("Camo", (0.3, 0.34, 0.18), 0.75, 0.05, camo_image())
GROEN = mat("Donkergroen", (0.20, 0.23, 0.13), 0.8)
RUPS = mat("Rups", (0.10, 0.10, 0.09), 0.9, 0.3)
WIEL = mat("Wiel", (0.22, 0.24, 0.16), 0.8)
RUBBER = mat("Rubber", (0.06, 0.06, 0.06), 0.95)
METAAL = mat("Metaal", (0.18, 0.18, 0.17), 0.45, 0.7)
GLAS = mat("Lamp", (0.85, 0.82, 0.6), 0.2)
HOUT = mat("Kist", (0.33, 0.27, 0.17), 0.85)

def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj

def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = loc
    return link(o, parent)

def prism_x(name, profile_yz, width, material, parent=None, loc=(0, 0, 0)):
    """Profiel in Y/Z (zijaanzicht), geëxtrudeerd over X (breedte, gecentreerd)."""
    bm = bmesh.new()
    left = [bm.verts.new((-width / 2, y, z)) for y, z in profile_yz]
    right = [bm.verts.new((width / 2, y, z)) for y, z in profile_yz]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    n = len(profile_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([left[i], left[j], right[j], right[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, loc)

def box(name, size, material, parent=None, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    return mesh_obj(name, bm, material, parent, loc)

from mathutils import Matrix

def cyl(name, r1, r2, depth, material, axis="Z", segs=12, parent=None, loc=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    o = mesh_obj(name, bm, material, parent, loc, smooth)
    if smooth:
        o.data.set_sharp_from_angle(angle=math.radians(40))
    return o


def bevel(o, w=0.03, segs=1):
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = segs
    m.limit_method = "ANGLE"


LOS = []  # losse, bewegende delen (wielen, schakels): niet samenvoegen met de romp

# ---------- hiërarchie: Tank > Body > romp, wielen, schakels, Toren > Loop ----------
root = link(bpy.data.objects.new("Tank", None))
body = link(bpy.data.objects.new("Body", None), root)

romp = prism_x("Romp", [(-3.0, 0.55), (3.05, 0.55), (3.45, 0.95), (3.1, 1.45), (-2.85, 1.45), (-3.15, 1.1)],
               2.3, CAMO, body)
bevel(romp, 0.04)
dek = box("Motordek", (1.9, 1.5, 0.12), GROEN, body, (0, -2.05, 1.5))
bevel(dek, 0.02)
for i in range(6):
    box(f"Rooster{i}", (1.7, 0.08, 0.04), METAAL, body, (0, -2.65 + i * 0.24, 1.57))

# Rupsprofiel (y, z) in zijaanzicht; de schakels lopen hieromheen.
PROFIEL = [(-3.3, 0.55), (-3.0, 0.12), (-2.6, 0.0), (2.75, 0.0), (3.2, 0.2), (3.55, 0.75),
           (3.3, 1.02), (-3.2, 1.02), (-3.45, 0.8)]


def chaikin(pts, n=3):
    for _ in range(n):
        out = []
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        pts = out
    return pts


PAD = chaikin(PROFIEL)
SEG = []
for i in range(len(PAD)):
    a, b = PAD[i], PAD[(i + 1) % len(PAD)]
    SEG.append((a, b, math.hypot(b[0] - a[0], b[1] - a[1])))
OMTREK = sum(s[2] for s in SEG)
N_SCHAKEL = int(OMTREK / 0.36)
STEEK = OMTREK / N_SCHAKEL


def op_pad(s):
    """Positie (y, z) en hoek langs de rups op booglengte s."""
    s %= OMTREK
    for a, b, l in SEG:
        if s <= l:
            k = s / l
            return a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, math.atan2(b[1] - a[1], b[0] - a[0])
        s -= l
    a, b, l = SEG[-1]
    return b[0], b[1], math.atan2(b[1] - a[1], b[0] - a[0])


WIELEN = {}   # naam -> (object, straal, symmetrie-hoek)
SCHAKELS = {"L": [], "R": []}
for side, sx in (("L", -1), ("R", 1)):
    x = sx * 1.47
    # donkere kern van de rupsband (iets kleiner), de schakels liggen eromheen
    kern = prism_x(f"Rupskern{side}", [(y * 0.985, 0.03 + z * 0.94) for y, z in PROFIEL], 0.5, RUPS, body, (x, 0, 0))
    bevel(kern, 0.05)
    for i in range(N_SCHAKEL):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=(0.7, STEEK * 0.86, 0.06), verts=bm.verts)
        nok = bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=(0.7, 0.07, 0.05), verts=nok["verts"])
        bmesh.ops.translate(bm, vec=(0, 0, -0.05), verts=nok["verts"])
        o = mesh_obj(f"Schakel{side}{i:02d}", bm, RUBBER if i % 2 else RUPS, body)
        y, z, a = op_pad(i * STEEK)
        o.location = (x, y, z)
        o.rotation_euler = (a, 0, 0)
        SCHAKELS[side].append(o)
        LOS.append(o)

    def wiel(naam, r, breed, mat_, y, z, bouten, steun=False):
        w = cyl(naam, r, r, breed, mat_, "X", 16 if not steun else 8, body, (x + sx * 0.34, y, z))
        delen = [cyl(naam + "naaf", r * 0.35, r * 0.28, breed + 0.08, METAAL, "X", 8, w)]
        for k in range(bouten):
            a = k * math.tau / bouten
            delen.append(box(naam + f"bout{k}", (breed + 0.05, 0.05, 0.05), METAAL, w,
                             (0, math.cos(a) * r * 0.62, math.sin(a) * r * 0.62)))
        if not steun:
            delen.append(cyl(naam + "band", r * 1.02, r * 1.02, breed * 0.35, RUBBER, "X", 16, w,
                             (sx * breed * 0.32, 0, 0)))
        bpy.ops.object.select_all(action="DESELECT")
        for d in delen:
            d.select_set(True)
        w.select_set(True)
        bpy.context.view_layer.objects.active = w
        bpy.ops.object.join()
        WIELEN[naam] = (w, r, math.tau / bouten)
        LOS.append(w)

    for i in range(6):
        wiel(f"Wiel{side}{i}", 0.4, 0.14, WIEL, -2.35 + i * 0.93, 0.42, 6)
    # aandrijfwiel met tanden achter, spanwiel voor, steunrollen boven
    tw = cyl(f"Tandwiel{side}", 0.34, 0.34, 0.16, METAAL, "X", 10, body, (x + sx * 0.34, -3.05, 0.62))
    tanden = [box(f"Tand{side}{k}", (0.12, 0.09, 0.14), METAAL, tw,
                  (0, math.cos(k * math.tau / 10) * 0.38, math.sin(k * math.tau / 10) * 0.38)) for k in range(10)]
    for k, t_ in enumerate(tanden):
        t_.rotation_euler = (k * math.tau / 10, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    for d in tanden:
        d.select_set(True)
    tw.select_set(True)
    bpy.context.view_layer.objects.active = tw
    bpy.ops.object.join()
    WIELEN[f"Tandwiel{side}"] = (tw, 0.42, math.tau / 10)
    LOS.append(tw)
    wiel(f"Spanwiel{side}", 0.32, 0.14, WIEL, 3.2, 0.62, 5)
    for i in range(3):
        wiel(f"Steunrol{side}{i}", 0.1, 0.1, METAAL, -1.6 + i * 1.5, 0.95, 4, steun=True)

    sb = prism_x(f"Spatbord{side}", [(-3.25, 1.10), (3.3, 1.10), (3.6, 0.92), (3.6, 0.86), (3.25, 1.04), (-3.25, 1.04)],
                 0.8, GROEN, body, (x + sx * 0.02, 0, 0))
    for i, y in enumerate((-1.9, -0.6)):
        k = box(f"Kist{side}{i}", (0.55, 1.05, 0.38), HOUT if i else GROEN, body, (x, y, 1.30))
        bevel(k, 0.03)
    cyl(f"Lamp{side}", 0.11, 0.11, 0.14, GLAS, "Y", 10, body, (sx * 0.85, 3.25, 1.3))
    box(f"Lampkap{side}", (0.3, 0.12, 0.05), METAAL, body, (sx * 0.85, 3.25, 1.43))
for i, x in enumerate((-0.6, 0.6)):
    cyl(f"Vat{i}", 0.26, 0.26, 0.8, GROEN, "X", 12, body, (x, -3.2, 1.25))
cyl("Bestuurderluik", 0.3, 0.28, 0.08, GROEN, "Z", 12, body, (0.55, 2.25, 1.5))
# uitlaten achter (voor rook in het spel)
for sx in (-1, 1):
    cyl(f"Uitlaat{sx}", 0.09, 0.09, 0.3, METAAL, "Y", 8, body, (sx * 0.75, -3.25, 0.95))
uitlaat = link(bpy.data.objects.new("Uitlaat", None), body)
uitlaat.location = (0, -3.45, 0.95)

# ---------- toren (draait om Z) en kanon (kantelt om X) ----------
toren = link(bpy.data.objects.new("Toren", None), body)
toren.location = (0, 0.2, 1.45)
koepel = cyl("TorenKoepel", 1.45, 1.12, 0.75, CAMO, "Z", 16, toren, (0, 0, 0.37))
koepel.scale = (0.95, 1.25, 1.0)
koepel.location = (0, -0.1, 0.37)
cyl("TorenRing", 1.3, 1.3, 0.1, METAAL, "Z", 16, toren, (0, 0, 0.03))
ab = box("TorenAchterbak", (1.7, 0.9, 0.45), GROEN, toren, (0, -1.75, 0.38))
bevel(ab, 0.04)
cyl("Commandokoepel", 0.38, 0.33, 0.32, GROEN, "Z", 12, toren, (-0.45, -0.45, 0.88))
cyl("Commandoluik", 0.33, 0.3, 0.07, METAAL, "Z", 12, toren, (-0.45, -0.45, 1.07))
cyl("Laderluik", 0.28, 0.27, 0.07, GROEN, "Z", 12, toren, (0.5, -0.3, 0.78))
box("MGBody", (0.1, 0.55, 0.13), METAAL, toren, (-0.45, -0.25, 1.22))
cyl("MGLoop", 0.025, 0.025, 0.7, METAAL, "Y", 6, toren, (-0.45, 0.3, 1.24))
box("MGKist", (0.14, 0.16, 0.14), GROEN, toren, (-0.33, -0.3, 1.15))
for sx in (-1, 1):
    for i in range(3):
        cyl(f"Rook{sx}{i}", 0.06, 0.06, 0.3, METAAL, "Y", 8, toren, (sx * (0.95 + i * 0.1), 0.85 - i * 0.12, 0.45))
cyl("Antenne1", 0.015, 0.008, 2.0, METAAL, "Z", 5, toren, (0.7, -2.0, 1.6), smooth=False)
cyl("Antenne2", 0.015, 0.008, 1.5, METAAL, "Z", 5, toren, (-0.7, -2.0, 1.35), smooth=False)

loop = link(bpy.data.objects.new("Loop", None), toren)
loop.location = (0, 1.25, 0.42)
mantel = box("Mantel", (0.75, 0.5, 0.55), GROEN, loop, (0, 0.1, 0))
bevel(mantel, 0.06, 2)
cyl("Kanon", 0.12, 0.1, 3.6, METAAL, "Y", 12, loop, (0, 2.1, 0))
cyl("Rookafzuiger", 0.16, 0.16, 0.5, GROEN, "Y", 12, loop, (0, 2.3, 0))
cyl("Mondingsrem", 0.15, 0.15, 0.3, METAAL, "Y", 8, loop, (0, 3.95, 0))
mond = link(bpy.data.objects.new("Monding", None), loop)
mond.location = (0, 4.15, 0)

# ---------- UV's, modifiers, samenvoegen ----------
for o in list(scene.objects):
    if o.type == "MESH":
        bpy.context.view_layer.objects.active = o
        for s in scene.objects:
            s.select_set(s == o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=2.5)
        bpy.ops.object.mode_set(mode="OBJECT")
for o in scene.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = romp
bpy.ops.object.convert(target="MESH")
los_namen = {o.name for o in LOS}
for parent, naam, eerste in ((body, "RompMesh", romp), (toren, "TorenMesh", koepel), (loop, "LoopMesh", mantel)):
    delen = [o for o in parent.children if o.type == "MESH" and o.name not in los_namen]
    bpy.ops.object.select_all(action="DESELECT")
    for o in delen:
        o.select_set(True)
    bpy.context.view_layer.objects.active = eerste
    bpy.ops.object.join()
    eerste.name = eerste.data.name = naam
    bpy.ops.object.select_all(action="DESELECT")
    eerste.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
loopmesh = bpy.data.objects["LoopMesh"]
bpy.data.images["tank_camo"].pack()

# ---------- animaties ----------
FPS = 30
scene.render.fps = FPS
LUS = 2.0  # seconden; alle lussen zijn hierop afgestemd zodat ze naadloos herhalen


def ease(t):
    return t * t * (3 - 2 * t)


def snap_snelheid(v):
    """Rupssnelheid zo afronden dat de schakels in LUS seconden een geheel aantal steken opschuiven."""
    k = round(v * LUS / STEEK)
    return k * STEEK / LUS


def clip(naam, duur, rups, pose, loop_y=lambda t: 0.0):
    """rups(t) -> (vL, vR) in m/s (positief = vooruit); pose(t) -> (x, y, z, pitch, roll) van Body."""
    frames = int(round(duur * FPS))
    objs = [body, loopmesh] + [w for w, _, _ in WIELEN.values()] + SCHAKELS["L"] + SCHAKELS["R"]
    for o in objs:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new(f"{naam}_{o.name}")
    basis = {o: (o.location.copy(), o.rotation_euler.copy()) for o in objs}
    afstand = {"L": 0.0, "R": 0.0}
    eind = {"L": 0.0, "R": 0.0}
    for f in range(1, frames + 1):
        vl, vr = rups(f / FPS)
        eind["L"] += vl / FPS
        eind["R"] += vr / FPS
    # per wiel een kleine correctie zodat de eindhoek een geheel aantal boutstappen is (naadloze lus)
    corr = {}
    for n, (w, r, sym) in WIELEN.items():
        side = n[-1] if n[-1] in "LR" else n[-2]
        raw = eind[side] / r
        corr[n] = (round(raw / sym) * sym / raw) if abs(raw) > 1e-6 and round(raw / sym) else 1.0
    for f in range(frames + 1):
        t = f / FPS
        if f:
            vl, vr = rups(t)
            afstand["L"] += vl / FPS
            afstand["R"] += vr / FPS
        x, y, z, pitch, roll = pose(t)
        body.location = (x, y, z)
        body.rotation_euler = (pitch, roll, 0)
        body.keyframe_insert("location", frame=f)
        body.keyframe_insert("rotation_euler", frame=f)
        lp = basis[loopmesh][0]
        loopmesh.location = (lp.x, lp.y + loop_y(t), lp.z)
        loopmesh.keyframe_insert("location", frame=f)
        for side in ("L", "R"):
            for i, o in enumerate(SCHAKELS[side]):
                # bij vooruit rijden schuift de onderkant naar achteren: booglengte neemt af
                yy, zz, a = op_pad(i * STEEK - afstand[side])
                o.location = (basis[o][0].x, yy, zz)
                o.rotation_euler = (a, 0, 0)
                o.keyframe_insert("location", frame=f)
                o.keyframe_insert("rotation_euler", frame=f)
        for n, (w, r, sym) in WIELEN.items():
            side = n[-1] if n[-1] in "LR" else n[-2]
            totaal = afstand[side]
            w.rotation_euler = (-totaal / r * corr[n], 0, 0)
            w.keyframe_insert("rotation_euler", frame=f)
    for o in objs:
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 0, a)
        st.name = naam
        o.animation_data.action = None
        o.location, o.rotation_euler = basis[o]


def tril(t, sterk=1.0):
    """Motortrilling: snelle kleine beweging, periode deelt LUS."""
    return (0.004 * sterk * math.sin(t * math.tau * 15), 0.0025 * sterk * math.sin(t * math.tau * 10 + 1.3))


V_RIJ = snap_snelheid(3.2)
V_ACH = snap_snelheid(1.8)
V_DRAAI = snap_snelheid(1.6)

clip("Stationair-loop", LUS, lambda t: (0, 0),
     lambda t: (0, 0, tril(t)[0], tril(t)[1], 0.0015 * math.sin(t * math.tau * 5)))

clip("Rijden-loop", LUS, lambda t: (V_RIJ, V_RIJ),
     lambda t: (0, 0, 0.012 * math.sin(t * math.tau * 2) + tril(t, 0.6)[0],
                math.radians(-0.9) + math.radians(0.7) * math.sin(t * math.tau * 1 + 0.4) + tril(t, 0.6)[1],
                math.radians(0.6) * math.sin(t * math.tau * 0.5)))

clip("Achteruit-loop", LUS, lambda t: (-V_ACH, -V_ACH),
     lambda t: (0, 0, 0.01 * math.sin(t * math.tau * 2) + tril(t, 0.6)[0],
                math.radians(0.7) + math.radians(0.5) * math.sin(t * math.tau + 1.0) + tril(t, 0.6)[1],
                math.radians(0.5) * math.sin(t * math.tau * 0.5)))

clip("Draaien-loop", LUS, lambda t: (-V_DRAAI, V_DRAAI),
     lambda t: (0, 0, 0.008 * math.sin(t * math.tau * 2) + tril(t, 0.7)[0], tril(t, 0.7)[1],
                math.radians(-1.0) + math.radians(0.4) * math.sin(t * math.tau)))


def schiet_pose(t):
    # de terugslag duwt de neus omhoog; de vering laat de romp een paar keer na-wippen
    k = math.exp(-t * 3.2)
    pitch = math.radians(2.6) * k * math.sin(t * math.tau * 1.6 + 0.35)
    z = 0.03 * k * math.sin(t * math.tau * 1.6)
    y = -0.06 * k * math.sin(min(t * 6, math.pi / 2))
    tz, tp = tril(t)
    return (0, y, z + tz, pitch + tp, 0)


def terugslag(t):
    if t < 0.06:
        return -0.55 * ease(t / 0.06)
    return -0.55 * (1 - ease(min(1.0, (t - 0.06) / 0.9)))


clip("Schieten", 1.6, lambda t: (0, 0), schiet_pose, terugslag)

scene.frame_start, scene.frame_end = 0, 60
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "tank.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_force_sampling=True, export_optimize_animation_size=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tank.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("TRIS", tris, "SCHAKELS", N_SCHAKEL, "STEEK", round(STEEK, 3), "V", round(V_RIJ, 2))
