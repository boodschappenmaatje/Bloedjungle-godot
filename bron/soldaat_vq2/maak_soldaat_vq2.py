#!/usr/bin/env python3
"""Realistische soldaat VQ2 (eigen team, speler/Rambo en vijanden) op het bestaande DEF-skelet.

    python3 bron/soldaat_vq2/maak_soldaat_vq2.py UIT --mpfb <mpfb2>/src/mpfb/data [--render] [--size 1024]

Leest het skelet en alle clips uit assets/soldaat.glb, bouwt een MakeHuman-lichaam (CC0) dat op dat skelet past,
vier lichaamsvarianten met kleding, de uitrusting per type en schrijft UIT/soldaat_vq2.glb, UIT/soldaat_vq2.blend en
UIT/tex/*. Zie README.md.
"""
import json
import math
import sys
import time
from pathlib import Path

import bpy
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lagen as L  # noqa: E402
import mens  # noqa: E402
import textuur as tx  # noqa: E402
import uitrusting  # noqa: E402
from materiaal import material  # noqa: E402

ROOT = HERE.parents[1]
OUT = Path(sys.argv[1])
DATA = Path(sys.argv[sys.argv.index("--mpfb") + 1])
SIZE = int(sys.argv[sys.argv.index("--size") + 1]) if "--size" in sys.argv else 1024
RENDER = "--render" in sys.argv
DECIMATE = 0.34
ALBEDO_GAIN = 0.66
(OUT / "tex").mkdir(parents=True, exist_ok=True)
T0 = time.time()


def log(*a):
    print(f"[{time.time() - T0:6.1f}s]", *a, flush=True)


# ---------------- skelet en clips ----------------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/soldaat.glb"))
rig = bpy.data.objects["Rig"]
for o in list(bpy.data.objects):
    if o.type == "MESH" or o.name == "Mannequin":
        bpy.data.objects.remove(o)
if rig.animation_data:
    rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis.identity()
mw = rig.matrix_world
DEF = {b.name: (np.array(mw @ b.head_local), np.array(mw @ b.tail_local)) for b in rig.data.bones}
CLIPS = sorted(a.name for a in bpy.data.actions)
log("clips", CLIPS)

# ---------------- lichaam ----------------
h = mens.build(DATA)
KEEP = {"body", "helper-l-eye", "helper-r-eye"}
faces = [f for f in h["faces"] if f[2] in KEEP]
used = sorted({v for f in faces for v in f[0]})
remap = {v: i for i, v in enumerate(used)}
pts, Wall, BONES, scale = mens.fit(h, DEF, 13380)
P = pts[used]
W = Wall[used]
F = [[remap[v] for v in f[0]] for f in faces]
FUV = [h["UV"][f[1]] for f in faces]
face_eye = np.array([f[2] != "body" for f in faces])
is_eye = np.zeros(len(P), bool)
for f, e in zip(F, face_eye):
    if e:
        is_eye[f] = True
EYES = (P[is_eye & (P[:, 0] > 0)].mean(0), P[is_eye & (P[:, 0] < 0)].mean(0))
log("lichaam", len(P), "hoekpunten", len(F), "vlakken, schaal", round(scale, 4))

# hoekpuntnormalen en buren
N = np.zeros_like(P)
for f in F:
    a = P[f]
    n = np.cross(a[1] - a[0], a[2] - a[0]) + (np.cross(a[2] - a[0], a[3] - a[0]) if len(f) == 4 else 0)
    N[f] += n
N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
edges = set()
for f in F:
    for i in range(len(f)):
        a, b = f[i], f[(i + 1) % len(f)]
        edges.add((min(a, b), max(a, b)))
E = np.array(sorted(edges))


def neighbour_mean(vals, mask=None, iters=1, keep=0.0):
    v = vals.copy()
    deg = np.bincount(E.ravel(), minlength=len(P)).astype(float)
    for _ in range(iters):
        acc = np.zeros_like(v)
        np.add.at(acc, E[:, 0], v[E[:, 1]])
        np.add.at(acc, E[:, 1], v[E[:, 0]])
        avg = acc / np.maximum(deg, 1).reshape((-1,) + (1,) * (v.ndim - 1))
        new = keep * v + (1 - keep) * avg
        if mask is None:
            v = new
        else:
            v[mask] = new[mask]
    return v


# ---------------- driehoeken + texelkaart (gedeeld door alle varianten: zelfde UV's) ----------------
tri_v, tri_uv, tri_f = [], [], []
for fi, (f, uv) in enumerate(zip(F, FUV)):
    for k in range(1, len(f) - 1):
        tri_v.append((f[0], f[k], f[k + 1]))
        tri_uv.append((uv[0], uv[k], uv[k + 1]))
        tri_f.append(fi)
tri_v = np.array(tri_v)
tri_uv = np.array(tri_uv)
tri_f = np.array(tri_f)
log("rasteren", len(tri_v), "driehoeken op", SIZE)
tri_id, bary = tx.rasterize(tri_uv, SIZE)
sy, sx, filled = tx.dilate_index(tri_id, 16)
T = tri_id[sy, sx]
B = bary[sy, sx]
valid = filled & (T >= 0)
Tv, Bv = T[valid], B[valid]
TP = (P[tri_v[Tv]] * Bv[:, :, None]).sum(1)
TN = (N[tri_v[Tv]] * Bv[:, :, None]).sum(1)
TN /= np.maximum(np.linalg.norm(TN, axis=1, keepdims=True), 1e-9)
yy, xx = np.nonzero(valid)
TUV = np.stack([(xx + 0.5) / SIZE, 1 - (yy + 0.5) / SIZE], 1)
TF = tri_f[Tv]
log("texels", len(TP))


def face_layers(variant):
    cent = np.array([P[f].mean(0) for f in F])
    return L.layer_of(variant, cent, face_eye)


def textures(variant, flay):
    lay = flay[TF]
    col = np.zeros((len(TP), 3))
    hgt = np.zeros(len(TP))
    rough = np.zeros(len(TP))
    for l in np.unique(lay):
        m = lay == l
        p, n, uv = TP[m], TN[m], TUV[m]
        if l == L.SKIN:
            r = L.skin(p, n, uv, EYES, variant)
        elif l == L.CAMO:
            r = L.camo(p, n, uv)
        elif l == L.SHIRT_E:
            r = L.shirt_enemy(p, n, uv)
        elif l == L.PANTS_E:
            r = L.shirt_enemy(p, n, uv, pants=True)
        elif l == L.TANK:
            r = L.tank(p, n, uv)
        elif l == L.GLOVE:
            r = L.glove(p, n, uv)
        elif l == L.BOOT:
            r = L.boot(p, n, uv)
        elif l == L.BOOT_E:
            r = L.boot(p, n, uv, enemy=True)
        else:
            r = L.eye(p, n, EYES)
        col[m], hgt[m], rough[m] = r
    A = np.zeros((SIZE, SIZE, 3), np.float32)
    H = np.zeros((SIZE, SIZE), np.float32)
    R = np.full((SIZE, SIZE), 0.8, np.float32)
    A[yy, xx], H[yy, xx], R[yy, xx] = col, hgt, rough
    return A, H, R


# ---------------- varianten bouwen ----------------
def make_object(name, verts, faces_, fuv, mat_idx, weights=None, groups=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces_)
    uvl = me.uv_layers.new(name="UVMap")
    flat = np.concatenate([np.asarray(u) for u in fuv]).ravel()
    uvl.data.foreach_set("uv", flat)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.materials.append(bpy.data.materials.new(name + "_m0"))
    me.materials.append(bpy.data.materials.new(name + "_m1"))
    me.polygons.foreach_set("material_index", list(mat_idx))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if weights is not None:
        loose = np.ones(len(verts), bool)
        for f in faces_:
            loose[f] = False
        for j, g in enumerate(groups):
            vg = ob.vertex_groups.new(name=g)
            nz = np.nonzero((weights[:, j] > 1e-3) & ~loose)[0]
            for vi in nz:
                vg.add([int(vi)], float(weights[vi, j]), "REPLACE")
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    return ob


def apply_mod(ob, mod):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def parent_to_rig(ob):
    ob.parent = rig
    m = ob.modifiers.new("Armature", "ARMATURE")
    m.object = rig


def img_from(arr, name, noncolor=False):
    """numpy (S,S,3) 0..1, rij 0 = boven -> Blender-afbeelding (rij 0 = onder)."""
    s = arr.shape[0]
    im = bpy.data.images.new(name, s, s, alpha=False)
    if noncolor:
        im.colorspace_settings.name = "Non-Color"
    rgba = np.concatenate([arr[::-1], np.ones((s, s, 1), np.float32)], 2)
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    return im


def bake(lo, hi, kind, samples):
    s = SIZE
    im = bpy.data.images.new(f"bake_{lo.name}_{kind}", s, s, alpha=False, float_buffer=True)
    im.colorspace_settings.name = "Non-Color"
    bm = bpy.data.materials.new("bake")
    node = bm.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = im
    bm.node_tree.nodes.active = node
    saved = [sl.material for sl in lo.material_slots]
    for sl in lo.material_slots:
        sl.material = bm
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.render.bake.margin = 16
    for o in bpy.context.selected_objects:
        o.select_set(False)
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    if kind == "NORMAL":
        hi.hide_render = False
        hi.select_set(True)
        bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=0.012,
                            max_ray_distance=0.03, normal_space="TANGENT")
    else:
        # alleen dit lichaam telt mee: eerdere varianten staan op dezelfde plek en zouden alles verduisteren
        hidden = {o.name: o.hide_render for o in bpy.data.objects if o.type == "MESH"}
        for o in bpy.data.objects:
            if o.type == "MESH":
                o.hide_render = o != lo
        bpy.ops.object.bake(type="AO")
        for n_, v in hidden.items():
            bpy.data.objects[n_].hide_render = v
    px = np.array(im.pixels[:], np.float32).reshape(s, s, 4)[::-1, :, :3]
    for sl, m in zip(lo.material_slots, saved):
        sl.material = m
    bpy.data.images.remove(im)
    bpy.data.materials.remove(bm)
    return px


def save_tex(name, A, Nrm, ORM):
    paths = {}
    for kind, arr in (("albedo", A), ("normal", Nrm * 0.5 + 0.5), ("orm", ORM)):
        p = OUT / "tex" / f"{name}_{kind}.jpg"
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(p, quality=92)
        im = bpy.data.images.load(str(p))
        if kind != "albedo":
            im.colorspace_settings.name = "Non-Color"
        paths[kind] = im
    return paths


report = {"clips": CLIPS, "mpfb_targets": h["targets"], "fit_scale": scale, "variants": {}, "gear": {}}
bodies = {}
for variant in L.VARIANTS:
    log("variant", variant)
    vlay = L.layer_of(variant, P, is_eye)
    off = L.offsets(variant, P, vlay)
    off = neighbour_mean(off, iters=2, keep=0.5)
    Q = P + N * off[:, None]
    flay = face_layers(variant)
    mat_idx = np.isin(flay, list(L.TINTED)).astype(int)     # 0 = huid/laars/handschoen, 1 = kleding (getint)
    inboot = np.array([(P[f][:, 2] < 0.20).all() for f in F])     # zit verborgen in de laars
    keep = np.nonzero(~inboot)[0]
    Fb = [F[i] for i in keep]
    FUVb = [FUV[i] for i in keep]
    hi = make_object(f"hi_{variant}", Q, Fb, FUVb, mat_idx[keep])
    lo = make_object(f"Lijf_{variant}", Q, Fb, FUVb, mat_idx[keep], W, BONES)
    # hoofd en handen minder vereenvoudigen: dat zijn de herkenbare delen
    keepg = lo.vertex_groups.new(name="vereenvoudig")
    regv = L.region(Q)
    for vi in range(len(Q)):
        keepg.add([vi], 0.15 if regv[vi] == L.HEAD else (0.5 if regv[vi] == L.HAND else 1.0), "REPLACE")
    dm = lo.modifiers.new("dec", "DECIMATE")
    dm.ratio = DECIMATE
    dm.vertex_group = "vereenvoudig"
    dm.vertex_group_factor = 4.0
    dm.use_symmetry = True
    dm.symmetry_axis = "X"
    apply_mod(lo, dm)
    tm = lo.modifiers.new("tri", "TRIANGULATE")
    apply_mod(lo, tm)
    lo.vertex_groups.remove(lo.vertex_groups["vereenvoudig"])
    head_tris = sum(1 for p in lo.data.polygons if p.center.z > 1.5 and abs(p.center.x) < 0.16)
    log("  driehoeken in het hoofd", head_tris)
    hi.hide_render = True
    A, H, R = textures(variant, flay)
    log("  texturen berekend")
    hi.hide_render = True
    nb = bake(lo, hi, "NORMAL", 1) * 2 - 1
    ao = bake(hi, lo, "AO", 48)[..., 0]    # AO op het fijne lichaam: geen facetten van de vereenvoudiging
    lo.hide_render = False
    log("  gebakken")
    detail = tx.normal_from_height(H, 1.6)
    Nrm = tx.blend_normals(nb, detail)
    ao = np.clip(ao, 0, 1) * 0.6 + 0.4
    # spelbelichting (zon 2,2 + belichting) is fel: albedo omlaag zodat huid en stof niet uitbleken (gemeten in Godot)
    A2 = A * (0.35 + 0.65 * ao[..., None]) * ALBEDO_GAIN
    ORM = np.stack([ao, R, np.zeros_like(R)], -1)
    imgs = save_tex(f"lijf_{variant.lower()}", A2, Nrm, ORM)
    lo.material_slots[0].material = material(f"{variant}_Huid", imgs)
    lo.material_slots[1].material = material(f"{variant}_Kleding", imgs)
    parent_to_rig(lo)
    bpy.data.objects.remove(hi)
    lo.data.calc_loop_triangles()
    report["variants"][variant] = {"triangles": len(lo.data.loop_triangles), "vertices": len(lo.data.vertices)}
    bodies[variant] = (Q, flay)
    log("  ", report["variants"][variant])

# ---------------- uitrusting ----------------
gear = uitrusting.build(OUT, P, N, F, FUV, W, BONES, EYES, rig, DEF, log)
for name, ob in gear.items():
    ob.data.calc_loop_triangles()
    report["gear"][name] = len(ob.data.loop_triangles)

# ---------------- export ----------------
rig.animation_data_create()
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.matrix_basis.identity()
bpy.context.preferences.filepaths.save_version = 0
for o in bpy.context.selected_objects:
    o.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(OUT / "soldaat_vq2.glb"), export_format="GLB", export_yup=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                          export_materials="EXPORT", export_image_format="AUTO", export_cameras=False, export_lights=False,
                          export_apply=False)
bpy.ops.file.pack_all()      # bewerkbare .blend met de texturen erin
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "soldaat_vq2.blend"))
(OUT / "rapport.json").write_text(json.dumps(report, indent=1))
log("klaar", json.dumps(report)[:600])

if RENDER:
    import render_soldaat
    render_soldaat.run(OUT, rig, log)
