"""Betonnen gewichtsdam met drie stalen sluisdeuren voor Bloedjungle (Blender-script, 1 eenheid = 1 meter).
Gebruik:  python3 maak_dam.py uit/            ->  uit/dam.blend, uit/dam.glb (+ uit/dam_stats.json)

Assen in Blender: X = over de dam (60 m kroon), Y = stroomopwaarts (naar het stuwmeer, in Godot -Z), Z = omhoog.
Nulpunt: midden van de kroon op bodemhoogte (Godot: dam.position = kloofbodem). Hoogte 14 m, kroon 6 m breed.
Opbouw (zie bron/dam/ONTWERP.md):
  statisch : Fundering, Flank_L/R (gewichtsdam + landhoofd), Slijtvloer, Wachthuis, Trappen, Leuningen, Lantaarns, Stenen
  Blok_i_j : 8 kolommen x 3 lagen betonblokken in het midden (de breuk), Pijler_1..4, Poort_1..3, Hijs_1..3, Loopbrug
  Kraak_k  : scheuren in de achterkant (groeien in Kraken), Lek_k : waterstralen
Animaties (NLA, 30 beeld/s): Kraken (5 s: scheuren groeien, lekstralen, trillen) en Breken (6 s: poorten scheuren los,
pijlers en blokken vallen stroomafwaarts, loopbrug stort in). Rustpose = dam intact.
Materialen: DAM_Beton, DAM_Staal, DAM_Steen, DAM_Water, DAM_Lamp, DAM_Glas. Foto-PBR (4K) wordt in Godot en in de viewer
aan DAM_Beton en DAM_Staal gehangen (zie assets/textures/dam/); in de .blend zitten ze al in de materialen."""
import bpy, bmesh, math, os, sys, json, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils import noise as mnoise

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[-1])
TEX = os.environ.get("DAM_TEX", os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "dam")))
# DAM_MESHY = map met de importstraat-uitvoer (dam/*.glb en sluisdeur/*.glb): dan komen Dennis' Meshy-dam en -sluisdeur in het
# model (bron/dam/meshy_dam.py). De knopen, namen, maten en clips blijven precies hetzelfde.
MESHY = os.environ.get("DAM_MESHY")
if MESHY:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import meshy_dam
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(17)
FPS = 30
scene.render.fps = FPS

# ------------------------------------------------------------------ maten
H = 14.0            # hoogte van de kroon boven de kloofbodem
CW = 3.0            # halve kroonbreedte (y -3..3)
SLOPE = 0.75        # achterkant: 0,75 m vlak per meter hoogte
BATTER = 0.04       # voorkant (stuwmeerkant): bijna verticaal
HALF = 30.0         # halve breedte kroon (60 m)
CEN = 18.0          # halve breedte van het middenstuk (36 m) met de sluisdeuren
SILL = 10.0         # drempelhoogte van de overlaat
LAKE_Z = 12.0       # waterpeil (Godot: LAKE_Y 14 minus kloofbodem 2)
LAYERS = [0.0, 3.5, 7.0, 10.0]
COLS = 8
GAP = 0.03


def y_up(z):
    return CW + BATTER * (H - z)


def y_dn(z):
    return -CW - SLOPE * (H - z)


def prof(z0, z1):
    return [(y_up(z0), z0), (y_dn(z0), z0), (y_dn(z1), z1), (y_up(z1), z1)]


# ------------------------------------------------------------------ materialen
def mat(name, color, rough=0.9, metal=0.0, emit=None, alpha=None, tex=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = 3.0
    if alpha is not None:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    if tex:
        # 4K foto-PBR (Poly Haven, CC0): albedo x vertexkleur, normal (OpenGL), ARM = occlusion/roughness/metallic
        tc = nt.nodes.new("ShaderNodeTexCoord")
        uvn = nt.nodes.new("ShaderNodeUVMap"); uvn.uv_map = "UVMap"
        def img(fn, cs):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = bpy.data.images.load(os.path.join(TEX, fn)); n.image.colorspace_settings.name = cs
            nt.links.new(uvn.outputs["UV"], n.inputs["Vector"])
            return n
        d = img(tex + "_albedo.jpg", "sRGB"); nm = img(tex + "_normal.jpg", "Non-Color"); o = img(tex + "_orm.jpg", "Non-Color")
        ca = nt.nodes.new("ShaderNodeVertexColor"); ca.layer_name = "Col"
        mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; mx.blend_type = "MULTIPLY"; mx.inputs["Factor"].default_value = 1.0
        nt.links.new(d.outputs["Color"], mx.inputs["A"]); nt.links.new(ca.outputs["Color"], mx.inputs["B"])
        nt.links.new(mx.outputs["Result"], p.inputs["Base Color"])
        nn = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(nm.outputs["Color"], nn.inputs["Color"]); nt.links.new(nn.outputs["Normal"], p.inputs["Normal"])
        sp = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(o.outputs["Color"], sp.inputs["Color"])
        nt.links.new(sp.outputs["Green"], p.inputs["Roughness"]); nt.links.new(sp.outputs["Blue"], p.inputs["Metallic"])
    return m


MATS = ["DAM_Beton", "DAM_Staal", "DAM_Steen", "DAM_Water", "DAM_Lamp", "DAM_Glas", "DAM_Kraak"]
M = {
    "DAM_Beton": mat("DAM_Beton", (0.55, 0.54, 0.50), 0.85, tex="beton"),
    "DAM_Staal": mat("DAM_Staal", (0.23, 0.30, 0.18), 0.55, 0.6, tex="staal"),
    "DAM_Steen": mat("DAM_Steen", (0.36, 0.34, 0.29), 0.95),
    "DAM_Water": mat("DAM_Water", (0.78, 0.86, 0.90), 0.1, 0.0, alpha=0.55),
    "DAM_Lamp": mat("DAM_Lamp", (1.0, 0.85, 0.5), 0.4, 0.0, (1.0, 0.82, 0.45)),
    "DAM_Glas": mat("DAM_Glas", (0.18, 0.26, 0.30), 0.1, 0.0, alpha=0.6),
    "DAM_Kraak": mat("DAM_Kraak", (0.05, 0.05, 0.05), 1.0),
}
if MESHY:   # gebakken Meshy-texturen (importstraat), geen vertexkleur nodig
    MATS += ["DAM_Meshy", "DAM_Sluis"]
    M["DAM_Meshy"] = mat("DAM_Meshy", (1.0, 1.0, 1.0), 0.9, tex="meshy_dam")
    M["DAM_Sluis"] = mat("DAM_Sluis", (1.0, 1.0, 1.0), 0.6, tex="meshy_sluis")
MI = {n: i for i, n in enumerate(MATS)}

# ------------------------------------------------------------------ objecten
root = bpy.data.objects.new("Dam", None)
scene.collection.objects.link(root)
OBJ = {}


class Ob:
    def __init__(self, name, pivot=(0, 0, 0)):
        self.name = name
        self.pivot = Vector(pivot)
        self.bm = bmesh.new()
        OBJ[name] = self

    def v(self, p):
        return self.bm.verts.new(Vector(p) - self.pivot)

    def poly(self, pts, mat_name, smooth=False):
        f = self.bm.faces.new([self.v(p) for p in pts])
        f.material_index = MI[mat_name]
        f.smooth = smooth
        return f


def rotm(rot):
    return Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")


def refine(o, maxlen):
    """Verdeel te lange randen (rasterbijvulling), zodat vertexkleur en stootranden detail dragen."""
    for _ in range(6):
        o.bm.normal_update()
        def lim(e):
            vis = any(abs(f.normal.y) > 0.5 or f.normal.z > 0.5 for f in e.link_faces)
            return maxlen if vis else max(4.0, maxlen)
        es = [e for e in o.bm.edges if e.calc_length() > lim(e)]
        if not es:
            break
        bmesh.ops.subdivide_edges(o.bm, edges=es, cuts=1, use_grid_fill=True)


def box(o, c, size, mat_name, rot=(0, 0, 0), bevel=0.0, maxlen=0.0, smooth=False):
    bm = o.bm
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=vs)
    if any(rot):
        bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=rotm(rot))
    bmesh.ops.translate(bm, verts=vs, vec=Vector(c) - o.pivot)
    fs = list({f for v in vs for f in v.link_faces})
    for f in fs:
        f.material_index = MI[mat_name]
        f.smooth = smooth
    if bevel > 0:
        ed = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=ed, offset=bevel, segments=1, affect="EDGES")
    return vs


def prism(o, poly_yz, x0, x1, mat_name, bevel=0.0, maxlen=0.0):
    """Doorsnede in (y,z), uitgetrokken in x van x0 tot x1 (convex)."""
    bm = o.bm
    a = [bm.verts.new(Vector((x0, y, z)) - o.pivot) for y, z in poly_yz]
    b = [bm.verts.new(Vector((x1, y, z)) - o.pivot) for y, z in poly_yz]
    n = len(a)
    fs = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    for i in range(n):
        fs.append(bm.faces.new([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]]))
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    for f in fs:
        f.material_index = MI[mat_name]
    if bevel > 0:
        ed = list({e for f in fs for e in f.edges})
        bmesh.ops.bevel(bm, geom=ed, offset=bevel, segments=1, affect="EDGES")
    if maxlen:
        refine(o, maxlen)


def cyl(o, c, r, depth, mat_name, axis="Z", seg=8, r2=None, smooth=True, cap=True):
    bm = o.bm
    rr = bmesh.ops.create_cone(bm, cap_ends=cap, segments=seg, radius1=r, radius2=(r if r2 is None else r2), depth=depth)
    vs = rr["verts"]
    rot = {"Z": (0, 0, 0), "X": (0, math.pi / 2, 0), "Y": (-math.pi / 2, 0, 0)}[axis]
    if any(rot):
        bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=rotm(rot))
    bmesh.ops.translate(bm, verts=vs, vec=Vector(c) - o.pivot)
    for f in {f for v in vs for f in v.link_faces}:
        f.material_index = MI[mat_name]
        f.smooth = smooth
    return vs


def bar(o, a, b, r, mat_name, seg=6):
    """Cilinder (staaf) tussen twee punten."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = o.bm
    rr = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=d.length)
    vs = rr["verts"]
    q = d.to_track_quat("Z", "Y")
    bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=q.to_matrix())
    bmesh.ops.translate(bm, verts=vs, vec=(a + b) / 2 - o.pivot)
    for f in {f for v in vs for f in v.link_faces}:
        f.material_index = MI[mat_name]
        f.smooth = True


def rock(o, c, r, seed, mat_name="DAM_Steen"):
    bm = o.bm
    rs = random.Random(seed)
    rr = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    vs = rr["verts"]
    sx, sy, sz = r * rs.uniform(0.9, 1.5), r * rs.uniform(0.8, 1.3), r * rs.uniform(0.55, 0.9)
    ph = rs.uniform(0, 100)
    for v in vs:
        p = v.co.copy()
        d = 1.0 + 0.28 * mnoise.noise(p * 1.7 + Vector((ph, ph, ph))) + 0.10 * mnoise.noise(p * 4.1 + Vector((ph, 0, ph)))
        v.co = Vector((p.x * sx * d, p.y * sy * d, max(p.z * sz * d, -sz * 0.35 * d)))
    bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=Matrix.Rotation(rs.uniform(0, 6.28), 3, "Z"))
    bmesh.ops.translate(bm, verts=vs, vec=Vector(c) - o.pivot)
    for f in {f for v in vs for f in v.link_faces}:
        f.material_index = MI[mat_name]
        f.smooth = True


# ------------------------------------------------------------------ vaste delen
LAKE_SIDE = 1
# Fundering (grotendeels onder de grond)
fund = Ob("Fundering")
prism(fund, [(5.4, -2.6), (-15.2, -2.6), (-15.2, 0.0), (5.4, 0.0)], -44, 44, "DAM_Beton", bevel=0.08, maxlen=3.0)

# flanken: volledige gewichtsdam + parapetten + landhoofd (het stuk dat in de rotswand zit)
for side, sx in (("L", -1), ("R", 1)):
    fl = Ob("Flank_" + side)
    xa, xb = sorted((sx * CEN, sx * HALF))
    if not MESHY:
        prism(fl, prof(0.0, H), xa, xb, "DAM_Beton", bevel=0.05, maxlen=0.8)
    xa2, xb2 = sorted((sx * HALF, sx * 44.0))
    prism(fl, [(y_up(0) + 0.3, 0.0), (y_dn(0) + 1.0, 0.0), (y_dn(H - 2) + 3, H + 0.9), (y_up(H) - 0.3, H + 0.9)], xa2, xb2, "DAM_Beton", maxlen=2.0)
    if MESHY:
        # Meshy-kroon is ~1,3 m dik: een betonnen kroondek (6 m breed, zoals het spel loopt) op consoles tegen de muur
        box(fl, ((xa + xb) / 2, (-CW + 1.9) / 2, H - 0.25), ((xb - xa), 1.9 + CW, 0.5), "DAM_Beton", bevel=0.03, maxlen=0.8)
        box(fl, ((xa + xb) / 2, -CW + 0.12, H + 0.25), ((xb - xa), 0.24, 0.5), "DAM_Beton", bevel=0.02, maxlen=0.8)
        for k in range(int((xb - xa) / 2.4) + 1):
            prism(fl, [(-CW + 0.3, H - 0.5), (1.6, H - 0.5), (1.6, H - 3.2)], xa + 0.3 + k * 2.4 - 0.2, xa + 0.3 + k * 2.4 + 0.2, "DAM_Beton", bevel=0.02)
        continue
    # parapetten op de kroon (0,9 m), achterkant ook met leuning (apart)
    box(fl, ((xa + xb) / 2, CW - 0.25, H + 0.45), ((xb - xa), 0.5, 0.9), "DAM_Beton", bevel=0.03, maxlen=0.8)
    box(fl, ((xa + xb) / 2, -CW + 0.25, H + 0.45), ((xb - xa), 0.5, 0.9), "DAM_Beton", bevel=0.03, maxlen=0.8)
    # inspectiegang aan de achterkant + afvoergaten
    gx = sx * 24.0
    box(fl, (gx, y_dn(2.0) - 0.15, 1.6), (2.2, 0.5, 3.0), "DAM_Beton", bevel=0.05)
    for k in range(4):
        zz = 3.5 + 2.4 * k
        for dx in (-3.0, 3.0, 8.0):
            cyl(fl, (sx * 24.0 + dx, y_dn(zz) - 0.02, zz), 0.16, 0.22, "DAM_Kraak", axis="Y", seg=8, smooth=True)
    # deur van de inspectiegang (staal)
    box(fl, (gx, y_dn(2.0) - 0.45, 1.5), (1.4, 0.1, 2.5), "DAM_Staal", bevel=0.02)
    for k in range(3):
        box(fl, (gx, y_dn(2.0) - 0.53, 0.7 + k * 0.8), (1.3, 0.05, 0.1), "DAM_Staal")
    cyl(fl, (gx + 0.5, y_dn(2.0) - 0.55, 1.5), 0.07, 0.1, "DAM_Staal", axis="Y")

# slijtvloer (energiedempend bekken) met barrièreblokken en eindrichel
def apron_z(y):
    return -0.15 - 1.2 * max(0.0, (-y - 13.5) / 12.5)
sl = Ob("Slijtvloer") if not MESHY else Ob("_slijtvloer_proc")   # Meshy-dam heeft een eigen slijtvloer
pts = [(-13.0, apron_z(-13.0) - 1.4), (-27.0, apron_z(-27.0) - 1.4), (-27.0, apron_z(-27.0)), (-13.0, apron_z(-13.0))]
prism(sl, pts, -22, 22, "DAM_Beton", bevel=0.06, maxlen=2.0)
for i in range(-4, 5):
    zb = apron_z(-17.5)
    box(sl, (i * 4.6, -17.5, zb + 0.55), (1.1, 1.1, 1.1), "DAM_Beton", bevel=0.07)
box(sl, (0, -27.4, apron_z(-27.4) + 0.55), (44, 0.9, 1.6), "DAM_Beton", bevel=0.07, maxlen=1.0)
for sx in (-1, 1):   # geleidemuren langs de slijtvloer
    prism(sl, [(-13.0, apron_z(-13.0)), (-27.0, apron_z(-27.0)), (-27.0, apron_z(-27.0) + 3.6), (-13.0, apron_z(-13.0) + 7.0)], sx * 22.0 - 0.5, sx * 22.0 + 0.5, "DAM_Beton", bevel=0.05, maxlen=2.0)

# Trappen naar de loopbrug (massief beton, treden) + leuningen, een per kant
for side, sx in (("L", -1), ("R", 1)):
    tr = Ob("Trap_" + side)
    n = 28
    rise = (19.0 - H) / n
    run = 0.30
    for k in range(n):
        x1 = sx * (28.4 - k * run)
        zt = H + rise * (k + 1)
        box(tr, (x1 - sx * run / 2, 2.2, (H + zt) / 2), (run, 1.8, zt - H), "DAM_Beton", bevel=0.01)
    box(tr, (sx * (28.4 - n * run - 0.8), 2.2, 18.5), (1.8, 1.8, 1.0), "DAM_Beton", bevel=0.03)   # bordes
    for k in range(0, n + 1, 4):
        x1 = sx * (28.4 - k * run)
        zt = H + rise * (k + 1)
        for yy in (1.3, 3.1):
            cyl(tr, (x1, yy, zt + 0.55), 0.03, 1.1, "DAM_Staal", seg=6)
    for yy in (1.3, 3.1):
        bar(tr, (sx * 28.4, yy, H + 1.1), (sx * (28.4 - n * run), yy, 19.0 + 1.1), 0.03, "DAM_Staal")

# Leuningen langs de achterkant van de kroon (staal, stijlen om de 1,5 m)
rl = Ob("Leuning")
for sx in (-1, 1):
    x_a, x_b = sx * (CEN + 0.2), sx * (HALF - 0.2)
    n = int(abs(x_b - x_a) / 1.5)
    xs = [x_a + (x_b - x_a) * i / n for i in range(n + 1)]
    for x in xs:
        cyl(rl, (x, -CW + 0.25, H + 0.9 + 0.55), 0.035, 1.1, "DAM_Staal", seg=6)
    for zz in (H + 0.9 + 0.5, H + 0.9 + 1.0):
        cyl(rl, ((x_a + x_b) / 2, -CW + 0.25, zz), 0.03, abs(x_b - x_a), "DAM_Staal", axis="X", seg=6)
    # kabelgoot met kabels langs de voet van het parapet
    box(rl, ((x_a + x_b) / 2, -CW + 0.7, H + 0.12), (abs(x_b - x_a), 0.4, 0.22), "DAM_Staal", bevel=0.01)
    for yy in (-CW + 0.6, -CW + 0.7, -CW + 0.8):
        cyl(rl, ((x_a + x_b) / 2, yy, H + 0.27), 0.025, abs(x_b - x_a), "DAM_Kraak", axis="X", seg=6)

# Lantaarns op de kroon
lp = Ob("Lantaarns")
for sx in (-1, 1):
    for x in (sx * 20.5, sx * 25.5, sx * 29.0):
        cyl(lp, (x, CW - 0.6, H + 2.4), 0.07, 4.8, "DAM_Staal", seg=8, r2=0.05)
        box(lp, (x, CW - 0.9, H + 4.75), (0.12, 0.7, 0.1), "DAM_Staal")
        box(lp, (x, CW - 1.25, H + 4.65), (0.5, 0.3, 0.14), "DAM_Staal", bevel=0.02)
        box(lp, (x, CW - 1.25, H + 4.55), (0.4, 0.2, 0.05), "DAM_Lamp")

# Wachthuis (links, op het landhoofd)
wh = Ob("Wachthuis")
hx, hy = -26.5, -0.4
box(wh, (hx, hy, H + 0.9 + 1.5), (4.6, 3.6, 3.0), "DAM_Beton", bevel=0.06, maxlen=0.9)
box(wh, (hx, hy, H + 0.9 + 3.12), (5.2, 4.2, 0.24), "DAM_Beton", bevel=0.04, maxlen=1.0)   # dakplaat
box(wh, (hx, hy, H + 0.9 + 3.32), (4.9, 3.9, 0.1), "DAM_Staal")
box(wh, (hx + 1.0, hy - 1.85, H + 0.9 + 1.0), (1.0, 0.12, 2.0), "DAM_Staal", bevel=0.02)   # deur
box(wh, (hx + 1.0, hy - 1.93, H + 0.9 + 1.0), (0.12, 0.04, 0.5), "DAM_Staal")
for wx in (hx - 1.2, hx + 0.1):                                                              # ramen
    box(wh, (wx, hy - 1.83, H + 0.9 + 1.6), (1.1, 0.1, 0.9), "DAM_Staal", bevel=0.02)
    box(wh, (wx, hy - 1.89, H + 0.9 + 1.6), (0.95, 0.05, 0.75), "DAM_Glas")
box(wh, (hx - 2.35, hy + 0.2, H + 0.9 + 1.7), (0.1, 1.5, 0.9), "DAM_Staal", bevel=0.02)
box(wh, (hx - 2.41, hy + 0.2, H + 0.9 + 1.7), (0.05, 1.35, 0.75), "DAM_Glas")
cyl(wh, (hx - 1.8, hy + 1.2, H + 0.9 + 4.1), 0.04, 1.8, "DAM_Staal", seg=6)                   # antenne
cyl(wh, (hx - 1.8, hy + 1.2, H + 0.9 + 4.9), 0.012, 1.6, "DAM_Staal", seg=5)
box(wh, (hx + 2.5, hy + 0.5, H + 0.9 + 0.6), (0.4, 0.9, 1.2), "DAM_Staal", bevel=0.03)     # kast
for k in range(3):
    cyl(wh, (hx - 2.2, hy - 1.0 + k * 0.15, H + 0.9 + 1.5), 0.035, 3.0, "DAM_Staal", seg=6)  # leidingen
box(wh, (hx, hy - 1.95, H + 0.9 + 3.0), (0.9, 0.12, 0.12), "DAM_Lamp")
for k in range(5):                                                                              # dakrand
    box(wh, (hx - 2.0 + k * 1.0, hy - 2.1, H + 0.9 + 3.35), (0.08, 0.08, 0.3), "DAM_Staal")

# stenen (damtenen, landhoofd aan de achterkant en de oevers van de slijtvloer)
st = Ob("Stenen") if not MESHY else Ob("_stenen_proc")   # Meshy-dam heeft eigen stortsteen
for i in range(46):
    side = rnd.choice((-1, 1))
    if i < 18:
        x = side * rnd.uniform(22, 31); y = rnd.uniform(-26.5, -13.0)
    elif i < 34:
        x = side * rnd.uniform(18, 36); y = rnd.uniform(-14.5, -8.5)
    else:
        x = rnd.uniform(-22, 22); y = rnd.uniform(-30.0, -27.5)
    rock(st, (x, y, apron_z(y) - 0.1 if abs(x) < 22 else rnd.uniform(0.0, 1.2)), rnd.uniform(0.5, 1.5), 1000 + i)

# ------------------------------------------------------------------ bewegende delen
block_c = {}
for j in range(3):
    for i in range(COLS):
        x0 = -CEN + (2 * CEN / COLS) * i + GAP
        x1 = -CEN + (2 * CEN / COLS) * (i + 1) - GAP
        z0, z1 = LAYERS[j] + (GAP if j else 0.0), LAYERS[j + 1] - GAP
        c = ((x0 + x1) / 2, (y_up(z0) + y_dn(z0) + y_up(z1) + y_dn(z1)) / 4, (z0 + z1) / 2)
        b = Ob(f"Blok_{i + 1}_{j + 1}", c)
        block_c[(i, j)] = Vector(c)
        prism(b, prof(z0, z1), x0, x1, "DAM_Beton", bevel=0.06, maxlen=0.9)
        # ruwe breukvlak aan de zijkanten: een paar uitstekende stenen en ijzers
        for k in range(rnd.randint(2, 4)):
            zz = rnd.uniform(z0 + 0.4, z1 - 0.4); yy = rnd.uniform(y_dn(zz) + 0.6, y_up(zz) - 0.6)
            cyl(b, (x0 - 0.04, yy, zz), 0.014, 0.22, "DAM_Staal", axis="X", seg=5)

MESHY_STATS = {}
PY0 = -5.5   # achterkant van de pijlers (stroomafwaarts)
if MESHY:
    Ob("Slijtvloer")   # krijgt de slijtvloer van de Meshy-dam (meshy_dam.build)
    WALL_BVH, MESHY_STATS = meshy_dam.build(OBJ, MI, block_c, MESHY)
    hits = [WALL_BVH.ray_cast(Vector((x, -60.0, SILL - 0.3)), Vector((0, 1, 0)), 120.0)[0] for x in (-15.0, -5.0, 5.0, 15.0)]
    PY0 = min(h.y for h in hits if h is not None) - 0.15   # de pijlers staan op de Meshy-muur, niet erover heen
for _n in ("_slijtvloer_proc", "_stenen_proc"):
    if _n in OBJ:
        OBJ.pop(_n).bm.free()

# pijlers boven de drempel
PX = (-15.0, -5.0, 5.0, 15.0)
pier_c = {}
for k, px in enumerate(PX):
    po = Ob(f"Pijler_{k + 1}", (px, 0.0, SILL))
    pier_c[k] = Vector((px, 0, SILL))
    box(po, (px, (PY0 + 3.3) / 2, SILL + 4.3), (2.0, 3.3 - PY0, 8.6), "DAM_Beton", bevel=0.07, maxlen=0.9)
    cyl(po, (px, 3.3, SILL + 4.3), 1.0, 8.6, "DAM_Beton", seg=16, smooth=True)
    for sg in (-1, 1):   # sleuvegeleiders (stalen U-profielen) en bouten
        box(po, (px + sg * 1.02, 1.9, SILL + 3.4), (0.08, 0.5, 6.8), "DAM_Staal", bevel=0.01)
        for z in range(0, 14):
            cyl(po, (px + sg * 1.08, 1.9, SILL + 0.4 + 0.5 * z), 0.03, 0.06, "DAM_Staal", axis="X", seg=6)
    for z in range(0, 16):  # ladder op de achterkant
        box(po, (px, PY0 - 0.05, SILL + 0.5 + z * 0.5), (0.7, 0.04, 0.04), "DAM_Staal")
    for sg in (-1, 1):
        box(po, (px + sg * 0.35, PY0 - 0.05, SILL + 4.3), (0.04, 0.04, 8.6), "DAM_Staal")
    box(po, (px, (PY0 + 3.3) / 2 + 1.1, SILL + 8.9), (2.3, 3.7 - PY0, 0.35), "DAM_Beton", bevel=0.05, maxlen=1.0)   # kop onder de loopbrug

# poorten (stalen schuiven) met ribben, bouten, hijsogen en kabels
GX = (-10.0, 0.0, 10.0)
gate_c = {}
for k, gx in enumerate(GX):
    go = Ob(f"Poort_{k + 1}", (gx, 1.5, SILL + 3.2))
    gate_c[k] = Vector((gx, 1.5, SILL + 3.2))
    if MESHY:   # Dennis' Meshy-sluisdeur (8 m breed, ribben stroomafwaarts zoals de oude), plus de kabels naar de hijsmachine
        meshy_dam.append(go.bm, meshy_dam.gate_mesh(MESHY, MI), Matrix.Translation(Vector((gx, 1.5, SILL)) - go.pivot))
        for sg in (-1, 1):
            cyl(go, (gx + sg * 2.0, 1.5, SILL + 8.1), 0.035, 3.0, "DAM_Staal", seg=6)
        continue
    box(go, (gx, 1.75, SILL + 3.2), (8.0, 0.14, 6.4), "DAM_Staal", bevel=0.015, maxlen=0.9)  # huid
    for i in range(6):   # horizontale liggers aan de achterkant
        zz = SILL + 0.5 + i * 1.1
        box(go, (gx, 1.25, zz), (7.8, 0.5, 0.14), "DAM_Staal", bevel=0.015, maxlen=1.0)
        box(go, (gx, 1.5, zz), (7.8, 0.06, 0.4), "DAM_Staal", bevel=0.01, maxlen=1.0)
    for i in range(5):   # verticale ribben
        xx = gx - 3.2 + i * 1.6
        box(go, (xx, 1.45, SILL + 3.2), (0.12, 0.6, 6.3), "DAM_Staal", bevel=0.01)
    for sg in (-1, 1):   # stijlen aan de zijkant met rollen
        box(go, (gx + sg * 4.0, 1.5, SILL + 3.2), (0.3, 0.9, 6.4), "DAM_Staal", bevel=0.02, maxlen=1.0)
        for z in range(4):
            cyl(go, (gx + sg * 4.2, 1.5, SILL + 0.9 + z * 1.5), 0.17, 0.25, "DAM_Staal", axis="X", seg=10)
    for i in range(7):   # klinknagels langs de bovenrand en onderrand
        for zz in (SILL + 0.15, SILL + 6.25):
            cyl(go, (gx - 3.6 + i * 1.2, 1.83, zz), 0.04, 0.05, "DAM_Staal", axis="Y", seg=6)
    box(go, (gx, 1.75, SILL + 0.06), (8.0, 0.2, 0.14), "DAM_Kraak")                    # rubber afdichting onderaan
    for sg in (-1, 1):   # hijsogen en kabels naar de hijsmachine
        box(go, (gx + sg * 2.0, 1.5, SILL + 6.55), (0.4, 0.3, 0.3), "DAM_Staal", bevel=0.02)
        cyl(go, (gx + sg * 2.0, 1.5, SILL + 8.1), 0.035, 3.0, "DAM_Staal", seg=6)

# loopbrug over de pijlers (staalbouw, rooster, leuning)
lb = Ob("Loopbrug", (0.0, 1.6, 19.0))
LBZ = 18.6
box(lb, (0, 1.6, LBZ + 0.2), (36.8, 3.0, 0.1), "DAM_Staal", bevel=0.01, maxlen=1.0)
for yy in (0.25, 2.95):
    box(lb, (0, yy, LBZ - 0.2), (36.8, 0.2, 0.8), "DAM_Staal", bevel=0.01, maxlen=1.2)
    box(lb, (0, yy, LBZ - 0.58), (36.8, 0.5, 0.06), "DAM_Staal")
    box(lb, (0, yy, LBZ + 0.12), (36.8, 0.5, 0.06), "DAM_Staal")
for i in range(25):
    xx = -18.0 + i * 1.5
    box(lb, (xx, 1.6, LBZ - 0.2), (0.12, 3.0, 0.3), "DAM_Staal")
    for yy in (0.25, 2.95):
        cyl(lb, (xx, yy, LBZ + 0.7), 0.035, 1.1, "DAM_Staal", seg=6)
for yy in (0.25, 2.95):
    for zz in (LBZ + 0.7, LBZ + 1.1):
        cyl(lb, (0, yy, zz), 0.03, 36.8, "DAM_Staal", axis="X", seg=6)
for i in range(60):   # roosterbalkjes
    box(lb, (-17.6 + i * 0.6, 1.6, LBZ + 0.26), (0.05, 2.9, 0.03), "DAM_Kraak")
for i in range(8):    # kabelgoot en lampjes onder de brug
    box(lb, (-16 + i * 4.6, 1.6, LBZ - 0.65), (0.3, 0.3, 0.14), "DAM_Lamp")

# hijsmachines op de loopbrug
for k, gx in enumerate(GX):
    h = Ob(f"Hijs_{k + 1}", (gx, 1.5, LBZ + 0.2))
    box(h, (gx, 1.5, LBZ + 1.2), (3.2, 1.7, 1.8), "DAM_Staal", bevel=0.05, maxlen=0.8)
    box(h, (gx, 1.5, LBZ + 2.2), (3.4, 1.9, 0.12), "DAM_Staal", bevel=0.02)
    for sg in (-1, 1):
        cyl(h, (gx + sg * 2.0, 1.5, LBZ + 1.1), 0.45, 0.9, "DAM_Staal", axis="Y", seg=14)
        box(h, (gx + sg * 1.4, 1.5, LBZ + 0.5), (0.6, 1.2, 0.5), "DAM_Staal", bevel=0.03)
    box(h, (gx + 0.2, 0.55, LBZ + 1.4), (1.2, 0.08, 0.8), "DAM_Glas")
    box(h, (gx, 0.58, LBZ + 1.25), (0.3, 0.06, 0.4), "DAM_Lamp")
    cyl(h, (gx, 2.4, LBZ + 2.6), 0.03, 0.9, "DAM_Staal", seg=5)

# ------------------------------------------------------------------ scheuren en lekstralen
n_dn = Vector((0.0, -1.0, SLOPE)).normalized()      # normaal van het achtervlak
t_up = Vector((0.0, SLOPE, 1.0)).normalized()       # langs het vlak omhoog
def face_pt(x, z):
    return Vector((x, y_dn(z), z))
cracks = []
cracks_spec = [(-13.5, 8.8, 5.2), (-9.0, 6.5, 6.0), (-4.5, 9.0, 7.0), (-1.0, 4.5, 6.5), (2.5, 8.5, 5.5), (6.0, 5.5, 6.5),
               (10.0, 9.2, 5.0), (13.5, 7.0, 4.0), (-17.0, 5.0, 3.5), (17.0, 5.5, 3.5), (-6.5, 2.2, 4.5), (7.5, 2.0, 4.5),
               (-21.0, 9.0, 4.0), (21.5, 9.0, 4.0), (0.0, 9.3, 3.5)]
for k, (cx, cz, ln) in enumerate(cracks_spec):
    o = Ob(f"Kraak_{k + 1}", face_pt(cx, cz) + n_dn * 0.03)
    # zigzaglijn van het beginpunt omhoog/zijwaarts; lint met breedte
    pts = [Vector((0, 0, 0))]
    p = Vector((0, 0, 0))
    steps = 9
    dirx = rnd.choice((-1, 1))
    for s in range(steps):
        ang = rnd.uniform(-0.9, 0.9)
        d = (Vector((math.sin(ang) * 0.5 * dirx, 0.0, 0.0)) + t_up * 1.0).normalized() if False else None
        step = ln / steps
        p = p + Vector((math.sin(ang) * step * 0.9, 0, 0)) + t_up * step * math.cos(ang) * 0.9
        pts.append(p)
    left, right = [], []
    for s, q in enumerate(pts):
        w = 0.17 * (1.0 - s / (len(pts) - 1)) + 0.02
        left.append(q + Vector((-w, 0, 0)) * (1 if s else 0.3))
        right.append(q + Vector((w, 0, 0)) * (1 if s else 0.3))
    bm = o.bm
    vl = [bm.verts.new(q) for q in left]
    vr = [bm.verts.new(q) for q in right]
    for s in range(len(pts) - 1):
        f = bm.faces.new([vl[s], vr[s], vr[s + 1], vl[s + 1]])
        f.material_index = MI["DAM_Kraak"]
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    for f in bm.faces:   # normaal van het vlak laten wijzen (naar achteren)
        if f.normal.dot(n_dn) < 0:
            f.normal_flip()
    cracks.append((o, face_pt(cx, cz) + n_dn * 0.03, rnd.uniform(0.0, 1.6)))

leaks = []
for k, (cx, cz, ln) in enumerate(cracks_spec[:11]):
    top = face_pt(cx, cz + ln * 0.35) + n_dn * 0.05
    o = Ob(f"Lek_{k + 1}", top)
    n = 12
    v0 = Vector((0, 0, 0))
    vel = Vector((0.0, -rnd.uniform(1.4, 2.6), 0.4))
    prev = None
    for s in range(n + 1):
        t = s * 0.14
        pc = vel * t + Vector((0, 0, -4.9 * t * t))
        r = 0.04 + 0.09 * (s / n)
        ring = []
        for a in range(6):
            ang = a * math.pi / 3
            ring.append(o.bm.verts.new(pc + Vector((math.cos(ang) * r, 0.0, 0.0)) + Vector((0, math.sin(ang) * r * 0.6, 0)) + Vector((0, 0, 0))))
        if prev:
            for a in range(6):
                f = o.bm.faces.new([prev[a], prev[(a + 1) % 6], ring[(a + 1) % 6], ring[a]])
                f.material_index = MI["DAM_Water"]
                f.smooth = True
        prev = ring
    bmesh.ops.recalc_face_normals(o.bm, faces=list(o.bm.faces))
    leaks.append((o, top, rnd.uniform(0.5, 2.2)))

if MESHY:   # scheuren en lekstralen op het Meshy-achtervlak leggen (dat ligt veel steiler dan het oude)
    hit = meshy_dam.snap_to_wall(None, WALL_BVH)
    for o, _, _ in cracks:
        p0 = hit(o.pivot)
        if p0 is None:
            continue
        for v in o.bm.verts:
            q = hit(v.co + o.pivot)
            v.co = (q if q is not None else v.co + p0) - p0
        o.pivot = p0
    for o, _, _ in leaks:
        p0 = hit(o.pivot)
        if p0 is not None:
            o.pivot = p0

# ------------------------------------------------------------------ UV's, vertexkleur, meshes maken
TILE = {"DAM_Beton": 3.0, "DAM_Staal": 2.0, "DAM_Steen": 2.5, "DAM_Kraak": 2.0, "DAM_Water": 2.0, "DAM_Lamp": 2.0, "DAM_Glas": 2.0}


def uv_for(world_p, nrm, mname):
    n = nrm.normalized()
    up = Vector((0, 0, 1))
    if abs(n.z) > 0.96:
        u_ax, v_ax = Vector((1, 0, 0)), Vector((0, 1, 0))
    else:
        v_ax = (up - n * up.dot(n)).normalized()
        u_ax = v_ax.cross(n).normalized()
    s = 1.0 / TILE[mname]
    return (world_p.dot(u_ax) * s, world_p.dot(v_ax) * s)


meshes = {}
for name, o in OBJ.items():
    bm = o.bm
    if not bm.faces:
        continue
    bm.normal_update()
    uvl = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        mn = MATS[f.material_index]
        if mn in ("DAM_Meshy", "DAM_Sluis"):   # gebakken Meshy-UV's blijven
            continue
        for l in f.loops:
            wp = l.vert.co + o.pivot
            l[uvl].uv = uv_for(wp, f.normal, mn)
    for e in bm.edges:
        if e.is_manifold and e.calc_face_angle(0) > math.radians(38):
            e.smooth = False
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    for mname in MATS:
        me.materials.append(M[mname])
    me.update()
    ob = bpy.data.objects.new(name, me)
    ob.location = o.pivot
    ob.parent = root
    scene.collection.objects.link(ob)
    meshes[name] = ob
    bm.free()

# AO + vuil per hoek (vertexkleur "Col")
bpy.context.view_layer.update()
tris = []
verts = []
for ob in meshes.values():
    mw = ob.matrix_world
    me = ob.data
    me.calc_loop_triangles()
    base = len(verts)
    verts.extend([mw @ v.co for v in me.vertices])
    for t in me.loop_triangles:
        tris.append(tuple(base + i for i in t.vertices))
bvh = BVHTree.FromPolygons(verts, tris)


def fbm(p, f, oct=3):
    s, a = 0.0, 1.0
    for _ in range(oct):
        s += a * mnoise.noise(p * f)
        f *= 2.0; a *= 0.5
    return s


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def hemi(n, k, seed):
    rs = random.Random(seed)
    t1 = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
    t2 = n.cross(t1)
    out = []
    for _ in range(k):
        u1, u2 = rs.random(), rs.random()
        r = math.sqrt(u1); ph = 2 * math.pi * u2
        out.append((t1 * (r * math.cos(ph)) + t2 * (r * math.sin(ph)) + n * math.sqrt(1 - u1)).normalized())
    return out


ao_cache = {}
for ob in meshes.values():
    me = ob.data
    mw = ob.matrix_world
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    nrm_mat = mw.to_3x3()
    # normalen en punten eerst ophalen: elke kleurtoewijzing markeert het net als gewijzigd, en dan zou elke .normal-vraag alles opnieuw rekenen
    vco = [v.co.copy() for v in me.vertices]
    vno = [v.normal.copy() for v in me.vertices]
    pno = [p_.normal.copy() for p_ in me.polygons]
    lvi = [l.vertex_index for l in me.loops]
    for poly in me.polygons:
        mname = MATS[poly.material_index] if poly.material_index < len(MATS) else "DAM_Beton"
        for li in poly.loop_indices:
            vi = lvi[li]
            p = mw @ vco[vi]
            n = (nrm_mat @ (vno[vi] if poly.use_smooth else pno[poly.index])).normalized()
            key = (round(p.x, 2), round(p.y, 2), round(p.z, 2), round(n.x, 1), round(n.y, 1), round(n.z, 1))
            if mname in ("DAM_Water", "DAM_Lamp", "DAM_Glas", "DAM_Kraak", "DAM_Meshy", "DAM_Sluis"):
                ca.data[li].color = (1, 1, 1, 1)
                continue
            if key not in ao_cache:
                hits = 0
                for d in hemi(n, 16, hash(key) & 0xffff):
                    if bvh.ray_cast(p + n * 0.04, d, 3.5)[0] is not None:
                        hits += 1
                ao_cache[key] = 1.0 - hits / 16.0
            ao = ao_cache[key]
            c = 0.92 * (0.55 + 0.45 * ao)
            tint = Vector((1.0, 1.0, 1.0))
            if mname == "DAM_Beton":
                st = fbm(Vector((p.x * 1.3, p.y * 1.3, p.z * 0.12)), 1.0, 3)           # verticale vuilstrepen
                c *= 1.0 - 0.28 * smooth(0.05, 0.45, st)
                if n.y > 0.3:                                                         # stuwmeerkant: waterlijn en alg
                    band = smooth(LAKE_Z - 2.2, LAKE_Z - 0.4, p.z) * (1.0 - smooth(LAKE_Z - 0.2, LAKE_Z + 0.5, p.z))
                    c *= 1.0 - 0.35 * band
                    below = 1.0 - smooth(LAKE_Z - 4.0, LAKE_Z - 1.0, p.z)
                    tint = tint.lerp(Vector((0.78, 0.92, 0.55)), 0.6 * (1.0 - below) * smooth(0.0, LAKE_Z - 0.2, p.z))
                toe = 1.0 - smooth(0.2, 2.6, p.z)
                c *= 1.0 - 0.30 * toe
                m = smooth(0.30, 0.65, fbm(p * 0.55 + Vector((9, 4, 2)), 1.0, 3)) * (0.35 + 0.65 * (1.0 - ao)) * (0.25 + 0.75 * toe + 0.3 * (1.0 if n.z > 0.5 else 0.0))
                tint = tint.lerp(Vector((0.55, 0.78, 0.35)), min(1.0, m * 0.85))
                drip = smooth(0.35, 0.7, fbm(Vector((p.x * 2.2, p.y * 2.2, p.z * 0.07)), 1.0, 2)) * 0.18
                c *= 1.0 - drip
            elif mname == "DAM_Staal":
                rust = smooth(0.15, 0.6, fbm(Vector((p.x * 3.0, p.y * 3.0, p.z * 0.3)), 1.0, 3)) * 0.5
                tint = tint.lerp(Vector((1.0, 0.72, 0.5)), rust * (0.6 + 0.4 * (1 - ao)))
            elif mname == "DAM_Steen":
                c *= 0.9 + 0.2 * fbm(p * 1.3, 1.0, 2)
                tint = tint.lerp(Vector((0.7, 0.9, 0.5)), smooth(0.35, 0.7, fbm(p * 0.9 + Vector((5, 1, 3)), 1.0, 2)) * 0.5)
            col = (min(1.0, c * tint.x), min(1.0, c * tint.y), min(1.0, c * tint.z), 1.0)
            ca.data[li].color = col
    me.color_attributes.active_color = ca

# ------------------------------------------------------------------ animatie
def ease(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def ease_in(u):
    u = max(0.0, min(1.0, u))
    return u * u


class Clip:
    def __init__(self, naam, dur):
        self.naam, self.dur = naam, dur
        self.frames = int(round(dur * FPS))
        self.tracks = {}

    def objs(self):
        return list(self.tracks)


def rest(o):
    return (o.location.copy(), Vector(o.rotation_euler), o.scale.copy())


REST = {o.name: rest(o) for o in meshes.values()}
HIDDEN = ("Kraak_", "Lek_")
for nm in REST:
    if nm.startswith(HIDDEN):
        l, r, _ = REST[nm]
        REST[nm] = (l, r, Vector((0.001, 0.001, 0.001)))
        meshes[nm].scale = (0.001, 0.001, 0.001)


def bake(naam, dur, fn, names):
    """fn(name, t) -> (loc_delta, rot_euler, scale_mult) ten opzichte van de rustpose."""
    frames = int(round(dur * FPS))
    for nm in names:
        o = meshes[nm]
        o.animation_data_create()
        o.animation_data.action = bpy.data.actions.new(f"{naam}_{nm}")
        l0, r0, s0 = REST[nm]
        for f in range(frames + 1):
            dl, dr, sm = fn(nm, f / FPS)
            o.location = l0 + Vector(dl)
            o.rotation_euler = (r0.x + dr[0], r0.y + dr[1], r0.z + dr[2])
            o.scale = sm if nm.startswith(HIDDEN) else (s0.x * sm[0], s0.y * sm[1], s0.z * sm[2])
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    for nm in names:
        o = meshes[nm]
        a = o.animation_data.action
        tr = o.animation_data.nla_tracks.new(); tr.name = naam
        s = tr.strips.new(naam, 0, a); s.name = naam
        o.animation_data.action = None
        l0, r0, s0 = REST[nm]
        o.location, o.rotation_euler, o.scale = l0, r0, s0


rs = random.Random(5)
VIB = {nm: (rs.uniform(0, 6.28), rs.uniform(0.7, 1.3)) for nm in meshes}
crack_delay = {o.name: d for o, _, d in cracks}
leak_delay = {o.name: d for o, _, d in leaks}
block_names = [n for n in meshes if n.startswith("Blok_")]
sway_names = block_names + [n for n in meshes if n.startswith(("Pijler_", "Poort_", "Loopbrug", "Hijs_"))]


def kraken(nm, t):
    T = 5.0
    if nm.startswith("Kraak_"):
        u = ease((t - crack_delay[nm]) / 2.6)
        return (0, 0, 0), (0, 0, 0), (max(u, 0.001), max(u, 0.001), max(u, 0.001))
    if nm.startswith("Lek_"):
        u = ease((t - 1.0 - leak_delay[nm]) / 1.1)
        w = 1.0 + 0.1 * math.sin(t * 25 + VIB[nm][0])
        return (0, 0, 0), (0, 0, 0), (max(u, 0.001) * w, max(u, 0.001), max(u, 0.001))
    if nm in sway_names:
        a = 0.004 + 0.02 * ease(t / T)
        ph, fr = VIB[nm]
        s = math.sin(t * 38 * fr + ph) * a * (1.0 if t < T - 0.3 else (T - t) / 0.3)
        c = math.cos(t * 31 * fr + ph) * a * 0.5
        return (s, c, abs(s) * 0.4), (c * 0.05, s * 0.05, 0), (1, 1, 1)
    return (0, 0, 0), (0, 0, 0), (1, 1, 1)


rs2 = random.Random(9)
FALL = {}
for (i, j), c in block_c.items():
    d0 = 0.5 + 0.16 * abs(i - 3.5) + 0.55 * (2 - j) + rs2.uniform(0, 0.25)
    dur = rs2.uniform(1.5, 2.2)
    mx = rs2.uniform(5.0, 16.0) * (1.0 + 0.5 * (2 - j) * 0.3)
    FALL[f"Blok_{i + 1}_{j + 1}"] = dict(d0=d0, dur=dur, dy=-(mx * (0.55 + 0.25 * (2 - j))), dx=rs2.uniform(-2.5, 2.5) + (i - 3.5) * 0.7,
                                         rest_z=-c.z + 0.9 + rs2.uniform(0, 0.4) * (j == 0), rot=(rs2.choice((0.0, math.pi / 2, -math.pi / 2, math.pi)) + rs2.uniform(-0.25, 0.25), rs2.uniform(-0.3, 0.3), rs2.uniform(-1.5, 1.5)))
for k in range(4):
    FALL[f"Pijler_{k + 1}"] = dict(d0=0.9 + 0.12 * abs(k - 1.5), dur=2.1, dy=-rs2.uniform(8.0, 13.0), dx=rs2.uniform(-2.5, 2.5), rest_z=-8.9 + 0.7,
                                    rot=(rs2.uniform(-0.9, -1.5), rs2.uniform(-0.4, 0.4), rs2.uniform(-0.6, 0.6)))
for k in range(3):
    FALL[f"Poort_{k + 1}"] = dict(d0=0.0 + 0.2 * k, dur=2.4, dy=-rs2.uniform(14.0, 20.0), dx=rs2.uniform(-2.0, 2.0), rest_z=-SILL - 3.2 + 2.2,
                                   rot=(rs2.uniform(-1.4, -2.3), rs2.uniform(-0.6, 0.6), rs2.uniform(-0.5, 0.5)))
    FALL[f"Hijs_{k + 1}"] = dict(d0=1.6 + 0.2 * k, dur=1.9, dy=-rs2.uniform(5.0, 9.0), dx=rs2.uniform(-2.0, 2.0), rest_z=-LBZ - 0.2 + 1.0,
                                  rot=(rs2.uniform(-0.8, 0.8), rs2.uniform(-0.8, 0.8), rs2.uniform(-1.5, 1.5)))
FALL["Loopbrug"] = dict(d0=1.4, dur=2.6, dy=-6.0, dx=0.0, rest_z=-18.0, rot=(-0.5, 0.18, 0.12))


def breken(nm, t):
    if nm.startswith("Kraak_"):   # scheuren op het middenstuk verdwijnen met de blokken; die op de flanken blijven
        if abs(REST[nm][0].x) < CEN:
            u = 1.0 - ease((t - 0.5) / 0.5)
            return (0, 0, 0), (0, 0, 0), (max(u, 0.001), max(u, 0.001), max(u, 0.001))
        return (0, 0, 0), (0, 0, 0), (1, 1, 1)
    if nm.startswith("Lek_"):
        u = 1.0 - ease(t / 0.8)
        return (0, 0, 0), (0, 0, 0), (max(u, 0.001), max(u, 0.001), max(u, 0.001))
    if nm in FALL:
        F = FALL[nm]
        u = (t - F["d0"]) / F["dur"]
        if u <= 0:
            return (0, 0, 0), (0, 0, 0), (1, 1, 1)
        u = min(u, 1.0)
        v = ease_in(u)
        h = ease(u * 1.15)
        # eerst even trillen, dan wegvallen: Y (stroomafwaarts) lineair-uitlopend, Z met zwaartekracht tot de vloer
        py = F["dy"] * (1 - (1 - u) ** 2)
        pz = F["rest_z"] * ease_in(min(1.0, u * 1.05))
        # stuiter bij de landing
        bounce = 0.0
        if u > 0.85:
            w = (u - 0.85) / 0.15
            bounce = 0.35 * math.sin(w * math.pi) * (1 - w)
        return (F["dx"] * u, py, pz + bounce), tuple(r * h for r in F["rot"]), (1, 1, 1)
    return (0, 0, 0), (0, 0, 0), (1, 1, 1)


anim_names = [n for n in meshes if n.startswith(("Kraak_", "Lek_", "Blok_", "Pijler_", "Poort_", "Hijs_", "Loopbrug"))]
bake("Kraken", 5.0, kraken, anim_names)
bake("Breken", 6.0, breken, anim_names)
scene.frame_start, scene.frame_end = 0, 180

# ------------------------------------------------------------------ opslaan en exporteren
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "dam.blend"))
stats = {"triangles": 0, "objects": len(meshes), "per_material": {}, **MESHY_STATS}
for ob in meshes.values():
    ob.data.calc_loop_triangles()
    stats["triangles"] += len(ob.data.loop_triangles)
    for t in ob.data.loop_triangles:
        mn = MATS[t.material_index]
        stats["per_material"][mn] = stats["per_material"].get(mn, 0) + 1
json.dump(stats, open(os.path.join(OUT, "dam_stats.json"), "w"), indent=1)
print("STATS", stats)
# Voor de .glb: de foto-PBR-knopen zijn voor Blender; Godot en de viewer hangen de maps zelf aan (zie assets/textures/dam)
for mname, m in M.items():
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type in ("TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR", "VERTEX_COLOR", "MIX", "UVMAP", "TEX_COORD"):
            nt.nodes.remove(n)
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dam.glb"), export_format="GLB", export_apply=True, export_yup=True,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_optimize_animation_size=False, export_vertex_color="ACTIVE",
                          export_active_vertex_color_when_no_material=True, export_tangents=False)
