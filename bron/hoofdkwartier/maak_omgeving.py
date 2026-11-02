"""Omgeving van het hoofdkwartier (voorplein): betonnen platen met voegen, belijning en HQ-stencil, twee lichtmasten, afzetblokken,
vaten in een opvangbak, een pallet met munitiekisten en zeil, een kabelhaspel, putdeksel, rooster en grondkabels met een kabelbrug.
Eenheden in meters, Z omhoog in Blender; de voorkant van het hoofdkwartier (deur) wijst naar Blender -Y (Godot +Z).

    python bron/hoofdkwartier/maak_omgeving.py hq     # bewerkbaar bronmodel (levende materialen): uit/Hoofdkwartier_omgeving.blend
    python bron/hoofdkwartier/maak_omgeving.py game   # Godot-versie: assets/hoofdkwartier_omgeving.glb (+ uit/Hoofdkwartier_omgeving.usdz)

Hergebruikt de helpers, materialen en de bakeketen van maak_hoofdkwartier.py. Botsblokken en nachtlichten staan in
scripts/hq_omgeving.gd (zelfde coordinaten; Godot z = -Blender y). Ontwerp: ASSET_DESIGN_SPEC.md, onderdeel Omgeving.
"""
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import maak_hoofdkwartier as H  # noqa: E402
import hk_bake as B  # noqa: E402

F = H.F
OUT, ROOT, LEVEL, D, SEGC = H.OUT, H.ROOT, H.LEVEL, H.D, H.SEGC
G, T, RX, RY, RZ, bx, cy, st, commit = H.G, H.T, H.RX, H.RY, H.RZ, H.bx, H.cy, H.st, H.commit

# ---- plaatsing (Blender-coordinaten, voorkant = -Y). Dezelfde getallen staan in scripts/hq_omgeving.gd.
PAD_X = (-5.4, 5.4)
PAD_Y = (-7.4, 3.4)
MASTS = ((-4.9, -6.0), (4.9, -6.0))
MAST_H = 5.9
BARRIERS = ((-4.6, -7.0), (-3.0, -7.0), (3.0, -7.0), (4.6, -7.0))     # 1,5 m lang, langs x
BOLLARDS = ((-1.95, -7.0), (1.95, -7.0))
BARREL_TRAY = (-4.2, -3.6)
BARRELS = ((-4.65, -3.35), (-4.05, -3.35), (-3.45, -3.35), (-4.35, -3.85), (-3.75, -3.85))
PALLET = (4.1, -4.3)
SPOOL = (4.75, -0.9)


def prism(g, prof, length, M4):
    """Dwarsdoorsnede (y, z) uitgetrokken langs lokaal x; M4 plaatst hem. Gaat in de bevel-bmesh."""
    bm = g.b
    a = [bm.verts.new(M4 @ Vector((-length / 2, y, z))) for y, z in prof]
    b = [bm.verts.new(M4 @ Vector((length / 2, y, z))) for y, z in prof]
    n = len(prof)
    faces = [bm.faces.new(a[::-1]), bm.faces.new(b)]
    for i in range(n):
        faces.append(bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def build_pad(M, root):
    gc = G()
    rng = random.Random(4)
    xs = np.linspace(PAD_X[0], PAD_X[1], 5)
    ys = np.linspace(PAD_Y[0], PAD_Y[1], 5)
    for i in range(4):
        for j in range(4):
            w = float(xs[i + 1] - xs[i]) - 0.03
            d = float(ys[j + 1] - ys[j]) - 0.03
            bx(gc, T(float((xs[i] + xs[i + 1]) / 2), float((ys[j] + ys[j + 1]) / 2), 0.025 + rng.uniform(-0.004, 0.004)) @ H.RZ(rng.uniform(-0.004, 0.004)), (w, d, 0.05))
    commit("Voorplein", gc, M["beton"], root, tile=2.5)
    gy, gw, gz = G(), G(), G()
    for x0, x1 in ((-5.2, -2.3), (2.3, 5.2)):                       # gele randlijn langs de voorkant, ingang open
        bx(gy, T((x0 + x1) / 2, -6.7, 0.052), (x1 - x0, 0.14, 0.006), bevel=False)
    for sx in (-1, 1):                                              # zijlijnen
        bx(gy, T(sx * 5.2, -2.4, 0.052), (0.14, 8.6, 0.006), bevel=False)
    bx(gw, T(0.0, -4.4, 0.052), (4.2, 0.1, 0.006), bevel=False)       # witte stoplijn voor het hoofdkwartier
    for k in range(9):                                              # gele schuine strepen langs de stoep
        bx(gy, T(-1.2 + k * 0.45, -4.1, 0.052) @ H.RZ(math.radians(45)), (0.35, 0.08, 0.006), bevel=False)
    commit("Voorplein_geel", gy, M["geel"], root, tile=1.0, bevel=False)
    commit("Voorplein_wit", gw, M["wit"], root, tile=1.0, bevel=False)
    # HQ-stencil, plat op de platen
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.active_object
    t.name = "HQ_stencil"
    t.data.body = "HQ"
    t.data.size = 1.3
    t.data.extrude = 0.004
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    t = bpy.context.active_object
    t.data.materials.append(M["wit"])
    t.parent = root
    t.location = (0.0, -5.5, 0.052)
    bm = bmesh.new()
    bm.from_mesh(t.data)
    H.uvw(bm, 1.0)
    bm.to_mesh(t.data)
    bm.free()
    # putdeksel en afvoerrooster
    gd = G()
    cy(gd, T(-2.3, -5.4, 0.056), 0.36, 0.012, seg=SEGC + 8)
    cy(gd, T(-2.3, -5.4, 0.053), 0.40, 0.008, seg=SEGC + 8)
    for k in range(-2, 3):
        bx(gd, T(-2.3 + k * 0.12, -5.4, 0.063), (0.02, 0.6, 0.006), bevel=False)
    bx(gd, T(3.2, -5.0, 0.056), (0.7, 0.46, 0.012))
    commit("Voorplein_metaal", gd, M["donker"], root, tile=1.0)
    for k in range(7):
        bx(gz, T(3.2 - 0.27 + k * 0.09, -5.0, 0.063), (0.03, 0.38, 0.006), bevel=False)
    commit("Voorplein_gleuven", gz, M["zwart"], root, tile=1.0, bevel=False)


def barrel(gb, gr, gy, M4):
    cy(gb, M4 @ T(0, 0, 0.44), 0.29, 0.88, seg=SEGC + 6)
    for z in (0.22, 0.66):
        cy(gr, M4 @ T(0, 0, z), 0.298, 0.035, seg=SEGC + 6)
    cy(gr, M4 @ T(0, 0, 0.885), 0.3, 0.025, seg=SEGC + 6)
    cy(gr, M4 @ T(0.12, 0.06, 0.9), 0.035, 0.03, seg=SEGC)
    cy(gr, M4 @ T(-0.09, -0.1, 0.9), 0.03, 0.025, seg=SEGC)
    if gy is not None:
        cy(gy, M4 @ T(0, 0, 0.44), 0.293, 0.1, seg=SEGC + 6)


def ammo_crate(gs, gd, M4):
    bx(gs, M4 @ T(0, 0, 0.15), (0.6, 0.34, 0.3))
    bx(gd, M4 @ T(0, 0, 0.292), (0.62, 0.36, 0.028))
    bx(gd, M4 @ T(0.31, 0, 0.2), (0.03, 0.16, 0.04))
    bx(gd, M4 @ T(-0.31, 0, 0.2), (0.03, 0.16, 0.04))
    for sx in (-0.15, 0.15):
        bx(gd, M4 @ T(sx, -0.175, 0.2), (0.05, 0.02, 0.07))


def build_props(M, root):
    gs, gd, gr, gy, gw, gz, gt, ga = G(), G(), G(), G(), G(), G(), G(), G()
    rng = random.Random(9)
    # opvangbak met vijf vaten
    bx(gs, T(BARREL_TRAY[0], BARREL_TRAY[1] + 0.2, 0.04), (2.4, 1.6, 0.08))
    for i, (x, y) in enumerate(BARRELS):
        M4 = T(x, y, 0.08) @ H.RZ(rng.uniform(0, 6.28))
        barrel(gr if i == 3 else gs, gd, gy if i in (1, 4) else None, M4)
    # pallet met munitiekisten, houten kist en zeil
    px, py = PALLET
    for xx in (-0.5, 0.0, 0.5):
        for yy in (-0.4, 0.0, 0.4):
            bx(gw, T(px + xx, py + yy, 0.06), (0.1, 0.1, 0.09))
    for k in range(5):
        bx(gw, T(px, py - 0.46 + k * 0.23, 0.125), (1.2, 0.18, 0.03))
    for k in range(3):
        bx(gw, T(px, py - 0.45 + k * 0.45, 0.025), (1.2, 0.1, 0.03))
    ammo_crate(gs, gd, T(px - 0.3, py - 0.22, 0.14) @ H.RZ(0.05))
    ammo_crate(gs, gd, T(px + 0.3, py - 0.22, 0.14) @ H.RZ(-0.04))
    ammo_crate(gs, gd, T(px - 0.28, py - 0.22, 0.46) @ H.RZ(-0.1))
    prism(gt, ((-0.3, 0), (0.3, 0), (0.3, 0.34), (0.0, 0.5), (-0.3, 0.34)), 0.9, T(px + 0.05, py + 0.25, 0.14))
    # kabelhaspel
    sx, sy = SPOOL
    for off in (-0.22, 0.22):
        cy(gw, T(sx, sy + off, 0.45) @ H.RX(math.pi / 2), 0.45, 0.04, seg=SEGC + 6)
    cy(gw, T(sx, sy, 0.45) @ H.RX(math.pi / 2), 0.15, 0.44, seg=SEGC)
    cy(gz, T(sx, sy, 0.45) @ H.RX(math.pi / 2), 0.31, 0.4, seg=SEGC + 6)
    # afzetblokken met reflecterende strepen
    for (x, y) in BARRIERS:
        M4 = T(x, y, 0.05)
        prism(gs, ((-0.27, 0), (0.27, 0), (0.27, 0.12), (0.12, 0.8), (-0.12, 0.8), (-0.27, 0.12)), 1.5, M4)
        for sgn in (-1, 1):
            bx(gy, M4 @ T(0, sgn * 0.19, 0.5), (1.2, 0.02, 0.12), bevel=False)
    for (x, y) in BOLLARDS:
        cy(gy, T(x, y, 0.5), 0.075, 0.9, seg=SEGC + 2)
        cy(gz, T(x, y, 0.66), 0.08, 0.1, seg=SEGC + 2)
        cy(gd, T(x, y, 0.96), 0.085, 0.03, seg=SEGC + 2)
    # lichtmasten: voet, conische paal, arm met twee armaturen, aansluitkast en kabelgoot
    for (x, y) in MASTS:
        yaw = math.atan2(-y, -x)                                      # richting hoofdkwartier
        base = T(x, y, 0) @ H.RZ(yaw)
        bx(gd, T(x, y, 0.06), (0.5, 0.5, 0.06))
        for sx in (-0.18, 0.18):
            for sy_ in (-0.18, 0.18):
                cy(gd, T(x + sx, y + sy_, 0.1), 0.025, 0.04, seg=6)
        cy(gd, T(x, y, MAST_H / 2 + 0.08), 0.095, MAST_H, seg=SEGC + 2, r2=0.055)
        bx(gd, base @ T(0, 0, MAST_H + 0.02), (0.12, 1.4, 0.08))
        for sgn in (-1, 1):
            M4 = base @ T(0.14, sgn * 0.6, MAST_H - 0.08) @ H.RY(math.radians(28))
            bx(gd, M4, (0.34, 0.5, 0.2))
            bx(gd, M4 @ T(-0.12, 0, 0.12), (0.2, 0.4, 0.05))
            bx(ga, M4 @ T(0.172, 0, 0), (0.012, 0.44, 0.16), bevel=False)
        bx(gs, T(x + 0.16, y, 1.05), (0.1, 0.24, 0.42))
        cy(gd, T(x + 0.16, y, 0.5), 0.02, 0.9, seg=SEGC)
    # grondkabels: mast links naar de voorwand van het hoofdkwartier, en tussen de masten met een kabelbrug op de ingang
    def ground_cable(pts):
        for p0, p1 in zip(pts[:-1], pts[1:]):
            st(gz, Vector(p0), Vector(p1), 0.022, seg=5)
        for p in pts[1:-1]:
            cy(gz, T(p[0], p[1], 0.03), 0.034, 0.06, seg=SEGC)

    ground_cable([(-4.9, -5.8, 0.03), (-4.9, -4.55, 0.03), (-2.0, -4.55, 0.03), (-2.0, -2.9, 0.03), (-2.0, -2.62, 0.45)])
    ground_cable([(-4.8, -6.0, 0.03), (-1.2, -6.0, 0.03)])
    ground_cable([(1.2, -6.0, 0.03), (4.8, -6.0, 0.03)])
    bx(gz, T(0.0, -6.0, 0.03), (2.4, 0.4, 0.05), bevel=True)           # kabelbrug
    for k in range(5):
        bx(gy, T(-0.8 + k * 0.4, -6.0, 0.058), (0.05, 0.4, 0.006), bevel=False)
    # verbinden en committen
    commit("Props_staal", gs, M["staal"], root, tile=1.2)
    commit("Props_donker", gd, M["donker"], root, tile=1.0)
    commit("Props_rood", gr, M["rood_verf"], root, tile=1.0, bevel=False)
    commit("Props_geel", gy, M["geel"], root, tile=1.0, bevel=False)
    commit("Props_hout", gw, M["hout"], root, tile=1.0)
    commit("Props_rubber", gz, M["zwart"], root, tile=1.0)
    commit("Props_zeil", gt, M["staal"], root, tile=1.0)
    commit("Lamp_Mast", ga, M["amber"], root, tile=1.0, bevel=False)


def main():
    if LEVEL == "lod1":
        print("omgeving heeft geen afstandsversie")
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    res = H.TEXRES
    cn = F.tinted_set("concrete", (0.80, 0.78, 0.72), res)
    ol = F.tinted_set("olive", (0.64, 0.70, 0.44), res)
    dk = F.tinted_set("steel", (0.58, 0.58, 0.54), res)
    M = {
        "beton": B.weathered("HK_Beton", "concrete", albedo=cn["albedo"], normal=cn["normal"], orm=cn["orm"], nstrength=1.1, seed=21),
        "staal": B.weathered("HK_Staal_olijf", "paint", albedo=ol["albedo"], normal=ol["normal"], orm=ol["orm"], nstrength=0.9, seed=22),
        "donker": B.weathered("HK_Metaal_donker", "metal", albedo=dk["albedo"], normal=dk["normal"], orm=dk["orm"], nstrength=0.6, seed=23),
        "wit": B.weathered("HK_Verf_wit", "paint", color=(0.50, 0.48, 0.42), rough=0.7, seed=24),
        "geel": B.weathered("HK_Verf_geel", "paint", color=(0.55, 0.38, 0.04), rough=0.65, seed=26),
        "zwart": B.weathered("HK_Rubber", "rubber", color=(0.03, 0.03, 0.03), rough=0.8, seed=28),
        "rood_verf": B.weathered("HK_Verf_rood", "paint", color=(0.38, 0.04, 0.03), rough=0.5, seed=29),
        "hout": B.weathered("HK_Hout", "paint", color=(0.30, 0.20, 0.11), rough=0.85, seed=30, wear=1.4),
        "amber": F.plain("HK_Lamp_amber", (1.0, 0.62, 0.16), 0.3, emission=((1.0, 0.55, 0.10), 4.0)),
    }
    root = bpy.data.objects.new("Omgeving", None)
    sc.collection.objects.link(root)
    build_pad(M, root)
    build_props(M, root)
    tris = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in bpy.data.objects:
        if o.type == "MESH":
            m = o.evaluated_get(dg).to_mesh()
            tris += sum(len(p.vertices) - 2 for p in m.polygons)
    print(f"[omgeving {LEVEL}] triangles: {tris}")
    if LEVEL != "hq":
        bake(root)
    stem = "Hoofdkwartier_omgeving"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{stem}.blend"))
    if LEVEL == "hq":
        print("HQ-bron opgeslagen:", OUT / f"{stem}.blend")
        return
    glb = ROOT / "assets" / "hoofdkwartier_omgeving.glb"
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", export_yup=True, export_apply=False, export_animations=False,
                              export_materials="EXPORT", export_image_format="AUTO", export_lights=False, export_cameras=False)
    print("geschreven:", glb)
    try:
        bpy.ops.wm.usd_export(filepath=str(OUT / f"{stem}.usdz"), export_materials=True, generate_preview_surface=True)
        print("geschreven:", OUT / f"{stem}.usdz")
    except Exception as exc:  # noqa
        print("USDZ-export mislukt:", exc)


def bake(root):
    """Een unieke 2K-atlas (albedo, ORM met AO, normal) voor alle bakeable onderdelen."""
    objs = [o for o in bpy.data.objects if o.type == "MESH" and o.material_slots
            and all(s.material and s.material.get("bake_kind") for s in o.material_slots)]
    print(f"[bake omgeving] {len(objs)} objecten, atlas {H.ATLAS}")
    sc = bpy.context.scene
    w = bpy.data.worlds.new("BakeWorld")
    sc.world = w
    w.light_settings.distance = 1.3
    margin = 0.003
    B.make_atlas_uvs(objs, margin=margin)
    B.cull_hidden(objs)
    B.make_atlas_uvs(objs, margin=margin)
    tag = "hk_omgeving"
    paths = B.run(objs, H.ATLAS, OUT, samples=H.SAMPLES, tag=tag)
    p_alb, p_orm, p_nrm = B.compose(paths, H.ATLAS, OUT, tag=tag, jpeg=True)
    mat = B.baked_material("HK_Gebakken_omgeving", p_alb, p_orm, p_nrm)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.material_index = 0
        if "UVMap" in o.data.uv_layers:
            o.data.uv_layers.remove(o.data.uv_layers["UVMap"])
    for m in list(bpy.data.materials):
        if m.get("bake_kind"):
            bpy.data.materials.remove(m)


if __name__ == "__main__":
    main()
