"""Stap 2 (jeep): lage spelversie van de delen. Leest <cache>/jeep_voxel.npz (stap 1), deelt de gesloten voxel-schil in (delen_jeep.py), maakt elk
deel dicht op de snijvlakken, decimeert, genereert de wielen schoon (omwentelingslichamen met het profiel van het bronwiel) en geeft alles UV's.
Schrijft <cache>/jeep_laag.blend (spelassen: x = breedte, +y = voorkant, z = omhoog, grond op z = 0).
Gebruik: python3 stap2_wagen.py <cache-map>"""
import sys, time, math
import numpy as np
import bpy, bmesh
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen_jeep as D

CACHE = Path(sys.argv[-1]).resolve()
t0 = time.time()
DOEL = {"Romp": 30000, "MG": 8000}
SEG = 36

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
view = bpy.context.view_layer
d = np.load(CACHE / "jeep_voxel.npz")
co_m, tri = d["co"], d["tri"]
lab = D.indelen(co_m[tri].mean(axis=1))
game = D.naar_spel(co_m).astype(np.float32)
print("labels:", {int(k): int(v) for k, v in zip(*np.unique(lab, return_counts=True))}, flush=True)


def alleen(*objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = objs[0]


def maak_object(naam, verts, faces):
    me = bpy.data.meshes.new(naam)
    me.from_pydata(np.asarray(verts, np.float32).tolist(), [], [list(map(int, f)) for f in faces])
    me.update()
    ob = bpy.data.objects.new(naam, me)
    scene.collection.objects.link(ob)
    return ob


def deel_uit_schil(naam, mask):
    t = tri[mask]
    used = np.unique(t.ravel())
    remap = np.full(len(game), -1, np.int64)
    remap[used] = np.arange(len(used))
    return maak_object(naam, game[used], remap[t])


def dichtmaken(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    rand = [e for e in bm.edges if e.is_boundary]
    n0 = len(rand)
    if rand:
        res = bmesh.ops.holes_fill(bm, edges=rand, sides=100000)
        bmesh.ops.triangulate(bm, faces=res["faces"])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    rest = sum(1 for e in bm.edges if e.is_boundary)
    bm.to_mesh(ob.data); bm.free()
    ob.data.validate()   # het dichtmaken laat dubbele vlakken achter (dunne wanden): weg ermee
    print("  %s: %d randranden dichtgemaakt, %d over" % (ob.name, n0, rest), flush=True)


def decimeer(ob, doel):
    n = len(ob.data.polygons)
    if n <= doel:
        return
    alleen(ob)
    m = ob.modifiers.new("Decimate", "DECIMATE")
    m.ratio = doel / n
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)


delen = []
for label, naam in ((D.ROMP, "Romp"), (D.MG, "MG")):
    mask = lab == label
    ob = deel_uit_schil(naam, mask)
    print("deel %s: %d driehoeken voor decimeren" % (naam, len(ob.data.polygons)), flush=True)
    dichtmaken(ob)
    decimeer(ob, DOEL[naam])
    ob.data.validate()   # het decimeren kan weer dubbele vlakken maken
    delen.append(ob)
    print("  -> %d driehoeken, %.0f s" % (len(ob.data.polygons), time.time() - t0), flush=True)


def wiel(naam, i, zijde):
    """i: as-index, zijde +1 = bronzijde Y > 0 (spel-x > 0, rechts)"""
    as_naam, xc, _s = D.ASSEN[i]
    sel = lab == (D.WIEL + i * 2 + (1 if zijde > 0 else 0))
    p = game[np.unique(tri[sel].ravel())]
    cy, cz = -(xc - D.X0), D.WIEL_R              # naaf in spelassen (y, z)
    cx = float(np.median(p[:, 0]))
    rr = np.hypot(p[:, 1] - cy, p[:, 2] - cz)
    R = D.WIEL_R
    uit = float(zijde)
    lat = (p[:, 0] - cx) * uit                    # > 0 = naar buiten
    kanten = np.array([0.0, 0.16, 0.34, 0.52, 0.68, 0.80, 0.90, 0.96, 1.0]) * R
    buiten, binnen = [], []
    for a, b in zip(kanten[:-1], kanten[1:]):
        m = (rr >= a) & (rr < b + 1e-6)
        if m.sum() < 5:
            buiten.append(buiten[-1] if buiten else 0.1); binnen.append(binnen[-1] if binnen else -0.1)
        else:
            buiten.append(float(np.percentile(lat[m], 96))); binnen.append(float(np.percentile(lat[m], 4)))
    rs = (kanten[:-1] + kanten[1:]) / 2.0
    prof = [(buiten[0], 0.0)] + [(buiten[k], rs[k]) for k in range(len(rs))] + [(buiten[-1], R)]
    prof += [(binnen[-1], R)] + [(binnen[k], rs[k]) for k in reversed(range(len(rs)))] + [(binnen[0], 0.0)]
    verts, ringen = [], []
    for (l, r) in prof:
        if r < 1e-6:
            ringen.append([len(verts)]); verts.append([cx + uit * l, cy, cz])
        else:
            idx = []
            for s in range(SEG):
                a = 2 * math.pi * s / SEG
                idx.append(len(verts)); verts.append([cx + uit * l, cy + r * math.cos(a), cz + r * math.sin(a)])
            ringen.append(idx)
    faces = []
    for k in range(len(prof)):
        a, b = ringen[k], ringen[(k + 1) % len(prof)]
        for s in range(SEG):
            s2 = (s + 1) % SEG
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                faces.append([a[0], b[s], b[s2]])
            elif len(b) == 1:
                faces.append([a[s], b[0], a[s2]])
            else:
                faces.append([a[s], b[s], b[s2]]); faces.append([a[s], b[s2], a[s2]])
    ob = maak_object(naam, verts, faces)
    bm = bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(ob.data); bm.free()
    ob["naaf"] = (cx, cy, cz)
    ob["straal"] = R
    return ob


wielen = []
for i, (as_naam, *_r) in enumerate(D.ASSEN):
    for zijde, kant in ((1, "R"), (-1, "L")):
        w = wiel("Wiel_%s%s" % (as_naam, kant), i, zijde)
        wielen.append(w)
        print("  wiel %s: naaf (%.2f, %.2f, %.2f), %d driehoeken" % (w.name, *w["naaf"], len(w.data.polygons)))

atlas = delen + wielen
for o in atlas:
    while len(o.data.uv_layers):
        o.data.uv_layers.remove(o.data.uv_layers[0])
    o.data.uv_layers.new(name="UVMap")
alleen(*atlas)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
bpy.ops.uv.pack_islands(margin=0.003, rotate=True)
bpy.ops.object.mode_set(mode="OBJECT")
for o in atlas:
    for pl in o.data.polygons:
        pl.use_smooth = True
print("laag klaar: %d driehoeken, %.0f s" % (sum(len(o.data.polygons) for o in atlas), time.time() - t0))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "jeep_laag.blend"))
