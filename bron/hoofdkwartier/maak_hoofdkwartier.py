"""Hoofdkwartier (HK), Blender-bron, versie 2 (hero-kwaliteit). Eenheden in meters, Z omhoog in Blender
(glTF zet het om naar Y omhoog). De voorkant (deur) wijst naar Blender -Y; dat wordt +Z in Godot.

Gebruik (Blender als Python-module, bijvoorbeeld `pip install bpy` in een venv):

    python bron/hoofdkwartier/maak_hoofdkwartier.py hq     # bewerkbaar bronmodel: uit/Hoofdkwartier_HQ.blend/.glb/.usdz
    python bron/hoofdkwartier/maak_hoofdkwartier.py game   # Godot-versie: assets/hoofdkwartier.glb
    python bron/hoofdkwartier/maak_hoofdkwartier.py lod1   # uitgezoomd: assets/hoofdkwartier_lod1.glb

Ontwerp: bron/hoofdkwartier/ASSET_DESIGN_SPEC.md. Alle bakeable onderdelen krijgen één uniek 2K-atlas (albedo, ORM met
AO, normal) uit verweerde Cycles-materialen, zie hk_bake.py. Glas, lampen, camonet, schadelagen en vlagdoek blijven
aparte materialen (Godot stuurt ze aan). Clips: Radar-loop, Open, Dicht, Wapperen-loop.
"""
import math
import os
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
sys.path.insert(0, str(HERE))
import maak_verzamelvlag as F  # noqa: E402  (zelfde niveau-argument: hq, game of lod1)
import hk_bake as B  # noqa: E402

OUT = HERE / "uit"
OUT.mkdir(exist_ok=True)
F.OUT = OUT
LEVEL = F.LEVEL
D = {"hq": 2, "game": 1, "lod1": 0}[LEVEL]
ATLAS = {"hq": 2048, "game": 2048, "lod1": 1024}[LEVEL]
TEXRES = 1024  # VQ2-brontexturen zijn native 1024 px; de atlas is uniek en 2K
SAMPLES = {"hq": 24, "game": 24, "lod1": 12}[LEVEL]
SEGC = {"hq": 14, "game": 10, "lod1": 6}[LEVEL]
BEV = {"hq": (0.012, 4), "game": (0.011, 3), "lod1": None}[LEVEL]
SEG = {"hq": 96, "game": 64, "lod1": 12}[LEVEL]
FPS = 30

W = 5.0            # breedte en diepte van de begane grond (spelcollider 5,0 x 5,0)
Z0 = 0.35          # bovenkant sokkel
Z1 = 2.75          # bovenkant begane grond
ZL = 2.87          # bovenkant lagere dak (de rand rond de bovenverdieping)
UW = 3.8           # bovenverdieping
ROOF = 5.17        # bovenkant dakdek
Z2 = 5.0           # (oud) referentie voor onderdelen op het dak


# ------------------------------------------------------------------ geometrie-helpers
class G:
    """Twee bmeshes: b (dozen, krijgen een bevel) en c (cilinders en dunne details, geen bevel)."""

    def __init__(self):
        self.b = bmesh.new()
        self.c = bmesh.new()


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def RX(a):
    return Matrix.Rotation(a, 4, "X")


def RY(a):
    return Matrix.Rotation(a, 4, "Y")


def RZ(a):
    return Matrix.Rotation(a, 4, "Z")


def WM(side, u=0.0, d=0.0, z=0.0, half=None):
    """Wandframe: lokaal +x langs de wand, lokaal -y naar buiten, +z omhoog. side 0 = voor (-Y), 1 = oost, 2 = achter, 3 = west."""
    half = W / 2 if half is None else half
    return RZ(side * math.pi / 2) @ T(u, -half - d, z)


def bx(g, M, size, bevel=True):
    tgt = g.b if (bevel and BEV) else g.c
    bmesh.ops.create_cube(tgt, size=1.0, matrix=M @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))


def cy(g, M, r, h, seg=None, r2=None, caps=True):
    seg = seg or SEGC
    bmesh.ops.create_cone(g.c, cap_ends=caps, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2,
                          depth=h, matrix=M)


def _frame(a, b, up):
    d = (b - a)
    L = d.length
    q = d.to_track_quat("Y", up)
    return T(*((a + b) / 2)) @ q.to_matrix().to_4x4(), L


def beam(g, a, b, w, h, bevel=True):
    """Balk met rechthoekige doorsnede w x h van a naar b (h loodrecht op de richting, bij benadering omhoog)."""
    a, b = Vector(a), Vector(b)
    up = "X" if abs((b - a).normalized().z) > 0.98 else "Z"
    M, L = _frame(a, b, up)
    bx(g, M, (w, L, h), bevel=bevel)


def st(g, a, b, r, seg=6):
    """Cilinder (leiding, draad, buis) van a naar b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    up = "X" if abs(d.normalized().y) > 0.98 else "Y"
    q = d.to_track_quat("Z", up)
    M = T(*((a + b) / 2)) @ q.to_matrix().to_4x4()
    cy(g, M, r, d.length, seg=seg)


def rivet(g, M, r=0.022):
    """Klinknagel/bout, wijst naar lokaal -y (de buitenkant van het wandframe)."""
    cy(g, M @ RX(math.pi / 2), r, 0.02, seg=max(6, SEGC), r2=r * 0.55)


def rivet_row(g, side, u0, u1, d, z, n, half=None, r=0.02):
    for i in range(n):
        u = u0 + (u1 - u0) * (i / max(1, n - 1))
        rivet(g, WM(side, u, d, z, half), r)


def uvw(bm, tile=2.0):
    """Wereldgebonden UV's per vlak (dominante as), eerste laag 'UVMap' voor de herhalende brontexturen."""
    bm.normal_update()
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = ((1, 2), (0, 2), (0, 1))[ax]
        for lp in f.loops:
            p = lp.vert.co
            lp[uv].uv = (p[a] / tile, p[b] / tile)


def commit(name, g, mat, parent, tile=2.0, smooth=False, bevel=True, bw=None):
    bm = g.b
    if BEV and bevel and bm.faces:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bw or BEV[0], segments=(2 if bw else BEV[1]), affect="EDGES", profile=0.55,
                        clamp_overlap=True)
    if g.c.faces:
        tmp = bpy.data.meshes.new("_tmp")
        g.c.to_mesh(tmp)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    g.c.free()
    if not bm.faces:
        bm.free()
        return None
    uvw(bm, tile)
    return F.new_obj(name, bm, mat, smooth=smooth, parent=parent)


def empty(name, parent, loc=(0, 0, 0), scale=1.0):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    e.scale = (scale, scale, scale)
    return e


# ------------------------------------------------------------------ textuur: camonet en schade
def make_net_texture(res):
    """Camouflagenet: dicht bladerpatroon (ongeveer 70% dekking) in lichte olijf-, bruin- en donkergroentinten,
    met een zichtbaar touwnet van ruiten en een stevige zoom. Van boven moet het net als net te lezen zijn."""
    rng = np.random.default_rng(11)

    def noise(n):
        return np.asarray(Image.fromarray((rng.random((n, n)) * 255).astype(np.uint8)).resize((res, res), Image.BICUBIC), dtype=np.float32) / 255.0

    big, mid, fine = noise(res // 24), noise(res // 9), noise(res // 3)
    cover = big * 0.5 + mid * 0.32 + fine * 0.22
    alpha = (cover > np.percentile(cover, 30)).astype(np.float32)
    cols = np.array([[0.13, 0.19, 0.07], [0.22, 0.29, 0.10], [0.31, 0.34, 0.14], [0.27, 0.19, 0.10]], dtype=np.float32)   # donkergroen, olijf, lichte olijf, bruin
    idx = np.clip(((big * 0.6 + mid * 0.4) * 3.99).astype(np.int32), 0, 3)
    rgb = cols[idx] * (0.8 + 0.4 * fine[..., None])
    # touwnet: ruiten van res/20 px, 3 px dik, ook zichtbaar in de gaten
    step = max(8, res // 20)
    yy, xx = np.mgrid[0:res, 0:res]
    rope = ((xx % step) < 3) | ((yy % step) < 3)
    rgb = np.where(rope[..., None], np.array([0.12, 0.10, 0.06], dtype=np.float32), rgb)
    alpha = np.where(rope, 1.0, alpha)
    # zoom rondom
    hem = max(10, res // 40)
    edge = (xx < hem) | (yy < hem) | (xx >= res - hem) | (yy >= res - hem)
    rgb = np.where(edge[..., None], np.array([0.16, 0.21, 0.08], dtype=np.float32), rgb)
    alpha = np.where(edge, 1.0, alpha)
    img = np.dstack([np.clip(rgb, 0, 1), alpha])
    p = OUT / f"camonet_{res}.png"
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(p)
    return p


def make_damage_texture(res):
    """Twee helften naast elkaar: links lichte roetvlekken en strepen, rechts zware brandplekken met scheuren."""
    W2, H2 = res * 2, res
    img = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
    rng = random.Random(5)

    def blotch(layer, cx, cy_, r, a):
        d = ImageDraw.Draw(layer)
        for k in range(14):
            rr = r * (1.0 - k / 16)
            ox, oy = rng.uniform(-r, r) * 0.12, rng.uniform(-r, r) * 0.12
            d.ellipse((cx - rr + ox, cy_ - rr + oy, cx + rr + ox, cy_ + rr + oy), fill=(12, 10, 8, int(a / 14 * 3.2)))

    left = Image.new("RGBA", (res, res), (0, 0, 0, 0))
    for _ in range(5):
        blotch(left, rng.uniform(0.2, 0.8) * res, rng.uniform(0.3, 0.9) * res, rng.uniform(0.08, 0.2) * res, 150)
    ds = ImageDraw.Draw(left)
    for _ in range(18):
        x = rng.uniform(0.1, 0.9) * res
        ds.line((x, res * rng.uniform(0.4, 1.0), x + rng.uniform(-8, 8), res * rng.uniform(0.0, 0.4)), fill=(10, 9, 8, 70), width=rng.randint(2, 7))
    left = left.filter(ImageFilter.GaussianBlur(4))
    right = Image.new("RGBA", (res, res), (0, 0, 0, 0))
    for _ in range(7):
        blotch(right, rng.uniform(0.15, 0.85) * res, rng.uniform(0.25, 0.9) * res, rng.uniform(0.12, 0.26) * res, 235)
    right = right.filter(ImageFilter.GaussianBlur(3))
    dr = ImageDraw.Draw(right)
    for _ in range(9):
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


# ------------------------------------------------------------------ onderdelen: romp
def build_concrete(M, root):
    g = G()
    # sokkel in twee treden, begane grond, hoekpilasters
    bx(g, T(0, 0, 0.09), (W + 0.55, W + 0.55, 0.18))
    bx(g, T(0, 0, 0.265), (W + 0.32, W + 0.32, 0.17))
    bx(g, T(0, 0, (Z0 + Z1) / 2), (W, W, Z1 - Z0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(g, T(sx * (W / 2 - 0.02), sy * (W / 2 - 0.02), (Z0 + Z1) / 2 + 0.05), (0.56, 0.56, Z1 - Z0 + 0.1))
            bx(g, T(sx * (W / 2 - 0.02), sy * (W / 2 - 0.02), Z1 + 0.13), (0.62, 0.62, 0.07))    # pilaarkap
    # bekistingspanelen: twee rijen per wand, naden ertussen
    cols = (-1.65, -0.55, 0.55, 1.65)
    rows = ((1.74, 0.46), (2.37, 0.62))
    for side in range(4):
        for ci, u in enumerate(cols):
            for ri, (zc, h) in enumerate(rows):
                if side == 0 and abs(u) < 1.0 and (ri == 0 or ri == 1):
                    continue
                bx(g, WM(side, u, 0.016, zc), (1.04, 0.032, h))
    # latei boven de deur: zwaar betonnen balk met neuswering
    bx(g, WM(0, 0, 0.06, 2.62), (2.1, 0.14, 0.26))
    bx(g, WM(0, 0, 0.02, 2.2), (0.22, 0.04, 0.9)) if False else None
    # schietsleuf-kaders (beton): vier randen rond elke sleuf
    for side, us in ((0, (-1.65, 1.65)), (1, (-1.65, 0.0, 1.65)), (2, (-1.65, 0.0, 1.65)), (3, (-1.65, 0.0, 1.65))):
        for u in us:
            bx(g, WM(side, u, 0.07, 2.37 + 0.12), (0.98, 0.07, 0.07))
            bx(g, WM(side, u, 0.07, 2.37 - 0.12), (0.98, 0.07, 0.07))
            for k in (-1, 1):
                bx(g, WM(side, u + k * 0.45, 0.07, 2.37), (0.08, 0.07, 0.3))
    # lagere dak: plaat, opstaande rand met spuigaten, kantelen langs de rand
    bx(g, T(0, 0, Z1 + 0.06), (W + 0.12, W + 0.12, 0.12))
    for side in range(4):
        bx(g, WM(side, 0, -0.0, ZL + 0.07, half=W / 2 + 0.04), (W + 0.12, 0.12, 0.14))
    # bovenverdieping: kniemuur met panelen, pilasters, ringbalk, dakplaat, borstwering
    uh = UW / 2
    bx(g, T(0, 0, (ZL + 3.62) / 2), (UW, UW, 3.62 - ZL))
    for side in range(4):
        for u in (-1.2, 0.0, 1.2):
            bx(g, WM(side, u, 0.016, 3.25, half=uh), (1.04, 0.032, 0.56))
        for u in (-1.05, 1.05):      # onderrand sleutelstenen
            pass
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx(g, T(sx * (uh - 0.02), sy * (uh - 0.02), (ZL + 4.86) / 2), (0.40, 0.40, 4.86 - ZL))
    for side in range(4):          # vensterbanken
        for bay in range(4):
            u = -1.1625 + bay * 0.775
            bx(g, WM(side, u, 0.08, 3.65, half=uh), (0.72, 0.18, 0.07))
    bx(g, T(0, 0, 4.74), (UW + 0.16, UW + 0.16, 0.24))                 # ringbalk
    bx(g, T(0, 0, 4.92), (UW + 0.46, UW + 0.46, 0.13))                 # onderkant dak (druiplijst)
    bx(g, T(0, 0, 5.02), (UW + 0.58, UW + 0.58, 0.14))
    bx(g, T(0, 0, 5.12), (UW + 0.50, UW + 0.50, 0.10))                 # dakdek tot 5,17
    for side in range(4):          # borstwering met deksteen
        bx(g, WM(side, 0, 0.0, ROOF + 0.17, half=UW / 2 + 0.25), (UW + 0.62, 0.13, 0.34))
        bx(g, WM(side, 0, 0.0, ROOF + 0.355, half=UW / 2 + 0.25), (UW + 0.70, 0.19, 0.04))
    commit("Romp", g, M["beton"], root, tile=2.5)
    # gaten van de bekistingsankers: donkere schijfjes op elk betonpaneel, vier per paneel
    if D >= 1:
        gh = G()
        for side in range(4):
            for u in cols:
                for ri, (zc, h) in enumerate(rows):
                    if side == 0 and abs(u) < 1.0:
                        continue
                    for dx in (-0.4, 0.4):
                        for dz in (-h * 0.34, h * 0.34):
                            cy(gh, WM(side, u + dx, 0.036, zc + dz) @ RX(math.pi / 2), 0.021, 0.008, seg=SEGC + 2, r2=0.017)
        uh = UW / 2
        for side in range(4):
            for u in (-1.2, 0.0, 1.2):
                for dx in (-0.4, 0.4):
                    for dz in (-0.17, 0.17):
                        cy(gh, WM(side, u + dx, 0.036, 3.25 + dz, half=uh) @ RX(math.pi / 2), 0.021, 0.008, seg=SEGC + 2, r2=0.017)
        commit("Gaten", gh, M["zwart"], root, tile=0.5, bevel=False)


def build_plates(M, root, bolts):
    """Pantserplaten en alle olijfgroene staaldelen."""
    g = G()
    cols = (-1.65, -0.55, 0.55, 1.65)
    for side in range(4):
        for u in cols:
            if side == 0 and abs(u) < 1.0:
                continue
            bx(g, WM(side, u, 0.04, 0.95), (1.05, 0.08, 1.05))
            bx(g, WM(side, u, 0.075, 1.50), (1.08, 0.11, 0.05))                 # bovenlip
            bx(g, WM(side, u, 0.075, 0.40), (1.08, 0.11, 0.05))                 # onderlip
            for k in (-0.34, 0.34):                                              # verstijvingsribben
                bx(g, WM(side, u + k, 0.095, 0.95), (0.05, 0.04, 0.88))
            if D >= 1:
                bx(g, WM(side, u, 0.092, 0.95), (0.62, 0.02, 0.05))             # dwarsnaad
                for k in (-0.46, 0.46):
                    bx(g, WM(side, u + k, 0.10, 1.40), (0.06, 0.07, 0.10))     # hijsoog
                rivet_row(bolts, side, u - 0.46, u + 0.46, 0.085, 1.44, 9)
                rivet_row(bolts, side, u - 0.46, u + 0.46, 0.085, 0.46, 9)
                for z in np.linspace(0.58, 1.34, 7):
                    for k in (-0.46, 0.46):
                        rivet(bolts, WM(side, u + k, 0.085, float(z)))
                for z in (0.62, 1.28):                                           # rijen langs de verstijvingsribben
                    for k in (-0.34, 0.34):
                        for dz in (-0.0,):
                            rivet(bolts, WM(side, u + k, 0.115, float(z)), 0.016)
    # bovenverdieping: stalen band onder en boven het glas, raamkozijnen met stijlen, regenkappen
    uh = UW / 2
    for side in range(4):
        bx(g, WM(side, 0, 0.05, 3.70, half=uh), (UW - 0.4, 0.1, 0.10))          # onderrail
        bx(g, WM(side, 0, 0.05, 4.57, half=uh), (UW - 0.4, 0.1, 0.12))          # bovenrail
        for i in range(5):
            u = -1.55 + i * 0.775
            bx(g, WM(side, u, 0.05, 4.135, half=uh), (0.07, 0.10, 0.88))         # stijlen
        for bay in range(4):
            u = -1.1625 + bay * 0.775
            bx(g, WM(side, u, 0.04, 4.135, half=uh), (0.68, 0.04, 0.04))         # tussenregel
        # regenkap boven het glas: schuine pantserplaat met zijwangen
        Mh = WM(side, 0, 0.30, 4.80, half=uh) @ RX(math.radians(-22))
        bx(g, Mh, (UW - 0.28, 0.58, 0.06))
        for k in (-1, 1):
            bx(g, WM(side, k * (UW / 2 - 0.2), 0.22, 4.72, half=uh) @ RX(math.radians(-8)), (0.06, 0.40, 0.22))
        if D >= 1:
            rivet_row(bolts, side, -1.5, 1.5, 0.05, 4.545, 9, half=uh, r=0.018)
            rivet_row(bolts, side, -1.5, 1.5, 0.05, 3.75, 9, half=uh, r=0.018)
    # deurkozijn (voorzijde): stijlen, bovenplaat, drempel
    for x in (-0.84, 0.84):
        bx(g, WM(0, x, 0.07, 1.40), (0.16, 0.14, 2.14))
    bx(g, WM(0, 0, 0.07, 2.50), (1.84, 0.16, 0.18))
    bx(g, WM(0, 0, 0.05, 0.38), (1.84, 0.12, 0.06))
    commit("Platen", g, M["staal"], root, tile=1.5)


def build_metal(M, root):
    """Donker staal: sleuven, leidingen, beugels, roosters, ladders, kabelgoten."""
    g = G()
    # schietsleuven (donker, in het kader)
    for side, us in ((0, (-1.65, 1.65)), (1, (-1.65, 0.0, 1.65)), (2, (-1.65, 0.0, 1.65)), (3, (-1.65, 0.0, 1.65))):
        for u in us:
            bx(g, WM(side, u, 0.045, 2.37), (0.86, 0.02, 0.13), bevel=False)
            if D >= 1:
                bx(g, WM(side, u, 0.06, 2.37), (0.86, 0.02, 0.03), bevel=False)
    # donkere nis achter de deur
    bx(g, WM(0, 0, 0.018, 1.40), (1.5, 0.03, 2.0), bevel=False)
    if D >= 1:
        # airco's en schakelkast op de achterwand (side 2), leidingen met flenzen en beugels
        for u in (-1.3, 0.35):
            bx(g, WM(2, u, 0.26, 1.7), (0.95, 0.42, 0.72))
            bx(g, WM(2, u, 0.50, 1.7), (1.02, 0.06, 0.78))
            for k in range(7):
                bx(g, WM(2, u, 0.54, 1.45 + k * 0.095), (0.88, 0.03, 0.04), bevel=False)
            cy(g, WM(2, u + 0.25, 0.54, 1.7) @ RX(math.pi / 2), 0.2, 0.03, seg=SEGC + 4)
            for a in range(4):
                bx(g, WM(2, u + 0.25, 0.56, 1.7) @ RY(a * math.pi / 4), (0.40, 0.012, 0.014), bevel=False)
            for k in (-0.38, 0.38):
                bx(g, WM(2, u + k, 0.03, 1.25), (0.06, 0.1, 0.06))
        for u in (-1.5, -1.45):
            pass
        # koelleidingen omhoog langs de wand
        for k, u in enumerate((-0.85, -0.78, -0.71)):
            st(g, (u * 1.0, W / 2 + 0.06, 1.2), (u * 1.0, W / 2 + 0.06, ZL - 0.12), 0.018 + 0.004 * k, seg=6)
        # ventilatieschacht met flenzen en knik
        xs = 1.85
        st(g, (xs, W / 2 + 0.17, Z0), (xs, W / 2 + 0.17, Z1 - 0.15), 0.1, seg=SEGC + 4)
        for z in (0.6, 1.4, 2.2, Z1 - 0.15):
            cy(g, T(xs, W / 2 + 0.17, z), 0.135, 0.04, seg=SEGC + 4)
        st(g, (xs, W / 2 + 0.17, Z1 - 0.15), (xs, W / 2 + 0.17, ZL + 0.30), 0.1, seg=SEGC + 4)
        cy(g, T(xs, W / 2 + 0.17, ZL + 0.32), 0.14, 0.05, seg=SEGC + 4, r2=0.06)
        for z in (0.5, 1.1, 1.7, 2.3):
            bx(g, T(xs, W / 2 + 0.09, z), (0.22, 0.12, 0.04))
        # kabelgoot over de achterwand en rond de hoek
        bx(g, WM(2, 0.0, 0.07, 2.6), (3.6, 0.07, 0.10))
        bx(g, WM(2, 0.0, 0.1, 2.6), (3.6, 0.02, 0.07), bevel=False)
        for u in np.linspace(-1.7, 1.7, 9):
            bx(g, WM(2, float(u), 0.05, 2.6), (0.04, 0.1, 0.16), bevel=False)
        # leidingen langs de westwand met klemmen, verdeeldoos
        for k, z in enumerate((0.7, 0.82)):
            st(g, (-W / 2 - 0.07, -2.0, z), (-W / 2 - 0.07, 2.0, z), 0.022, seg=6)
        for y in np.linspace(-1.8, 1.8, 7):
            bx(g, T(-W / 2 - 0.045, float(y), 0.76), (0.03, 0.06, 0.2), bevel=False)
        bx(g, WM(3, 1.4, 0.1, 1.5), (0.3, 0.2, 0.36))
        bx(g, WM(3, 1.4, 0.21, 1.5), (0.24, 0.02, 0.3), bevel=False)
        # schakelkast achterwand: deur, grendel, kabels onderin
        bx(g, WM(2, 1.15, 0.12, 1.2), (0.7, 0.24, 1.15))
        bx(g, WM(2, 1.15, 0.25, 1.2), (0.62, 0.02, 1.06), bevel=False)
        bx(g, WM(2, 1.4, 0.27, 1.2), (0.06, 0.04, 0.2))
        # lampen naast de deur (kooi + behuizing)
        for u in (-2.0, 2.0):
            bx(g, WM(0, u, 0.12, 2.45), (0.12, 0.2, 0.16))
            bx(g, WM(0, u, 0.06, 2.25), (0.08, 0.1, 0.5))
            for k in (-1, 1):
                bx(g, WM(0, u + k * 0.09, 0.24, 2.45), (0.02, 0.1, 0.18), bevel=False)
    # onderste regel: loopplank en afvoergoot rond de voet
    bx(g, T(0, 0, 0.18), (W + 0.7, W + 0.7, 0.02), bevel=False) if False else None
    # ladder naar het dak (oostzijde bovenverdieping), met valbeugel
    xl = UW / 2 + 0.1
    for dy in (-0.2, 0.2):
        bx(g, T(xl, 1.2 + dy, (ZL + ROOF + 0.6) / 2), (0.06, 0.05, ROOF + 0.6 - ZL))
    z = ZL + 0.25
    while z < ROOF + 0.4:
        st(g, (xl, 1.0, z), (xl, 1.4, z), 0.016, seg=6)
        z += 0.3
    for z in (ZL + 0.5, ZL + 1.2, ZL + 1.9):
        bx(g, T(xl, 1.2, z + 0.05), (0.06, 0.1, 0.06))
    if D >= 1:
        for z in (ZL + 1.5, ZL + 1.95, ZL + 2.4):                              # valbeugels
            for ang in np.linspace(-1.4, 1.4, 6):
                bx(g, T(xl + 0.28 * math.cos(ang), 1.2 + 0.32 * math.sin(ang), z), (0.03, 0.03, 0.03), bevel=False)
        for k in (-1, 1):
            st(g, (xl + 0.28, 1.2 + k * 0.32, ZL + 1.4), (xl + 0.28, 1.2 + k * 0.32, ZL + 2.5), 0.012, seg=5)
    commit("Metaal", g, M["donker"], root, tile=1.0)


def build_stairs(M, root):
    """Buitentrap van de grond naar het lagere dak, oostzijde, met leuning, steunen en geelgemarkeerde treden."""
    g = G()
    gy = G()
    n = 14
    rise = (ZL - Z0 - 0.04) / n
    run = 0.27
    x0, wd = W / 2 + 0.16, 0.86
    y0 = -2.35
    for i in range(n):
        y = y0 + i * run
        z = Z0 + 0.04 + (i + 1) * rise
        bx(g, T(x0 + wd / 2, y + run / 2, z - 0.025), (wd, run - 0.012, 0.05))
        bx(gy, T(x0 + wd / 2, y + 0.015, z + 0.001), (wd - 0.04, 0.045, 0.012), bevel=False)
        if D >= 1:
            for k in range(3):
                bx(g, T(x0 + 0.17 + k * 0.26, y + run / 2, z - 0.005), (0.14, run - 0.07, 0.014), bevel=False)
    ytop = y0 + n * run
    ztop = ZL
    # bordes
    bx(g, T(x0 + wd / 2, ytop + 0.5, ztop - 0.03), (wd, 1.0, 0.05))
    bx(gy, T(x0 + wd / 2, ytop + 0.04, ztop + 0.001), (wd - 0.04, 0.06, 0.012), bevel=False)
    # zijbalken
    for x in (x0 - 0.03, x0 + wd + 0.03):
        beam(g, (x, y0, Z0 + 0.0), (x, ytop, ztop - 0.07), 0.05, 0.22)
        bx(g, T(x, ytop + 0.5, ztop - 0.08), (0.05, 1.0, 0.2))
    # leuning aan de buitenzijde en de wandzijde
    for x in (x0 + wd + 0.03, x0 - 0.03):
        a = Vector((x, y0 - 0.1, Z0 + 0.95))
        b = Vector((x, ytop, ztop + 0.92))
        beam(g, a, b, 0.045, 0.045)
        beam(g, a + Vector((0, 0, -0.42)), b + Vector((0, 0, -0.42)), 0.03, 0.03)
        bx(g, T(x, ytop + 0.5, ztop + 0.92), (0.045, 1.0, 0.045))
        bx(g, T(x, ytop + 0.5, ztop + 0.5), (0.03, 1.0, 0.03))
        for i in range(0, n + 1, 2):
            y = y0 + i * run
            z = Z0 + 0.04 + (i + 1) * rise
            bx(g, T(x, y + run / 2, z + 0.45), (0.04, 0.04, 0.9))
        for yy in (ytop + 0.1, ytop + 0.95):
            bx(g, T(x, yy, ztop + 0.46), (0.04, 0.04, 0.92))
    bx(g, T(x0 + wd / 2, ytop + 1.0, ztop + 0.92), (wd + 0.06, 0.045, 0.045))
    bx(g, T(x0 + wd / 2, ytop + 1.0, ztop + 0.5), (wd + 0.06, 0.03, 0.03))
    # draagpoten
    for yy, zz in ((y0 + 4 * run, Z0 + 0.04 + 5 * rise), (y0 + 9 * run, Z0 + 0.04 + 10 * rise), (ytop + 0.9, ztop)):
        bx(g, T(x0 + wd + 0.03, yy, zz / 2 - 0.01), (0.08, 0.08, zz))
        beam(g, (x0 + wd + 0.03, yy, 0.2), (x0 + 0.1, yy - 0.0, zz - 0.2), 0.04, 0.04)
        bx(g, T(x0 + wd + 0.03, yy, 0.02), (0.22, 0.22, 0.04))
    commit("Trap", g, M["donker"], root, tile=1.0)
    commit("Trap_markering", gy, M["geel"], root, tile=1.0)


def build_whites(M, root):
    g = G()
    pts = []
    for k in range(10):
        r = 0.34 if k % 2 == 0 else 0.14
        a = math.pi / 2 + k * math.pi / 5
        pts.append((r * math.cos(a), r * math.sin(a)))
    bm = g.c
    vs = [bm.verts.new((-1.55 + px, -W / 2 - 0.075, 2.0 + 0.42 + py)) for px, py in pts]
    ctr = bm.verts.new((-1.55, -W / 2 - 0.075, 2.42))
    for k in range(10):
        bm.faces.new((ctr, vs[(k + 1) % 10], vs[k]))
    # zwart nummerpaneel: 'HQ-01' pleet en randen
    bx(g, WM(0, 1.55, 0.08, 1.9), (0.9, 0.02, 0.38), bevel=False)
    obj = commit("Ster", g, M["wit"], root, tile=1.0)
    bpy.ops.object.text_add(location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
    t = bpy.context.active_object
    t.name = "HQ_letters"
    t.data.body = "HQ"
    t.data.size = 0.44
    t.data.extrude = 0.02
    t.data.align_x = "CENTER"
    bpy.ops.object.convert(target="MESH")
    t = bpy.context.active_object
    t.data.materials.append(M["wit"])
    t.parent = root
    t.location = (1.55, -W / 2 - 0.085, 1.80)
    # uv voor de bewerkbare letters (herhaling is hier niet kritisch)
    bm = bmesh.new()
    bm.from_mesh(t.data)
    uvw(bm, 1.0)
    bm.to_mesh(t.data)
    bm.free()
    return obj


# ------------------------------------------------------------------ deur, luifel
def build_door(M, root):
    """Pantserdeur die zijwaarts in de muur schuift (clips Open en Dicht); geeft de empty terug."""
    door = empty("Deur", root, (0, -W / 2 - 0.145, 1.4))
    g = G()
    bx(g, T(0, 0, 0), (1.5, 0.1, 2.0))
    for z in (-0.9, 0.9):
        bx(g, T(0, -0.05, z), (1.44, 0.03, 0.12))
    for x in (-0.68, 0.68):
        bx(g, T(x, -0.05, 0), (0.1, 0.03, 1.88))
    bx(g, T(0, -0.045, 0.0), (1.2, 0.02, 1.5))
    for z in (-0.35, 0.35):
        bx(g, T(0, -0.07, z), (1.1, 0.025, 0.05))
    bx(g, T(0, -0.065, 0.0), (0.05, 0.025, 1.4))
    commit("Deurblad", g, M["staal"], door, tile=1.5)
    g = G()
    if D >= 1:
        for z in np.linspace(-0.85, 0.85, 6):          # klinknagels langs de rand
            rivet(g, T(-0.64, -0.05, float(z)) @ RX(0), 0.02) if False else None
        for z in np.linspace(-0.88, 0.88, 7):
            for x in (-0.68, 0.68):
                cy(g, T(x, -0.075, float(z)) @ RX(math.pi / 2), 0.022, 0.02, seg=6, r2=0.012)
        # vergrendelwiel met spaken en naaf; kijkspleet met kader
        cy(g, T(0.42, -0.09, 0.05) @ RX(math.pi / 2), 0.11, 0.05, seg=SEGC + 4)
        for a in range(4):
            bx(g, T(0.42, -0.12, 0.05) @ RY(a * math.pi / 4), (0.40, 0.03, 0.04))
        bx(g, T(-0.2, -0.065, 0.55), (0.46, 0.025, 0.07), bevel=False)
        for z in (-0.25, 0.25):
            bx(g, T(0.0, -0.09, z), (1.3, 0.04, 0.03), bevel=False) if False else None
        # scharnier-rollen aan de bovenkant (lopen in de rail)
        for x in (-0.55, 0.55):
            bx(g, T(x, 0.0, 1.03), (0.1, 0.1, 0.1))
            cy(g, T(x, 0.0, 1.11) @ RX(math.pi / 2), 0.05, 0.04, seg=SEGC)
        for x in (-0.55, 0.55):
            bx(g, T(x, 0.0, -1.03), (0.08, 0.16, 0.06))
    commit("Deurrollen", g, M["donker"], door, tile=1.0)
    g = G()
    n = 10 if D >= 1 else 5
    for i in range(n):
        if i % 2 == 0:
            bx(g, T(-0.66 + i * 0.147, -0.096, -0.88), (0.075, 0.012, 0.2), bevel=False)
    commit("Deurstrepen", g, M["geel"], door, tile=1.0)
    # luifel met steunen, rail van de schuifdeur en lamp
    g = G()
    bx(g, WM(0, 0, 0.45, 2.78), (2.4, 0.9, 0.09))
    for x in (-1.1, 1.1):
        bx(g, WM(0, x, 0.88, 1.4), (0.1, 0.1, 2.72))
        bx(g, WM(0, x, 0.88, 0.04), (0.28, 0.28, 0.06))
        beam(g, (x * 0.95, -W / 2 - 0.88, 2.2), (x * 0.95, -W / 2 - 0.1, 2.72), 0.06, 0.06) if D >= 1 else None
    bx(g, WM(0, 0, 0.9, 2.74), (2.4, 0.07, 0.14))
    # rail van de schuifdeur: balk boven de deur, doorlopend naar rechts
    bx(g, WM(0, 0.65, 0.24, 2.58), (2.7, 0.12, 0.09))
    for u in (-0.6, 0.4, 1.4, 1.9):
        bx(g, WM(0, u, 0.12, 2.58), (0.08, 0.14, 0.14))
    bx(g, WM(0, 0.0, 0.24, 0.37), (1.7, 0.12, 0.04))
    commit("Luifel", g, M["donker"], root, tile=1.0)
    g = G()
    cy(g, T(0, -W / 2 - 0.3, 2.68), 0.09, 0.14, seg=SEGC + 2)
    commit("Lamp_Deur", g, M["amber"], root, tile=1.0)
    return door


# ------------------------------------------------------------------ radar, masten, net
def spin_profile(bm, prof, steps):
    vs = [bm.verts.new((r, 0, z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    es.append(bm.edges.new((vs[-1], vs[0])))
    bmesh.ops.spin(bm, geom=vs + es, axis=(0, 0, 1), cent=(0, 0, 0), angle=2 * math.pi, steps=steps, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0008)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def build_radar(M, root):
    """Schotel op draaitafel op het dak. Empty 'Radar' draait rond Z; Radarvoet staat stil."""
    base = (0.0, 0.0, ROOF)
    g = G()
    cy(g, T(base[0], base[1], base[2] + 0.1), 0.62, 0.2, seg=SEGC + 8)                  # fundering
    cy(g, T(base[0], base[1], base[2] + 0.27), 0.46, 0.14, seg=SEGC + 8)
    cy(g, T(base[0], base[1], base[2] + 0.55), 0.3, 0.42, seg=SEGC + 6)                # kolom
    cy(g, T(base[0], base[1], base[2] + 0.80), 0.38, 0.08, seg=SEGC + 8)               # draailager
    for a in range(8):
        ang = a * math.pi / 4
        cy(g, T(0.50 * math.cos(ang), 0.50 * math.sin(ang), base[2] + 0.22) , 0.022, 0.06, seg=6)
    bx(g, T(0.58, 0.0, base[2] + 0.5), (0.34, 0.4, 0.5))                                 # aandrijfkast
    bx(g, T(0.58, 0.0, base[2] + 0.77), (0.38, 0.44, 0.05))
    for z in (0.35, 0.5, 0.65):
        bx(g, T(0.76, 0.0, base[2] + z), (0.02, 0.32, 0.05), bevel=False)
    commit("Radarvoet", g, M["donker"], root, tile=1.0)
    radar = empty("Radar", root, (base[0], base[1], base[2] + 0.84))
    # schotelschaal: parabool
    bm = bmesh.new()
    R, k = 0.98, 0.34
    steps = {2: 24, 1: 16, 0: 6}[D]
    prof = []
    for i in range(steps + 1):
        r = R * i / steps
        prof.append((r, k * (r / R) ** 2))
    shell = [(r, z) for r, z in prof] + [(r - 0.025 if r > 0.05 else 0.0, z - 0.03) for r, z in reversed(prof)]
    spin_profile(bm, shell, SEG)
    tilt = RX(math.radians(-40))
    pos = T(0, 0.3, 0.52)
    bm.transform(pos @ tilt)
    uvw(bm, 1.2)
    F.new_obj("Schotel", bm, M["wit_g"], smooth=True, parent=radar)
    # rand, ribben aan de achterzijde, voedingsarm met hoorn, steunen en contragewicht
    g = G()
    n_rib = 12 if D >= 1 else 4
    for i in range(n_rib):
        a = i * 2 * math.pi / n_rib
        pts = []
        for j in range(6):
            rr = 0.12 + (R * 0.97 - 0.12) * j / 5
            pts.append(pos @ tilt @ Vector((rr * math.cos(a), rr * math.sin(a), k * (rr / R) ** 2 - 0.05)))
        for q0, q1 in zip(pts[:-1], pts[1:]):
            st(g, q0, q1, 0.016, seg=5)
    if D >= 1:
        for rr in (0.45, 0.72):
            segs = 28
            for i in range(segs):
                a0, a1 = i * 2 * math.pi / segs, (i + 1) * 2 * math.pi / segs
                pa = pos @ tilt @ Vector((rr * math.cos(a0), rr * math.sin(a0), k * (rr / R) ** 2 - 0.05))
                pb = pos @ tilt @ Vector((rr * math.cos(a1), rr * math.sin(a1), k * (rr / R) ** 2 - 0.05))
                st(g, pa, pb, 0.012, seg=4)
        # rand (buis rond de omtrek)
        segs = 40
        for i in range(segs):
            a0, a1 = i * 2 * math.pi / segs, (i + 1) * 2 * math.pi / segs
            pa = pos @ tilt @ Vector((R * math.cos(a0), R * math.sin(a0), k + 0.0))
            pb = pos @ tilt @ Vector((R * math.cos(a1), R * math.sin(a1), k + 0.0))
            st(g, pa, pb, 0.022, seg=5)
    foc = pos @ tilt @ Vector((0, 0, 0.62))
    hub = pos @ tilt @ Vector((0, 0, 0.0))
    for a in (0, 2.094, 4.188):
        edge = pos @ tilt @ Vector((R * 0.9 * math.cos(a + 0.5), R * 0.9 * math.sin(a + 0.5), k * 0.81))
        st(g, edge, foc, 0.015, seg=5)
    cy(g, T(*foc) @ tilt @ T(0, 0, 0.0), 0.075, 0.18, seg=SEGC, r2=0.035)
    st(g, hub, foc, 0.028, seg=6)
    # kanteltafel: twee wangen die de schotel dragen
    for x in (-0.3, 0.3):
        bx(g, T(x, 0.05, 0.28), (0.08, 0.5, 0.5))
    bx(g, T(0, 0.28, 0.5), (0.7, 0.14, 0.12))
    bx(g, T(0, -0.5, 0.25), (0.34, 0.26, 0.3))   # contragewicht
    commit("Radarhoorn", g, M["donker"], radar, tile=1.0)
    return radar


def mast(g, x, y, z0, h, w=0.09, antennas=True):
    """Vakwerkmast met drie poten, diagonalen, rustplatform en antennes."""
    legs = [(x + w * math.cos(a), y + w * math.sin(a)) for a in (math.pi / 2, math.pi / 2 + 2.094, math.pi / 2 + 4.188)]
    for lx, ly in legs:
        st(g, (lx, ly, z0), (lx, ly, z0 + h), 0.014, seg=5)
    n = max(3, int(h / 0.3))
    for i in range(n):
        za, zb = z0 + h * i / n, z0 + h * (i + 1) / n
        for j in range(3):
            a, b = legs[j], legs[(j + 1) % 3]
            if (i + j) % 2 == 0:
                st(g, (a[0], a[1], za), (b[0], b[1], zb), 0.007, seg=4)
            else:
                st(g, (b[0], b[1], za), (a[0], a[1], zb), 0.007, seg=4)
            if D >= 2 and j == 0:
                st(g, (a[0], a[1], zb), (b[0], b[1], zb), 0.006, seg=4)
    cy(g, T(x, y, z0 + 0.04), 0.14, 0.08, seg=SEGC)
    bx(g, T(x, y, z0 + 0.08), (0.34, 0.34, 0.03))
    if antennas:
        # dwarsarmen met schotel-antenne en yagi
        st(g, (x - 0.3, y, z0 + h * 0.72), (x + 0.3, y, z0 + h * 0.72), 0.01, seg=5)
        for k in range(5):
            xx = x - 0.28 + k * 0.14
            st(g, (xx, y - 0.06 - 0.01 * k, z0 + h * 0.72), (xx, y + 0.06 + 0.01 * k, z0 + h * 0.72), 0.005, seg=4)
        st(g, (x, y, z0 + h), (x, y, z0 + h + 0.35), 0.008, seg=5)
        st(g, (x - 0.2, y, z0 + h * 0.45), (x + 0.2, y, z0 + h * 0.45), 0.008, seg=5)
    return legs


def build_masts(M, root):
    """Vakwerkmasten op het dak (rood knipperlicht op de hoogste), haakse steunen, haken en een zendkast."""
    g = G()
    specs = [(-1.55, -1.55, 2.9), (0.45, 1.65, 1.8), (1.65, 0.25, 1.4)]
    for x, y, h in specs:
        mast(g, x, y, ROOF, h)
    # tuidraden
    x, y, h = specs[0]
    for tx, ty in ((-1.9, -0.3), (-0.2, -1.9), (-1.9, -1.9)):
        st(g, (x, y, ROOF + h * 0.8), (tx, ty, ROOF + 0.35), 0.004, seg=4)
    if D >= 1:
        # zendkast, buizen en kabelgoot op het dak, hatch
        bx(g, T(-0.8, -1.55, ROOF + 0.3), (0.6, 0.5, 0.6))
        bx(g, T(-0.8, -1.80, ROOF + 0.3), (0.52, 0.02, 0.5), bevel=False)
        for z in (0.2, 0.3, 0.4):
            bx(g, T(-0.8, -1.82, ROOF + z), (0.46, 0.02, 0.03), bevel=False)
        st(g, (-1.1, -1.55, ROOF + 0.05), (-1.5, -1.55, ROOF + 0.05), 0.03, seg=6)
        st(g, (-0.8, -1.3, ROOF + 0.02), (-0.8, 0.2, ROOF + 0.02), 0.035, seg=6)
        st(g, (-0.8, 0.2, ROOF + 0.02), (-0.2, 0.2, ROOF + 0.02), 0.035, seg=6)
        # toegangsluik
        bx(g, T(0.55, -1.2, ROOF + 0.07), (0.95, 0.95, 0.14))
        bx(g, T(0.55, -1.2, ROOF + 0.17), (0.82, 0.82, 0.07))
        cy(g, T(0.82, -1.2, ROOF + 0.23), 0.04, 0.05, seg=SEGC)
        for k in (-1, 1):
            bx(g, T(0.55 + k * 0.38, -1.58, ROOF + 0.2), (0.07, 0.05, 0.07))
        # schoorstenen / ontluchters
        for (vx, vy) in ((1.0, 1.3), (-1.0, 0.9)):
            cy(g, T(vx, vy, ROOF + 0.2), 0.08, 0.4, seg=SEGC)
            cy(g, T(vx, vy, ROOF + 0.45), 0.13, 0.04, seg=SEGC, r2=0.04)
        # spuigaten en regenpijp over de rand
        for side in range(4):
            bx(g, WM(side, 0.9, 0.0, ROOF + 0.07, half=UW / 2 + 0.25), (0.2, 0.15, 0.1))
    commit("Antennes", g, M["donker"], root, tile=1.0)
    g = G()
    x, y, h = specs[0]
    cy(g, T(x, y, ROOF + h + 0.05), 0.07, 0.1, seg=SEGC)
    commit("Lamp_Rood", g, M["rood"], root, tile=1.0, smooth=True)


def build_net(M, root):
    nx, ny = (16, 22) if D >= 1 else (4, 6)
    bm = bmesh.new()
    verts = []
    x_in, x_out = -W / 2 - 0.02, -W / 2 - 2.6
    y0, y1 = -2.3, 2.5
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
    g = G()
    for (y, h) in ((-2.3, 1.9), (0.1, 1.8), (2.5, 1.85)):
        cy(g, T(x_out, y, h / 2 + Z0 * 0.2), 0.045, h + 0.5, seg=SEGC)
        cy(g, T(x_out, y, 0.04), 0.14, 0.06, seg=SEGC)
        st(g, (x_out, y, h * 0.9), (x_out - 0.5, y + (0.35 if y < 0.5 else -0.35), 0.02), 0.01, seg=4)   # tuidraad
    for y in (-2.3, -1.1, 0.1, 1.3, 2.5):
        st(g, (x_in, y, 2.52), (x_out, y, 1.86), 0.012, seg=4)
    bx(g, T(x_in - 0.03, (y0 + y1) / 2, 2.57), (0.06, y1 - y0, 0.08))        # lat waaraan het net hangt
    commit("Netpalen", g, M["donker"], root, tile=1.0)


# ------------------------------------------------------------------ extra detail: raamwerk, plaatjes, kabels, ranken
def cable(g, a, b, sag, r=0.008, n=8):
    a, b = Vector(a), Vector(b)
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(a.lerp(b, t) + Vector((0, 0, -sag * 4 * t * (1 - t))))
    for q0, q1 in zip(pts[:-1], pts[1:]):
        st(g, q0, q1, r, seg=4)


def vine(gs, gl, side, u0, z0, height, half, seed):
    rng = random.Random(seed)
    u, d = u0, 0.035
    z = z0
    prev = None
    n = max(3, int(height / 0.11))
    for i in range(n + 1):
        u += rng.uniform(-0.07, 0.07)
        d = 0.03 + 0.02 * rng.random()
        z += 0.11 * rng.uniform(0.8, 1.2)
        P = (WM(side, u, d, z, half=half) @ Vector((0, 0, 0)))
        if prev is not None:
            st(gs, prev, P, 0.009, seg=4)
        prev = P
        for k in range(3 if D >= 1 else 1):
            L = rng.uniform(0.09, 0.16)
            Mq = WM(side, u + rng.uniform(-0.05, 0.05), d + 0.02 + 0.03 * k, z + rng.uniform(-0.04, 0.04), half=half) @ RY(rng.uniform(0, 6.28)) @ RX(rng.uniform(-0.6, 0.6))
            bm = gl.c
            cs = ((0, 0, L / 2), (L * 0.30, 0, 0), (0, 0, -L / 2), (-L * 0.30, 0, 0))
            bm.faces.new([bm.verts.new(Mq @ Vector(c)) for c in cs])
            bm.faces.new([bm.verts.new(Mq @ Vector((c[0], c[1] + 0.001, c[2]))) for c in cs[::-1]])


def build_extra(M, root):
    uh = UW / 2
    g = G()
    # raamwerk: scharnieren, grendels, druipkap per vak
    for side in range(4):
        for bay in range(4):
            u = -1.1625 + bay * 0.775
            for z in (3.95, 4.38):
                bx(g, WM(side, u - 0.355, 0.085, z, half=uh), (0.035, 0.05, 0.1))
            bx(g, WM(side, u + 0.34, 0.085, 4.14, half=uh), (0.03, 0.05, 0.14))
            cy(g, WM(side, u + 0.34, 0.115, 4.14, half=uh) @ RX(math.pi / 2), 0.022, 0.03, seg=SEGC)
            bx(g, WM(side, u, 0.08, 4.625, half=uh), (0.72, 0.06, 0.03))
            bx(g, WM(side, u, 0.075, 3.76, half=uh), (0.70, 0.05, 0.03))
    # lasnaden tussen de pantserplaten
    for side in range(4):
        for u in (-1.1, 0.0, 1.1):
            if side == 0 and abs(u) < 1.0:
                continue
            bx(g, WM(side, u, 0.085, 0.95), (0.018, 0.02, 1.0), bevel=False)
    # kabelbeugels langs de leidingen op de achterwand en bij de trap
    for u in np.linspace(-1.2, 1.2, 5):
        bx(g, WM(2, float(u), 0.03, 2.28), (0.03, 0.05, 0.12))
    # vuurblusser met slang en beugel (achterwand)
    cy(g, WM(2, -0.45, 0.12, 0.95), 0.075, 0.42, seg=SEGC + 2)
    cy(g, WM(2, -0.45, 0.12, 1.19), 0.03, 0.08, seg=SEGC)
    bx(g, WM(2, -0.45, 0.2, 1.24), (0.06, 0.06, 0.04))
    for z in (0.8, 1.1):
        bx(g, WM(2, -0.45, 0.1, z), (0.16, 0.03, 0.03))
    # kooilampen op het lagere dak
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = Vector((sx * 2.3, sy * 2.3, ZL))
            bx(g, T(*c) @ T(0, 0, 0.05), (0.2, 0.2, 0.1))
            for k in range(6):
                a = k * math.pi / 3
                st(g, c + Vector((0.07 * math.cos(a), 0.07 * math.sin(a), 0.1)), c + Vector((0.04 * math.cos(a), 0.04 * math.sin(a), 0.3)), 0.006, seg=4)
            cy(g, T(*c) @ T(0, 0, 0.2), 0.055, 0.14, seg=SEGC)
    # dakbedekking: bitumenbanen met naden, schoorstenen, afvoeren, bevestigingsstrips en looproosters
    gr_ = G()
    for k, y in enumerate(np.linspace(-1.55, 1.55, 8)):
        bx(gr_, T(0, float(y), ROOF + 0.004), (3.62, 0.016, 0.008), bevel=False)
    for x in np.linspace(-1.5, 1.5, 6):
        bx(gr_, T(float(x), 0, ROOF + 0.004), (0.016, 3.62, 0.008), bevel=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cy(gr_, T(sx * 1.78, sy * 1.78, ROOF + 0.03), 0.11, 0.06, seg=SEGC + 4)        # afvoerputjes
            cy(gr_, T(sx * 1.78, sy * 1.78, ROOF + 0.065), 0.075, 0.02, seg=SEGC + 4)
    for i in range(7):                                                                         # looproosterlatten naar het luik
        bx(gr_, T(0.55, -0.55 - i * 0.12, ROOF + 0.015), (0.8, 0.07, 0.022))
    for k in range(10):                                                                        # bevestigingsstrips langs de rand
        a = -1.7 + k * 0.38
        bx(gr_, T(a, -1.86, ROOF + 0.012), (0.12, 0.03, 0.02))
        bx(gr_, T(a, 1.86, ROOF + 0.012), (0.12, 0.03, 0.02))
    commit("Dakbedekking", gr_, M["zwart"], root, tile=1.0)
    # kabels over het dak
    cable(g, (-1.55, -1.55, ROOF + 1.2), (-0.8, -1.8, ROOF + 0.45), 0.25, 0.01)
    cable(g, (-0.8, -1.3, ROOF + 0.55), (0.0, 0.0, ROOF + 0.45), 0.12, 0.011)
    cable(g, (0.55, -1.2, ROOF + 0.2), (1.5, -1.5, ROOF + 0.15), 0.1, 0.01)
    cable(g, (1.35, 1.0, ROOF + 0.9), (0.0, 0.5, ROOF + 0.4), 0.2, 0.01)
    cable(g, (0.45, 1.65, ROOF + 1.2), (1.35, 1.35, ROOF + 1.2), 0.15, 0.007)
    cable(g, (-W / 2 - 0.1, -0.2, 2.6), (-W / 2 - 0.1, 1.6, 2.5), 0.12, 0.012)
    commit("Details", g, M["donker"], root, tile=1.0)
    # plaatjes: waarschuwingsbord, eenheidsplaat, geel-zwarte randen
    gy = G()
    gz = G()
    gw = G()
    gr = G()
    bx(gy, WM(0, -1.65, 0.05, 1.78) @ RY(math.pi / 4), (0.3, 0.012, 0.3), bevel=False)
    bx(gz, WM(0, -1.65, 0.058, 1.78) @ RY(math.pi / 4), (0.22, 0.012, 0.22), bevel=False)
    bx(gy, WM(0, -1.65, 0.066, 1.78) @ RY(math.pi / 4), (0.16, 0.012, 0.16), bevel=False)
    bx(gz, WM(0, -1.65, 0.075, 1.8), (0.03, 0.01, 0.1), bevel=False)
    bx(gw, WM(0, 1.65, 0.05, 1.8), (0.6, 0.012, 0.22), bevel=False)
    bx(gz, WM(0, 1.65, 0.056, 1.8), (0.56, 0.012, 0.18), bevel=False)
    for k in range(5):
        bx(gw, WM(0, 1.45 + k * 0.1, 0.064, 1.8), (0.05, 0.012, 0.1), bevel=False)
    for side in (1, 2, 3):
        bx(gy, WM(side, 1.2 if side != 1 else -1.2, 0.05, 2.0), (0.4, 0.012, 0.18), bevel=False)
        for k in range(5):
            bx(gz, WM(side, (1.2 if side != 1 else -1.2) - 0.16 + k * 0.08, 0.058, 2.0) @ RY(0.0), (0.03, 0.012, 0.18), bevel=False)
    cy(gr, WM(2, -0.45, 0.12, 0.95), 0.0775, 0.3, seg=SEGC + 2)
    commit("Plaatjes_geel", gy, M["geel"], root, tile=1.0, bevel=False)
    commit("Plaatjes_zwart", gz, M["zwart"], root, tile=1.0, bevel=False)
    commit("Plaatjes_wit", gw, M["wit"], root, tile=1.0, bevel=False)
    commit("Blusser", gr, M["rood_verf"], root, tile=1.0, bevel=False)
    # ranken: jungle neemt het gebouw terug
    gs = G()
    gl = G()
    vine(gs, gl, 3, 2.1, 0.3, 2.4, W / 2, 1)      # westwand hoek
    vine(gs, gl, 2, -1.6, 0.3, 2.0, W / 2, 2)     # achterwand links
    vine(gs, gl, 2, 1.0, 0.3, 1.2, W / 2, 3)
    vine(gs, gl, 0, -2.15, 0.3, 2.7, W / 2, 4)    # voorhoek links
    vine(gs, gl, 1, 2.1, 0.3, 2.9, W / 2, 5)      # oosthoek achter
    vine(gs, gl, 3, -0.4, 2.9, 1.2, UW / 2, 6)    # bovenverdieping west
    commit("Rankstam", gs, M["stam"], root, tile=1.0, bevel=False)
    commit("Ranken", gl, M["blad"], root, tile=1.0, smooth=False, bevel=False)


# ------------------------------------------------------------------ niveau 1 voller: leidingen, kratten, lampen, airco
def crate(g, gd, M4, sz):
    bx(g, M4, sz)
    for k in (-0.28, 0.28):          # stalen banden
        bx(gd, M4 @ T(sz[0] * k, 0, 0), (0.03, sz[1] + 0.02, sz[2] + 0.02), bevel=False)


def build_vol(M, root):
    """Niveau 1 af: het lagere dak en de wanden zijn niet langer kaal. Leidingen, kratten, regenpijpen, luchtroosters, een kooilamp,
    een betonnen stoep, op het dak een airco, ventilatiekappen en antennes. Altijd zichtbaar (geen niveau-onderdeel)."""
    gc = G()
    bx(gc, WM(0, 1.2, 0.63, 0.06), (2.4, 0.72, 0.12))                          # stoep voor de pantserdeur
    bx(gc, WM(0, 1.2, 0.95, 0.03), (2.1, 0.5, 0.06))
    commit("Vol_beton", gc, M["beton"], root, tile=2.0)
    if D < 1:
        return
    gs, gd, ga = G(), G(), G()
    uh = UW / 2
    # lagere dak, voorkant: leidingstrang met beugels en twee aansluitkastjes
    cy(gd, WM(0, 0, 0.09, ZL + 0.07, half=uh) @ RY(math.pi / 2), 0.045, 3.5, seg=SEGC)
    for u in (-1.6, -0.8, 0.0, 0.8, 1.6):
        bx(gd, WM(0, u, 0.09, ZL + 0.03, half=uh), (0.07, 0.11, 0.06))
    for u in (-0.95, 0.95):
        bx(gs, WM(0, u, 0.15, ZL + 0.15, half=uh), (0.22, 0.12, 0.2))
        cy(gd, WM(0, u, 0.15, ZL + 0.3, half=uh), 0.02, 0.1, seg=SEGC)
    # lagere dak, westkant: voorraadkratten met banden en een opgerold zeil
    crate(gs, gd, WM(3, -1.0, 0.17, ZL + 0.14, half=uh) @ RZ(0.05), (0.55, 0.27, 0.28))
    crate(gs, gd, WM(3, -0.35, 0.17, ZL + 0.14, half=uh) @ RZ(-0.04), (0.5, 0.27, 0.28))
    crate(gs, gd, WM(3, -0.95, 0.17, ZL + 0.42, half=uh) @ RZ(-0.09), (0.48, 0.25, 0.26))
    cy(gs, WM(3, 0.55, 0.16, ZL + 0.1, half=uh) @ RY(math.pi / 2), 0.1, 0.85, seg=SEGC + 2)
    for u in (0.3, 0.8):
        cy(gd, WM(3, u, 0.16, ZL + 0.1, half=uh) @ RY(math.pi / 2), 0.103, 0.03, seg=SEGC + 2)
    # lagere dak, achterkant: regenpijp-trechters
    for u in (-2.0, 1.95):
        bx(gs, WM(2, u, 0.12, ZL + 0.06, half=uh), (0.22, 0.2, 0.12))
    # regenpijpen langs de achterwand met beugels en een knie onderaan
    for u in (-2.0, 1.95):
        cy(gd, WM(2, u, 0.09, 1.7), 0.045, 2.5, seg=SEGC)
        for z in (0.7, 1.35, 2.0, 2.6):
            bx(gd, WM(2, u, 0.06, z), (0.1, 0.07, 0.05))
        cy(gd, WM(2, u, 0.2, 0.46) @ RX(math.pi / 2), 0.045, 0.2, seg=SEGC)
    # westwand: twee luchtroosters met schuine lamellen
    for u in (-1.05, 1.05):
        bx(gs, WM(3, u, 0.045, 1.35), (0.74, 0.06, 0.5))
        for k in range(6):
            bx(gd, WM(3, u, 0.085, 1.16 + k * 0.075) @ RX(math.radians(-35)), (0.64, 0.028, 0.045), bevel=False)
    # voorwand: kooilamp links van de deur met lens en kabel
    u, z = -0.55, 2.0
    bx(gd, WM(0, u, 0.05, z), (0.1, 0.1, 0.18))
    cy(gd, WM(0, u, 0.15, z) @ RX(math.pi / 2), 0.085, 0.14, seg=SEGC + 2)
    for k in range(6):
        a = k * math.pi / 3
        Pn = Vector((0.095 * math.cos(a), 0.0, 0.095 * math.sin(a)))
        st(gd, WM(0, u, 0.09, z) @ Pn, WM(0, u, 0.24, z) @ Pn, 0.006, seg=4)
    cy(ga, WM(0, u, 0.245, z) @ RX(math.pi / 2), 0.07, 0.03, seg=SEGC + 2)
    st(gd, WM(0, u, 0.04, z + 0.09).translation, WM(0, u, 0.04, z + 0.55).translation, 0.012, seg=4)
    commit("Lamp_Wand", ga, M["amber"], root, tile=1.0)
    # dak: airco-kast met ventilator, twee ventilatiekappen, twee zweepantennes, luikgreep
    bx(gs, T(-0.55, 1.42, ROOF + 0.27), (0.7, 0.42, 0.5))
    for sx in (-0.28, 0.28):
        bx(gd, T(-0.55 + sx, 1.42, ROOF + 0.06), (0.08, 0.5, 0.12))
    cy(gd, T(-0.7, 1.42, ROOF + 0.53), 0.16, 0.03, seg=SEGC + 4)
    for k in range(4):
        bx(gd, T(-0.7, 1.42, ROOF + 0.545) @ RZ(k * math.pi / 4), (0.3, 0.014, 0.012), bevel=False)
    for k in range(5):
        bx(gd, T(-0.2, 1.42, ROOF + 0.14 + k * 0.07), (0.015, 0.36, 0.03), bevel=False)
    for (x, y, h) in ((-1.62, -0.78, 0.55), (-1.42, -1.02, 0.42)):
        cy(gd, T(x, y, ROOF + h / 2), 0.06, h, seg=SEGC)
        cy(gd, T(x, y, ROOF + h + 0.03), 0.11, 0.06, seg=SEGC, r2=0.02)
        cy(gd, T(x, y, ROOF + 0.03), 0.09, 0.04, seg=SEGC)
    for (x, y, h) in ((0.2, -1.72, 1.4), (-0.95, 1.78, 1.1)):
        cy(gd, T(x, y, ROOF + 0.03), 0.05, 0.06, seg=SEGC)
        st(gd, (x, y, ROOF + 0.05), (x + 0.02, y, ROOF + h), 0.007, seg=4)
        cy(gd, T(x + 0.02, y, ROOF + h), 0.014, 0.05, seg=SEGC)
    bx(gd, T(0.44, -1.0, ROOF + 0.13), (0.2, 0.03, 0.03))
    commit("Vol_staal", gs, M["staal"], root, tile=1.2)
    commit("Vol_donker", gd, M["donker"], root, tile=1.0)


# ------------------------------------------------------------------ niveaus
def sandbag(g, M4, sz=(0.5, 0.28, 0.17)):
    bmesh.ops.create_cube(g.b, size=1.0, matrix=M4 @ Matrix.Diagonal((sz[0], sz[1], sz[2], 1.0)))


def build_levels(M, root):
    """Zandzakwal rond het lagere dak: hoort bij elk niveau (sluit de open dakrand). Niveau 2: radardeel (tweede schotel, antennerek,
    pantserlijsten). Niveau 3: dikke wal (vijf lagen en een binnenrij), zoeklicht, luiken, ruimte voor het dakgeschut (het zandzaknest
    om het geweer bouwt Godot zelf). De vlag krijgt een ster per niveau: zie doek_*_s2/_s3 bij de export."""
    n2 = empty("Niveau2", root)
    g = G()
    # antennerek met kast (dak, oosthoek achter)
    bx(g, T(1.35, 1.35, ROOF + 0.35), (0.8, 0.8, 0.5))
    for dx in (-0.35, 0.35):
        for dy in (-0.35, 0.35):
            cy(g, T(1.35 + dx, 1.35 + dy, ROOF + 0.9), 0.018, 0.8, seg=6)
    bx(g, T(1.35, 1.35, ROOF + 1.3), (0.84, 0.84, 0.04))
    for k in range(4):
        beam(g, (1.35 - 0.35, 1.35 - 0.35, ROOF + 0.65 + 0.15 * k), (1.35 + 0.35, 1.35 + 0.35, ROOF + 0.8 + 0.15 * k), 0.012, 0.012, bevel=False)
    # pantserlijsten onder de ramen
    for side in range(4):
        bx(g, WM(side, 0, 0.14, 3.34, half=UW / 2), (UW - 0.2, 0.06, 0.4))
        rivet_row(g, side, -1.6, 1.6, 0.18, 3.34, 8, half=UW / 2, r=0.018) if D >= 1 else None
    commit("Niveau2_rek", g, M["staal"], n2, tile=1.2)
    g = G()
    sp = Vector((-1.2, 0.2, ROOF))
    cy(g, T(sp.x, sp.y, ROOF + 0.12), 0.34, 0.24, seg=SEGC + 4)
    cy(g, T(sp.x, sp.y, ROOF + 0.35), 0.11, 0.28, seg=SEGC)
    bm = g.c
    bmesh.ops.create_uvsphere(bm, u_segments=SEGC + 8 if D else 6, v_segments=10 if D else 4, radius=0.5,
                              matrix=T(sp.x, sp.y, ROOF + 0.86) @ RX(math.radians(-30)) @ Matrix.Diagonal((1, 1, 0.34, 1)))
    st(g, (sp.x, sp.y, ROOF + 0.5), (sp.x + 0.1, sp.y - 0.12, ROOF + 1.05), 0.02, seg=5)
    commit("Niveau2_schotel", g, M["wit_g"], n2, smooth=False, tile=1.0)
    # zandzakwal rond het lagere dak: drie lagen, verspringend; staat op de wortel (niet onder Niveau3), dus op elk niveau zichtbaar
    g = G()
    rng = random.Random(8)
    ring_h = W / 2 + 0.02
    for layer in range(3):
        for side in range(4):
            n = 11
            span = W - 0.9
            for i in range(n):
                u = -span / 2 + (i + 0.5 + (0.5 if layer % 2 else 0.0)) * span / n
                if abs(u) > span / 2:
                    continue
                m4 = WM(side, u + rng.uniform(-0.02, 0.02), -0.15, ZL + 0.11 + layer * 0.17, half=ring_h) @ RZ(rng.uniform(-0.05, 0.05))
                sandbag(g, m4, (span / n * 1.02, 0.30, 0.18))
    commit("Zandzakwal", g, M["zak"], root, tile=1.2, bevel=True, bw=0.045)
    n3 = empty("Niveau3", root)
    # dikke wal (niveau 3): twee extra lagen op de buitenrij (samen vijf lagen) en een tweede, binnenste rij van drie lagen
    g = G()
    rng = random.Random(9)
    for layer in (3, 4):
        for side in range(4):
            n = 11
            span = W - 0.9
            for i in range(n):
                u = -span / 2 + (i + 0.5 + (0.5 if layer % 2 else 0.0)) * span / n
                if abs(u) > span / 2:
                    continue
                m4 = WM(side, u + rng.uniform(-0.02, 0.02), -0.15, ZL + 0.11 + layer * 0.17, half=ring_h) @ RZ(rng.uniform(-0.05, 0.05))
                sandbag(g, m4, (span / n * 1.02, 0.30, 0.18))
    commit("Niveau3_wal_buiten", g, M["zak"], n3, tile=1.2, bevel=True, bw=0.045)
    g = G()
    for layer in range(3):
        for side in range(4):
            n = 9
            span = UW - 0.4
            for i in range(n):
                u = -span / 2 + (i + 0.5 + (0.5 if layer % 2 else 0.0)) * span / n
                if abs(u) > span / 2:
                    continue
                m4 = WM(side, u + rng.uniform(-0.02, 0.02), -0.40, ZL + 0.11 + layer * 0.17, half=ring_h) @ RZ(rng.uniform(-0.05, 0.05))
                sandbag(g, m4, (span / n * 1.02, 0.30, 0.18))
    commit("Niveau3_wal_binnen", g, M["zak"], n3, tile=1.2, bevel=True, bw=0.045)
    g = G()
    # zoeklicht op paal met steunen en kabel
    cy(g, T(1.5, -1.5, ROOF + 0.9), 0.045, 1.4, seg=SEGC)
    cy(g, T(1.5, -1.5, ROOF + 0.12), 0.18, 0.1, seg=SEGC)
    cy(g, T(1.5, -1.5, ROOF + 1.75) @ RX(math.pi / 2), 0.2, 0.34, seg=SEGC + 4)
    bx(g, T(1.5, -1.5, ROOF + 1.55), (0.1, 0.1, 0.14))
    for k in (-1, 1):
        beam(g, (1.5, -1.5, ROOF + 0.4), (1.5 + k * 0.26, -1.5, ROOF + 0.1), 0.03, 0.03)
    commit("Niveau3_zoeklicht", g, M["donker"], n3, smooth=False, tile=1.0)
    g = G()
    cy(g, T(1.5, -1.71, ROOF + 1.75) @ RX(math.pi / 2), 0.15, 0.03, seg=SEGC + 4)
    commit("Niveau3_zoeklamp", g, M["amber"], n3, tile=1.0)
    # rollende stalen luiken boven de ramen (half gesloten) met geribde lamellen
    g = G()
    for side in range(4):
        for x in (-1.2, 1.2):
            bx(g, WM(side, x, 0.22, 4.40, half=UW / 2), (1.1, 0.05, 0.4))
            if D >= 1:
                for k in range(4):
                    bx(g, WM(side, x, 0.255, 4.25 + k * 0.1, half=UW / 2), (1.08, 0.02, 0.03), bevel=False)
                rivet_row(g, side, x - 0.5, x + 0.5, 0.25, 4.58, 4, half=UW / 2, r=0.016)
        bx(g, WM(side, 0, 0.28, 4.66, half=UW / 2), (UW - 0.4, 0.12, 0.14))
    commit("Niveau3_luiken", g, M["staal"], n3, tile=1.2)


def build_damage(M, root):
    for lvl, ux in ((1, 0.0), (2, 0.5)):
        e = empty(f"Schade{lvl}", root)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        spots = [(-1.2, -W / 2 - 0.115, 1.9, 1.6, 1.3, 0), (1.3, -W / 2 - 0.115, 1.3, 1.5, 1.2, 0),
                 (W / 2 + 0.115, -0.4, 1.8, 1.8, 1.4, 1), (-W / 2 - 0.115, 0.7, 1.5, 1.7, 1.3, 3),
                 (0.0, -UW / 2 - 0.12, 3.5, 1.9, 1.0, 0)]
        if lvl == 1:
            spots = spots[:3]
        for i, (x, y, z, w, h, side) in enumerate(spots):
            vs = []
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                if abs(x) > W / 2 - 0.1 and abs(y) < W / 2 - 0.1:
                    p = Vector((x, y + sx * w / 2, z + sz * h / 2))
                else:
                    p = Vector((x + sx * w / 2, y, z + sz * h / 2))
                vs.append(bm.verts.new(p))
            f = bm.faces.new(vs)
            for lp, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                lp[uv].uv = (ux + u * 0.5, v)
        F.new_obj(f"Schade{lvl}_vlakken", bm, M["schade"], smooth=False, parent=e)


# ------------------------------------------------------------------ binnenkant bovenverdieping
def build_interior(M, root):
    g = G()
    bx(g, T(0, 0, 4.12), (UW - 0.3, UW - 0.3, 1.0), bevel=False)
    if D >= 1:
        # consoles langs de wanden, kaartentafel in het midden, stoelen
        for side in range(4):
            bx(g, WM(side, 0, -0.35, 3.85, half=UW / 2 - 0.15), (2.6, 0.5, 0.45))
            bx(g, WM(side, 0, -0.38, 4.12, half=UW / 2 - 0.15), (2.7, 0.55, 0.05))
        bx(g, T(0, 0, 3.85), (1.2, 0.9, 0.5))
        bx(g, T(0, 0, 4.12), (1.3, 1.0, 0.05))
        for x in (-0.5, 0.5):
            bx(g, T(x, -0.9, 3.95), (0.4, 0.4, 0.1))
            bx(g, T(x, -1.0, 4.2), (0.4, 0.06, 0.45))
    commit("Binnen", g, M["donker"], root, tile=2.0)
    if D >= 1:
        g = G()
        for i, x in enumerate((-1.2, -0.4, 0.4, 1.2)):
            bx(g, T(x, -UW / 2 + 0.52, 4.2), (0.55, 0.05, 0.32), bevel=False)
        for x in (-1.2, 1.2):
            bx(g, T(x, UW / 2 - 0.52, 4.2), (0.55, 0.05, 0.32), bevel=False)
        for y in (-0.9, 0.0, 0.9):
            bx(g, T(UW / 2 - 0.52, y, 4.2), (0.05, 0.5, 0.32), bevel=False)
        commit("Schermen", g, M["amber"], root, tile=1.0)
    g = G()
    for side in range(4):
        bx(g, WM(side, 0, 0.005, 4.135, half=UW / 2), (UW - 0.42, 0.03, 0.86), bevel=False)
    commit("Glas", g, M["glas"], root, tile=2.0)


def clip(o, name, action):
    ad = o.animation_data_create()
    ad.action = None
    tr = ad.nla_tracks.new()
    tr.name = name
    st_ = tr.strips.new(name, 0, action)
    st_.name = name


def animate(radar, door, rig):
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    radar.rotation_mode = "XYZ"
    for f, ang in ((0, 0.0), (120, math.pi), (240, 2 * math.pi)):
        radar.rotation_euler = (0, 0, ang)
        radar.keyframe_insert("rotation_euler", frame=f)
    act = radar.animation_data.action
    act.name = "Radar-loop"
    clip(radar, "Radar-loop", act)
    for name, seq in (("Dicht", ((0, 1.28), (6, 1.28), (30, 0.0))), ("Open", ((0, 0.0), (6, 0.0), (30, 1.28)))):   # Open bovenaan: rustpose = dicht
        for f, x in seq:
            door.location = (x, door.location[1], door.location[2])
            door.keyframe_insert("location", frame=f)
        act = door.animation_data.action
        act.name = name
        clip(door, name, act)
    act = rig.animation_data.action
    clip(rig, "Wapperen-loop", act)
    for tr in door.animation_data.nla_tracks:   # rustpose = dicht; de clips doen de rest
        tr.mute = True
    door.location = (0, door.location[1], door.location[2])
    sc.frame_set(0)
    for tr in door.animation_data.nla_tracks:
        tr.mute = False
    door.location = (0, door.location[1], door.location[2])
    sc.frame_end = 240


# ------------------------------------------------------------------ bakken
DETAIL_NAMES = {"Trap", "Trap_markering", "Radarvoet", "Radarhoorn", "Schotel", "Antennes", "Netpalen", "Niveau2_schotel",
                "Niveau2_rek", "Zandzakwal", "Niveau3_wal_buiten", "Niveau3_wal_binnen", "Niveau3_zoeklicht", "Niveau3_luiken", "Paal", "Messing", "Binnen", "Ranken", "Rankstam",
                "Vol_staal", "Vol_donker"}


def bake_all(root, M, bake_names):
    """Bak alle bakeable objecten in twee 2K-atlassen (romp en details) en vervang hun materialen."""
    objs = [o for o in bpy.data.objects if o.type == "MESH" and o.material_slots
            and all(s.material and s.material.get("bake_kind") for s in o.material_slots)]
    print(f"[bake] {len(objs)} objecten, atlas {ATLAS}")
    sc = bpy.context.scene
    w = bpy.data.worlds.new("BakeWorld")
    sc.world = w
    w.light_settings.distance = 1.3
    margin = 0.003 if ATLAS >= 2048 else 0.005
    B.make_atlas_uvs(objs, margin=margin)
    B.cull_hidden(objs)
    dg = bpy.context.evaluated_depsgraph_get()
    tri_total = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            me = o.evaluated_get(dg).to_mesh()
            tri_total += sum(len(p.vertices) - 2 for p in me.polygons)
    print(f"[{LEVEL}] driehoeken na snoeien: {tri_total}")
    if os.environ.get("HK_STOP_AFTER_CULL"):
        # controle: de kniemuur onder de ramen (grote verticale vlakken tussen z 2,8 en 3,7) moet in de Romp zitten
        romp = bpy.data.objects.get("Romp")
        if romp is not None:
            n_wall = 0
            for p in romp.data.polygons:
                zs = [(romp.matrix_world @ romp.data.vertices[i].co).z for i in p.vertices]
                if p.area > 0.4 and abs(p.normal.z) < 0.3 and min(zs) >= 2.8 and max(zs) <= 3.7:
                    n_wall += 1
            print(f"[cull] kniemuurvlakken in de Romp: {n_wall}")
        sys.exit(0)
    suffix = "" if LEVEL != "lod1" else "_lod1"
    groups = (("romp", [o for o in objs if o.name not in DETAIL_NAMES]), ("details", [o for o in objs if o.name in DETAIL_NAMES]))
    for gname, gobjs in groups:
        if not gobjs:
            continue
        B.make_atlas_uvs(gobjs, margin=margin)
        tag = f"hk_{gname}{suffix}"
        paths = B.run(gobjs, ATLAS, OUT, samples=SAMPLES, tag=tag)
        p_alb, p_orm, p_nrm = B.compose(paths, ATLAS, OUT, tag=tag, jpeg=(LEVEL != 'hq'))
        mat = B.baked_material(f"HK_Gebakken_{gname}", p_alb, p_orm, p_nrm)
        for o in gobjs:
            o.data.materials.clear()
            o.data.materials.append(mat)
            for p in o.data.polygons:
                p.material_index = 0
            if "UVMap" in o.data.uv_layers:
                o.data.uv_layers.remove(o.data.uv_layers["UVMap"])
        # bakeable materialen pas weghalen als ze niet meer nodig zijn voor de volgende groep
    for m in list(bpy.data.materials):
        if m.get("bake_kind"):
            bpy.data.materials.remove(m)


# ------------------------------------------------------------------ opbouw
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    res = TEXRES
    cn = F.tinted_set("concrete", (0.80, 0.78, 0.72), res)
    ol = F.tinted_set("olive", (0.64, 0.70, 0.44), res)
    dk = F.tinted_set("steel", (0.58, 0.58, 0.54), res)
    M = {
        "beton": B.weathered("HK_Beton", "concrete", albedo=cn["albedo"], normal=cn["normal"], orm=cn["orm"], nstrength=1.1, seed=1),
        "staal": B.weathered("HK_Staal_olijf", "paint", albedo=ol["albedo"], normal=ol["normal"], orm=ol["orm"], nstrength=0.9, seed=2),
        "donker": B.weathered("HK_Metaal_donker", "metal", albedo=dk["albedo"], normal=dk["normal"], orm=dk["orm"], nstrength=0.6, seed=3),
        "wit": B.weathered("HK_Verf_wit", "paint", color=(0.50, 0.48, 0.42), rough=0.7, seed=4),
        "wit_g": B.weathered("HK_Verf_schotel", "paint", albedo=ol["albedo"], normal=ol["normal"], orm=ol["orm"], nstrength=0.5, seed=5, wear=0.8),
        "geel": B.weathered("HK_Verf_geel", "paint", color=(0.55, 0.38, 0.04), rough=0.65, seed=6),
        "zak": B.weathered("HK_Zandzak", "rubber", color=(0.27, 0.22, 0.13), rough=0.95, seed=7),
        "zwart": B.weathered("HK_Rubber", "rubber", color=(0.03, 0.03, 0.03), rough=0.8, seed=8),
        "rood_verf": B.weathered("HK_Verf_rood", "paint", color=(0.38, 0.04, 0.03), rough=0.5, seed=9),
        "blad": B.weathered("HK_Blad", "rubber", color=(0.05, 0.11, 0.03), rough=0.6, seed=10),
        "stam": B.weathered("HK_Rank", "rubber", color=(0.08, 0.06, 0.035), rough=0.85, seed=11),
        "glas": F.plain("HK_Glas", (0.05, 0.10, 0.11), 0.06, metal=0.0, alpha=0.42),
        "rood": F.plain("HK_Lamp_rood", (1.0, 0.05, 0.03), 0.3, emission=((1.0, 0.06, 0.03), 5.0)),
        "amber": F.plain("HK_Lamp_amber", (1.0, 0.62, 0.16), 0.3, emission=((1.0, 0.55, 0.10), 4.0)),
        "net": alpha_mat("HK_Camonet", make_net_texture(1024 if D else 512)),
        "schade": alpha_mat("HK_Schade", make_damage_texture(512 if D else 256)),
    }
    t_alb, t_nrm, t_orm = F.make_cloth_textures(1024 if D else 512)
    if LEVEL != "hq":
        # vlag: een ster per niveau; Godot wisselt de doektextuur bij niveau 2 (twee sterren) en 3 (drie sterren)
        for n_stars in (2, 3):
            F.make_cloth_textures(1024 if D else 512, stars=n_stars)
    M["doek"] = F.pbr("Vlagdoek_olijf_goud", t_alb, t_nrm, t_orm, normal_strength=1.0, double_sided=True)
    # de vlaghelper (paal, lamp) krijgt bakeable materialen: de paal gebruikt 'staal' en 'donker'

    root = bpy.data.objects.new("Hoofdkwartier", None)
    sc.collection.objects.link(root)
    bolts = G()
    build_concrete(M, root)
    build_plates(M, root, bolts)
    commit("Bouten", bolts, M["donker"], root, tile=0.5, bevel=False) if D >= 1 else None
    build_metal(M, root)
    build_stairs(M, root)
    build_whites(M, root)
    build_interior(M, root)
    door = build_door(M, root)
    radar = build_radar(M, root)
    build_masts(M, root)
    build_net(M, root)
    build_extra(M, root)
    build_vol(M, root)
    build_levels(M, root)
    build_damage(M, root)
    vlag = empty("Vlag", root, (-1.55, 1.55, ROOF + 0.03), scale=0.8)
    cfg = dict(seg=max(8, SEG // 3), cloth=(12, 7) if D else (6, 4), bone_n=6 if D else 3)
    F.build_pole(M["staal"], M["donker"], cfg["seg"], vlag)
    F.build_lamp(M["amber"], cfg["seg"], vlag)
    cloth = F.build_cloth(M["doek"], cfg["cloth"], cfg["bone_n"], vlag)
    rig = F.rig_cloth(cloth, vlag, cfg["bone_n"])

    tris = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in bpy.data.objects:
        if o.type == "MESH":
            m = o.evaluated_get(dg).to_mesh()
            tris += sum(len(p.vertices) - 2 for p in m.polygons)
    print(f"[{LEVEL}] triangles: {tris}")
    if LEVEL != "hq":
        bake_all(root, M, None)       # de HQ-bron houdt de levende procedurele materialen (bewerkbaar), zonder bake
    animate(radar, door, rig)

    stem = {"hq": "Hoofdkwartier_HQ", "game": "hoofdkwartier", "lod1": "hoofdkwartier_lod1"}[LEVEL]
    print(f"[{LEVEL}] materialen: {len(bpy.data.materials)}")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    if LEVEL == "hq":
        print("HQ-bron opgeslagen (procedurele materialen, geen bake):", OUT / f"{stem}.blend")
        return
    glb = (OUT if LEVEL == "hq" else ROOT / "assets") / f"{stem}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb), export_format="GLB", export_yup=True, export_apply=False,
        export_skins=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
        export_materials="EXPORT", export_image_format="AUTO", export_lights=False, export_cameras=False,
    )
    print("geschreven:", glb)
    res = 1024 if D else 512
    for n_stars in (2, 3):   # vlag met twee en drie sterren voor niveau 2 en 3 (Godot wisselt de albedo-textuur)
        dst = ROOT / "assets" / f"{stem}_vlag_s{n_stars}_albedo_{res}.jpg"
        Image.open(OUT / f"doek_albedo_{res}_s{n_stars}.png").convert("RGB").save(dst, quality=90)
        print("geschreven:", dst)
    if LEVEL == "game":
        usdz = OUT / "Hoofdkwartier.usdz"
        try:
            bpy.ops.wm.usd_export(filepath=str(usdz), export_materials=True, export_animation=True, generate_preview_surface=True)
            print("geschreven:", usdz)
        except Exception as exc:  # noqa
            print("USDZ-export mislukt:", exc)


if __name__ == "__main__":
    main()
