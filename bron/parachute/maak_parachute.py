"""Parachute voor de parachutisten van Bloedjungle (kracht Parachutisten, E2): ronde koepel van 16 banen, 16 draagkoorden, twee bandstukken naar de schouders.
Geen 'nep': de koepel is één mesh met shape keys (Gesloten, Open, Blazen, Inzakken, SlingerL/R, Duik) en echte clips: Openen (0,8 s met openingsschok),
Zweven-loop (3 s, pendel + ademende koepel) en Inzakken (1,2 s). Alles loopt via NLA-tracks naar de GLB (morph targets in Godot).
Gebruik:  blender --background --python maak_parachute.py -- <uitmap> [--tex 1024] [--usdz]
Oorsprong = het ophangpunt tussen de schouders (waar de soldaat hangt); Z omhoog, voorkant +Y (in Godot -Z). Koepel 5,3 m breed, 3,0 m boven de schouders."""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import numpy as np
import bpy
from mathutils import Vector
import vlieg_common as vc

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(ARGS[0])
TEX = int(ARGS[ARGS.index("--tex") + 1]) if "--tex" in ARGS else 1024
scene = vc.init(OUT, TEX)

N = 16            # banen
NR = 12           # ringen over de koepel
NS = 6            # segmenten per koord
PHI_V, PHI_E = 0.16, 1.36
R0, HD, ZC = 2.7, 1.55, 3.0   # straal, koepelhoogte, hoogte van het middelpunt boven de schouders
JZ = 0.95         # hoogte van de bandsamenkomst boven de schouders
SHOULDER = 0.23
GROUND = -1.62    # grond ten opzichte van de schouders (soldaat staat 1,6 m onder zijn schouders)
BREEDTE = 0.014   # koordbreedte

rng = np.random.default_rng(7)
WRINKLE = rng.random((NR + 1, N * 4 + 1))


def sm(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def kanop(stand):
    """-> (NR+1, N*4, 3) punten van de koepel in een stand; stand = dict(R, H, ...)."""
    th = np.linspace(0, math.tau, N * 4, endpoint=False)
    ph = np.linspace(PHI_V, PHI_E, NR + 1)
    T, P = np.meshgrid(th, ph)
    t = (P - PHI_V) / (PHI_E - PHI_V)
    naad = (1 - np.cos(N * T)) / 2          # 0 op de naad (koord), 1 midden baan
    kind = stand["kind"]
    if kind in ("open", "blazen", "slinger_l", "slinger_r", "duik"):
        r = R0 * np.sin(P)
        z = ZC + HD * np.cos(P)
        f = 1 + 0.06 * naad * np.sin(np.pi * t) - 0.11 * naad * t ** 4
        w = {"open": 1.0, "blazen": 1.0, "slinger_l": 1.0, "slinger_r": 1.0, "duik": 1.0}[kind]
        if kind == "blazen":     # openingsschok: breder en lager, bol
            r = r * 1.16
            z = ZC - 0.35 + (z - ZC) * 0.78
            f = f + 0.05 * np.sin(np.pi * t)
        x = r * f * np.cos(T)
        y = r * f * np.sin(T)
        if kind == "slinger_l":
            x = x - 0.16 * t * (np.cos(T) * 0 + 1)
            z = z + 0.05 * np.sin(T)
        if kind == "slinger_r":
            x = x + 0.16 * t
            z = z - 0.04 * np.sin(T)
        if kind == "duik":       # koepel kantelt naar voren: de voorrand zakt
            y = y + 0.20 * t
            z = z - 0.45 * t * np.sin(T) * 0.0 - 0.32 * np.clip(np.sin(T), 0, 1) * t
        return np.stack([x, y, z], -1)
    if kind == "gesloten":       # nog in de luchtstroom: lange, dunne slang boven de koorden
        z = (JZ + 3.55) + (1 - t) * 3.3
        r = 0.10 + 0.08 * np.sin(np.pi * t) * (0.6 + 0.4 * np.cos(6 * T))
        tw = T + 3.0 * t
        return np.stack([r * np.cos(tw) + 0.15 * (1 - t) * np.sin(2 * t * 6), r * np.sin(tw), z], -1)
    if kind == "inzakken":       # plat opgevouwen hoop op de grond, achter de soldaat
        r = 1.15 * R0 * np.sin(P) * (0.85 + 0.3 * sm(0, 1, t)) * (1 + 0.12 * np.sin(5 * T + 2.0) + 0.06 * np.cos(9 * T))
        w = WRINKLE[:, : N * 4]
        x = r * np.cos(T) * 0.9
        y = r * np.sin(T) * 1.25 - 2.6
        folds = 0.30 * np.abs(np.sin(N * T / 2 + 0.4)) + 0.14 * np.cos(7 * T + 3 * t) + 0.10 * np.sin(3 * T - 5 * t)
        z = GROUND + 0.05 + (0.10 + 0.22 * np.sin(np.pi * t)) * (0.5 + w) * np.clip(folds + 0.45, 0.05, 1.0) + 0.12 * sm(0.6, 1, t) * (w - 0.3)
        return np.stack([x, y, z], -1)
    raise ValueError(kind)


def rand_en_knoop(kan, stand):
    """Randpunten van de baannaden (voor de koorden) en de samenkomsten."""
    rand = kan[-1]               # (N*4, 3)
    naad = rand[::4]             # N punten op de naden
    kind = stand["kind"]
    if kind == "gesloten":
        j = np.array([[0, 0, JZ]] * 2) + 0
        return naad, np.array([[-0.12, 0, JZ], [0.12, 0, JZ]])
    if kind == "inzakken":
        return naad, np.array([[-0.10, -0.20, GROUND + 0.5], [0.10, -0.20, GROUND + 0.5]])
    if kind == "duik":
        return naad, np.array([[-0.12, 0.08, JZ - 0.08], [0.12, 0.08, JZ - 0.08]])
    return naad, np.array([[-0.12, 0, JZ], [0.12, 0, JZ]])


def schouders(stand):
    if stand["kind"] == "inzakken":   # de soldaat is geland: banden liggen slap naar de grond
        return np.array([[-SHOULDER, 0, 0], [SHOULDER, 0, 0]])
    return np.array([[-SHOULDER, 0, 0], [SHOULDER, 0, 0]])


def koord(a, b, sag, stand, kant=1):
    """6 segmenten van punt a naar b als plat lint; geeft (NS+1, 2, 3) punten (twee zijden van het lint)."""
    pts = []
    for k in range(NS + 1):
        u = k / NS
        p = a * (1 - u) + b * u
        p = p + np.array([0, 0, -sag * math.sin(math.pi * u)])
        pts.append(p)
    pts = np.array(pts)
    tan = np.gradient(pts, axis=0)
    tan = tan / (np.linalg.norm(tan, axis=1, keepdims=True) + 1e-9)
    side = np.cross(tan, np.array([0, 1.0, 0]))
    bad = np.linalg.norm(side, axis=1) < 1e-3
    side[bad] = np.cross(tan[bad], np.array([1.0, 0, 0]))
    side = side / (np.linalg.norm(side, axis=1, keepdims=True) + 1e-9)
    return np.stack([pts - side * BREEDTE / 2, pts + side * BREEDTE / 2], 1)


def alle_punten(stand):
    kan = kanop(stand)
    naad, jn = rand_en_knoop(kan, stand)
    sh = schouders(stand)
    sag = {"gesloten": 0.02, "inzakken": 0.35, "blazen": 0.0, "open": 0.0, "slinger_l": 0.03, "slinger_r": 0.03, "duik": 0.05}[stand["kind"]]
    koorden = []
    for m in range(N):
        j = jn[0] if naad[m][0] < 0 else jn[1]
        koorden.append(koord(naad[m], j, sag + 0.03 * (m % 3) * (1 if stand["kind"] == "inzakken" else 0), stand))
    banden = [koord(jn[0], sh[0], 0.0, stand), koord(jn[1], sh[1], 0.0, stand)]
    return kan, koorden, banden


STANDEN = ["open", "gesloten", "blazen", "inzakken", "slinger_l", "slinger_r", "duik"]


def topologie():
    """Vaste vlakken: koepel (quads), koorden en banden (lint)."""
    f = []
    W = N * 4
    for j in range(NR):
        for i in range(W):
            a = j * W + i
            b = j * W + (i + 1) % W
            f.append((a, b, b + W, a + W))
    base = (NR + 1) * W
    for c in range(N + 2):
        for k in range(NS):
            a = base + c * (NS + 1) * 2 + k * 2
            f.append((a, a + 1, a + 3, a + 2))
    return f


def vertices(stand):
    kan, koorden, banden = alle_punten({"kind": stand})
    v = [kan.reshape(-1, 3)]
    for k in koorden + banden:
        v.append(k.reshape(-1, 3))
    return np.concatenate(v, 0)


# ------------------------------------------------------------------ textuur (ripstop-nylon, banen om en om olijf/zand, naden en rand)
def stof_textures(size=TEX):
    uu = np.linspace(0, 1, size)[None, :].repeat(size, 0)
    baan = (np.floor(uu * N) % 2).astype(float)
    ol = np.array([0.30, 0.34, 0.20])
    zand = np.array([0.62, 0.57, 0.42])
    alb = ol[None, None, :] * baan[..., None] + zand[None, None, :] * (1 - baan[..., None])
    y, x = np.mgrid[0:size, 0:size]
    rip = ((x // 6) % 6 == 0) | ((y // 6) % 6 == 0)          # ripstop-raster
    alb = alb * (1 - 0.07 * rip[..., None])
    nz = vc.fbm(size, 7, 5, 3)
    alb = alb * (0.92 + 0.16 * nz[..., None])
    naad = np.abs((uu * N) % 1.0 - 0.5) > 0.485
    alb = alb * (1 - 0.35 * naad[..., None])
    vlek = vc.fbm(size, 3, 9, 4)
    alb = alb * (1 - 0.18 * np.clip(vlek - 0.55, 0, 1)[..., None] * 2)
    hoogte = rip.astype(float) * 0.25 + nz * 0.3 + naad * 0.5
    nor = vc.normal_from_height(hoogte, 2.5)
    orm = np.zeros((size, size, 3))
    orm[..., 0] = 1.0
    orm[..., 1] = 0.82
    orm[..., 2] = 0.0
    return [vc.save_img("parachute_stof_albedo", np.clip(alb, 0, 1)), vc.save_img("parachute_stof_normaal", nor, True), vc.save_img("parachute_stof_orm", orm, True)]


def maak():
    alb, nor, orm = stof_textures()
    m_stof = vc.pbr("Stof", (alb, nor, orm), rough=0.82)
    m_stof.use_backface_culling = False
    m_lijn = vc.pbr("Koord", None, color=(0.10, 0.10, 0.08), rough=0.7)
    m_lijn.use_backface_culling = False
    me = bpy.data.meshes.new("Parachute")
    V = vertices("open")
    me.from_pydata([tuple(p) for p in V], [], topologie())
    me.update()
    W = N * 4
    # UV: u = baan, v = ring
    uvl = me.uv_layers.new(name="UV")
    for poly in me.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            if vi < (NR + 1) * W:
                j, i = divmod(vi, W)
                u = i / W
                if u == 0 and poly.vertices[0] != vi and any((p % W) > W // 2 for p in poly.vertices):
                    u = 1.0
                uvl.data[li].uv = (u, 1 - j / NR)
            else:
                uvl.data[li].uv = (0.01, 0.01)
    me.materials.append(m_stof)
    me.materials.append(m_lijn)
    for poly in me.polygons:
        poly.material_index = 0 if poly.vertices[0] < (NR + 1) * W else 1
        poly.use_smooth = True
    obj = bpy.data.objects.new("Zeil", me)
    root = vc.leeg("Parachute")
    vc.link(obj)
    obj.parent = root
    obj.shape_key_add(name="Open", from_mix=False)
    for s in STANDEN[1:]:
        k = obj.shape_key_add(name=s.capitalize(), from_mix=False)
        Vs = vertices(s)
        for i, p in enumerate(Vs):
            k.data[i].co = tuple(p)
        k.value = 0.0
    me.shape_keys.use_relative = True
    vc.ALLE.extend([root, obj])
    return root, obj


root, obj = maak()
keys = obj.data.shape_keys
KB = {k.name: k for k in keys.key_blocks}


def clip_keys(naam, frames, f):
    """f(t)-> (gewichten per shape key, rot, loc). Nieuwe actie per clip op de shape keys en op de wortel."""
    for tgt in (keys, root):
        tgt.animation_data_create()
        a = bpy.data.actions.new(f"{naam}_{tgt.name if hasattr(tgt, 'name') else 'k'}")
        tgt.animation_data.action = a
    for fr in range(frames + 1):
        t = fr / vc.FPS
        w, rot, loc = f(t)
        for nm, k in KB.items():
            if nm == "Open":
                continue
            k.value = float(w.get(nm, 0.0))
            k.keyframe_insert("value", frame=fr)
        root.rotation_euler = rot
        root.keyframe_insert("rotation_euler", frame=fr)
        root.location = loc
        root.keyframe_insert("location", frame=fr)
    for tgt in (keys, root):
        a = tgt.animation_data.action
        fcs = []
        for layer in getattr(a, "layers", []):
            for strip in layer.strips:
                for bag in strip.channelbags:
                    fcs.extend(bag.fcurves)
        fcs.extend(getattr(a, "fcurves", []))
        for fc in fcs:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        tr = tgt.animation_data.nla_tracks.new()
        tr.name = naam
        st = tr.strips.new(naam, 0, a)
        st.name = naam
        tgt.animation_data.action = None


def hold(x):
    return x * x * (3 - 2 * x)


def openen(t):
    T = 0.8
    u = min(t / T, 1.0)
    if u < 0.55:                       # koepel stroomt omhoog en vult zich
        a = hold(u / 0.55)
        w = {"Gesloten": 1 - a, "Blazen": 0.0}
        w["Open"] = a
    elif u < 0.8:                      # openingsschok: bol en breder
        a = hold((u - 0.55) / 0.25)
        w = {"Gesloten": 0.0, "Blazen": a * 0.9}
    else:                              # zakt terug naar de gewone vorm
        a = hold((u - 0.8) / 0.2)
        w = {"Gesloten": 0.0, "Blazen": 0.9 * (1 - a)}
    # de soldaat krijgt een ruk omhoog: de wortel zwiept even naar achteren en terug
    rot = (-0.22 * math.sin(math.pi * min(u * 1.3, 1.0)) * (1 - 0.0), 0.0, 0.06 * math.sin(math.tau * u))
    return {k: v for k, v in w.items() if k != "Open"}, rot, (0, 0, 0)


def zweven(t):
    ph = math.tau * t / 3.0
    w = {"Slinger_l": max(0.0, math.sin(ph)) * 0.8, "Slinger_r": max(0.0, -math.sin(ph)) * 0.8, "Duik": 0.3 + 0.3 * math.sin(2 * ph + 1.0), "Blazen": 0.12 + 0.08 * math.sin(2 * ph)}
    rot = (0.05 * math.sin(2 * ph + 0.6), 0.0, 0.07 * math.sin(ph))
    return w, rot, (0, 0, 0)


def inzakken(t):
    T = 1.2
    u = min(t / T, 1.0)
    a = hold(u)
    w = {"Inzakken": a, "Duik": 0.5 * math.sin(math.pi * u)}
    rot = (-0.28 * math.sin(math.pi * u), 0.0, 0.05 * math.sin(math.tau * u))
    return w, rot, (0, 0, 0)


clip_keys("Openen", 24, openen)
clip_keys("Zweven-loop", 90, zweven)
clip_keys("Inzakken", 36, inzakken)
for k in KB.values():
    if k.name != "Open":
        k.value = 0.0
root.rotation_euler = (0, 0, 0)
root.location = (0, 0, 0)

bpy.ops.object.select_all(action="DESELECT")
for o in vc.ALLE:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "parachute.glb"), export_format="GLB", export_apply=False, export_yup=True, use_selection=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_range=False,
                          export_morph=True, export_image_format="JPEG", export_jpeg_quality=90, export_lights=False, export_cameras=False)
print("PARACHUTE driehoeken", sum(len(p.vertices) - 2 for p in obj.data.polygons), "materialen", len(bpy.data.materials), "tex", TEX)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "parachute.blend"))

if "--usdz" in ARGS:   # iPhone Bestanden/Quick Look: de drie clips achter elkaar (shape-key-animatie als blend shapes)
    volgorde = [("Openen", 24), ("Zweven-loop", 90), ("Inzakken", 36)]
    start = 0
    for naam, lengte in volgorde:
        for tgt in (keys, root):
            ad = tgt.animation_data
            if ad:
                for tr in ad.nla_tracks:
                    if tr.name == naam:
                        for st in tr.strips:
                            st.frame_end += start - st.frame_start
                            st.frame_start = start
                            st.frame_end = start + lengte
        start += lengte + 10
    scene.frame_start, scene.frame_end = 0, start - 10
    bpy.ops.wm.usd_export(filepath=os.path.join(OUT, "parachute.usdz"), selected_objects_only=False, export_animation=True, export_materials=True,
                          generate_preview_surface=True, export_textures_mode="NEW", overwrite_textures=True, evaluation_mode="RENDER")
    print("PARACHUTE USDZ geschreven")
