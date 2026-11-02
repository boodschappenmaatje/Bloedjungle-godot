"""Gemeenschappelijke bouwstenen voor het voorraaddepot, de voorraadtruck en de voorraadstapel (Generals-plan stap 4b, stijl "Intendance").

Alle modellen worden in het Godot-assenstelsel getekend (x rechts, y omhoog, z naar voren) en hier omgezet naar Blender (Z omhoog,
voorkant naar -Y): `P(x, y, z)` doet dat. Blender als Python-module (`pip install bpy`), eenheden in meters.

Gebruik (het eerste argument is het niveau, net als bij het hoofdkwartier):
    python bron/voorraad/maak_stapel.py hq|game        # of maak_truck.py / maak_depot.py (truck en depot ook: lod1)

Stijl "Intendance": geel-zwarte waarschuwingsbanden, witte stencilletters (Engels), olijfgroene kisten met gele band, camonet, een gele
chevron als embleem. Ontwerp: modellen/voorraad/ASSET_DESIGN_SPEC.md (in het project) en docs/GENERALS_PLAN.md.
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
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "bron/verzamelvlag"))
sys.path.insert(0, str(ROOT / "bron/hoofdkwartier"))
import maak_hoofdkwartier as H  # noqa: E402  (hergebruik: bevel/UV/commit, camonet; leest het niveau uit sys.argv[1])
import hk_bake as B  # noqa: E402

F = H.F
OUT = HERE / "uit"
OUT.mkdir(exist_ok=True)
F.OUT = OUT
H.OUT = OUT
LEVEL = F.LEVEL
D = {"hq": 2, "game": 1, "lod1": 0}[LEVEL]
ATLAS = {"hq": 2048, "game": 2048, "lod1": 1024}[LEVEL]
SAMPLES = {"hq": 24, "game": 24, "lod1": 12}[LEVEL]
SEGC = H.SEGC
BEV = H.BEV
FPS = 30
TEXRES = 1024

# een houtsoort voor pallets en kisten (de hoofdkwartier-bakketen kent alleen beton, verf, metaal en rubber)
B.KINDS["wood"] = dict(chip=(0.30, 0.22, 0.14), chip_metal=0.0, dirt=0.95, mud=0.8, streak=0.9, edge=0.45, rust=0.0, moss=0.35, dust=0.55,
                       metal_scale=0.0, bump=0.45)

G = H.G
T, RX, RY, RZ = H.T, H.RX, H.RY, H.RZ

YELLOW = (0.62, 0.45, 0.04)


# ------------------------------------------------------------------ assenstelsel: Godot (x rechts, y omhoog, z voor) -> Blender
def P(x=0.0, y=0.0, z=0.0):
    """Godot-punt naar Blender-vector."""
    return Vector((x, -z, y))


def GM(c, yaw=0.0, pitch=0.0, roll=0.0):
    """Matrix voor een onderdeel op Godot-positie c, met draaiing om de verticale as (yaw), de x-as (pitch) en de lengteas (roll)."""
    return T(*P(*c)) @ RZ(yaw) @ RX(pitch) @ RY(-roll)


def bx(g, c, size, yaw=0.0, pitch=0.0, roll=0.0, bevel=True):
    """Doos met middelpunt c en afmetingen size = (breedte x, hoogte y, lengte z), allemaal in Godot-assen."""
    H.bx(g, GM(c, yaw, pitch, roll), (size[0], size[2], size[1]), bevel=bevel)


def cyl(g, a, b, r, seg=None, r2=None):
    """Cilinder (buis, as, stang) van Godot-punt a naar b."""
    a, b = P(*a), P(*b)
    d = b - a
    if d.length < 1e-5:
        return
    q = d.to_track_quat("Z", "Y" if abs(d.normalized().y) < 0.98 else "X")
    H.cy(g, T(*((a + b) / 2)) @ q.to_matrix().to_4x4(), r, d.length, seg=seg or SEGC, r2=r2)


def disc(g, c, r, h, axis="x", seg=None, r2=None):
    """Cilinder met middelpunt c, as langs 'x', 'y' of 'z' (Godot), lengte h."""
    v = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis]
    a = (c[0] - v[0] * h / 2, c[1] - v[1] * h / 2, c[2] - v[2] * h / 2)
    b = (c[0] + v[0] * h / 2, c[1] + v[1] * h / 2, c[2] + v[2] * h / 2)
    cyl(g, a, b, r, seg=seg, r2=r2)


def bar(g, a, b, w, h, bevel=True, up=(0, 1, 0)):
    """Balk met rechthoekige doorsnede w x h van Godot-punt a naar b (h langs 'up' bij benadering)."""
    a, b = P(*a), P(*b)
    d = b - a
    if d.length < 1e-5:
        return
    upv = Vector((up[0], -up[2], up[1]))
    if abs(d.normalized().dot(upv.normalized())) > 0.98:
        upv = Vector((1, 0, 0))
    q = d.to_track_quat("Y", "Z" if abs(upv.z) > 0.5 else "X")
    M = T(*((a + b) / 2)) @ q.to_matrix().to_4x4()
    H.bx(g, M, (w, d.length, h), bevel=bevel)


def commit(name, g, mat, parent, tile=1.0, smooth=False, bevel=True, bw=None):
    return H.commit(name, g, mat, parent, tile=tile, smooth=smooth, bevel=bevel, bw=bw)


def empty(name, parent, loc=(0, 0, 0)):
    """Lege pivot op Godot-positie loc (lokaal t.o.v. de ouder)."""
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = P(*loc)
    return e


def tri_count():
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            me = o.evaluated_get(dg).to_mesh()
            n += sum(len(p.vertices) - 2 for p in me.polygons)
    return n


# ------------------------------------------------------------------ textuur: waarschuwingsbanden en stencilsheet
STRIPE = OUT / "gevaarband_512.png"


def make_stripe_texture():
    """Geel-zwarte schuine banden, naadloos herhaalbaar (45 graden, vier banden per tegel)."""
    res = 512
    yy, xx = np.mgrid[0:res, 0:res]
    t = ((xx + yy) % (res // 2)) < (res // 4)
    yellow = np.array([0.70, 0.50, 0.04])
    black = np.array([0.045, 0.045, 0.04])
    rgb = np.where(t[..., None], yellow, black)
    Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(STRIPE)
    return STRIPE


SHEET = OUT / "intendance_stencil_2048.png"
CELLS = {  # naam: (x, y, w, h) in pixels van het sheet (2048 x 1024)
    "intendance": (0, 0, 2048, 230),
    "depot01": (0, 240, 1100, 230),
    "keepclear": (1120, 240, 928, 230),
    "swl": (0, 480, 560, 190),
    "batch": (580, 480, 780, 190),
    "crane": (1380, 480, 668, 190),
    "int": (0, 690, 360, 190),
    "n01": (380, 690, 220, 190),
    "n02": (620, 690, 220, 190),
    "n03": (860, 690, 220, 190),
    "chevron": (1100, 690, 330, 330),
    "plaat": (1450, 690, 598, 330),
}
FONT = HERE / "BigShoulders-Bold.ttf"


def _stencil(draw, box, text, color, rng):
    x, y, w, h = box
    size = h
    font = ImageFont.truetype(str(FONT), size)
    while True:
        bb = draw.textbbox((0, 0), text, font=font)
        if bb[2] - bb[0] <= w - 8 or size < 20:
            break
        size -= 6
        font = ImageFont.truetype(str(FONT), size)
    bb = draw.textbbox((0, 0), text, font=font)
    tx = x + (w - (bb[2] - bb[0])) / 2 - bb[0]
    ty = y + (h - (bb[3] - bb[1])) / 2 - bb[1]
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.text((tx - x, ty - y), text, font=font, fill=color + (255,))
    # stencilbruggen: korte horizontale en verticale strepen door de letters (de verf mist daar)
    a = np.asarray(layer).copy()
    gap = max(2, h // 40)
    for _ in range(max(4, len(text) * 2)):
        cx = rng.randrange(0, w)
        cy = rng.randrange(h // 6, h - h // 6)
        if rng.random() < 0.5:
            a[max(0, cy - gap // 2):cy + gap, max(0, cx - h // 9):cx + h // 9, 3] = 0
        else:
            a[max(0, cy - h // 9):cy + h // 9, max(0, cx - gap // 2):cx + gap, 3] = 0
    layer = Image.fromarray(a, "RGBA")
    return layer


def make_stencil_sheet():
    rng = random.Random(7)
    sheet = Image.new("RGBA", (2048, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(sheet)
    white = (232, 229, 214)
    for name, text in (("intendance", "INTENDANCE"), ("depot01", "DEPOT 01"), ("keepclear", "KEEP CLEAR"), ("swl", "SWL 3T"),
                       ("batch", "BATCH 0417"), ("crane", "CRANE"), ("int", "INT"), ("n01", "01"), ("n02", "02"), ("n03", "03")):
        x, y, w, h = CELLS[name]
        sheet.alpha_composite(_stencil(d, (x, y, w, h), text, white, rng), (x, y))
    # chevron: twee gele punten boven elkaar met een donkere rand
    x, y, w, h = CELLS["chevron"]
    ch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(ch)
    for k, dy in enumerate((0.0, 0.26)):
        pts = [(0.08, 0.34 + dy), (0.5, 0.06 + dy), (0.92, 0.34 + dy), (0.92, 0.52 + dy), (0.5, 0.24 + dy), (0.08, 0.52 + dy)]
        pts = [(px * w, py * h) for px, py in pts]
        cd.polygon(pts, fill=(176, 128, 14, 255), outline=(20, 18, 12, 255))
    sheet.alpha_composite(ch, (x, y))
    # plaat: donkere plaat met een gele rand en de tekst INTENDANCE (voor borden)
    x, y, w, h = CELLS["plaat"]
    pl = Image.new("RGBA", (w, h), (28, 31, 22, 255))
    pd = ImageDraw.Draw(pl)
    pd.rectangle((6, 6, w - 7, h - 7), outline=(176, 128, 14, 255), width=10)
    txt = _stencil(pd, (0, 0, w - 60, h // 3), "INTENDANCE", (232, 229, 214), rng)
    pl.alpha_composite(txt, (30, h // 6))
    txt2 = _stencil(pd, (0, 0, w - 200, h // 3), "DEPOT 01", (176, 128, 14), rng)
    pl.alpha_composite(txt2, (100, h // 2 + 10))
    sheet.alpha_composite(pl, (x, y))
    # verwering: de verf is op sommige plekken afgesleten
    a = np.asarray(sheet).astype(np.float32)
    n = np.asarray(Image.fromarray((np.random.default_rng(3).random((256, 128)) * 255).astype(np.uint8)).resize((2048, 1024), Image.BICUBIC),
                   dtype=np.float32) / 255.0
    a[..., 3] *= np.clip((n - 0.18) * 3.0, 0.0, 1.0)
    Image.fromarray(a.astype(np.uint8), "RGBA").save(SHEET)
    return SHEET


def decal(bm, name, M, w, h):
    """Een vlak w x h met het stencilplaatje `name` (lokaal: vlak in x/y, kijkend naar +z) in bmesh bm."""
    x0, y0, cw, ch = CELLS[name]
    u0, u1 = x0 / 2048, (x0 + cw) / 2048
    v0, v1 = 1.0 - (y0 + ch) / 1024, 1.0 - y0 / 1024
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((M @ Vector(p))) for p in ((-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0))]
    f = bm.faces.new(vs)
    for lp, (u, v) in zip(f.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
        lp[uv].uv = (u, v)
    return f


def decal_at(bm, name, c, w, h, yaw=0.0, pitch=0.0, roll=0.0):
    """Stencil op Godot-positie c; het vlak kijkt naar +z (Godot) en wordt daarna met yaw/pitch/roll gedraaid."""
    # lokaal vlak in Blender: x = breedte, y = hoogte (Godot y), kijkend naar +z(Blender) -> we willen Godot +z = Blender -y: draai 90 om x
    M = GM(c, yaw, pitch, roll) @ RX(math.pi / 2)
    # RX(90): lokaal (x, y, z) -> (x, -z, y): het vlak (x, y, 0) wordt (x, 0, y) (staand) en de normaal +z wordt -y (Blender) = +z (Godot)
    return decal(bm, name, M, w, h)


# ------------------------------------------------------------------ materialen
def materials():
    res = TEXRES
    cn = F.tinted_set("concrete", (0.80, 0.78, 0.72), res)
    ol = F.tinted_set("olive", (0.64, 0.70, 0.44), res)
    ol2 = F.tinted_set("olive", (0.46, 0.51, 0.31), res)
    st = F.tinted_set("steel", (0.58, 0.58, 0.54), res)
    tm = F.tinted_set("timber", (0.95, 0.88, 0.76), res)
    rf = F.tinted_set("roof", (0.70, 0.72, 0.64), res)
    cv = F.tinted_set("canvas", (0.66, 0.64, 0.46), res)
    make_stripe_texture()
    make_stencil_sheet()
    sheet = F.load_img(SHEET)
    M = {
        "olijf": B.weathered("VR_Verf_olijf", "paint", albedo=ol["albedo"], normal=ol["normal"], orm=ol["orm"], nstrength=0.9, seed=2),
        "olijf2": B.weathered("VR_Verf_olijf_donker", "paint", albedo=ol2["albedo"], normal=ol2["normal"], orm=ol2["orm"], nstrength=0.9, seed=12),
        "staal": B.weathered("VR_Staal", "metal", albedo=st["albedo"], normal=st["normal"], orm=st["orm"], nstrength=0.6, seed=3),
        "beton": B.weathered("VR_Beton", "concrete", albedo=cn["albedo"], normal=cn["normal"], orm=cn["orm"], nstrength=1.1, seed=1),
        "hout": B.weathered("VR_Hout", "wood", albedo=tm["albedo"], normal=tm["normal"], orm=tm["orm"], nstrength=1.0, seed=13),
        "dak": B.weathered("VR_Golfplaat", "metal", albedo=rf["albedo"], normal=rf["normal"], orm=rf["orm"], nstrength=0.8, seed=14),
        "doek": B.weathered("VR_Doek", "rubber", albedo=cv["albedo"], normal=cv["normal"], orm=cv["orm"], nstrength=0.7, seed=15),
        "geel": B.weathered("VR_Verf_geel", "paint", color=YELLOW, rough=0.62, seed=6),
        "gevaar": B.weathered("VR_Gevaarband", "paint", albedo=STRIPE, rough=0.62, seed=16, wear=0.9),
        "zwart": B.weathered("VR_Rubber", "rubber", color=(0.03, 0.03, 0.03), rough=0.8, seed=8),
        "donker": B.weathered("VR_Metaal_donker", "metal", color=(0.07, 0.07, 0.065), rough=0.55, metal=0.6, seed=9),
        "wit": B.weathered("VR_Verf_wit", "paint", color=(0.50, 0.48, 0.42), rough=0.7, seed=4),
        "glas": F.plain("VR_Glas", (0.05, 0.10, 0.11), 0.06, metal=0.0, alpha=0.42),
        "amber": F.plain("VR_Lamp_amber", (1.0, 0.62, 0.16), 0.3, emission=((1.0, 0.55, 0.10), 4.0)),
        "rood": F.plain("VR_Lamp_rood", (1.0, 0.05, 0.03), 0.3, emission=((1.0, 0.06, 0.03), 5.0)),
        "wit_lamp": F.plain("VR_Lamp_wit", (1.0, 0.95, 0.8), 0.3, emission=((1.0, 0.92, 0.7), 3.0)),
        "net": H.alpha_mat("VR_Camonet", H.make_net_texture(1024 if D else 512)),
        "stencil": H.alpha_mat("VR_Stencil", SHEET),
    }
    return M


# ------------------------------------------------------------------ onderdelen: kist, pallet, net
CRATE = (1.25, 0.72, 1.5)   # breedte x, hoogte y, lengte z (zoals het 4a-blok)


def crate(gs, gm, gy, gk, c, yaw=0.0, stencil=None, variant=0, size=CRATE, lid_off=0.0):
    """Olijfgroene voorraadkist met deksel, hoekbeslag, handgrepen, grendels en een gele band.
    gs = olijf (body), gm = staal (beslag), gy = geel (band), gk = decalbmesh. c = middelpunt (Godot)."""
    w, h, l = size
    hb = h * 0.84
    cx, cy_, cz = c
    # romp en deksel
    bx(gs, (cx, cy_ - h / 2 + hb / 2, cz), (w, hb, l), yaw=yaw)
    bx(gs, (cx, cy_ + h / 2 - (h - hb) / 2, cz), (w + 0.05, h - hb, l + 0.05), yaw=yaw)

    def loc(dx, dy, dz):
        a = math.cos(yaw) * dx + math.sin(yaw) * dz
        b = -math.sin(yaw) * dx + math.cos(yaw) * dz
        return (cx + a, cy_ + dy, cz + b)

    # geperste ribben op de lange zijden
    if D >= 2:
        for sx in (-1, 1):
            for dz in (-l * 0.27, l * 0.27):
                bx(gs, loc(sx * (w / 2 + 0.012), -h * 0.08, dz), (0.03, hb * 0.72, 0.07), yaw=yaw)
    # hoekbeslag (verticale hoeklijsten) en lid-banden
    if D >= 1:
        for sx in (-1, 1):
            for sz in (-1, 1):
                bx(gm, loc(sx * (w / 2 + 0.01), 0.0, sz * (l / 2 + 0.01)), (0.07, h * 0.96, 0.07), yaw=yaw, bevel=False)
    else:
        for sx in (-1, 1):
            bx(gm, loc(sx * (w / 2 + 0.01), 0.0, 0.0), (0.03, h * 0.9, 0.09), yaw=yaw, bevel=False)
    # handgrepen op de korte zijden (U-beugel)
    if D >= 2:
        for sz in (-1, 1):
            for dx in (-0.2, 0.2):
                bx(gm, loc(dx, h * 0.12, sz * (l / 2 + 0.035)), (0.03, 0.03, 0.07), yaw=yaw, bevel=False)
            bx(gm, loc(0, h * 0.12, sz * (l / 2 + 0.07)), (0.46, 0.03, 0.03), yaw=yaw, bevel=False)
    # grendels op de lange zijden
    if D >= 2:
        for sx in (-1, 1):
            for dz in (-0.35, 0.35):
                bx(gm, loc(sx * (w / 2 + 0.03), h * 0.27, dz), (0.03, 0.05, 0.11), yaw=yaw, bevel=False)
    # gele band over het deksel
    bx(gy, loc(0, h / 2 + 0.002, l * 0.18), (w * 0.98, 0.012, 0.09), yaw=yaw, bevel=False)
    if stencil and gk is not None:
        decal_at(gk, stencil, loc(w / 2 + 0.032, h * 0.02, 0), 0.62, 0.22, yaw=yaw + math.pi / 2)


def pallet(gh, gm, c, w=5.0, d=4.0, yaw=0.0, boards=9):
    """Houten pallet 5 x 4 m: drie stringers, onderplanken, dekplanken en hoekblokken. c = middelpunt van de bovenkant."""
    cx, cy_, cz = c

    def loc(dx, dy, dz):
        a = math.cos(yaw) * dx + math.sin(yaw) * dz
        b = -math.sin(yaw) * dx + math.cos(yaw) * dz
        return (cx + a, cy_ + dy, cz + b)

    # stringers langs x (breedte), dekplanken langs z (diepte)
    for dz in (-d / 2 + 0.12, 0.0, d / 2 - 0.12):
        bx(gh, loc(0, -0.12, dz), (w, 0.14, 0.14), yaw=yaw)
    n = boards
    for i in range(n):
        dx = -w / 2 + 0.25 + i * (w - 0.5) / (n - 1)
        bx(gh, loc(dx, -0.025, 0), (0.42, 0.05, d), yaw=yaw)
    for dx in (-w / 2 + 0.14, 0.0, w / 2 - 0.14):
        bx(gh, loc(dx, -0.2, 0), (0.28, 0.04, d), yaw=yaw)
    if D >= 1:
        for sx in (-1, 1):
            for dz in (-d / 2 + 0.12, 0.0, d / 2 - 0.12):
                bx(gm, loc(sx * (w / 2 - 0.2), -0.06, dz), (0.06, 0.04, 0.12), yaw=yaw, bevel=False)


def cloth_patch(gc, c, w, d, drop, seed, yaw=0.0, nx=14, nz=10, sag=0.12):
    """Los over de lading gelegd net (golvend vlak). Eenvoudig bmesh-raster in gc (de alfa-camonetmaterialen krijgen UV's mee)."""
    rng = random.Random(seed)
    uv = gc.loops.layers.uv.get("UVMap") or gc.loops.layers.uv.new("UVMap")
    cx, cy_, cz = c
    verts = []
    for iz in range(nz + 1):
        row = []
        for ix in range(nx + 1):
            u, v = ix / nx, iz / nz
            x = (u - 0.5) * w
            z = (v - 0.5) * d
            edge = min(u, 1 - u, v, 1 - v)
            y = cy_ - drop * (1 - min(1.0, edge * 5.0)) + math.sin(u * 9 + seed) * sag * 0.3 + math.sin(v * 7 + seed * 2) * sag * 0.25 + rng.uniform(-0.01, 0.01)
            xr = cx + math.cos(yaw) * x + math.sin(yaw) * z
            zr = cz - math.sin(yaw) * x + math.cos(yaw) * z
            row.append(gc.verts.new(P(xr, y, zr)))
        verts.append(row)
    for iz in range(nz):
        for ix in range(nx):
            f = gc.faces.new((verts[iz][ix], verts[iz][ix + 1], verts[iz + 1][ix + 1], verts[iz + 1][ix]))
            for lp, (uu, vv) in zip(f.loops, ((ix / nx, iz / nz), ((ix + 1) / nx, iz / nz), ((ix + 1) / nx, (iz + 1) / nz), (ix / nx, (iz + 1) / nz))):
                lp[uv].uv = (uu, vv)


def chain(gm, a, b, link=0.06, r=0.012, seg=5):
    """Ketting als reeks afwisselend gedraaide schakels (kleine doosjes) van a naar b (Godot)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(2, int(d.length / link))
    for i in range(n):
        p = a + d * ((i + 0.5) / n)
        if i % 2 == 0:
            bx(gm, tuple(p), (link * 0.55, link * 1.1, link * 0.22), bevel=False)
        else:
            bx(gm, tuple(p), (link * 0.22, link * 1.1, link * 0.55), bevel=False)


# ------------------------------------------------------------------ animatie
def keys(obj, prop, seq):
    """Zet sleutelframes: seq = [(frame, waarde), ...] voor obj.<prop> (waarde als tuple voor vectoren)."""
    for f, v in seq:
        setattr(obj, prop, v)
        obj.keyframe_insert(prop, frame=f)


def add_clip(obj, name, frames, start=0):
    """Maak van de net ingevoegde sleutelframes van obj een NLA-clip `name`. Geeft de actie terug."""
    ad = obj.animation_data
    act = ad.action
    act.name = f"{name}_{obj.name}"
    tr = ad.nla_tracks.new()
    tr.name = name
    s = tr.strips.new(name, int(start), act)
    s.name = name
    ad.action = None
    return act


def linear():
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"


def smooth_interp():
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"


# ------------------------------------------------------------------ bakken en exporteren
def bake_groups(groups, margin=0.003):
    """groups = [(naam, [objecten])]; elke groep krijgt een eigen atlas (albedo, ORM, normal) en een gebakken materiaal."""
    objs = [o for gname, gobjs in groups for o in gobjs]
    sc = bpy.context.scene
    w = bpy.data.worlds.new("BakeWorld")
    sc.world = w
    w.light_settings.distance = 1.3
    B.make_atlas_uvs(objs, margin=margin)
    # bewegende onderdelen (kraan, wielen, poort) niet snoeien: hun verborgen vlakken komen bij het bewegen wel in beeld
    B.cull_hidden([o for o in objs if not o.get("nocull")] or objs)
    suffix = "" if LEVEL != "lod1" else "_lod1"
    out = {}
    for gname, gobjs in groups:
        gobjs = [o for o in gobjs if o.name in bpy.data.objects]
        if not gobjs:
            continue
        B.make_atlas_uvs(gobjs, margin=margin)
        tag = f"vr_{gname}{suffix}"
        paths = B.run(gobjs, ATLAS, OUT, samples=SAMPLES, tag=tag)
        p_alb, p_orm, p_nrm = B.compose(paths, ATLAS, OUT, tag=tag, jpeg=(LEVEL != "hq"))
        mat = B.baked_material(f"VR_Gebakken_{gname}", p_alb, p_orm, p_nrm)
        for o in gobjs:
            o.data.materials.clear()
            o.data.materials.append(mat)
            for p in o.data.polygons:
                p.material_index = 0
            if "UVMap" in o.data.uv_layers:
                o.data.uv_layers.remove(o.data.uv_layers["UVMap"])
        out[gname] = (p_alb, p_orm, p_nrm)
    for m in list(bpy.data.materials):
        if m.get("bake_kind"):
            bpy.data.materials.remove(m)
    return out


def bakeable():
    return [o for o in bpy.data.objects if o.type == "MESH" and o.material_slots
            and all(s.material and s.material.get("bake_kind") for s in o.material_slots)]


def export_glb(path):
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", export_yup=True, export_apply=False,
        export_skins=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
        export_materials="EXPORT", export_image_format="AUTO", export_lights=False, export_cameras=False,
    )
    print("geschreven:", path)


def export_usdz(path):
    try:
        bpy.ops.wm.usd_export(filepath=str(path), export_materials=True, export_animation=True, generate_preview_surface=True)
        print("geschreven:", path)
    except Exception as exc:  # noqa
        print("USDZ-export mislukt:", exc)


def fresh_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    return sc
