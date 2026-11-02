"""Stap 4: hiërarchie met draaipunten, clips Laden en Lossen (dezelfde knopen en clipnamen als de vorige voorraadtruck), .blend en .glb.
Knopen (contract met scripts/voorraad_truck.gd): Voorraadtruck > [Romp, Wiel_FL..Wiel_RR, Lading, Kolom > [KolomMesh, Giek > [GiekMesh, GiekUit >
[GiekUitMesh, Telescoop, Kettingpunt > [Ketting, Grijper > [GrijperMesh, Kist_vast, Klauw_LV, Klauw_LA, Klauw_RV]]]]]].
Spelassen: x = breedte, voorkant = -Y in Blender (+Z in Godot), 1 eenheid = 1 m. Eindpose = beginpose van elke clip.
Gebruik: python3 stap4_export.py <cache-map> <uit-map> [textuurgrootte]"""
import sys, math, time, json
import numpy as np
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import delen as D

CACHE, UIT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
GAME_TEX = int(sys.argv[3]) if len(sys.argv) > 3 else 2048
UIT.mkdir(parents=True, exist_ok=True)
K = D.SCHAAL
FPS = 30
T_CLIP = 6.0                         # s, beide clips (LOAD_T / UNLOAD_T in voorraad_truck.gd)
NF = int(round(T_CLIP * FPS))
bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
bpy.ops.wm.open_mainfile(filepath=str(CACHE / "gebakken.blend"))
scene = bpy.context.scene
view = bpy.context.view_layer
scene.render.fps = FPS
for _o in bpy.data.objects:
    if _o.type == "MESH":
        _bad = _o.data.validate(verbose=False, clean_customdata=False)
        if _bad:
            print("mesh %s hersteld bij validatie" % _o.name)
for n in ("Truck_HQ",):
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n])



def externaliseer(map_, namen=None):
    """de gebakken beelden als JPEG naast de .blend (anders zit er 15 MB aan PNG in elke .blend); zonder weergavetransformatie"""
    map_ = Path(map_); map_.mkdir(parents=True, exist_ok=True)
    for im in list(bpy.data.images):
        if im.users == 0 or im.name.startswith("Image_") or im.type != "IMAGE":    # restanten van de bron-import en ongebruikte beelden
            bpy.data.images.remove(im)
            continue
        if im.size[0] < 8 or (namen and im.name not in namen):
            continue
        pad = map_ / (im.name + (".png" if im.name.startswith("Kist") else ".jpg"))
        im.filepath_raw = str(pad)
        im.file_format = "PNG" if pad.suffix == ".png" else "JPEG"
        im.save()
        if im.packed_file:
            im.unpack(method="REMOVE")
        im.filepath = str(pad)
        im.source = "FILE"
        im.reload()


def G(x_src, y_src, z_src):
    """bronmaat -> spelassen (Blender)"""
    return Vector((-y_src * K, x_src * K, (z_src - D.GROND) * K))


def leeg(naam, loc=(0, 0, 0)):
    e = bpy.data.objects.new(naam, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.2
    scene.collection.objects.link(e)
    e.location = Vector(loc)
    return e


def hang(ob, ouder):
    view.update()
    m = ob.matrix_world.copy()
    ob.parent = ouder
    ob.matrix_parent_inverse = ouder.matrix_world.inverted()
    ob.matrix_world = m


def zet_origin(ob, punt):
    d = Vector(punt) - ob.location
    ob.data.transform(Matrix.Translation(-d))
    ob.location = Vector(punt)


# ---------- punten (spelassen) ----------
P_ZWENK = G(D.ZWENK_AS[0], D.ZWENK_AS[1], 0.012)               # kraankolom draait hier om de verticale as
P_HINGE = G(D.GIEK_DRAAI[0], 0.0, D.GIEK_DRAAI[1])               # gieksscharnier (as langs x)
P_KP = G(D.KLAUW_ASPUNT[0], D.KLAUW_ASPUNT[1], 0.345)            # kettingpunt = bovenkant grijper, op de as van de klauwen
EXT_MAX = 2.5                                                    # m: maximale uitschuiving van GiekUit
HOEK = math.atan(0.27)                                           # helling van de giek in rust
DIR = Vector((0.0, math.cos(HOEK), math.sin(HOEK)))             # schuifrichting van de uitschuifgiek
P_ARMEN = {}
R0 = 0.04
for lbl, hoek in D.ARM_HOEK.items():
    naam = D.NAMEN[lbl]
    th = math.radians(hoek)
    p = G(D.KLAUW_ASPUNT[0] + R0 * math.cos(th), D.KLAUW_ASPUNT[1] + R0 * math.sin(th), D.KLAUW_SCHARNIER_Z)
    # scharnieras = raaklijn aan de cirkel (horizontaal, spelassen)
    as_ = Vector((-math.cos(th), -math.sin(th), 0.0))
    radiaal = Vector((-math.sin(th), math.cos(th), 0.0))         # naar buiten in spelassen: bronrichting (cos th, sin th) -> (-sin th, cos th)
    P_ARMEN[naam] = (p, as_, radiaal)

# ---------- doorsnede van de giek bij de snede (voor de telescoopbuis) ----------
_gu = bpy.data.objects["GiekUit"].data
_pts = np.array([v.co[:] for v in _gu.vertices])
_bij = _pts[np.abs(_pts[:, 1] - D.GIEK_SPLIT_X * K) < 0.12]
BW = float(_bij[:, 0].max() - _bij[:, 0].min())
BH = float(_bij[:, 2].max() - _bij[:, 2].min())
BC = (float((_bij[:, 0].max() + _bij[:, 0].min()) / 2), float((_bij[:, 2].max() + _bij[:, 2].min()) / 2))
print("giekdoorsnede bij de snede: b %.2f h %.2f, midden x %.2f z %.2f" % (BW, BH, BC[0], BC[1]), flush=True)

# ---------- hiërarchie ----------
for oud, nieuw in (("Kolom", "KolomMesh"), ("Giek", "GiekMesh"), ("GiekUit", "GiekUitMesh"), ("Grijper", "GrijperMesh")):
    bpy.data.objects[oud].name = nieuw
for o in bpy.data.objects:
    if o.type == "MESH":
        o.data.name = o.name
root = leeg("Voorraadtruck")
kolom = leeg("Kolom", P_ZWENK)
giek = leeg("Giek", P_HINGE)
uit = leeg("GiekUit", P_HINGE)
kp = leeg("Kettingpunt", P_KP)
grab = leeg("Grijper", P_KP)
view.update()
hang(kolom, root); hang(giek, kolom); hang(uit, giek); hang(kp, uit); hang(grab, kp)


def mesh_aan(naam, ouder, origin=None):
    ob = bpy.data.objects[naam]
    if origin is not None:
        zet_origin(ob, origin)
    hang(ob, ouder)
    return ob


romp = mesh_aan("Romp", root, (0, 0, 0))
lading_c = G(0.52, 0.0, -0.03)
lading = mesh_aan("Lading", root, lading_c)
mesh_aan("KolomMesh", kolom, P_ZWENK)
mesh_aan("GiekMesh", giek, P_HINGE)
mesh_aan("GiekUitMesh", uit, P_HINGE)
mesh_aan("GrijperMesh", grab, P_KP)
wielen = {}
for o in [o for o in bpy.data.objects if o.name.startswith("Wiel_")]:
    zet_origin(o, o["naaf"]); hang(o, root); wielen[o.name] = o
armen = {}
for naam, (p, as_, rad) in P_ARMEN.items():
    o = bpy.data.objects[naam]
    zet_origin(o, p); hang(o, grab)
    o.rotation_mode = "QUATERNION"
    armen[naam] = o

# ---------- onderdelen die er niet in het bronmodel zijn: telescoopbuis, ketting, kist ----------
mat_staal = bpy.data.materials.new("VR_Staal"); mat_staal.use_nodes = True
pb = mat_staal.node_tree.nodes["Principled BSDF"]
pb.inputs["Base Color"].default_value = (0.11, 0.12, 0.085, 1); pb.inputs["Metallic"].default_value = 0.35; pb.inputs["Roughness"].default_value = 0.6


def doos(bm, c, ab, uvb=None):
    """doos met middelpunt c en afmetingen ab; uvb = (u0, v0, u1, v1) voor alle zijden"""
    r = bmesh.ops.create_cube(bm, size=1.0)
    verts = r["verts"]
    bmesh.ops.scale(bm, vec=Vector(ab), verts=verts)
    bmesh.ops.translate(bm, vec=Vector(c), verts=verts)
    return verts


# telescoopbuis: binnenste tak die zichtbaar wordt in de opening tussen Giek en GiekUit als de giek uitschuift. Kind van Giek (staat vast), lengte
# schaalt mee met de uitschuiving: 0,5 m in de Giek, dan tot 0,4 m in GiekUit. Eigen as = +Y, oorsprong aan het achtereinde.
Y_SNEDE = D.GIEK_SPLIT_X * K
bm = bmesh.new()
verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
for v in verts:
    v.co.x *= BW * 0.74
    v.co.z *= BH * 0.70
    v.co.y = v.co.y + 0.5          # lengte 1 langs +Y, achtereinde op y = 0
me_t = bpy.data.meshes.new("Telescoop"); bm.to_mesh(me_t); bm.free()
me_t.materials.append(mat_staal)
tele = bpy.data.objects.new("Telescoop", me_t); scene.collection.objects.link(tele)
for pl in me_t.polygons:
    pl.use_smooth = False
tele.rotation_euler = (HOEK, 0, 0)
y0 = Y_SNEDE - 0.5
tele.location = Vector((BC[0], y0, BC[1] + (y0 - Y_SNEDE) * math.tan(HOEK)))
tele.scale = (1, 0.9, 1)
hang(tele, giek)
# ketting (cilinder langs -z, lengte 1 m, aan de oorsprong in het kettingpunt)
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=False, segments=6, radius1=0.03, radius2=0.03, depth=1.0)
for v in bm.verts:
    v.co.z -= 0.5
me_k = bpy.data.meshes.new("KettingMesh"); bm.to_mesh(me_k); bm.free()
ketting = bpy.data.objects.new("Ketting", me_k); scene.collection.objects.link(ketting)
me_k.materials.append(mat_staal)
ketting.location = P_KP
hang(ketting, kp)
for pl in me_k.polygons:
    pl.use_smooth = True

# kist in de klauwen (olijfgroen met gele band; eigen kleine textuur)
CB = (0.96, 1.3, 0.62)   # breed, lang, hoog (zelfde kist als de stapel en het depot)
H_KIST = 1.87            # hoogte van het middelpunt boven de grond in de rustpose: de kist hangt onder de klauwtoppen (bovenkant 0,15 m boven de toppen)
bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new("UVMap")
def kistdoos(bm, c, ab, uvb):
    r = bmesh.ops.create_cube(bm, size=1.0)
    verts = r["verts"]
    bmesh.ops.scale(bm, vec=Vector(ab), verts=verts)
    bmesh.ops.translate(bm, vec=Vector(c), verts=verts)
    for f in {f for v in verts for f in v.link_faces}:
        for lp, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            lp[uv_layer].uv = (uvb[0] + (uvb[2] - uvb[0]) * u, uvb[1] + (uvb[3] - uvb[1]) * v)
kistdoos(bm, (0, 0, 0), CB, (0.02, 0.02, 0.48, 0.98))                       # olijf
for yy in (-0.38, 0.38):
    kistdoos(bm, (0, yy, 0), (CB[0] + 0.02, 0.14, CB[2] + 0.02), (0.52, 0.02, 0.98, 0.98))   # gele band
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me_c = bpy.data.meshes.new("Kist_vast_mesh"); bm.to_mesh(me_c); bm.free()
kist_m = bpy.data.objects.new("Kist_vast_mesh", me_c); scene.collection.objects.link(kist_m)
# textuur 512x256: links olijf met slijtage, rechts geel
rng = np.random.default_rng(7)
W, H = 512, 256
img = np.zeros((H, W, 4), np.float32); img[:, :, 3] = 1
ruis = rng.normal(0, 0.035, (H, W))
img[:, :W // 2, 0] = 0.13 + ruis[:, :W // 2] * 0.6; img[:, :W // 2, 1] = 0.165 + ruis[:, :W // 2] * 0.7; img[:, :W // 2, 2] = 0.07 + ruis[:, :W // 2] * 0.4
img[:, W // 2:, 0] = 0.62 + ruis[:, W // 2:]; img[:, W // 2:, 1] = 0.46 + ruis[:, W // 2:]; img[:, W // 2:, 2] = 0.04 + ruis[:, W // 2:] * 0.3
for x0, x1 in ((0, W // 2), (W // 2, W)):                         # donkere rand per paneel
    img[:6, x0:x1, :3] *= 0.6; img[-6:, x0:x1, :3] *= 0.6; img[:, x0:x0 + 6, :3] *= 0.6; img[:, x1 - 6:x1, :3] *= 0.6
im = bpy.data.images.new("Kist_albedo", W, H, alpha=False); im.pixels.foreach_set(np.clip(img, 0, 1).ravel()); im.pack()
mat_kist = bpy.data.materials.new("VR_Kist"); mat_kist.use_nodes = True
pk = mat_kist.node_tree.nodes["Principled BSDF"]
tx = mat_kist.node_tree.nodes.new("ShaderNodeTexImage"); tx.image = im
mat_kist.node_tree.links.new(tx.outputs["Color"], pk.inputs["Base Color"]); pk.inputs["Roughness"].default_value = 0.75
me_c.materials.append(mat_kist)
_g = G(D.KLAUW_ASPUNT[0], D.KLAUW_ASPUNT[1], 0)
kist = leeg("Kist_vast", (_g.x, _g.y, H_KIST))
hang(kist, grab)
kist_m.location = kist.location
hang(kist_m, kist)
for pl in me_c.polygons:
    pl.use_smooth = False
view.update()

# ---------- clips ----------
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data_clear()
E = 0.001
REST = {}
for o in (kolom, giek, uit, kp, grab, ketting, tele, kist, lading, *armen.values()):
    REST[o.name] = (o.location.copy(), o.rotation_euler.copy(), o.scale.copy())
    o.rotation_mode = "XYZ" if o.name not in armen else "QUATERNION"


def sm(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def kromme(keys):
    """keys: [(beeld, waarde)] met gladde overgangen (smoothstep) tussen de sleutels"""
    def f(fr):
        if fr <= keys[0][0]:
            return keys[0][1]
        for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
            if f0 <= fr <= f1:
                return v0 if f1 == f0 else v0 + (v1 - v0) * sm((fr - f0) / (f1 - f0))
        return keys[-1][1]
    return f


def stel(yaw, elev, ext, L, claw, held, load):
    kolom.rotation_euler = (0, 0, yaw)
    giek.rotation_euler = (elev, 0, 0)
    uit.location = REST["GiekUit"][0] + DIR * ext
    kp.rotation_euler = (-elev, 0, 0)
    ketting.scale = (1, 1, max(L, E))
    tele.scale = (1, 0.9 + ext, 1)
    grab.location = REST["Grijper"][0] + Vector((0, 0, -L))
    for naam, o in armen.items():
        p, as_, rad = P_ARMEN[naam]
        # zó draaien dat de punt naar buiten opent: probeer teken
        o.rotation_quaternion = Quaternion(as_, SIGN[naam] * claw)
    kist.scale = (max(held, E),) * 3
    lading.scale = (max(load, E),) * 3


# teken van de klauwdraaiing: de punt (onderaan, buitenwaarts) moet bij een positieve hoek naar buiten gaan
SIGN = {}
HOEK_VAN = {D.NAMEN[l]: h for l, h in D.ARM_HOEK.items()}
for naam, (p, as_, rad) in P_ARMEN.items():
    tip = G(D.KLAUW_ASPUNT[0] + 0.2 * math.cos(math.radians(HOEK_VAN[naam])), D.KLAUW_ASPUNT[1] + 0.2 * math.sin(math.radians(HOEK_VAN[naam])), 0.10)
    r_before = math.hypot(tip.x - P_KP.x, tip.y - P_KP.y)
    SIGN[naam] = 1.0
    q = Quaternion(as_, 0.2)
    tip2 = p + q @ (tip - p)
    if math.hypot(tip2.x - P_KP.x, tip2.y - P_KP.y) < r_before:
        SIGN[naam] = -1.0
print("klauwtekens:", SIGN)

# ---- reikwijdte: waar staat de klauwas (m voor het midden van de truck, -y) bij een halve slag zwenken, hoek en uitschuiving
def klauw_pos(elev, ext, L=0.0):
    """geeft (yaw, positie): de zwenkhoek (rond pi) waarbij de klauwas precies op de lengteas van de truck uitkomt, en de wereldpositie"""
    rel = P_KP - P_HINGE
    v = Matrix.Rotation(elev, 3, "X") @ (rel + DIR * ext)
    p = P_HINGE + v
    dx, dy = p.x - P_ZWENK.x, p.y - P_ZWENK.y
    psi = PI + math.atan2(dx, dy)
    nx = dx * math.cos(psi) - dy * math.sin(psi)
    ny = dx * math.sin(psi) + dy * math.cos(psi)
    return psi, Vector((P_ZWENK.x + nx, P_ZWENK.y + ny, p.z - L))


PI = math.pi
ELEV_G = 0.14            # hoek van de giek bij het grijpen en neerzetten
EXT_G = EXT_MAX          # uitschuiving bij het grijpen
YAW_G, pg = klauw_pos(ELEV_G, EXT_G)
REACH = -pg.y
print("klauwas bij zwenk pi, hoek %.2f, uitschuiving %.2f: %.2f m voor het midden, z %.2f, dwars %.2f" % (ELEV_G, EXT_G, REACH, pg.z, pg.x), flush=True)
# kettinglengte: klauw boven de kist: nabij de grond. Kisthoogte op de stapel: kist + pallet ~0,9 m; klauwtoppen 0,86 m onder het kettingpunt
Z_GRIJP = 1.56           # kettingpunt (bovenkant grijper) boven de grond bij het grijpen van de afhaalkist (pallet + kist ~0,85 m hoog)
Z_PLAAT = 1.50           # idem bij het neerzetten op de laadplaat (0,17 m hoog + kist 0,62)
L_GRIJP = pg.z - Z_GRIJP
L_PLAAT = pg.z - Z_PLAAT
print("ketting L grijpen %.2f m, plaat %.2f m" % (L_GRIJP, L_PLAAT), flush=True)
OPEN, GRIJP = 0.80, 0.20


def clip(naam, ch):
    """ch: kanalen yaw, elev, ext, L, claw, held, load als [(beeld, waarde)]; één sleutel per beeld; NLA-spoor met de clipnaam"""
    fun = {k: kromme(v) for k, v in ch.items()}
    objs = (kolom, giek, uit, kp, grab, ketting, tele, kist, lading, *armen.values())
    for o in objs:
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new("%s_%s" % (naam, o.name))
    for fr in range(NF + 1):
        stel(*(fun[k](fr) for k in ("yaw", "elev", "ext", "L", "claw", "held", "load")))
        for o in objs:
            if o.name in armen:
                o.keyframe_insert("rotation_quaternion", frame=fr)
            elif o in (kolom, giek, kp):
                o.keyframe_insert("rotation_euler", frame=fr)
            elif o is uit or o is grab:
                o.keyframe_insert("location", frame=fr)
            else:
                o.keyframe_insert("scale", frame=fr)
    for o in objs:
        act = o.animation_data.action
        o.animation_data.action = None
        tr = o.animation_data.nla_tracks.new(); tr.name = naam
        tr.strips.new(act.name, 0, act)


# Laden (6,0 s = 180 beelden): zwenk naar voren en uitschuiven, klauwen open, zakken, grijpen (beeld 90 = LOAD_TAKE 0,5: kist in de klauwen),
# omhoog, terugzwenken, kist in de bak (Lading verschijnt), klauwen open en dicht
clip("Laden", dict(
    yaw=[(0, 0.0), (45, YAW_G), (110, YAW_G), (150, 0.0), (180, 0.0)],
    elev=[(0, 0.0), (30, 0.14), (105, ELEV_G), (125, 0.18), (160, 0.0), (180, 0.0)],
    ext=[(0, 0.0), (40, EXT_G), (110, EXT_G), (155, 0.0), (180, 0.0)],
    L=[(0, 0.0), (45, 0.0), (75, L_GRIJP), (92, L_GRIJP), (115, 0.0), (180, 0.0)],
    claw=[(0, 0.0), (35, OPEN), (78, OPEN), (90, GRIJP), (160, GRIJP), (168, OPEN), (178, 0.0), (180, 0.0)],
    held=[(0, E), (89, E), (90, 1.0), (165, 1.0), (166, E), (180, E)],
    load=[(0, E), (165, E), (166, 1.0), (180, 1.0)]))
# Lossen (6,0 s): kist uit de bak (Lading weg), zwenk naar voren, kist op de laadplaat (beeld 126 = UNLOAD_DROP 0,7), terug
clip("Lossen", dict(
    yaw=[(0, 0.0), (45, 0.0), (90, YAW_G), (140, YAW_G), (180, 0.0)],
    elev=[(0, 0.0), (20, 0.14), (95, ELEV_G), (135, ELEV_G), (170, 0.0), (180, 0.0)],
    ext=[(0, 0.0), (50, 0.0), (95, EXT_G), (140, EXT_G), (178, 0.0), (180, 0.0)],
    L=[(0, 0.0), (95, 0.0), (112, L_PLAAT), (130, L_PLAAT), (150, 0.0), (180, 0.0)],
    claw=[(0, 0.0), (8, OPEN), (20, GRIJP), (122, GRIJP), (130, OPEN), (150, OPEN), (170, 0.0), (180, 0.0)],
    held=[(0, E), (19, E), (20, 1.0), (126, 1.0), (127, E), (180, E)],
    load=[(0, 1.0), (19, 1.0), (20, E), (180, E)]))
# rustpose = beginpose
stel(0, 0, 0, 0, 0, E, 1.0)
json.dump({"reach": REACH, "yaw": YAW_G, "elev": ELEV_G, "ext": EXT_G, "L_grijp": L_GRIJP, "L_plaat": L_PLAAT, "claw_dwars": pg.x, "claw_z": pg.z},
          open(UIT / "voorraadtruck_maten.json", "w"), indent=1)
for im in bpy.data.images:
    if im.name.startswith("Truck_") and im.name.endswith(("_albedo", "_normal", "_orm")) and im.size[0] > GAME_TEX:
        im.scale(GAME_TEX, GAME_TEX)
externaliseer(UIT / "textures_truck")
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(UIT / "voorraadtruck_meshy.blend"), compress=True)
for o in bpy.data.objects:
    o.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(UIT / "voorraadtruck_meshy.glb"), export_format="GLB", use_selection=False,
                          export_apply=True, export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_image_format="JPEG", export_jpeg_quality=88, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_optimize_animation_size=False)
print("STAP4 klaar; GLB in", UIT)
