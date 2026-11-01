"""Hoofdkwartier (HK), Blender-bron. Eenheden in meters, Z omhoog in Blender (glTF zet het om naar Y omhoog).
De voorkant (deur) wijst naar Blender -Y; dat wordt +Z in Godot, naar de toegang van de basis.

Gebruik (Blender als Python-module, bijvoorbeeld `pip install bpy` in een venv):

    python bron/hoofdkwartier/maak_hoofdkwartier.py hq     # bewerkbaar bronmodel: uit/Hoofdkwartier_HQ.blend/.glb/.usdz
    python bron/hoofdkwartier/maak_hoofdkwartier.py game   # Godot-versie: assets/hoofdkwartier.glb
    python bron/hoofdkwartier/maak_hoofdkwartier.py lod1   # uitgezoomd: assets/hoofdkwartier_lod1.glb

Ontwerp: bron/hoofdkwartier/ASSET_DESIGN_SPEC.md. Hergebruikt de helpers en het wapperende vlagdoek van
bron/verzamelvlag/maak_verzamelvlag.py en de goedgekeurde VQ2-materiaalsets (concrete, olive, steel).
Clips: Radar-loop (schotel draait rond), Open en Dicht (pantserdeur), Wapperen-loop (vlag).
Godot schakelt de onderdelen Niveau2 en Niveau3 aan, de schadelagen Schade1 en Schade2, en laat de lampen knipperen of gloeien.
"""
import math
import random
import sys
from pathlib import Path

import bpy  # moet voor bmesh/mathutils
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "bron/verzamelvlag"))
import maak_verzamelvlag as F  # noqa: E402  (zelfde niveau-argument: hq, game of lod1)

OUT = HERE / "uit"
OUT.mkdir(exist_ok=True)
F.OUT = OUT  # tussenbestanden van de helpers (getinte texturen, doektextuur) komen hier terecht
LEVEL = F.LEVEL
D = {"hq": 2, "game": 1, "lod1": 0}[LEVEL]
TEXRES = {"hq": 1024, "game": 1024, "lod1": 512}[LEVEL]  # VQ2-brontexturen zijn native 1024 px
SEG = {"hq": 48, "game": 20, "lod1": 10}[LEVEL]
FPS = 30

W = 5.0            # breedte en diepte van de begane grond (spelcollider 5,0 x 5,0)
Z0 = 0.35          # bovenkant sokkel
Z1 = 2.75          # bovenkant begane grond
UW = 3.8           # bovenverdieping
Z2 = 5.0           # dakplaat boven


# ------------------------------------------------------------------ geometrie
def add_box(bm, c, s, rot=0.0):
    m = Matrix.Translation(c) @ Matrix.Rotation(rot, 4, "Z") @ Matrix.Diagonal((s[0], s[1], s[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def add_cyl(bm, c, r, h, seg=None, axis="Z", r2=None):
    seg = seg or max(6, SEG // 2)
    rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2,
                          depth=h, matrix=Matrix.Translation(c) @ rot)


def bevel_all(bm, width):
    if LEVEL == "hq":
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=width, segments=2, affect="EDGES", profile=0.6)


def uvw(bm, tile=2.0):
    """Wereldgebonden UV's per vlak (dominante as), zodat de textuurdichtheid overal gelijk is."""
    bm.normal_update()
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = ((1, 2), (0, 2), (0, 1))[ax]
        for lp in f.loops:
            p = lp.vert.co
            lp[uv].uv = (p[a] / tile, p[b] / tile)


def obj(name, bm, mat, parent, smooth=False, tile=2.0, bevel=0.0):
    if bevel:
        bevel_all(bm, bevel)
    uvw(bm, tile)
    o = F.new_obj(name, bm, mat, smooth=smooth, parent=parent)
    return o


def empty(name, parent, loc=(0, 0, 0), scale=1.0):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    e.scale = (scale, scale, scale)
    return e


def seq_boxes(bm, y, xs, zc, size):
    for x in xs:
        add_box(bm, (x, y, zc), size)


# ------------------------------------------------------------------ textuur: camonet en schade
def make_net_texture(res):
    rng = np.random.default_rng(11)
    lo = rng.random((res // 32, res // 32)).astype(np.float32)
    big = np.asarray(Image.fromarray((lo * 255).astype(np.uint8)).resize((res, res), Image.BICUBIC), dtype=np.float32) / 255.0
    fine = np.asarray(Image.fromarray((rng.random((res // 6, res // 6)) * 255).astype(np.uint8)).resize((res, res), Image.BICUBIC), dtype=np.float32) / 255.0
    alpha = ((big * 0.7 + fine * 0.5) > 0.50).astype(np.float32)
    cols = np.array([[0.13, 0.17, 0.07], [0.20, 0.23, 0.10], [0.25, 0.20, 0.11], [0.09, 0.11, 0.06]], dtype=np.float32)
    idx = np.clip((big * 3.99).astype(np.int32), 0, 3)
    rgb = cols[idx] * (0.8 + 0.4 * fine[..., None])
    img = np.dstack([np.clip(rgb, 0, 1), alpha])
    p = OUT / f"camonet_{res}.png"
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(p)
    return p


def make_damage_texture(res):
    """Twee helften naast elkaar: links lichte roetvlekken en strepen, rechts zware brandplekken met scheuren."""
    W2, H2 = res * 2, res
    img = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
    rng = random.Random(5)

    def blotch(layer, cx, cy, r, a):
        d = ImageDraw.Draw(layer)
        for k in range(14):
            rr = r * (1.0 - k / 16)
            ox, oy = rng.uniform(-r, r) * 0.12, rng.uniform(-r, r) * 0.12
            d.ellipse((cx - rr + ox, cy - rr + oy, cx + rr + ox, cy + rr + oy), fill=(12, 10, 8, int(a / 14 * 3.2)))

    left = Image.new("RGBA", (res, res), (0, 0, 0, 0))
    for _ in range(5):
        blotch(left, rng.uniform(0.2, 0.8) * res, rng.uniform(0.3, 0.9) * res, rng.uniform(0.08, 0.2) * res, 150)
    ds = ImageDraw.Draw(left)
    for _ in range(18):  # roetstrepen naar boven
        x = rng.uniform(0.1, 0.9) * res
        ds.line((x, res * rng.uniform(0.4, 1.0), x + rng.uniform(-8, 8), res * rng.uniform(0.0, 0.4)), fill=(10, 9, 8, 70), width=rng.randint(2, 7))
    left = left.filter(ImageFilter.GaussianBlur(4))
    right = Image.new("RGBA", (res, res), (0, 0, 0, 0))
    for _ in range(7):
        blotch(right, rng.uniform(0.15, 0.85) * res, rng.uniform(0.25, 0.9) * res, rng.uniform(0.12, 0.26) * res, 235)
    right = right.filter(ImageFilter.GaussianBlur(3))
    dr = ImageDraw.Draw(right)
    for _ in range(9):  # scheuren
        x, y = rng.uniform(0.1, 0.9) * res, rng.uniform(0.1, 0.9) * res
        pts = [(x, y)]
        for _ in range(9):
            x += rng.uniform(-30, 30)
            y += rng.uniform(10, 60)
            pts.append((x, y))
        dr.line(pts, fill=(6, 5, 5, 255), width=3)
        dr.line([(px + 2, py) for px, py in pts], fill=(70, 66, 60, 150), width=1)
    img.paste(left, (0, 0))
    img.paste(right, (res, 0))
    p = OUT / f"schade_{res}.png"
    img.save(p)
    return p


def alpha_mat(name, path, double_sided=True):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    n, l = mat.node_tree.nodes, mat.node_tree.links
    b = n["Principled BSDF"]
    t = n.new("ShaderNodeTexImage")
    t.image = F.load_img(path)
    l.new(t.outputs["Color"], b.inputs["Base Color"])
    l.new(t.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = 0.9
    mat.surface_render_method = "BLENDED"
    mat.use_backface_culling = not double_sided
    return mat


# ------------------------------------------------------------------ onderdelen
def build_body(M, root):
    """Begane grond, sokkel, bovenverdieping, daken, pantserplaten, schietsleuven en de details."""
    # sokkel + begane grond + daklip
    bm = bmesh.new()
    add_box(bm, (0, 0, Z0 / 2), (W + 0.3, W + 0.3, Z0))
    add_box(bm, (0, 0, (Z0 + Z1) / 2), (W, W, Z1 - Z0))
    add_box(bm, (0, 0, Z1 + 0.06), (W + 0.12, W + 0.12, 0.12))           # daklip begane grond
    add_box(bm, (0, 0, (Z1 + 0.12 + 3.6) / 2 - 0.04), (UW, UW, 3.6 - Z1 - 0.12 + 0.08))  # onderdeel bovenverdieping (kniemuur)
    # kniemuur-lijst en dakplaat
    add_box(bm, (0, 0, Z2 - 0.1), (UW + 0.5, UW + 0.5, 0.22))
    add_box(bm, (0, 0, Z2 + 0.09), (UW + 0.62, UW + 0.62, 0.16))        # dakrand
    # borstwering rond het dak
    for sgn in (-1, 1):
        add_box(bm, (0, sgn * (UW / 2 + 0.25), Z2 + 0.28), (UW + 0.62, 0.12, 0.28))
        add_box(bm, (sgn * (UW / 2 + 0.25), 0, Z2 + 0.28), (0.12, UW + 0.1, 0.28))
    obj("Romp", bm, M["beton"], root, tile=2.5, bevel=0.025)

    # pantserplaten onderaan elke zijde (olijfgroen staal) met bouten
    bm = bmesh.new()
    bolt = bmesh.new()
    zc = 0.95
    for side in range(4):
        yaw = side * math.pi / 2
        n = 4
        for i in range(n):
            x = -W / 2 + (i + 0.5) * W / n
            if side == 0 and abs(x) < 0.95:
                continue  # hier zit de deur
            c = Matrix.Rotation(yaw, 4, "Z") @ Vector((x, -W / 2 - 0.04, zc))
            add_box(bm, c, (W / n - 0.08, 0.08, 1.05), rot=yaw)
            if D >= 1:
                for bx in (-1, 1):
                    for bz in ((-0.4, 0.4) if D == 1 else (-0.42, 0.0, 0.42)):
                        cb = Matrix.Rotation(yaw, 4, "Z") @ Vector((x + bx * (W / n / 2 - 0.14), -W / 2 - 0.09, zc + bz))
                        add_cyl(bolt, cb, 0.028, 0.03, seg=6 if D == 1 else 10, axis="Y")
    # bovenverdieping: stalen band onder het glas en boven het glas
    for z, h in ((3.58, 0.14), (4.67, 0.14)):
        add_box(bm, (0, 0, z), (UW + 0.08, UW + 0.08, h))
    obj("Platen", bm, M["staal"], root, tile=1.5, bevel=0.012)
    if D >= 1 and bolt.verts:
        obj("Bouten", bolt, M["donker"], root, tile=0.5)
    else:
        bolt.free()

    # donkere details: schietsleuven, deurkozijn en -binnenkant, glaspijlers, ventilatie, leiding, ladders
    bm = bmesh.new()
    for side in range(1, 4):  # sleuven op achter- en zijkanten
        yaw = side * math.pi / 2
        for i in range(3):
            x = -1.5 + i * 1.5
            c = Matrix.Rotation(yaw, 4, "Z") @ Vector((x, -W / 2 - 0.012, 2.15))
            add_box(bm, c, (0.85, 0.05, 0.13), rot=yaw)
    for i in (-1.6, 1.6):  # sleuven voorzijde naast de deur
        add_box(bm, (i, -W / 2 - 0.012, 2.15), (0.85, 0.05, 0.13))
    # deurkozijn: twee stijlen en een latei, achter de deur een donkere nis
    for x in (-0.82, 0.82):
        add_box(bm, (x, -W / 2 - 0.07, 1.4), (0.14, 0.12, 2.15))
    add_box(bm, (0, -W / 2 - 0.07, 2.52), (1.78, 0.12, 0.16))
    add_box(bm, (0, -W / 2 - 0.018, 1.4), (1.5, 0.03, 2.0))       # donkere nis achter de deur
    # glaspijlers
    for side in range(4):
        yaw = side * math.pi / 2
        n = 4 if D >= 1 else 2
        for i in range(n + 1):
            x = -UW / 2 + i * UW / n
            c = Matrix.Rotation(yaw, 4, "Z") @ Vector((x, -UW / 2 - 0.02, 4.12))
            add_box(bm, c, (0.07, 0.07, 1.1), rot=yaw)
    # ventilatieroosters en airco op de oostwand
    if D >= 1:
        for y in (-1.3, 0.3):
            add_box(bm, (W / 2 + 0.17, y, 1.55), (0.34, 0.9, 0.7))
            for k in range(5 if D == 2 else 3):
                add_box(bm, (W / 2 + 0.345, y, 1.30 + k * 0.12), (0.02, 0.8, 0.045))
        # leiding langs de achterwand naar boven
        add_cyl(bm, (-1.9, W / 2 + 0.08, (Z0 + Z1) / 2), 0.05, Z1 - Z0, seg=8)
        add_cyl(bm, (-1.9, W / 2 + 0.08, Z1 - 0.3), 0.075, 0.12, seg=8)
    # ladders: begane grond en bovenverdieping (oostkant)
    for (xl, z_a, z_b) in ((W / 2 + 0.06, Z0, Z1 + 0.5), (UW / 2 + 0.06, Z1 + 0.12, Z2 + 0.5)):
        for dy in (-0.2, 0.2):
            add_box(bm, (xl, 1.7 + dy, (z_a + z_b) / 2), (0.05, 0.05, z_b - z_a))
        z = z_a + 0.25
        while z < z_b - 0.15:
            add_cyl(bm, (xl, 1.7, z), 0.017, 0.4, axis="Y", seg=6)
            z += 0.3
    obj("Metaal", bm, M["donker"], root, tile=1.0)

    # glaswanden
    bm = bmesh.new()
    for side in range(4):
        yaw = side * math.pi / 2
        c = Matrix.Rotation(yaw, 4, "Z") @ Vector((0, -UW / 2 - 0.005, 4.12))
        add_box(bm, c, (UW - 0.1, 0.03, 1.08), rot=yaw)
    obj("Glas", bm, M["glas"], root, tile=2.0)

    # binnenkant bovenverdieping: donkere ruimte met lichtgevende schermen (versierd, in een eigen materiaal)
    bm = bmesh.new()
    add_box(bm, (0, 0, 4.12), (UW - 0.3, UW - 0.3, 1.0))
    obj("Binnen", bm, M["donker"], root, tile=2.0)
    if D >= 1:
        bm = bmesh.new()
        for i, x in enumerate((-1.2, -0.4, 0.4, 1.2)):
            add_box(bm, (x, -UW / 2 + 0.52, 3.95), (0.55, 0.05, 0.32))
        for x in (-1.2, 1.2):
            add_box(bm, (x, UW / 2 - 0.52, 3.95), (0.55, 0.05, 0.32))
        obj("Schermen", bm, M["amber"], root, tile=1.0)

    # tekst HQ en een ster boven de deur
    bm = bmesh.new()
    # ster: vijfpuntig, plat tegen de muur (voorkant, -Y)
    pts = []
    for k in range(10):
        r = 0.34 if k % 2 == 0 else 0.14
        a = math.pi / 2 + k * math.pi / 5
        pts.append((r * math.cos(a), r * math.sin(a)))
    vs = [bm.verts.new((-1.55 + px, -W / 2 - 0.03, 2.0 + 0.42 + py * 1.0)) for px, py in pts]
    ctr = bm.verts.new((-1.55, -W / 2 - 0.03, 2.42))
    for k in range(10):
        bm.faces.new((ctr, vs[(k + 1) % 10], vs[k]))
    obj("Ster", bm, M["wit"], root, tile=1.0)
    bpy.ops.object.text_add(location=(0.0, -W / 2 - 0.035, 2.2), rotation=(math.pi / 2, 0, 0))
    t = bpy.context.active_object
    t.name = "HQ_letters"
    t.data.body = "HQ"
    t.data.size = 0.42
    t.data.extrude = 0.015
    t.data.align_x = "CENTER"
    bpy.ops.object.convert(target="MESH")
    t = bpy.context.active_object
    t.data.materials.append(M["wit"])
    t.parent = root
    t.location = (1.55, -W / 2 - 0.035, 2.14)
    return root


def build_door(M, root):
    """Pantserdeur die zijwaarts in de muur schuift (clips Open en Dicht); geeft de empty terug."""
    door = empty("Deur", root, (0, -W / 2 - 0.145, 1.4))
    bm = bmesh.new()
    add_box(bm, (0, 0, 0), (1.5, 0.1, 2.0))
    obj("Deurblad", bm, M["staal"], door, tile=1.5, bevel=0.012)
    bm = bmesh.new()
    n = 7 if D >= 1 else 4
    for i in range(n):
        if i % 2 == 0:
            add_box(bm, (-0.62 + i * 0.2, -0.056, -0.86), (0.1, 0.012, 0.26))
    add_box(bm, (0.5, -0.06, 0.05), (0.08, 0.04, 0.22))    # handgreep
    add_box(bm, (0, -0.058, 0.55), (1.38, 0.014, 0.04))
    obj("Deurstrepen", bm, M["wit"], door, tile=1.0)
    # luifel met twee steunen en een lamp
    bm = bmesh.new()
    add_box(bm, (0, -W / 2 - 0.4, 2.72), (2.2, 0.8, 0.1))
    for x in (-1.0, 1.0):
        add_box(bm, (x, -W / 2 - 0.72, 1.4), (0.08, 0.08, 2.65))
        add_box(bm, (x * 0.8, -W / 2 - 0.4, 2.5), (0.05, 0.7, 0.05), rot=0.0)
    obj("Luifel", bm, M["donker"], root, tile=1.0)
    bm = bmesh.new()
    add_cyl(bm, (0, -W / 2 - 0.25, 2.62), 0.09, 0.14, seg=10 if D else 6, axis="Z")
    obj("Lamp_Deur", bm, M["amber"], root, tile=1.0, smooth=False)
    return door


def build_radar(M, root):
    """Schotel op een draaitafel boven op het dak, met voetstuk en voedingsarm. Empty 'Radar' draait rond Z."""
    base = (0.0, 0.0, Z2 + 0.36)
    bm = bmesh.new()
    add_cyl(bm, (base[0], base[1], base[2] + 0.18), 0.42, 0.36, seg=SEG // 2 or 8)
    add_cyl(bm, (base[0], base[1], base[2] + 0.55), 0.13, 0.4, seg=10)
    obj("Radarvoet", bm, M["donker"], root, tile=1.0)
    radar = empty("Radar", root, (base[0], base[1], base[2] + 0.74))
    # schotel: parabool als gesloten schaal (voor- en achterkant), gedraaid rond Z en dan gekanteld
    bm = bmesh.new()
    R = 0.95
    k = 0.36   # diepte
    steps = {2: 14, 1: 8, 0: 5}[D]
    prof = []
    for i in range(steps + 1):
        r = R * i / steps
        prof.append((r, k * (r / R) ** 2))
    shell = [(r, z) for r, z in prof] + [(r - 0.03 if r > 0.05 else 0.0, z - 0.03) for r, z in reversed(prof)]
    vs = [bm.verts.new((r, 0, z)) for r, z in shell]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    es.append(bm.edges.new((vs[-1], vs[0])))
    bmesh.ops.spin(bm, geom=vs + es, axis=(0, 0, 1), cent=(0, 0, 0), angle=2 * math.pi, steps=SEG, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0008)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.transform(Matrix.Rotation(math.radians(-40), 4, "X"))   # kantel: kijkt schuin omhoog naar +Y
    bm.transform(Matrix.Translation((0, 0.3, 0.45)))
    dish = obj("Schotel", bm, M["staal"], radar, smooth=True, tile=1.2)
    # voedingsarm en hoorn
    bm = bmesh.new()
    foc = Vector((0, 0.3, 0.45)) + Matrix.Rotation(math.radians(-40), 4, "X") @ Vector((0, 0, 0.5))
    arm_base = Vector((0, 0.3, 0.45))
    for dx in (-0.55, 0.55):
        d = (foc - arm_base)
        add_cyl(bm, (0, 0, 0), 0.018, 0.1, seg=6)
    add_cyl(bm, foc, 0.07, 0.16, seg=8, r2=0.03)
    # steunen van het tafeltje naar de schotel
    add_box(bm, (0, 0.12, 0.28), (0.14, 0.14, 0.5))
    obj("Radarhoorn", bm, M["donker"], radar, tile=1.0)
    return radar


def build_masts(M, root):
    """Antennes op het dak (rood knipperlicht op de hoogste) en het camouflagenet langs de westkant."""
    bm = bmesh.new()
    spec = [((-1.45, -1.45), 2.4), ((1.55, -1.6), 1.7), ((-1.5, 1.55), 1.3), ((1.2, 0.4), 1.0)]
    for (x, y), h in spec:
        add_cyl(bm, (x, y, Z2 + 0.2 + h / 2), 0.028, h, seg=8)
        for k in range(2 if D else 1):
            zc = Z2 + 0.2 + h * (0.55 + 0.3 * k)
            add_box(bm, (x, y, zc), (0.6 - 0.2 * k, 0.025, 0.025))
    obj("Antennes", bm, M["donker"], root, tile=1.0, smooth=False)
    bm = bmesh.new()
    x, y = spec[0][0]
    bmesh.ops.create_uvsphere(bm, u_segments=10 if D else 6, v_segments=8 if D else 5, radius=0.07,
                              matrix=Matrix.Translation((x, y, Z2 + 0.2 + spec[0][1] + 0.05)))
    obj("Lamp_Rood", bm, M["rood"], root, smooth=True, tile=1.0)


def build_net(M, root):
    nx, ny = (10, 14) if D >= 1 else (4, 6)
    bm = bmesh.new()
    verts = []
    x_in, x_out = -W / 2 - 0.02, -W / 2 - 2.1
    y0, y1 = -1.9, 2.3
    rng = random.Random(3)
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x = x_in + (x_out - x_in) * u
            y = y0 + (y1 - y0) * v
            z = 2.55 - 0.7 * u + 0.12 * math.sin(v * math.pi * 3) * (1 - 0.4 * u) - 0.1 * math.sin(u * math.pi) - 0.015 * rng.random()
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    uv = bm.loops.layers.uv.new("UVMap")
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
            for lp, (ii, jj) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                lp[uv].uv = (jj / ny * 1.6, ii / nx)
    F.new_obj("Camonet", bm, M["net"], smooth=True, parent=root)
    bm = bmesh.new()
    for (y, h) in ((-1.9, 1.9), (0.2, 1.8), (2.3, 1.85)):
        add_cyl(bm, (x_out, y, h / 2 + Z0 * 0.2), 0.045, h + 0.5, seg=8)
    obj("Netpalen", bm, M["staal"], root, tile=1.0)


def build_levels(M, root):
    """Niveau 2: tweede kleine schotel en antennerek. Niveau 3: pantserplaten rond de kniemuur, zoeklicht en zandzakrand."""
    n2 = empty("Niveau2", root)
    bm = bmesh.new()
    add_box(bm, (1.45, 1.45, Z2 + 0.45), (0.9, 0.9, 0.5))
    for dx in (-0.3, 0.3):
        for dy in (-0.3, 0.3):
            add_cyl(bm, (1.45 + dx, 1.45 + dy, Z2 + 0.95), 0.02, 1.0, seg=6)
    add_box(bm, (1.45, 1.45, Z2 + 1.35), (0.9, 0.9, 0.04))
    # extra pantserplaten onder het dak
    for side in range(4):
        yaw = side * math.pi / 2
        c = Matrix.Rotation(yaw, 4, "Z") @ Vector((0, -UW / 2 - 0.06, 3.2))
        add_box(bm, c, (UW - 0.2, 0.06, 0.5), rot=yaw)
    obj("Niveau2_rek", bm, M["staal"], n2, tile=1.2, bevel=0.01)
    bm = bmesh.new()
    spiegel = Vector((-1.45, 1.45, Z2 + 0.4))
    add_cyl(bm, spiegel + Vector((0, 0, 0.25)), 0.35, 0.5, seg=8 if D else 6)
    bmesh.ops.create_uvsphere(bm, u_segments=12 if D else 6, v_segments=8 if D else 4, radius=0.34,
                              matrix=Matrix.Translation(spiegel + Vector((0, 0, 0.85))) @ Matrix.Diagonal((1, 1, 0.6, 1)))
    obj("Niveau2_schotel", bm, M["donker"], n2, smooth=True, tile=1.0)
    n3 = empty("Niveau3", root)
    bm = bmesh.new()
    # betonnen stootrand met zandzakken rond het begane-grondsdak
    for side in range(4):
        yaw = side * math.pi / 2
        c = Matrix.Rotation(yaw, 4, "Z") @ Vector((0, -W / 2 + 0.2, Z1 + 0.35))
        add_box(bm, c, (W - 0.7, 0.34, 0.5), rot=yaw)
    obj("Niveau3_zakken", bm, M["beton"], n3, tile=1.5, bevel=0.02)
    bm = bmesh.new()
    # zoeklicht op een paal
    add_cyl(bm, (1.5, -1.5, Z2 + 0.9), 0.04, 1.4, seg=8)
    add_cyl(bm, (1.5, -1.5, Z2 + 1.75), 0.2, 0.34, seg=10, axis="Y")
    obj("Niveau3_zoeklicht", bm, M["donker"], n3, smooth=True, tile=1.0)
    bm = bmesh.new()
    add_cyl(bm, (1.5, -1.71, Z2 + 1.75), 0.15, 0.03, seg=10, axis="Y")
    obj("Niveau3_zoeklamp", bm, M["amber"], n3, tile=1.0)
    # zware stalen luiken vóór de glaswand (omhoog geschoven open, hier half dicht)
    bm = bmesh.new()
    for side in range(4):
        yaw = side * math.pi / 2
        for x in (-1.2, 1.2):
            c = Matrix.Rotation(yaw, 4, "Z") @ Vector((x, -UW / 2 - 0.2, 4.45))
            add_box(bm, c, (1.1, 0.05, 0.22), rot=yaw)
    obj("Niveau3_luiken", bm, M["staal"], n3, tile=1.2, bevel=0.01)


def build_damage(M, root):
    for lvl, ux in ((1, 0.0), (2, 0.5)):
        e = empty(f"Schade{lvl}", root)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        spots = [(-1.2, -W / 2 - 0.045, 1.9, 1.6, 1.3, 0), (1.3, -W / 2 - 0.045, 1.3, 1.5, 1.2, 0),
                 (W / 2 + 0.045, -0.4, 1.8, 1.8, 1.4, 1), (-W / 2 - 0.045, 0.7, 1.5, 1.7, 1.3, 3),
                 (0.0, -UW / 2 - 0.06, 3.5, 1.9, 1.0, 0)]
        if lvl == 1:
            spots = spots[:3]
        for i, (x, y, z, w, h, side) in enumerate(spots):
            yaw = (0, 1, 2, 3)[side] * math.pi / 2
            if side == 1:
                yaw = -math.pi / 2
            vs = []
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                if abs(x) > W / 2 - 0.1 and abs(y) < W / 2 - 0.1:   # wand in de x-richting
                    p = Vector((x, y + sx * w / 2, z + sz * h / 2))
                else:
                    p = Vector((x + sx * w / 2, y, z + sz * h / 2))
                vs.append(bm.verts.new(p))
            f = bm.faces.new(vs)
            for lp, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                lp[uv].uv = (ux + u * 0.5, v)
        F.new_obj(f"Schade{lvl}_vlakken", bm, M["schade"], smooth=False, parent=e)


def clip(o, name, action):
    ad = o.animation_data_create()
    ad.action = None
    tr = ad.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, 0, action)
    st.name = name


def animate(radar, door, rig):
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    # radar: precies 1 omwenteling in 8 s, lineair
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    radar.rotation_mode = "XYZ"
    for f, ang in ((0, 0.0), (120, math.pi), (240, 2 * math.pi)):
        radar.rotation_euler = (0, 0, ang)
        radar.keyframe_insert("rotation_euler", frame=f)
    act = radar.animation_data.action
    act.name = "Radar-loop"
    clip(radar, "Radar-loop", act)
    # deur: Open en Dicht
    for name, seq in (("Open", ((0, 0.0), (6, 0.0), (30, 1.28))), ("Dicht", ((0, 1.28), (6, 1.28), (30, 0.0)))):
        for f, x in seq:
            door.location = (x, door.location[1], door.location[2])
            door.keyframe_insert("location", frame=f)
        act = door.animation_data.action
        act.name = name
        clip(door, name, act)
    # vlag: de clip die rig_cloth al maakte staat als actieve actie op het skelet
    act = rig.animation_data.action
    clip(rig, "Wapperen-loop", act)
    door.location = (0, door.location[1], door.location[2])
    sc.frame_end = 240


# ------------------------------------------------------------------ opbouw
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    res = TEXRES
    cn = F.tinted_set("concrete", (0.80, 0.80, 0.76), res)
    ol = F.tinted_set("olive", (0.86, 0.95, 0.70), res)
    dk = F.tinted_set("steel", (0.34, 0.36, 0.32), res)
    M = {
        "beton": F.pbr("HK_Beton", cn["albedo"], cn["normal"], cn["orm"], normal_strength=1.1),
        "staal": F.pbr("HK_Staal_olijf", ol["albedo"], ol["normal"], ol["orm"], normal_strength=0.9),
        "donker": F.pbr("HK_Metaal_donker", dk["albedo"], dk["normal"], dk["orm"], normal_strength=0.6),
        "glas": F.plain("HK_Glas", (0.05, 0.10, 0.11), 0.06, metal=0.0, alpha=0.42),
        "rood": F.plain("HK_Lamp_rood", (1.0, 0.05, 0.03), 0.3, emission=((1.0, 0.06, 0.03), 5.0)),
        "amber": F.plain("HK_Lamp_amber", (1.0, 0.62, 0.16), 0.3, emission=((1.0, 0.55, 0.10), 4.0)),
        "wit": F.plain("HK_Verf_wit", (0.82, 0.80, 0.72), 0.7),
        "net": alpha_mat("HK_Camonet", make_net_texture(1024 if D else 512)),
        "schade": alpha_mat("HK_Schade", make_damage_texture(512 if D else 256)),
    }
    t_alb, t_nrm, t_orm = F.make_cloth_textures(1024 if D else 512)
    M["doek"] = F.pbr("Vlagdoek_olijf_goud", t_alb, t_nrm, t_orm, normal_strength=1.0, double_sided=True)

    root = bpy.data.objects.new("Hoofdkwartier", None)
    sc.collection.objects.link(root)
    build_body(M, root)
    door = build_door(M, root)
    radar = build_radar(M, root)
    build_masts(M, root)
    build_net(M, root)
    build_levels(M, root)
    build_damage(M, root)
    # vlag op de noordoosthoek van het dak: de vlaghelpers van het verzamelpunt, iets kleiner
    vlag = empty("Vlag", root, (-1.55, 1.55, Z2 + 0.2), scale=0.8)
    cfg = dict(seg=max(8, SEG // 3), cloth=(12, 7) if D else (6, 4), bone_n=6 if D else 3)
    F.build_pole(M["staal"], M["donker"], cfg["seg"], vlag)
    F.build_lamp(M["amber"], cfg["seg"], vlag)
    cloth = F.build_cloth(M["doek"], cfg["cloth"], cfg["bone_n"], vlag)
    rig = F.rig_cloth(cloth, vlag, cfg["bone_n"])
    animate(radar, door, rig)

    tris = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in bpy.data.objects:
        if o.type == "MESH":
            m = o.evaluated_get(dg).to_mesh()
            tris += sum(len(p.vertices) - 2 for p in m.polygons)
    print(f"[{LEVEL}] triangles: {tris}, materialen: {len(bpy.data.materials)}")

    stem = {"hq": "Hoofdkwartier_HQ", "game": "hoofdkwartier", "lod1": "hoofdkwartier_lod1"}[LEVEL]
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    glb = (OUT if LEVEL == "hq" else ROOT / "assets") / f"{stem}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb), export_format="GLB", export_yup=True, export_apply=False,
        export_skins=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
        export_materials="EXPORT", export_image_format="AUTO", export_lights=False, export_cameras=False,
    )
    print("geschreven:", glb)
    if LEVEL == "hq":
        usdz = OUT / "Hoofdkwartier.usdz"
        try:
            bpy.ops.wm.usd_export(filepath=str(usdz), export_materials=True, export_animation=True, generate_preview_surface=True)
            print("geschreven:", usdz)
        except Exception as exc:  # noqa
            print("USDZ-export mislukt:", exc)


main()
