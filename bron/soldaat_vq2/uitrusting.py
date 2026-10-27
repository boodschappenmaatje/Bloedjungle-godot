"""Uitrusting van de VQ2-soldaat: laarzen, helmen, hoofddeksels, vest, koppel, rugzak, borsttuig, patroongordels en
raketzak. Gevormd op het echte lichaamsoppervlak (schalen langs de normaal), met eigen UV's in een gedeelde 1K-atlas
(4x4 tegels) waarvan de texturen per texel uit de 3D-rustpositie berekend worden, net als bij het lichaam.

Alle delen zijn gewogen op het DEF-skelet (gewichten van het dichtstbijzijnde lichaamspunt; helmen en petten
volledig aan DEF-head), dus ze bewegen mee met elke bestaande clip.
"""
import math

import bmesh
import bpy
import numpy as np
from PIL import Image

import textuur as tx
from textuur import fbm3, smooth, srgb

TILES = ["Helm", "Vest", "Koppel", "Rugzak", "Hoofdband", "Bandana", "Boonie", "Pet",
         "Staalhelm", "Borsttuig", "Patroongordels", "Raketzak", "Laarzen", "Laarzen_V"]
GRID = 4
RIGID_HEAD = {"Helm", "Hoofdband", "Bandana", "Boonie", "Pet", "Staalhelm"}
TARGET_TRIS = {"Helm": 520, "Vest": 1500, "Koppel": 700, "Rugzak": 420, "Hoofdband": 260, "Bandana": 420,
               "Boonie": 520, "Pet": 440, "Staalhelm": 520, "Borsttuig": 900, "Patroongordels": 900,
               "Raketzak": 1400, "Laarzen": 900, "Laarzen_V": 900}


class Ctx:
    pass


def _bm_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _select_only(ob):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def shell_bm(c, vmask, offset, thick, smooth_it=0, bm=None):
    """Schaal over de lichaamsvlakken waarvan alle hoekpunten in vmask liggen, offset langs de normaal (m)."""
    P, N, F = c.P, c.N, c.F
    sel = [f for f in F if vmask[f].all()]
    vids = sorted({v for f in sel for v in f})
    m = {v: i for i, v in enumerate(vids)}
    off = offset[vids] if isinstance(offset, np.ndarray) else offset
    pts = P[vids] + N[vids] * (off[:, None] if isinstance(off, np.ndarray) else off)
    bm = bm or bmesh.new()
    sub = bmesh.new()
    vs = [sub.verts.new(tuple(p)) for p in pts]
    for f in sel:
        try:
            sub.faces.new([vs[m[v]] for v in f])
        except ValueError:
            pass
    for _ in range(smooth_it):
        inner = [v for v in sub.verts if not v.is_boundary]
        bmesh.ops.smooth_vert(sub, verts=inner, factor=0.6, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    sub.normal_update()
    if thick:
        bmesh.ops.solidify(sub, geom=sub.faces[:], thickness=thick)
    me = bpy.data.meshes.new("tmp")
    sub.to_mesh(me)
    sub.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    return bm


def box(bm, center, size, bevel=0.006, rot_z=0.0):
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=vs)
    if rot_z:
        from mathutils import Matrix
        bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=Matrix.Rotation(rot_z, 3, "Z"))
    bmesh.ops.translate(bm, vec=center, verts=vs)
    if bevel:
        edges = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", profile=0.5)
    return vs


def cylinder(bm, center, radius, depth, axis=(0, 0, 1), segs=10, r2=None):
    from mathutils import Vector
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=radius,
                              radius2=radius if r2 is None else r2, depth=depth)
    q = Vector((0, 0, 1)).rotation_difference(Vector(axis))
    bmesh.ops.rotate(bm, verts=r["verts"], cent=(0, 0, 0), matrix=q.to_matrix())
    bmesh.ops.translate(bm, vec=center, verts=r["verts"])
    return r["verts"]


def surf_y(c, x, z, side=-1, tol=0.018):
    """Y van het lichaamsoppervlak (voor -1, achter +1) bij (x, z)."""
    P = c.P
    m = (np.abs(P[:, 0] - x) < tol) & (np.abs(P[:, 2] - z) < tol) & (np.abs(P[:, 0]) < 0.2)
    ys = P[m, 1]
    return ys.min() if side < 0 else ys.max()


# ---------------- vormen ----------------
def head_frame(c):
    el, er = c.EYES
    ez = (el[2] + er[2]) / 2
    head = (c.P[:, 2] > 1.50) & (np.abs(c.P[:, 0]) < 0.16)
    return ez, head


def cap_mask(c, front, back, extra=None):
    """Hoofdhuid boven een schuin vlak: hoogte 'front' (t.o.v. ooghoogte) bij het voorhoofd, 'back' achterin."""
    ez, head = head_frame(c)
    y = c.P[:, 1]
    zc = ez + front + (back - front) * np.clip((y + 0.10) / 0.20, 0, 1)
    return head & (c.P[:, 2] > zc)


def make_helm(c):
    bm = shell_bm(c, cap_mask(c, 0.035, -0.035), 0.030, 0.012, smooth_it=12)
    ez, _ = head_frame(c)
    top = c.P[cap_mask(c, 0.05, 0.05)][:, 2].max()
    box(bm, (0, -0.075, top - 0.035), (0.05, 0.03, 0.035), 0.005)       # NVG-houder op het voorhoofd
    return bm


def make_staalhelm(c):
    ez, _ = head_frame(c)
    mask = cap_mask(c, 0.03, -0.045)
    bm = shell_bm(c, mask, 0.034, 0.010, smooth_it=14)
    hc = np.array([0, 0.0, ez + 0.02])
    for v in bm.verts:   # uitlopende rand
        if v.co.z < ez + 0.03:
            d = np.array(v.co) - hc
            d[2] = 0
            k = (ez + 0.03 - v.co.z) / 0.06
            v.co.x += d[0] * 0.25 * k
            v.co.y += d[1] * 0.25 * k
    return bm


def make_band(c, cover=False):
    ez, head = head_frame(c)
    y, z = c.P[:, 1], c.P[:, 2]
    if cover:
        mask = cap_mask(c, 0.028, -0.05)
        bm = shell_bm(c, mask, 0.007, 0.004, smooth_it=4)
    else:
        zc = ez + 0.048 - 0.10 * np.clip((y + 0.10) / 0.20, 0, 1)
        mask = head & (np.abs(z - zc) < 0.016)
        bm = shell_bm(c, mask, 0.006, 0.004, smooth_it=2)
    # knoop met twee slippen achter op het hoofd
    by = surf_y(c, 0.0, ez + 0.035, side=+1, tol=0.02) + 0.01
    box(bm, (0, by, ez + 0.035), (0.03, 0.02, 0.025), 0.006)
    for sx, ang in ((-1, 0.18), (1, -0.12)):
        vs = box(bm, (0, 0, 0), (0.028, 0.004, 0.13), 0.0)
        from mathutils import Matrix
        bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0.065), matrix=Matrix.Rotation(ang, 3, "Y") @ Matrix.Rotation(0.25, 3, "X"))
        bmesh.ops.translate(bm, vec=(sx * 0.012, by + 0.012, ez + 0.035 - 0.065), verts=vs)
    return bm


def _brim(bm, width, droop, ez, front_only=False, segs=36):
    """Rand als eigen ring onder de open onderkant van een hoed (hoek-voor-hoek straal van de schaalrand)."""
    bnd = [v.co.copy() for v in bm.verts if v.is_boundary]
    bm.verts.ensure_lookup_table()
    pts = np.array([v[:] for v in bnd])
    pts = pts[pts[:, 2] < pts[:, 2].min() + 0.05]
    cx, cy = pts[:, 0].mean(), pts[:, 1].mean()
    ang = np.arctan2(pts[:, 1] - cy, pts[:, 0] - cx)
    rad = np.hypot(pts[:, 0] - cx, pts[:, 1] - cy)
    rings = []
    th = np.linspace(-math.pi, math.pi, segs, endpoint=False)
    if front_only:   # klep: alleen de voorkant (gezicht is -Y)
        th = np.linspace(-math.pi * 0.86, -math.pi * 0.14, 14)
    for k, t in enumerate(th):
        d = np.abs((ang - t + math.pi) % (2 * math.pi) - math.pi)
        w = np.exp(-(d / 0.25) ** 2)
        r0 = (rad * w).sum() / w.sum()
        z0 = (pts[:, 2] * w).sum() / w.sum()
        ring = []
        for f in (0.0, 0.5, 1.0):
            wd = width * (math.sin(-t) ** 0.8 if front_only else 1.0)
            r = r0 + wd * f - 0.004
            ring.append(bm.verts.new((cx + r * math.cos(t), cy + r * math.sin(t), z0 - droop * f * f)))
        rings.append(ring)
    n = len(rings)
    for i in range(n if not front_only else n - 1):
        a_, b_ = rings[i], rings[(i + 1) % n]
        for j in range(2):
            bm.faces.new((a_[j], b_[j], b_[j + 1], a_[j + 1]))
    return bm


def make_boonie(c):
    ez, _ = head_frame(c)
    bm = shell_bm(c, cap_mask(c, 0.035, -0.02), 0.020, 0.0, smooth_it=10)
    n0 = len(bm.faces)
    _brim(bm, 0.075, 0.03, ez)
    bm.faces.ensure_lookup_table()
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.005)
    return bm


def make_pet(c):
    ez, _ = head_frame(c)
    bm = shell_bm(c, cap_mask(c, 0.040, -0.01), 0.012, 0.0, smooth_it=10)
    n0 = len(bm.faces)
    _brim(bm, 0.065, 0.015, ez, front_only=True)
    bm.faces.ensure_lookup_table()
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.006)
    return bm


def torso_mask(c, z0, z1, ax_max):
    P = c.P
    return (P[:, 2] > z0) & (P[:, 2] < z1) & (np.abs(P[:, 0]) < ax_max)


def make_vest(c):
    P = c.P
    ax = np.abs(P[:, 0])
    mask = torso_mask(c, 1.08, 1.43, 0.168) | ((P[:, 2] >= 1.40) & (P[:, 2] < 1.505) & (ax > 0.05) & (ax < 0.125))
    bm = shell_bm(c, mask, 0.038, 0.024, smooth_it=6)
    for x in (-0.088, 0.0, 0.088):       # magazijntassen
        y = surf_y(c, x, 1.17) - 0.062
        box(bm, (x, y, 1.165), (0.078, 0.05, 0.125), 0.008)
    y = surf_y(c, 0.0, 1.33) - 0.06
    box(bm, (0.0, y, 1.335), (0.17, 0.03, 0.09), 0.006)                 # admintas
    y = surf_y(c, 0.10, 1.30, side=+1) + 0.07
    box(bm, (0.10, y, 1.30), (0.075, 0.05, 0.16), 0.008)                # radiotas achter
    cylinder(bm, (0.10, y, 1.43), 0.006, 0.20)                          # antenne
    return bm


def make_koppel(c):
    P = c.P
    mask = (np.abs(P[:, 2] - 1.0) < 0.026) & (np.abs(P[:, 0]) < 0.22)
    bm = shell_bm(c, mask, 0.024, 0.009, smooth_it=3)
    box(bm, (0.0, surf_y(c, 0.0, 1.0) - 0.034, 1.0), (0.055, 0.012, 0.04), 0.004)     # gesp
    for sx in (-1, 1):
        y = surf_y(c, sx * 0.13, 0.99) - 0.03
        box(bm, (sx * 0.17, y + 0.035, 0.975), (0.05, 0.07, 0.085), 0.008, rot_z=sx * 0.6)
    yb = surf_y(c, -0.08, 0.99, side=+1) + 0.05
    cylinder(bm, (-0.08, yb, 0.965), 0.042, 0.13, segs=12)                               # veldfles
    box(bm, (0.08, yb, 0.975), (0.09, 0.05, 0.08), 0.008)                                 # EHBO-tas
    return bm


def make_rugzak(c, extra=0.04):
    y = surf_y(c, 0.0, 1.27, side=+1)
    bm = bmesh.new()
    vs = box(bm, (0, y + extra + 0.065, 1.26), (0.30, 0.13, 0.38), 0.03)
    box(bm, (0, y + extra + 0.135, 1.20), (0.22, 0.04, 0.16), 0.012)                     # voorvak
    box(bm, (0, y + extra + 0.07, 1.47), (0.24, 0.10, 0.05), 0.015)                      # rolmat-klep
    return bm


def make_raketzak(c):
    y = surf_y(c, 0.0, 1.27, side=+1) + 0.02
    bm = bmesh.new()
    box(bm, (0, y + 0.075, 1.25), (0.27, 0.15, 0.40), 0.03)
    for x in (-0.075, 0.075):                                        # RPG-granaten steken boven de zak uit
        cylinder(bm, (x, y + 0.08, 1.50), 0.022, 0.16, segs=10)
        cylinder(bm, (x, y + 0.08, 1.625), 0.042, 0.09, segs=12, r2=0.042)
        cylinder(bm, (x, y + 0.08, 1.70), 0.042, 0.07, segs=12, r2=0.012)
    return bm


def make_borsttuig(c):
    P = c.P
    ax = np.abs(P[:, 0])
    front = P[:, 1] < 0.03
    mask = (torso_mask(c, 1.09, 1.25, 0.165) & front) | ((np.abs(ax - 0.09) < 0.022) & (P[:, 2] > 1.22) & (P[:, 2] < 1.51))
    bm = shell_bm(c, mask, 0.024, 0.010, smooth_it=4)
    for x in (-0.075, 0.0, 0.075):
        y = surf_y(c, x, 1.17) - 0.05
        box(bm, (x, y, 1.16), (0.068, 0.045, 0.15), 0.007)
    for sx in (-1, 1):
        y = surf_y(c, sx * 0.13, 1.16) - 0.035
        cylinder(bm, (sx * 0.135, y, 1.16), 0.028, 0.08, segs=10)                     # granaattas
    return bm


def make_gordels(c):
    P = c.P
    x, z = P[:, 0], P[:, 2]
    bands = np.zeros(len(P), bool)
    for s in (1, -1):
        x0, z0, x1, z1 = 0.11 * s, 1.49, -0.15 * s, 1.0
        d = np.abs((x1 - x0) * (z0 - z) - (x0 - x) * (z1 - z0)) / math.hypot(x1 - x0, z1 - z0)
        bands |= (d < 0.026) & (z > 0.97) & (z < 1.51) & (np.abs(x) < 0.2)
    return shell_bm(c, bands, 0.030, 0.016, smooth_it=4)


def make_laarzen(c):
    P = c.P
    mbs = bpy.data.metaballs.new("laars")
    mbs.resolution = 0.007
    mbs.threshold = 0.6
    K = 0.57
    for sx in (1, -1):
        legx = P[(np.sign(P[:, 0]) == sx) & (P[:, 2] < 0.30)]
        for zq in (0.26, 0.21, 0.16, 0.115, 0.085):
            s = legx[np.abs(legx[:, 2] - zq) < 0.015]
            if len(s) < 4:
                continue
            cx, cy = s[:, 0].mean(), s[:, 1].mean()
            rx = (s[:, 0].max() - s[:, 0].min()) / 2 + 0.016
            ry = (s[:, 1].max() - s[:, 1].min()) / 2 + 0.016
            e = mbs.elements.new()
            e.type = "ELLIPSOID"
            e.co = (cx, cy, zq)
            e.radius = max(rx, ry) / K
            e.size_x, e.size_y, e.size_z = rx / max(rx, ry), ry / max(rx, ry), 0.06 / max(rx, ry)
        foot = legx[legx[:, 2] < 0.12]
        for yq in np.linspace(foot[:, 1].max() - 0.03, foot[:, 1].min() + 0.03, 6):
            s = foot[np.abs(foot[:, 1] - yq) < 0.015]
            if len(s) < 4:
                continue
            cx = s[:, 0].mean()
            rx = (s[:, 0].max() - s[:, 0].min()) / 2 + 0.014
            zt = s[:, 2].max() + 0.012
            rz = zt / 2 + 0.004
            e = mbs.elements.new()
            e.type = "ELLIPSOID"
            e.co = (cx, yq, rz - 0.006)
            r = max(rx, rz, 0.035)
            e.radius = r / K
            e.size_x, e.size_y, e.size_z = rx / r, 0.04 / r, rz / r
    ob = bpy.data.objects.new("laars_mb", mbs)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for v in bm.verts:     # platte zool
        if v.co.z < 0.02:
            v.co.z = 0.02 - (0.02 - v.co.z) * 0.12 - 0.004
    return bm


SHAPES = {"Helm": make_helm, "Vest": make_vest, "Koppel": make_koppel, "Rugzak": make_rugzak,
          "Hoofdband": lambda c: make_band(c), "Bandana": lambda c: make_band(c, cover=True),
          "Boonie": make_boonie, "Pet": make_pet, "Staalhelm": make_staalhelm, "Borsttuig": make_borsttuig,
          "Patroongordels": make_gordels, "Raketzak": make_raketzak, "Laarzen": make_laarzen,
          "Laarzen_V": make_laarzen}


# ---------------- texturen per onderdeel (rustpositie p, normaal n) ----------------
def _nylon(p, n, base, seed):
    g = fbm3(p, 160, seed, 2)
    col = srgb(base)[None, :] * (0.85 + 0.25 * fbm3(p, 8, seed + 1, 3) + 0.08 * g)[:, None]
    molle = smooth(np.sin(p[:, 2] * 2 * math.pi / 0.025) - 0.55, 0, 0.2)
    return col, g, molle


def tex_part(name, p, n, c):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    zeros = np.zeros(len(p))
    metal = zeros.copy()
    ez = c.ez
    if name in ("Helm",):
        q = p * np.array([1, 1, 0.7])
        col = np.tile(srgb("6b6a4c"), (len(p), 1))
        for seed, thr, cc in ((5, 0.55, "4b5634"), (13, 0.57, "6e5a3e"), (21, 0.63, "262722")):
            m = smooth(fbm3(q, 22, seed, 3), thr, thr + 0.02)
            col = col * (1 - m[:, None]) + srgb(cc) * m[:, None]
        band = smooth(0.012 - np.abs(z - (ez + 0.075 - 0.2 * np.clip((y + 0.1) / 0.2, 0, 1))), 0, 0.003)
        col = col * (1 - band[:, None] * 0.8) + srgb("23241f") * band[:, None] * 0.8
        h = fbm3(p, 120, 3, 2) * 0.5 + band * 0.6 + fbm3(p * np.array([1, 1, 3]), 30, 9, 2) * 0.4
        rough = 0.85 + zeros
    elif name == "Staalhelm":
        col = srgb("4b5233")[None, :] * (0.85 + 0.2 * fbm3(p, 10, 4, 3))[:, None]
        chips = smooth(fbm3(p, 70, 8, 3), 0.66, 0.70) * smooth(ez + 0.05 - z, 0, 0.04)
        col = col * (1 - chips[:, None]) + srgb("38342e") * chips[:, None]
        h = fbm3(p, 40, 2, 2) * 0.3 - chips * 0.4
        rough = 0.55 + 0.3 * chips
        metal = chips * 0.8
    elif name in ("Hoofdband", "Bandana"):
        if name == "Hoofdband":
            col = srgb("e6e1d6")[None, :] * (0.88 + 0.15 * fbm3(p, 40, 2, 2))[:, None]
        else:
            col = srgb("6b1d18")[None, :] * (0.8 + 0.3 * fbm3(p, 10, 2, 2))[:, None]
            pais = smooth(np.sin(fbm3(p, 60, 4, 2) * 30), 0.6, 0.8)
            col = col * (1 - pais[:, None] * 0.8) + srgb("151312") * pais[:, None] * 0.8
        sweat = smooth(fbm3(p, 14, 6, 2), 0.55, 0.75) * 0.25
        col *= (1 - sweat)[:, None]
        h = fbm3(p * np.array([1, 1, 4]), 80, 3, 2) * 0.6
        rough = 0.9 + zeros
    elif name in ("Boonie", "Pet"):
        base = "6c6a4d" if name == "Boonie" else "4e5337"
        col = srgb(base)[None, :] * (0.82 + 0.25 * fbm3(p, 9, 3, 3))[:, None]
        fade = (n[:, 2] > 0.6) * 0.12
        col *= (1 + fade)[:, None]
        r = np.hypot(x, y + 0.005)
        stitch = smooth(np.sin(r * 2 * math.pi / 0.012) - 0.85, 0, 0.1) * (z < ez + 0.03)
        crown_band = smooth(0.010 - np.abs(z - (ez + 0.035)), 0, 0.003)
        col = col * (1 - 0.25 * stitch[:, None]) * (1 - 0.35 * crown_band[:, None])
        h = stitch * 0.4 + crown_band * 0.5 + fbm3(p, 60, 2, 2) * 0.4
        rough = 0.9 + zeros
    elif name in ("Vest", "Koppel", "Rugzak", "Borsttuig", "Raketzak"):
        base = {"Vest": "5a5944", "Koppel": "4c4f3a", "Rugzak": "565640", "Borsttuig": "6d6747", "Raketzak": "5e5841"}[name]
        col, g, molle = _nylon(p, n, base, len(name))
        flat = (n[:, 2] < 0.7)
        col *= (1 - 0.12 * molle * flat)[:, None]
        edge = smooth(fbm3(p, 30, 3, 2), 0.62, 0.7) * 0.25
        col = col * (1 - edge[:, None]) + srgb("8a8063") * edge[:, None]
        dirt = smooth(1.05 - z, 0, 0.2) * 0.3 + smooth(fbm3(p, 12, 77, 3), 0.6, 0.75) * 0.3
        col = col * (1 - dirt[:, None]) + srgb("5a4a35") * dirt[:, None]
        h = molle * flat * 0.6 + g * 0.3
        rough = 0.85 + 0.05 * g
        if name == "Koppel":
            buckle = (np.abs(x) < 0.03) & (y < -0.10) & (np.abs(z - 1.0) < 0.022)
            col[buckle] = srgb("2b2b28")
            metal = buckle * 0.6
            rough = np.where(buckle, 0.45, rough)
            can = (y > 0.08) & (x < -0.03) & (z < 1.035)
            col[can] = srgb("3f4530") * (0.9 + 0.2 * fbm3(p[can], 20, 3, 2))[:, None]
        if name == "Raketzak":
            war = z > 1.47
            head = z > 1.58
            col[war] = srgb("2f3328")
            col[head] = srgb("3e4a2a") * (0.85 + 0.2 * fbm3(p[head], 20, 2, 2))[:, None]
            tip = z > 1.70
            col[tip] = srgb("1d1d1b")
            metal = war * 0.5
            rough = np.where(war, 0.5, rough)
        if name == "Vest":
            radio = (y > 0.10) & (z > 1.22) & (z < 1.385) & (x > 0.06)
            col[radio] = srgb("2a2c26")
            ant = (z > 1.39) & (y > 0.10)
            col[ant] = srgb("141414")
    elif name == "Patroongordels":
        d = np.stack([x, z], 1)
        s = np.where(x * (z - 1.25) > 0, (x * 0.47 + z * 0.88), (-x * 0.47 + z * 0.88))
        cart = smooth(np.sin(s * 2 * math.pi / 0.021) - 0.1, 0, 0.3)
        out = n[:, 1] < -0.2
        col = srgb("4a3626")[None, :] * (0.85 + 0.2 * fbm3(p, 30, 3, 2))[:, None]
        brass = cart * out
        col = col * (1 - brass[:, None]) + srgb("b5913f") * (0.8 + 0.25 * fbm3(p, 50, 4, 2))[:, None] * brass[:, None]
        h = cart * out * 0.9
        rough = 0.7 - 0.35 * brass
        metal = brass
    else:  # laarzen
        import lagen
        col, h, rough = lagen.boot(p, n, np.zeros((len(p), 2)), enemy=(name == "Laarzen_V"))
        top = smooth(z - 0.245, 0, 0.01)
        col *= (1 - 0.3 * top)[:, None]
    return col, h, rough, metal


# ---------------- hoofdroutine ----------------
def build(out, P, N, F, FUV, W, BONES, EYES, rig, DEF, log, size=1024):
    c = Ctx()
    c.P, c.N, c.F, c.EYES = P, N, F, EYES
    c.ez = (EYES[0][2] + EYES[1][2]) / 2
    objs = {}
    for i, name in enumerate(TILES):
        bm = SHAPES[name](c)
        ob = _bm_object(name, bm)
        _select_only(ob)
        n_tri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        tgt = TARGET_TRIS[name]
        if n_tri > tgt * 1.1:
            d = ob.modifiers.new("dec", "DECIMATE")
            d.ratio = tgt / n_tri
            d.use_symmetry = False
            d.symmetry_axis = "X"
            bpy.ops.object.modifier_apply(modifier=d.name)
        t = ob.modifiers.new("tri", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=t.name)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        # UV's: slim projecteren, dan in de eigen atlastegel zetten
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        uv = ob.data.uv_layers.active
        arr = np.zeros(len(uv.data) * 2)
        uv.data.foreach_get("uv", arr)
        arr = arr.reshape(-1, 2)
        col_, row = i % GRID, i // GRID
        m = 0.02
        arr = (np.array([col_, GRID - 1 - row]) + m + arr * (1 - 2 * m)) / GRID
        uv.data.foreach_set("uv", arr.ravel())
        objs[name] = ob
        log("  uitrusting", name, len(ob.data.polygons), "driehoeken")

    # ---------- atlas ----------
    tri_p, tri_n, tri_uv, tri_o = [], [], [], []
    for oi, name in enumerate(TILES):
        me = objs[name].data
        me.calc_loop_triangles()
        uvd = np.zeros(len(me.loops) * 2)
        me.uv_layers.active.data.foreach_get("uv", uvd)
        uvd = uvd.reshape(-1, 2)
        co = np.array([v.co[:] for v in me.vertices])
        vn = np.array([v.normal[:] for v in me.vertices])
        for lt in me.loop_triangles:
            tri_p.append(co[list(lt.vertices)])
            tri_n.append(vn[list(lt.vertices)])
            tri_uv.append(uvd[list(lt.loops)])
            tri_o.append(oi)
    tri_p, tri_n, tri_uv, tri_o = map(np.array, (tri_p, tri_n, tri_uv, tri_o))
    tid, bary = tx.rasterize(tri_uv, size)
    sy, sx, filled = tx.dilate_index(tid, 8)
    T = tid[sy, sx]
    Bc = bary[sy, sx]
    valid = filled & (T >= 0)
    Tv, Bv = T[valid], Bc[valid]
    TP = (tri_p[Tv] * Bv[:, :, None]).sum(1)
    TN = (tri_n[Tv] * Bv[:, :, None]).sum(1)
    TN /= np.maximum(np.linalg.norm(TN, axis=1, keepdims=True), 1e-9)
    TO = tri_o[Tv]
    yy, xx = np.nonzero(valid)
    A = np.full((size, size, 3), 0.3, np.float32)
    H = np.zeros((size, size), np.float32)
    R = np.full((size, size), 0.85, np.float32)
    M = np.zeros((size, size), np.float32)
    for oi, name in enumerate(TILES):
        s = TO == oi
        col, h, rough, metal = tex_part(name, TP[s], TN[s], c)
        A[yy[s], xx[s]], H[yy[s], xx[s]], R[yy[s], xx[s]], M[yy[s], xx[s]] = col, h, rough, metal
    A *= 0.8      # zelfde reden als ALBEDO_GAIN bij het lichaam
    Nrm = tx.normal_from_height(H, 1.4)
    ORM = np.stack([np.ones_like(R), R, M], -1)
    imgs = {}
    for kind, arr in (("albedo", A), ("normal", Nrm * 0.5 + 0.5), ("orm", ORM)):
        path = out / "tex" / f"uitrusting_{kind}.jpg"
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path, quality=92)
        im = bpy.data.images.load(str(path))
        if kind != "albedo":
            im.colorspace_settings.name = "Non-Color"
        imgs[kind] = im
    from materiaal import material
    mat = material("Uitrusting", imgs)
    band = material("Hoofdband", imgs)

    # ---------- gewichten en skelet ----------
    head_j = BONES.index("DEF-head")
    feet = P[:, 2] < 0.32
    for name, ob in objs.items():
        ob.data.materials.append(band if name == "Hoofdband" else mat)
        co = np.array([v.co[:] for v in ob.data.vertices])
        if name in RIGID_HEAD:
            Wg = np.zeros((len(co), len(BONES)))
            Wg[:, head_j] = 1
        else:
            pool = np.nonzero(feet)[0] if name.startswith("Laarzen") else np.arange(len(P))
            idx = np.zeros(len(co), int)
            for i in range(0, len(co), 256):
                d = ((co[i:i + 256, None, :] - P[None, pool, :]) ** 2).sum(2)
                idx[i:i + 256] = pool[d.argmin(1)]
            Wg = W[idx]
        for j, g in enumerate(BONES):
            nz = np.nonzero(Wg[:, j] > 1e-3)[0]
            if len(nz) == 0:
                continue
            vg = ob.vertex_groups.new(name=g)
            for vi in nz:
                vg.add([int(vi)], float(Wg[vi, j]), "REPLACE")
        ob.parent = rig
        am = ob.modifiers.new("Armature", "ARMATURE")
        am.object = rig
    return objs
