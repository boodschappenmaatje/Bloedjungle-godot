"""Stap 2: lage spelversie van de delen. Romp, toren en kanon worden gedecimeerd (met kappen op de draaivlakken), wielen en
rupsbanden worden schoon gegenereerd (gelijkmatig draaiende wielen, een band met bewegende textuur), alle delen krijgen UV's.
Leest delen_hoog.blend en geo.npz uit de cache, schrijft laag.blend.
Gebruik: python3 stap2_laag.py <cache-map> [driehoeken romp] [driehoeken toren] [driehoeken kanon]"""
import sys, time, math
import numpy as np
import bpy, bmesh
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tiger_delen as TD

args = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else sys.argv[-1:]
CACHE = Path(args[0]).resolve()
N_ROMP = int(args[1]) if len(args) > 1 else 9000
N_TOREN = int(args[2]) if len(args) > 2 else 7000
K = TD.SCHAAL
SEG = 16                 # segmenten per wiel
t0 = time.time()
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "delen_hoog.blend"))
g = np.load(CACHE / "geo.npz")
gco, gtri, glab = g["co"], g["tri"], g["lab"]
scene = bpy.context.scene
view = bpy.context.view_layer


def alleen(*objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    view.objects.active = objs[0]


def maak_object(naam, verts, faces, uvs=None):
    """verts Nx3, faces Mx3 (of lijst vlakken), uvs per hoekpunt van elk vlak"""
    me = bpy.data.meshes.new(naam)
    me.from_pydata(verts.tolist(), [], [list(f) for f in faces])
    me.update()
    if uvs is not None:
        layer = me.uv_layers.new(name="UVMap")
        layer.data.foreach_set("uv", np.asarray(uvs, np.float32).ravel())
    ob = bpy.data.objects.new(naam, me)
    scene.collection.objects.link(ob)
    return ob


def decimeer(naam_hoog, naam_laag, doel):
    """decimeren van het gesloten, dichtgemaakte voxel-deel uit stap 1"""
    hoog = bpy.data.objects[naam_hoog]
    laag = hoog.copy(); laag.data = hoog.data.copy(); laag.name = laag.data.name = naam_laag
    scene.collection.objects.link(laag); laag.hide_render = False
    alleen(laag)
    d = laag.modifiers.new("Decimate", "DECIMATE")
    d.ratio = doel / len(hoog.data.polygons); d.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=d.name)
    while len(laag.data.uv_layers):
        laag.data.uv_layers.remove(laag.data.uv_layers[0])
    laag.data.materials.clear()
    return laag


def schijf(naam, middelpunt, straal, z_normaal):
    """platte kap (cirkel) voor de draaivlakken van romp (omhoog) en toren (omlaag)"""
    n = 24
    ang = np.linspace(0, 2 * math.pi, n, endpoint=False)
    v = np.vstack([[middelpunt], [[middelpunt[0] + straal * math.cos(a), middelpunt[1] + straal * math.sin(a), middelpunt[2]] for a in ang]])
    f = [[0, 1 + i, 1 + (i + 1) % n] if z_normaal > 0 else [0, 1 + (i + 1) % n, 1 + i] for i in range(n)]
    return maak_object(naam, v, f)


# ---------- romp, toren, kanon ----------
romp = decimeer("Romp_V", "Romp", N_ROMP)
toren = decimeer("Toren_V", "Toren", N_TOREN)
tx, ty = 0.0, -TD.TOREN_AS[0] * K
tz = TD.TOREN_AS[1] * K
kap_romp = schijf("Romp_kap", (tx, ty, tz - 0.03), 1.20, +1)
kap_toren = schijf("Toren_kap", (tx, ty, tz + 0.0), 1.20, -1)
# (de draaivlakken zijn al dichtgemaakt in stap 1; kappen niet meer nodig)
bpy.data.objects.remove(kap_romp); bpy.data.objects.remove(kap_toren)


def kanon_maken():
    """kanon als omwentelingslichaam om zijn eigen (licht omhoog wijzende) as; het profiel komt uit het bronmodel,
    de details (remrem, steunen) komen uit de normal map"""
    sel = glab == TD.KANON
    p = gco[np.unique(gtri[sel].ravel())]
    # as: middelpunt van de top en onderkant per 12 cm, rechte lijn door het deel vóór de wieg (y > 1,0)
    ys_fit, zs_fit = [], []
    for a in np.arange(1.0, float(p[:, 1].max()), 0.12):
        m = (p[:, 1] >= a) & (p[:, 1] < a + 0.12)
        if m.sum() > 20:
            ys_fit.append(a + 0.06); zs_fit.append((np.percentile(p[m, 2], 2) + np.percentile(p[m, 2], 98)) / 2)
    hel, z0 = np.polyfit(ys_fit, zs_fit, 1)
    y0, y1 = 0.74, float(p[:, 1].max())
    stap = 0.09
    ys = np.arange(y0, y1 + stap, stap)
    radii = []
    for a in ys:
        m = (p[:, 1] >= a - stap / 2) & (p[:, 1] < a + stap / 2)
        zc = z0 + hel * a
        r = np.hypot(p[m, 0], p[m, 2] - zc) if m.sum() > 3 else None
        radii.append(float(np.percentile(r, 94)) if r is not None else (radii[-1] if radii else 0.1))
    radii = np.array(radii)
    seg = 14
    verts, faces = [], []
    for y, r in zip(ys, radii):
        zc = z0 + hel * y
        for s_ in range(seg):
            a = 2 * math.pi * s_ / seg
            verts.append([r * math.cos(a), y, zc + r * math.sin(a)])
    for i in range(len(ys) - 1):
        for s_ in range(seg):
            s2 = (s_ + 1) % seg
            a, b = i * seg + s_, i * seg + s2
            faces.append([a, a + seg, b + seg]); faces.append([a, b + seg, b])
    for i, ring0 in ((0, True), (len(ys) - 1, False)):
        c = len(verts); verts.append([0.0, ys[i], z0 + hel * ys[i]])
        for s_ in range(seg):
            s2 = (s_ + 1) % seg
            faces.append([c, i * seg + s2, i * seg + s_] if ring0 else [c, i * seg + s_, i * seg + s2])
    ob = maak_object("Kanon", np.array(verts, np.float32), faces)
    bm = bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(ob.data); bm.free()
    ob["monding"] = (0.0, float(ys[-1]), float(z0 + hel * ys[-1]))
    ob["helling"] = float(hel)
    ob["draaipunt"] = (0.0, -TD.LOOP_AS[0] * K, float(z0 + hel * (-TD.LOOP_AS[0] * K)))
    print("kanon: as helling %.3f rad, z0 %.3f, radius begin %.2f eind %.2f" % (math.atan(hel), z0, radii[0], radii[-1]))
    return ob


kanon = kanon_maken()
print("romp/toren/kanon klaar %.0f s" % (time.time() - t0), flush=True)


# ---------- wielen (omwentelingslichamen om de X-as) ----------
def wiel(naam, label, naaf, zijde):
    sel = glab == label
    v = np.unique(gtri[sel].ravel()); p = gco[v]
    hx, hz, r_bron, wn = naaf
    cy, cz = -hx * K, hz * K
    cx = float(np.median(p[:, 0]))
    rr = np.hypot(p[:, 1] - cy, p[:, 2] - cz)
    R = float(np.percentile(rr, 99.7))
    uit = -zijde                                    # buitenkant van het wiel: weg van de romp
    lat = (p[:, 0] - cx) * uit                      # >0 = naar buiten
    edges = np.array([0.0, 0.18, 0.40, 0.62, 0.80, 0.93, 1.0]) * R
    prof_buiten, prof_binnen = [], []
    for a, b in zip(edges[:-1], edges[1:]):
        m = (rr >= a) & (rr < b + 1e-6)
        if m.sum() < 5:
            prof_buiten.append(prof_buiten[-1] if prof_buiten else 0.1); prof_binnen.append(prof_binnen[-1] if prof_binnen else -0.1)
        else:
            prof_buiten.append(float(np.percentile(lat[m], 97))); prof_binnen.append(float(np.percentile(lat[m], 3)))
    rs = (edges[:-1] + edges[1:]) / 2.0
    # profiel van buitenkant-as, over de velg, terug langs de binnenkant
    prof = [(prof_buiten[0], 0.0)] + [(prof_buiten[i], rs[i]) for i in range(len(rs))] + [(prof_buiten[-1], R)]
    prof += [(prof_binnen[-1], R)] + [(prof_binnen[i], rs[i]) for i in reversed(range(len(rs)))] + [(prof_binnen[0], 0.0)]
    verts, ring_index = [], []
    for (l, r) in prof:
        if r < 1e-6:
            ring_index.append([len(verts)]); verts.append([cx + uit * l, cy, cz])
        else:
            idx = []
            for s in range(SEG):
                a = 2 * math.pi * s / SEG
                idx.append(len(verts)); verts.append([cx + uit * l, cy + r * math.cos(a), cz + r * math.sin(a)])
            ring_index.append(idx)
    faces = []
    for i in range(len(prof)):
        j = (i + 1) % len(prof)
        a, b = ring_index[i], ring_index[j]
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
    ob = maak_object(naam, np.array(verts, np.float32), faces)
    # draaipunt = naaf; normalen buitenwaarts
    bm = bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(ob.data); bm.free()
    ob["naaf"] = (cx, cy, cz)
    return ob


wielen = []
for zijde, basis, tag in ((-1, TD.WIEL0, "L"), (1, TD.WIEL0 + 100, "R")):
    for i, naaf in enumerate(TD.NAVEN):
        naam = "Wiel%s_%s" % (tag, naaf[3])
        w = wiel(naam, basis + i, naaf, zijde)
        w.name = w.data.name = naam
        wielen.append(w)
print("wielen klaar: %d driehoeken totaal, %.0f s" % (sum(len(w.data.polygons) for w in wielen), time.time() - t0), flush=True)


# ---------- rupsbanden: gesloten band met u = afstand langs de baan ----------
def convex_hull(pts):
    pts = sorted(map(tuple, pts))
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


DIKTE = 0.10             # m, schakelhoogte
STAP = 0.16              # m tussen twee doorsneden
banen = {}


def rups(naam, label, zijde):
    sel = glab == label
    v = np.unique(gtri[sel].ravel()); p = gco[v]
    xlo, xhi = np.percentile(p[:, 0], 0.5), np.percentile(p[:, 0], 99.5)
    # convexe omhullende van de zijkant (y,z), snijdt de hobbels van de schakels weg
    poly = TD.baan_polygon()                       # bronmaat (x, z) tegen de klok in
    hull = np.array([(-x * K, z * K) for x, z in poly])[::-1]       # spel (y, z); y = -x spiegelt, dus omkeren
    # opnieuw bemonsteren op gelijke afstand, tegen de klok in (y vooruit, z omhoog), start onderaan voor
    d = np.hypot(*np.diff(np.vstack([hull, hull[:1]]), axis=0).T)
    L = d.sum()
    n = int(round(L / STAP)); L_stap = L / n
    cum = np.concatenate([[0], np.cumsum(d)])
    t = np.linspace(0, L, n, endpoint=False)
    path = np.array([np.interp(t, cum, np.append(hull[:, k], hull[0, k])) for k in range(2)]).T
    start = int(np.argmin(path[:, 1] - 0.001 * path[:, 0]))        # laagste punt
    path = np.roll(path, -start, axis=0)
    # naar buiten gerichte normalen
    tang = np.roll(path, -1, axis=0) - np.roll(path, 1, axis=0)
    nor = np.stack([tang[:, 1], -tang[:, 0]], axis=1); nor /= np.linalg.norm(nor, axis=1)[:, None]
    binnen = path - nor * DIKTE
    verts, faces, uvs = [], [], []
    ringen = n + 1                                  # laatste doorsnede valt op de eerste (u = 1)
    banden = [(0.00, 0.60), (0.62, 0.78), (0.80, 0.92), (0.94, 1.00)]
    for i in range(ringen):
        k = i % n
        u = i / n
        o, b = path[k], binnen[k]
        # hoekpunten: buiten-binnenkant-x, buiten-buitenkant-x, binnen-buitenkant-x, binnen-binnenkant-x
        xin, xuit = (xhi, xlo) if zijde < 0 else (xlo, xhi)
        punten = [(xin, o), (xuit, o), (xuit, b), (xin, b)]
        verts.extend([[x, q[0], q[1]] for x, q in punten])
    base = lambda i, c: i * 4 + c
    for i in range(n):
        for c in range(4):
            a, b = base(i, c), base(i, (c + 1) % 4)
            a2, b2 = base(i + 1, c), base(i + 1, (c + 1) % 4)
            faces.append([a, b, b2, a2])
    # UV per hoekpunt van elk vlak
    uv = []
    for i in range(n):
        for c in range(4):
            v0, v1 = banden[c]
            u0, u1 = i / n, (i + 1) / n
            uv += [(u0, v0), (u0, v1), (u1, v1), (u1, v0)]
    ob = maak_object(naam, np.array(verts, np.float32), faces, uv)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
    banen[naam] = float(L)
    ob["baanlengte"] = float(L)
    return ob


rups_l = rups("RupsL", TD.RUPS_L, -1)
rups_r = rups("RupsR", TD.RUPS_R, +1)
print("rupsen: baan %.2f m, %d driehoeken, %.0f s" % (rups_l["baanlengte"], len(rups_l.data.polygons), time.time() - t0), flush=True)

# ---------- UV's voor alles behalve de rupsen (die hebben hun eigen band-UV) ----------
atlas = [romp, toren, kanon] + wielen
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
for o in atlas + [rups_l, rups_r]:
    for pl in o.data.polygons:
        pl.use_smooth = True
tot = sum(len(o.data.polygons) for o in atlas + [rups_l, rups_r])
print("laag klaar: %d driehoeken, %.0f s" % (tot, time.time() - t0))
for o in atlas + [rups_l, rups_r]:
    print(" ", o.name, len(o.data.polygons))
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE / "laag.blend"))
