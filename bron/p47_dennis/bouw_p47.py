"""P-47D Thunderbolt van Dennis (eigen scan-model) -> animeerbaar spelmodel voor Bloedjungle (kracht Luchtaanval, E2).

Bron: Dennis' GLB "Republic P-47 Thunderbolt.glb" (één mesh, 501.646 driehoeken, geen onderdelen, geen animaties; 3 x 2K-texturen).
Dit script (1) verdeelt de mesh in bewegende onderdelen (segment.py), (2) maakt er een lichte spelversie van (decimeren + nieuwe UV's +
bakken van kleur en normalen van het origineel op één 2K-atlas), (3) bouwt de scharnierpunten, bommen, raketten, mondingsknopen en
propellerschijf, (4) maakt de clips en (5) exporteert GLB (+ .blend, optioneel .usdz).

Gebruik:  python3 bouw_p47.py <bron.glb> <uitmap> [--tris 45000] [--tex 2048] [--usdz] [--nobake]
Blender: Z omhoog, 1 eenheid = 1 meter, oorsprong = zwaartepunt, voorkant = +Y (in Godot -Z). Spanwijdte 12,44 m, lengte ca. 11 m.

Knopen in de GLB (P47 = wortel): Body (mesh; clips kantelen/rollen dit) met kinderen Propeller (draait om Y: Spinner, PropBladen, PropSchijf),
RoerAs > Roer, ElevatorR/L (gescharnierd), AileronAsR/L > AileronR/L, GearR/L (poot+wiel), GearStaart, Bom1/Bom2, Raket1..4,
Monding1..6 (lege knopen op de loopmondingen voor mondingsflitsen).
Clips: Stationair-loop (3 s), Vliegen-loop (2 s), Bocht (3 s), Aanval (3 s), Rol (2 s), Landingsgestel (2,4 s)."""
import io, math, os, sys
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


BUDGET = opt("--tris", 45000)
TEX = opt("--tex", 2048)
NOBAKE = "--nobake" in ARGS
scene = vc.init(OUT, TEX)
S = sg.SCHAAL

# ============================================================ bron lezen en verdelen
P, UV, I, kleur_jpg, normaal_jpg = sg.lees_glb(BRON)
Q = sg.naar_q(P)
LAB = sg.labels(Q, I)
B = sg.bouw_b(Q)
os.makedirs(os.path.join(OUT, "bron_tex"), exist_ok=True)
open(os.path.join(OUT, "bron_tex", "albedo.jpg"), "wb").write(kleur_jpg)
open(os.path.join(OUT, "bron_tex", "normaal.jpg"), "wb").write(normaal_jpg)
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
    p.inputs["Roughness"].default_value = 0.45
    p.inputs["Metallic"].default_value = 0.0
    return m


def mesh_uit(naam, V, UVs, T, mat, uvnaam="UVMap"):
    """Mesh uit globale arrays: neemt alleen de gebruikte hoekpunten mee."""
    used = np.unique(T)
    remap = np.full(len(V), -1, np.int64)
    remap[used] = np.arange(len(used))
    t = remap[T]
    me = bpy.data.meshes.new(naam)
    me.from_pydata(V[used].tolist(), [], t.tolist())
    uvl = me.uv_layers.new(name=uvnaam)
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
dg = bpy.context.evaluated_depsgraph_get()
BUDGET_DEEL = {"Body": 0.80, "Propeller": 0.035, "Spinner": 0.015, "Roer": 0.010, "ElevatorR": 0.010, "ElevatorL": 0.010, "AileronR": 0.014,
               "AileronL": 0.014, "GearR": 0.035, "GearL": 0.035, "GearStaart": 0.010}
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

# alles in één lage mesh (voor één gedeelde UV-atlas); per vlak onthouden we het deel
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
bpy.ops.uv.smart_project(angle_limit=math.radians(70), island_margin=0.004)
bpy.ops.uv.pack_islands(margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")

img_a = bpy.data.images.new("p47_albedo", TEX, TEX)
img_n = bpy.data.images.new("p47_normaal", TEX, TEX)
img_n.colorspace_settings.name = "Non-Color"
mat_lo = bpy.data.materials.new("P47")
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
pr.inputs["Roughness"].default_value = 0.45
pr.inputs["Metallic"].default_value = 0.0
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
    for node, naam, soort in ((ta, "albedo", "DIFFUSE"), (tn, "normaal", "NORMAL")):
        nt.nodes.active = node
        kw = dict(type=soort, margin=12, use_selected_to_active=True, cage_extrusion=0.06, max_ray_distance=0.25, use_clear=True)
        if soort == "DIFFUSE":
            kw["pass_filter"] = {"COLOR"}
        else:
            kw["normal_space"] = "TANGENT"
        bpy.ops.object.bake(**kw)
        print("gebakken:", naam)
    img_a.filepath_raw = os.path.join(OUT, "p47_albedo.png")
    img_a.file_format = "PNG"
    img_a.save()
    img_n.filepath_raw = os.path.join(OUT, "p47_normaal.png")
    img_n.file_format = "PNG"
    img_n.save()
    img_a.pack()
    img_n.pack()
else:
    ta.image = hi_materiaal().node_tree.nodes["Image Texture"].image   # alleen om de scène te testen

# lage mesh terug splitsen in onderdelen (UV's behouden)
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


def q2b(q):
    return sg.SCHAAL * np.array([-q[2], -(q[0] - sg.CG_Q[0]), q[1] - sg.CG_Q[1]]) + np.array([0, 0, 0])


def deel_mesh(naam, k, pivot_b, rot_z=0.0):
    """Mesh van deel k met oorsprong op pivot_b (Blender-meters) en optioneel een rustrotatie rond Z (voor schuine scharnierlijnen)."""
    sel = LP == k
    T = LF2[sel]
    used = np.unique(T)
    remap = np.full(len(LV2), -1, np.int64)
    remap[used] = np.arange(len(used))
    v = LV2[used] - np.asarray(pivot_b)
    if rot_z:
        c, s = math.cos(-rot_z), math.sin(-rot_z)
        v = v @ np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]]).T
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


root = vc.leeg("P47")
body_me = deel_mesh("Body", 0, (0, 0, 0))
body = maak("Body", body_me, root, (0, 0, 0))

# propeller
HUB = q2b((0, 0, 0))
prop = vc.leeg("Propeller", body, HUB)
maak("Spinner", deel_mesh("Spinner", 2, HUB), prop, (0, 0, 0))
bladen = maak("PropBladen", deel_mesh("PropBladen", 1, HUB), prop, (0, 0, 0))
# straal van de propeller en propellerschijf (bewegingsonscherpte bij vollast)
bq = Q[np.unique(I[LAB == 1])]
RPROP = float(np.hypot(bq[:, 1], bq[:, 2]).max()) * S
schijf = vc.leeg("PropSchijf", prop)
sm = vc.pbr("PropSchijf", None, (0.08, 0.08, 0.08), 0.8, 0.0, alpha=0.12)
st = vc.pbr("PropSchijfTip", None, (0.85, 0.65, 0.05), 0.8, 0.0, alpha=0.22)
bm = bmesh.new()
n = 64
for i in range(n):
    a0, a1 = i / n * math.tau, (i + 1) / n * math.tau
    vs = [bm.verts.new((math.sin(a) * r, 0, math.cos(a) * r)) for a, r in ((a0, RPROP), (a1, RPROP), (a1, RPROP * 0.18), (a0, RPROP * 0.18))]
    bm.faces.new(vs)
vc.mesh_obj("SchijfBinnen", bm, sm, None, schijf, smooth=False)
bm = bmesh.new()
for i in range(n):
    a0, a1 = i / n * math.tau, (i + 1) / n * math.tau
    vs = [bm.verts.new((math.sin(a) * r, 0, math.cos(a) * r)) for a, r in ((a0, RPROP), (a1, RPROP), (a1, RPROP * 0.93), (a0, RPROP * 0.93))]
    bm.faces.new(vs)
vc.mesh_obj("SchijfTip", bm, st, None, schijf, smooth=False)

# roer (scharnierlijn vrijwel verticaal bij x = 1,535)
RP = q2b((1.535, 0.05, 0))
roer = maak("Roer", deel_mesh("Roer", 3, RP), body, RP)

# elevators: as langs de spanwijdte (X)
ELEV = {}
for k, tag, zq in ((4, "R", -0.18), (5, "L", 0.18)):
    p = q2b((1.535, -0.065, zq))
    ELEV[tag] = maak("Elevator" + tag, deel_mesh("Elevator" + tag, k, p), body, p)

# rolroeren: schuine scharnierlijn; as-leeg met rustrotatie, aileron-mesh erin
AIL = {}
hoek_h = math.atan2(0.075, 0.33)
for k, tag, zq, phi in ((6, "R", -0.70, hoek_h), (7, "L", 0.70, -hoek_h)):
    hxq = 0.62 + (0.83 - abs(zq)) * (0.075 / 0.33)
    sel = LP == k
    yq = float(np.median(LV2[np.unique(LF2[sel])][:, 2]) / S + sg.CG_Q[1])   # Blender Z = qy*S
    p = q2b((hxq, yq, zq))
    asl = vc.leeg("AileronAs" + tag, body, p)
    asl.rotation_mode = "XYZ"
    asl.rotation_euler = (0, 0, phi)
    AIL[tag] = maak("Aileron" + tag, deel_mesh("Aileron" + tag, k, p, rot_z=phi), asl, (0, 0, 0))

# hoofdgestel: scharnier bovenaan de poot, intrekken naar binnen (rond Y)
GEAR = []
for k, tag, zq, zijde in ((8, "R", -0.36, 1), (9, "L", 0.36, -1)):
    p = q2b((0.43, -0.09, zq))
    g = maak("Gear" + tag, deel_mesh("Gear" + tag, k, p), body, p)
    g.rotation_mode = "XYZ"
    GEAR.append((g, (0, zijde * math.pi / 2, 0)))
pt = q2b((1.36, -0.15, 0))
gs = maak("GearStaart", deel_mesh("GearStaart", 10, pt), body, pt)
gs.rotation_mode = "XYZ"
GEAR.append((gs, (math.pi / 2, 0, 0)))

# mondingsknopen (3 per vleugel) op de looptips
for j, zq in enumerate((0.425, 0.46, 0.495)):
    for zijde, off in ((1, 0), (-1, 3)):
        vc.leeg(f"Monding{j + 1 + off}", body, q2b((0.305, -0.055, -zijde * zq)))

# bommen (2) en raketten (4) onder de vleugels: de scan heeft ze niet
OD = vc.pbr("BomOD", vc.lak_textures("p47_bom", [(0.30, 0.31, 0.22)], False, size=512, seed=41, vlek=0.12, roet_k=0.2))
STAAL = vc.pbr("BomStaal", vc.metaal_textures("p47_bomstaal", (0.30, 0.30, 0.29), size=256))
GEELT = vc.pbr("BomBand", None, (0.85, 0.65, 0.05), 0.5, 0.0)
RAK = vc.pbr("RaketGrijs", vc.lak_textures("p47_raket", [(0.55, 0.56, 0.50)], False, size=512, seed=42, vlek=0.1, roet_k=0.2))


def onderkant_y(xq, zq):
    m = (np.abs(Q[:, 0] - xq) < 0.03) & (np.abs(np.abs(Q[:, 2]) - abs(zq)) < 0.03) & (Q[:, 1] < 0.0)
    return float(Q[m][:, 1].min())


for nr, zq in ((1, -0.60), (2, 0.60)):    # Bom1 = rechts (+X)
    xq = 0.52
    yu = onderkant_y(xq, zq)
    pos = q2b((xq, yu, zq)) + np.array([0, 0, -0.30])
    vc.doos(f"BomPyloon{nr}", (0.14, 1.1, 0.30), STAAL, body, tuple(pos + np.array([0, 0, 0.22])))
    bom = vc.leeg(f"Bom{nr}", body, tuple(pos))
    vc.cyl(f"BomRomp{nr}", 0.20, 1.20, OD, bom, (0, 0.05, 0), "y", 18)
    vc.cyl(f"BomNeus{nr}", 0.20, 0.36, OD, bom, (0, 0.83, 0), "y", 18, 0.05)
    vc.cyl(f"BomStaart{nr}", 0.20, 0.72, OD, bom, (0, -0.91, 0), "y", 18, 0.08)
    vc.cyl(f"BomBand{nr}", 0.205, 0.08, GEELT, bom, (0, 0.40, 0), "y", 18)
    for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
        b = vc.doos(f"BomVin{nr}_{a:.1f}", (0.025, 0.46, 0.26), OD, bom, (math.sin(a) * 0.22, -1.18, math.cos(a) * 0.22))
        b.rotation_euler = (0, a, 0)
for nr, (zq, xq) in enumerate(((-0.74, 0.60), (-0.84, 0.56), (0.74, 0.60), (0.84, 0.56)), start=1):   # Raket1,2 rechts; 3,4 links
    yu = onderkant_y(xq, zq)
    pos = q2b((xq, yu, zq)) + np.array([0, 0, -0.14])
    vc.doos(f"RaketRail{nr}", (0.05, 1.3, 0.05), STAAL, body, tuple(pos + np.array([0, 0, 0.10])))
    rk = vc.leeg(f"Raket{nr}", body, tuple(pos))
    vc.cyl(f"RaketRomp{nr}", 0.062, 1.25, RAK, rk, (0, -0.05, 0), "y", 12)
    vc.cyl(f"RaketNeus{nr}", 0.062, 0.34, RAK, rk, (0, 0.82, 0), "y", 12, 0.014)
    vc.cyl(f"RaketBand{nr}", 0.065, 0.05, GEELT, rk, (0, 0.5, 0), "y", 12)
    for a in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
        b = vc.doos(f"RaketVin{nr}_{a:.1f}", (0.014, 0.24, 0.14), RAK, rk, (math.sin(a) * 0.09, -0.70, math.cos(a) * 0.09))
        b.rotation_euler = (0, a, 0)

# ============================================================ animaties
hoek, sin, smooth, bump = vc.hoek, vc.sin, vc.smooth, vc.bump
SPIL = [body, prop, bladen, schijf, roer] + list(ELEV.values()) + list(AIL.values())
for o in SPIL:
    o.rotation_mode = "XYZ"


def piek(t, duur):
    return math.sin(math.pi * min(max(t / duur, 0.0), 1.0))


def vliegen(t, periode, pitch=0.0, roll=0.0, yaw=0.0, dz=0.0, ail=0.0, pedaal=0.0, hoogte=0.0, rpm=8.0, gas=0.8):
    """rpm = propelleromwentelingen per `periode` s (geheel getal: de lus sluit); gas bepaalt wanneer de schijf de bladen vervangt."""
    stand = {body: {"rot": (pitch + sin(t, periode, hoek(0.5)), roll + sin(t, periode * 2, hoek(1.0)), yaw), "loc": (0, 0, dz + sin(t, periode, 0.05))}}
    stand[prop] = {"rot": (0, math.tau * rpm * t / periode, 0)}
    aan = smooth((gas - 0.30) / 0.30)
    stand[schijf] = {"scale": (max(aan, 0.001),) * 3}
    stand[bladen] = {"scale": (max(1.0 - aan, 0.001),) * 3}
    for tag, o in AIL.items():
        r = 1.0 if tag == "L" else -1.0       # rechts (+X) omhoog = rol naar rechts
        stand[o] = {"rot": (r * ail + sin(t, periode, hoek(0.8), 0.6 * r), 0, 0)}
    for tag, o in ELEV.items():
        stand[o] = {"rot": (-hoogte + sin(t, periode, hoek(0.8), 0.3), 0, 0)}
    stand[roer] = {"rot": (0, 0, -pedaal + sin(t, periode * 2, hoek(0.7)))}
    return stand


def gear_pose(t):
    stand = vliegen(t, 2.4, rpm=3, gas=0.25)
    u = smooth(t / 0.9) if t < 1.5 else 1.0 - smooth((t - 1.5) / 0.9)    # 0 = ingeklapt, 1 = uitgeklapt
    for g, rust in GEAR:
        stand[g] = {"rot": tuple(r * (1 - u) for r in rust)}
    return stand


zet = vc.zet_actie
zet("Stationair-loop", 90, lambda t: vliegen(t, 3.0, rpm=1, gas=0.10), SPIL)
zet("Vliegen-loop", 60, lambda t: vliegen(t, 2.0, rpm=24, gas=0.8), SPIL)
zet("Bocht", 90, lambda t: vliegen(t, 3.0, pitch=hoek(-2) * piek(t, 3.0), roll=hoek(32) * piek(t, 3.0) ** 0.8, ail=hoek(9) * piek(t, 3.0),
                                   pedaal=hoek(8) * piek(t, 3.0), hoogte=hoek(3) * piek(t, 3.0), rpm=24, gas=0.85), SPIL)
zet("Aanval", 90, lambda t: vliegen(t, 3.0, pitch=hoek(-9) * piek(t, 3.0), dz=-0.35 * piek(t, 3.0), hoogte=-hoek(3) * piek(t, 3.0), rpm=18, gas=0.95), SPIL)
zet("Rol", 60, lambda t: vliegen(t, 2.0, roll=math.tau * smooth(t / 2.0), ail=hoek(22) * piek(t, 2.0), rpm=24, gas=1.0), SPIL)
zet("Landingsgestel", 72, gear_pose, SPIL + [g for g, _ in GEAR])
for o in SPIL + [g for g, _ in GEAR]:
    o.rotation_euler = (0, 0, 0)
    o.scale = (1, 1, 1)
for tag, a in AIL.items():
    pass
body.location = (0, 0, 0)
for g, rust in GEAR:
    g.rotation_euler = rust
_r = vliegen(0.0, 2.0, rpm=24, gas=0.8)
schijf.scale = _r[schijf]["scale"]
bladen.scale = _r[bladen]["scale"]
scene.frame_start, scene.frame_end = 0, 90

# ============================================================ export
for o in list(HI.objects) + [lo_obj]:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in vc.ALLE:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "p47.glb"), export_format="GLB", export_apply=False, export_yup=True,
                          use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_frame_range=False, export_image_format="JPEG", export_jpeg_quality=90, export_lights=False, export_cameras=False)
tris = sum((len(o.data.polygons) for o in vc.ALLE if o.type == "MESH"))
print("P47 driehoeken", tris, "materialen", len(bpy.data.materials), "tex", TEX)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "p47.blend"))

if "--usdz" in ARGS:
    volgorde = [("Stationair-loop", 90), ("Vliegen-loop", 60), ("Rol", 60), ("Bocht", 90), ("Aanval", 90), ("Landingsgestel", 72)]
    start = 0
    for naam, lengte in volgorde:
        for o in vc.ALLE:
            ad = o.animation_data
            if ad:
                for tr in ad.nla_tracks:
                    if tr.name == naam:
                        tr.strips[0].frame_start_ui = start
                        tr.strips[0].extrapolation = "HOLD" if o in [g for g, _ in GEAR] else "NOTHING"
        start += lengte + 10
    scene.frame_start, scene.frame_end = 0, start - 10
    bpy.ops.wm.usd_export(filepath=os.path.join(OUT, "p47.usdz"), selected_objects_only=False, export_animation=True, export_materials=True,
                          generate_preview_surface=True, export_textures_mode="NEW", overwrite_textures=True, evaluation_mode="RENDER")
    print("P47 USDZ geschreven")
