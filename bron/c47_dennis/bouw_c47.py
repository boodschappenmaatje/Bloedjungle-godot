"""C-47 Skytrain van Dennis (eigen scan-model) -> animeerbaar spelmodel voor Bloedjungle (kracht Parachutisten, E2).

Bron: Dennis' GLB (één mesh, 277.780 driehoeken, 3 x 4K-texturen, geen onderdelen, geen animaties). Dit script (1) verdeelt de mesh in
bewegende onderdelen (segment.py): twee propellers, de laaddeur (bakboord, scharnier op de achterrand), het richtingsroer en het hoogteroer,
(2) maakt een spelversie (decimeren + nieuwe UV's + bakken van kleur, normalen, ruwheid en metaal van het origineel op 2K-atlassen),
(3) bouwt de laadruimte achter de deur, springlichten en propellerschijven, (4) maakt de clips en (5) exporteert GLB (+ .blend, optioneel .usdz).

Gebruik:  python3 bouw_c47.py <bron.glb> <uitmap> [--tris 60000] [--tex 2048] [--usdz] [--nobake]
Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = midden van de romp, voorkant = +Y (in Godot -Z), bakboord (deur) = -X.
Knopen: C47 > Body (mesh) > PropL/PropR (draaien om Y; PropSchijf), RoerAs > Roer, ElevAs > Elev, Deur (scharnier) > DeurPaneel, Laadruimte, LampGroen/LampRood.
Clips: Stationair-loop (3 s), Vliegen-loop (2 s), Bocht (3 s), Droppen (2 s: deur gaat open, licht groen), Open-loop (2 s: deur blijft open),
Sluiten (1,5 s: deur dicht, licht rood)."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import numpy as np
import bpy, bmesh
from mathutils import Matrix, Vector
import segment as sg
import vlieg_common as vc

ARGS = sys.argv[1:]
POS = [a for a in ARGS if not a.startswith("--")]
BRON, OUT = os.path.abspath(POS[0]), os.path.abspath(POS[1])


def opt(naam, std):
    return int(ARGS[ARGS.index(naam) + 1]) if naam in ARGS else std


BUDGET = opt("--tris", 60000)
TEX = opt("--tex", 2048)
NOBAKE = "--nobake" in ARGS
scene = vc.init(OUT, TEX)
S = sg.SCHAAL

# ============================================================ bron lezen en verdelen
P, UV, I, kleur_jpg, mr_jpg, normaal_jpg = sg.lees_glb(BRON)
LAB = sg.labels(P, I)
B = sg.bouw_b(P)
os.makedirs(os.path.join(OUT, "bron_tex"), exist_ok=True)
for naam, data in (("albedo", kleur_jpg), ("mr", mr_jpg), ("normaal", normaal_jpg)):
    open(os.path.join(OUT, "bron_tex", naam + ".jpg"), "wb").write(data)
print("driehoeken per deel:", {n: int((LAB == k).sum()) for k, n in enumerate(sg.DELEN)})


def laad(pad, kleurruimte):
    im = bpy.data.images.load(pad)
    im.colorspace_settings.name = kleurruimte
    return im


def hi_materiaal():
    m = bpy.data.materials.new("HI")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    a = nt.nodes.new("ShaderNodeTexImage")
    a.image = laad(os.path.join(OUT, "bron_tex", "albedo.jpg"), "sRGB")
    nt.links.new(a.outputs["Color"], p.inputs["Base Color"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = laad(os.path.join(OUT, "bron_tex", "normaal.jpg"), "Non-Color")
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    r = nt.nodes.new("ShaderNodeTexImage")
    r.image = laad(os.path.join(OUT, "bron_tex", "mr.jpg"), "Non-Color")
    sp = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(r.outputs["Color"], sp.inputs["Color"])
    nt.links.new(sp.outputs["Green"], p.inputs["Roughness"])
    nt.links.new(sp.outputs["Blue"], p.inputs["Metallic"])
    # metaal ook als emissie, zodat het apart gebakken kan worden
    nt.links.new(sp.outputs["Blue"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 1.0
    return m


def mesh_uit(naam, V, UVs, T, mat):
    used = np.unique(T)
    remap = np.full(len(V), -1, np.int64)
    remap[used] = np.arange(len(used))
    t = remap[T]
    me = bpy.data.meshes.new(naam)
    me.from_pydata(V[used].tolist(), [], t.tolist())
    uvl = me.uv_layers.new(name="UVMap")
    uv = UVs[T.ravel()]
    uvl.data.foreach_set("uv", np.stack([uv[:, 0], 1.0 - uv[:, 1]], axis=1).ravel().astype(np.float32))
    me.materials.append(mat)
    if hasattr(me, "shade_smooth"):
        me.shade_smooth()
    return me


HI = bpy.data.collections.new("HI")
scene.collection.children.link(HI)
mat_hi = hi_materiaal()
hi_obj = {}
for k, n in enumerate(sg.DELEN):
    T = I[LAB == k]
    if len(T) == 0:
        continue
    o = bpy.data.objects.new("HI_" + n, mesh_uit("HI_" + n, B, UV, T, mat_hi))
    HI.objects.link(o)
    hi_obj[n] = o

# ============================================================ lage versie: decimeren, UV's, bakken
BUDGET_DEEL = {"Body": 0.80, "PropL": 0.04, "PropR": 0.03, "Deur": 0.03, "Roer": 0.05, "Elev": 0.04}
lo_data = {}
for n, o in hi_obj.items():
    tris = len(o.data.polygons)
    doel = max(300, int(BUDGET * BUDGET_DEEL[n]))
    md = o.modifiers.new("d", "DECIMATE")
    md.ratio = min(1.0, doel / tris)
    md.use_collapse_triangulate = True
    ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = bpy.data.meshes.new_from_object(ev)
    o.modifiers.remove(md)
    lo_data[n] = me
    print("deel", n, tris, "->", len(me.polygons))

alle_v, alle_f, part_id, off = [], [], [], 0
for k, n in enumerate(sg.DELEN):
    if n not in lo_data:
        continue
    me = lo_data[n]
    v = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", v)
    f = np.zeros(len(me.loops))
    me.loops.foreach_get("vertex_index", f)
    f = f.astype(np.int64).reshape(-1, 3)
    alle_v.append(v.reshape(-1, 3))
    alle_f.append(f + off)
    part_id.append(np.full(len(f), k))
    off += len(v) // 3
LV = np.concatenate(alle_v)
LF = np.concatenate(alle_f)
LP = np.concatenate(part_id)
lo_me = bpy.data.meshes.new("LO")
lo_me.from_pydata(LV.tolist(), [], LF.tolist())
lo_me.shade_smooth() if hasattr(lo_me, "shade_smooth") else None
lo_obj = bpy.data.objects.new("LO", lo_me)
scene.collection.objects.link(lo_obj)
print("lage versie totaal", len(LF), "driehoeken")

bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = lo_obj
lo_obj.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
bpy.ops.uv.pack_islands(margin=0.002)
bpy.ops.object.mode_set(mode="OBJECT")

img_a = bpy.data.images.new("c47_albedo", TEX, TEX)
img_n = bpy.data.images.new("c47_normaal", TEX, TEX)
img_n.colorspace_settings.name = "Non-Color"
img_r = bpy.data.images.new("c47_ruw", TEX, TEX)
img_r.colorspace_settings.name = "Non-Color"
img_m = bpy.data.images.new("c47_metaal", TEX, TEX)
img_m.colorspace_settings.name = "Non-Color"
mat_lo = bpy.data.materials.new("C47")
mat_lo.use_nodes = True
nt = mat_lo.node_tree
pr = nt.nodes["Principled BSDF"]
ta = nt.nodes.new("ShaderNodeTexImage")
ta.image = img_a
nt.links.new(ta.outputs["Color"], pr.inputs["Base Color"])
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = img_n
nmn = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tn.outputs["Color"], nmn.inputs["Color"])
nt.links.new(nmn.outputs["Normal"], pr.inputs["Normal"])
tr_ = nt.nodes.new("ShaderNodeTexImage")
tr_.image = img_r
tm = nt.nodes.new("ShaderNodeTexImage")
tm.image = img_m
nt.links.new(tr_.outputs["Color"], pr.inputs["Roughness"])
nt.links.new(tm.outputs["Color"], pr.inputs["Metallic"])
lo_me.materials.append(mat_lo)

if not NOBAKE:
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 6
    scene.cycles.use_denoising = False
    bpy.ops.object.select_all(action="DESELECT")
    for o in hi_obj.values():
        o.select_set(True)
    lo_obj.select_set(True)
    bpy.context.view_layer.objects.active = lo_obj
    for node, naam, soort in ((ta, "albedo", "DIFFUSE"), (tn, "normaal", "NORMAL"), (tr_, "ruw", "ROUGHNESS"), (tm, "metaal", "EMIT")):
        nt.nodes.active = node
        kw = dict(type=soort, margin=12, use_selected_to_active=True, cage_extrusion=0.10, max_ray_distance=0.30, use_clear=True)
        if soort == "DIFFUSE":
            kw["pass_filter"] = {"COLOR"}
        elif soort == "NORMAL":
            kw["normal_space"] = "TANGENT"
        bpy.ops.object.bake(**kw)
        print("gebakken:", naam)
    # ORM (R = occlusie 1, G = ruwheid, B = metaal) in één afbeelding, zoals de rest van het spel
    def px(im):
        a = np.zeros(TEX * TEX * 4, np.float32)
        im.pixels.foreach_get(a)
        return a.reshape(-1, 4)
    ruw = px(img_r)[:, 0]
    met = px(img_m)[:, 0]
    orm = np.stack([np.ones_like(ruw), ruw, np.clip(met, 0, 1), np.ones_like(ruw)], axis=1)
    img_o = bpy.data.images.new("c47_orm", TEX, TEX)
    img_o.colorspace_settings.name = "Non-Color"
    img_o.pixels.foreach_set(orm.ravel())
    for im, nm_ in ((img_a, "c47_albedo"), (img_n, "c47_normaal"), (img_o, "c47_orm")):
        im.filepath_raw = os.path.join(OUT, nm_ + ".png")
        im.file_format = "PNG"
        im.save()
        im.pack()
    nt.nodes.remove(tr_)
    nt.nodes.remove(tm)
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = img_o
    so = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(to.outputs["Color"], so.inputs["Color"])
    nt.links.new(so.outputs["Green"], pr.inputs["Roughness"])
    nt.links.new(so.outputs["Blue"], pr.inputs["Metallic"])
else:
    pr.inputs["Roughness"].default_value = 0.5

lo_me.calc_loop_triangles()
uv_l = lo_me.uv_layers[0]
uv_arr = np.zeros(len(lo_me.loops) * 2)
uv_l.data.foreach_get("uv", uv_arr)
uv_arr = uv_arr.reshape(-1, 2)
fl = np.zeros(len(lo_me.loops))
lo_me.loops.foreach_get("vertex_index", fl)
LF2 = fl.astype(np.int64).reshape(-1, 3)
lv = np.zeros(len(lo_me.vertices) * 3)
lo_me.vertices.foreach_get("co", lv)
LV2 = lv.reshape(-1, 3)

# ============================================================ onderdelen met scharnierpunten
vc.ALLE.clear()


def deel_mesh(naam, k, pivot_b):
    sel = LP == k
    T = LF2[sel]
    used = np.unique(T)
    remap = np.full(len(LV2), -1, np.int64)
    remap[used] = np.arange(len(used))
    v = LV2[used] - np.asarray(pivot_b)
    me = bpy.data.meshes.new(naam)
    me.from_pydata(v.tolist(), [], remap[T].tolist())
    uvl = me.uv_layers.new(name="UVMap")
    corner = np.where(np.repeat(sel, 3))[0]
    uvl.data.foreach_set("uv", uv_arr[corner].ravel().astype(np.float32))
    me.materials.append(mat_lo)
    if hasattr(me, "shade_smooth"):
        me.shade_smooth()
    return me


def maak(naam, me, parent, loc):
    o = bpy.data.objects.new(naam, me)
    o.location = loc
    return vc.link(o, parent)


root = vc.leeg("C47")
body = maak("Body", deel_mesh("Body", 0, (0, 0, 0)), root, (0, 0, 0))

# propellers: draaien om de eigen as (Y); de schijf is de bewegingsonscherpte bij vollast
SCHIJF_M = vc.pbr("PropSchijf", None, (0.08, 0.08, 0.08), 0.8, 0.0, alpha=0.10)
SCHIJF_M.use_backface_culling = False
PROPS = {}
for k, tag, nm in ((1, "L", "PropL"), (2, "R", "PropR")):
    h = sg.p2b(sg.NAAF[tag])
    V = LV2[np.unique(LF2[LP == k])]
    cx = float(np.median(V[:, 0] if False else V[:, 0]))
    naaf = np.array([h[0], float(V[:, 1].mean()), h[2]])    # draaipunt: as door de naaf, in het vlak van de bladen
    pr_ = vc.leeg(nm, body, tuple(naaf))
    maak(nm + "Mesh", deel_mesh(nm + "Mesh", k, naaf), pr_, (0, 0, 0))
    rad = float(np.hypot(V[:, 0] - h[0], V[:, 2] - h[2]).max()) * 0.97
    bm = bmesh.new()
    n = 64
    for i in range(n):
        a0, a1 = i / n * math.tau, (i + 1) / n * math.tau
        vs = [bm.verts.new((math.sin(a) * r, 0, math.cos(a) * r)) for a, r in ((a0, rad), (a1, rad), (a1, rad * 0.2), (a0, rad * 0.2))]
        bm.faces.new(vs)
    disc = vc.mesh_obj(nm + "Schijf", bm, SCHIJF_M, None, pr_, (0, 0.02, 0), smooth=False)
    PROPS[tag] = (pr_, disc)
    print(nm, "straal", rad, "naaf", naaf)

# richtingsroer: scharnier verticaal op x = 0,554 (bron), hoogteroer: scharnier langs de spanwijdte op x = 0,592
RP = sg.p2b((sg.ROER_X, 0.0, 0.0))
roer_as = vc.leeg("RoerAs", body, tuple(RP))
maak("Roer", deel_mesh("Roer", 4, RP), roer_as, (0, 0, 0))
EP = sg.p2b((sg.ELEV_X, -0.075, 0.0))
elev_as = vc.leeg("ElevAs", body, tuple(EP))
maak("Elev", deel_mesh("Elev", 5, EP), elev_as, (0, 0, 0))

# laaddeur (bakboord = -X): scharnier op de achterrand van het kozijn, draait om de verticale as naar buiten
DX0, DX1 = sg.DEUR["x"]
DY0, DY1 = sg.DEUR["y"]
HZ = 0.087       # romphuid in de bron (z)
HP = sg.p2b((DX1, (DY0 + DY1) / 2, HZ))
deur = vc.leeg("Deur", body, tuple(HP))
maak("DeurPaneel", deel_mesh("DeurPaneel", 3, HP), deur, (0, 0, 0))

# laadruimte achter de deur: vloer, plafond, voor-, achter- en binnenwand (donker, ruw), zodat het gat niet doorzichtig is
HOUT = vc.pbr("Laadruimte", None, (0.075, 0.075, 0.062), 0.85, 0.0)
HOUT.use_backface_culling = False
LICHT = vc.pbr("Laadlicht", None, (0.9, 0.85, 0.6), 0.6, 0.0, emit=(0.9, 0.85, 0.6), strength=0.6)
x0, y0, z0 = sg.p2b((DX1, DY0, HZ + 0.004))    # achter-onder-buiten
x1, y1, z1 = sg.p2b((DX0, DY1, 0.04))           # voor-boven-binnen
xa, xb = sorted((x0, x1))
ya, yb = sorted((y0, y1))
za, zb = sorted((z0, z1))
bm = bmesh.new()
for (lo_, hi_) in (((xa, ya, za), (xb, yb, za)), ((xa, ya, zb), (xb, yb, zb)), ((xa, ya, za), (xb, ya, zb)), ((xa, yb, za), (xb, yb, zb)), ((xb, ya, za), (xb, yb, zb))):
    vs = []
    for c in range(8):
        pass
    a = np.array(lo_)
    b = np.array(hi_)
    # vlak tussen twee tegenover elkaar liggende hoeken: constante as is waar a en b gelijk zijn
    ax = [i for i in range(3) if abs(a[i] - b[i]) < 1e-9][0]
    u, v = [i for i in range(3) if i != ax]
    pts = []
    for (pu, pv) in ((a[u], a[v]), (b[u], a[v]), (b[u], b[v]), (a[u], b[v])):
        q = [0, 0, 0]
        q[ax], q[u], q[v] = a[ax], pu, pv
        pts.append(bm.verts.new(q))
    bm.faces.new(pts)
vc.mesh_obj("Laadruimte", bm, HOUT, None, body, (0, 0, 0), smooth=False)
# banken langs de binnenwand en een plafondlamp
vc.doos("LaadBank1", (0.12, abs(yb - ya) * 0.85, 0.30), HOUT, body, (xb - 0.10, (ya + yb) / 2, za + 0.25))
vc.doos("LaadLamp", (0.16, 0.30, 0.04), LICHT, body, ((xa + xb) / 2, (ya + yb) / 2, zb - 0.03))
# springlichten naast de deur (voorkant van het kozijn)
GROEN = vc.pbr("Springlicht", None, (0.1, 1.0, 0.2), 0.4, 0.0, emit=(0.1, 1.0, 0.2), strength=3.0)
ROOD = vc.pbr("Springlicht rood", None, (1.0, 0.1, 0.05), 0.4, 0.0, emit=(1.0, 0.1, 0.05), strength=2.0)
lp = sg.p2b((DX0 - 0.012, DY1 + 0.012, HZ + 0.002))
lamp_g = vc.doos("LampGroen", (0.12, 0.12, 0.12), GROEN, body, (lp[0], lp[1], lp[2]))
lamp_r = vc.doos("LampRood", (0.12, 0.12, 0.12), ROOD, body, (lp[0], lp[1], lp[2] - 0.2))

# ============================================================ animaties
hoek, sin, smooth, bump = vc.hoek, vc.sin, vc.smooth, vc.bump
DEUR_OPEN = hoek(100)


def vliegen(t, periode, pitch=0.0, roll=0.0, yaw=0.0, pedaal=0.0, hoogte=0.0, rpm=8.0, gas=0.8, deur=0.0, licht=0.0):
    """rpm = omwentelingen per `periode` s (geheel getal: de lus sluit); deur 0..1 = dicht..open; licht 0 = rood, 1 = groen."""
    st = {root: {"rot": (pitch + sin(t, periode, hoek(0.4)), roll + sin(t, periode * 2, hoek(0.8)), yaw), "loc": (0, 0, sin(t, periode, 0.05))}}
    aan = smooth((gas - 0.30) / 0.30)
    for tag, (p_, d_) in PROPS.items():
        st[p_] = {"rot": (0, math.tau * rpm * t / periode * (1.0 if tag == "L" else 1.0), 0)}
        st[d_] = {"scale": (max(aan, 0.001),) * 3}
    st[roer_as] = {"rot": (0, 0, -pedaal + sin(t, periode * 2, hoek(0.6)))}
    st[elev_as] = {"rot": (-hoogte + sin(t, periode, hoek(0.6), 0.3), 0, 0)}
    st[deur_o] = {"rot": (0, 0, DEUR_OPEN * deur)}
    g = max(licht, 0.001)
    st[lamp_g] = {"scale": (g, g, g)}
    r_ = max(1.0 - licht, 0.001)
    st[lamp_r] = {"scale": (r_, r_, r_)}
    return st


deur_o = deur


def piek(t, duur):
    return math.sin(math.pi * min(max(t / duur, 0.0), 1.0))


zet = vc.zet_actie
SPIL = [root, roer_as, elev_as, deur_o, lamp_g, lamp_r] + [p for p, _ in PROPS.values()] + [d for _, d in PROPS.values()]
for o in SPIL:
    o.rotation_mode = "XYZ"
zet("Stationair-loop", 90, lambda t: vliegen(t, 3.0, rpm=1, gas=0.10), SPIL)
zet("Vliegen-loop", 60, lambda t: vliegen(t, 2.0, rpm=8, gas=0.8), SPIL)
zet("Bocht", 90, lambda t: vliegen(t, 3.0, pitch=hoek(-1.5) * piek(t, 3.0), roll=hoek(24) * piek(t, 3.0) ** 0.8, pedaal=hoek(9) * piek(t, 3.0),
                                   hoogte=hoek(3) * piek(t, 3.0), rpm=12, gas=0.85), SPIL)
zet("Droppen", 60, lambda t: vliegen(t, 2.0, rpm=8, gas=0.8, deur=smooth((t - 0.25) / 1.3), licht=1.0 if t > 0.6 else 0.0), SPIL)
zet("Open-loop", 60, lambda t: vliegen(t, 2.0, rpm=8, gas=0.8, deur=1.0, licht=1.0), SPIL)
zet("Sluiten", 45, lambda t: vliegen(t, 2.0, rpm=8, gas=0.8, deur=1.0 - smooth((t - 0.1) / 1.2), licht=1.0 if t < 0.2 else 0.0), SPIL)
for o in SPIL:
    o.rotation_euler = (0, 0, 0)
    o.scale = (1, 1, 1)
    if o in (root,):
        o.location = (0, 0, 0)
_r = vliegen(0.0, 2.0)
for o in (lamp_g, lamp_r) + tuple(d for _, d in PROPS.values()):
    o.scale = _r[o]["scale"]
scene.frame_start, scene.frame_end = 0, 90

# ============================================================ export
for o in list(HI.objects) + [lo_obj]:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in vc.ALLE:
    if o.name in bpy.data.objects:
        o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "c47.glb"), export_format="GLB", export_apply=False, export_yup=True,
                          use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_frame_range=False, export_image_format="JPEG", export_jpeg_quality=90, export_lights=False, export_cameras=False)
tris = sum((len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"))
print("C47 driehoeken", tris, "materialen", len(bpy.data.materials), "tex", TEX)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "c47.blend"))

if "--usdz" in ARGS:
    volgorde = [("Stationair-loop", 90), ("Vliegen-loop", 60), ("Bocht", 90), ("Droppen", 60), ("Open-loop", 60), ("Sluiten", 45)]
    start = 0
    for naam, lengte in volgorde:
        for o in bpy.data.objects:
            ad = o.animation_data
            if ad:
                for tr in ad.nla_tracks:
                    if tr.name == naam:
                        tr.strips[0].frame_start_ui = start
        start += lengte + 10
    scene.frame_start, scene.frame_end = 0, start - 10
    bpy.ops.wm.usd_export(filepath=os.path.join(OUT, "c47.usdz"), selected_objects_only=False, export_animation=True, export_materials=True,
                          generate_preview_surface=True, export_textures_mode="NEW", overwrite_textures=True, evaluation_mode="RENDER")
    print("C47 USDZ geschreven")
