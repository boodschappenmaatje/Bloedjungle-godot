"""Houten wachttoren voor Bloedjungle. Middelpunt op de grond = (0,0,0), platform op 5,3 m, klimladder aan de +X zijde
(Blender X = Godot X). Een speler kan de trap op en over het platform lopen. 1 eenheid = 1 meter."""
import math, sys, os, random
import bpy, bmesh
from mathutils import Matrix, Vector
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vq2_common import pbr, finish_mesh, corrugated, bolt, export_and_save

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else str(Path(__file__).parent / "uit"))
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(5)

def mat(name, color, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m

M = {
    "paal": mat("Paal", (0.30, 0.22, 0.13)),
    "plank1": mat("Plank1", (0.42, 0.31, 0.19)),
    "plank2": mat("Plank2", (0.36, 0.27, 0.16)),
    "plank3": mat("Plank3", (0.48, 0.37, 0.23)),
    "dak": mat("Dak", (0.45, 0.24, 0.14), 0.6, 0.5),
    "dakrib": mat("Dakrib", (0.36, 0.19, 0.11), 0.6, 0.5),
    "metaal": mat("Metaal", (0.18, 0.18, 0.17), 0.45, 0.7),
    "zak": mat("Zak", (0.50, 0.44, 0.28)),
    "lamp": mat("Lamp", (0.9, 0.8, 0.45), 0.3),
    "kist": mat("Kist", (0.27, 0.31, 0.18)),
}
bms = {k: bmesh.new() for k in M}
PL = ["plank1", "plank2", "plank3"]

def beam(k, p0, p1, w=0.14, w2=None):
    """Balk met vierkante doorsnede tussen twee punten."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    bm = bms[k]
    r = bmesh.ops.create_cube(bm, size=1)
    v = r["verts"]
    bmesh.ops.scale(bm, vec=(w, w2 or w, L), verts=v)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm, verts=v, cent=(0, 0, 0), matrix=q.to_matrix())
    bmesh.ops.translate(bm, verts=v, vec=(p0 + p1) / 2)

def box(k, loc, size, rot=(0, 0, 0)):
    bm = bms[k]
    r = bmesh.ops.create_cube(bm, size=1)
    v = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=v)
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(bm, verts=v, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(bm, verts=v, vec=loc)

def blob(k, loc, size, rot=0.0):
    bm = bms[k]
    r = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=6, radius=0.5)
    v = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=v)
    bmesh.ops.rotate(bm, verts=v, cent=(0, 0, 0), matrix=Matrix.Rotation(rot, 3, "Z"))
    bmesh.ops.translate(bm, verts=v, vec=loc)

H = 5.3           # bovenkant platform
FB, FT = 1.15, 0.95  # halve breedte onder / boven (poten staan iets schuin)

# ---- poten, horizontale ringen en kruisverbanden
legs = {}
for sx in (-1, 1):
    for sy in (-1, 1):
        legs[(sx, sy)] = ((sx * FB, sy * FB, -0.15), (sx * FT, sy * FT, H - 0.05))
        beam("paal", *legs[(sx, sy)], w=0.24)
def at(sx, sy, z):
    a, b = legs[(sx, sy)]
    t = (z - a[2]) / (b[2] - a[2])
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, z)
LEV = [0.5, 2.0, 3.6, H - 0.25]
for z in LEV:
    for (a, b) in [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]:
        beam("paal", at(*a, z), at(*b, z), w=0.13)
for i in range(len(LEV) - 1):
    z0, z1 = LEV[i], LEV[i + 1]
    flip = i % 2
    for (a, b) in [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]:
        if flip:
            beam("paal", at(*a, z0), at(*b, z1), w=0.09)
        else:
            beam("paal", at(*b, z0), at(*a, z1), w=0.09)

# ---- platform: dwarsbalken en dek
for y in (-1.0, -0.5, 0.0, 0.5, 1.0):
    beam("paal", (-1.3, y, H - 0.14), (1.3, y, H - 0.14), w=0.12, w2=0.12)
x = -1.3
while x < 1.3:
    box(rnd.choice(PL), (x + 0.1, rnd.uniform(-0.01, 0.01), H - 0.05), (0.19, 2.7, 0.10), (0, 0, rnd.uniform(-0.01, 0.01)))
    x += 0.205
# vloerluik/laag kistje en lantaarn
box("kist", (-0.78, -0.78, H + 0.17), (0.5, 0.4, 0.28))
box("paal", (-0.78, -0.78, H + 0.33), (0.52, 0.42, 0.04))

# ---- wanden en reling: plankenborstwering aan 3 zijden, aan de trapzijde een opening
def panel(p0, p1, z0, z1):
    p0, p1 = Vector(p0), Vector(p1)
    n = max(1, int((p1 - p0).length / 0.21))
    for i in range(n):
        c = p0 + (p1 - p0) * ((i + 0.5) / n)
        w = (p1 - p0).length / n - 0.012
        a = math.atan2((p1 - p0).y, (p1 - p0).x)
        h = z1 - z0 + rnd.uniform(-0.03, 0.03)
        box(rnd.choice(PL), (c.x, c.y, z0 + h / 2), (w, 0.06, h), (0, 0, a))
R = 1.27
panel((-R, -R), (R, -R), H, H + 0.9)       # zuid-wand (-Y)
panel((-R, R), (R, R), H, H + 0.9)         # noord-wand (+Y)
panel((-R, -R), (-R, R), H, H + 0.9)       # achterwand (-X)
for sy in (-1, 1):
    beam("paal", (-R, sy * R, H + 0.9), (R, sy * R, H + 0.9), w=0.1, w2=0.12)
beam("paal", (-R, -R, H + 0.9), (-R, R, H + 0.9), w=0.12)
# voorkant (+X): lage reling met opening in het midden voor de trap
for sy in (-1, 1):
    beam("paal", (R, sy * 0.55, H + 1.0), (R, sy * R, H + 1.0), w=0.09)
    beam("paal", (R, sy * 0.55, H + 0.5), (R, sy * R, H + 0.5), w=0.07)
    beam("paal", (R, sy * 0.55, H), (R, sy * 0.55, H + 1.05), w=0.1)

# ---- dakpalen en dak (twee hellende platen met ribbels en nok)
ROOF_Z = H + 2.3
for sx in (-1, 1):
    for sy in (-1, 1):
        beam("paal", (sx * R, sy * R, H), (sx * R, sy * R, ROOF_Z), w=0.15)
OV = 0.5
for sy in (-1, 1):
    corrugated(bms["dak"],2*(R+OV),R+OV,ROOF_Z+.75,ROOF_Z-.05,sy)
    tilt=-sy*math.atan2(.8,R+OV)
    for xx in (-.9,.9):
        box("dakrib",(xx,sy*(R+OV)/2,ROOF_Z+.37),(.028,math.hypot(R+OV,.8),.035),(tilt,0,0))
        for f in (.15,.6,.94):
            bolt(bms["dakrib"],(xx,sy*(R+OV)*f,ROOF_Z+.75-.8*f+.03),radius=.022)
    box("dakrib",(0,sy*(R+OV),ROOF_Z-.09),(2*(R+OV),.07,.11))
    # All drainage and roof hardware deliberately stay in the two hideable roof groups.
    box("dakrib",(-R-.17,sy*(R+OV),ROOF_Z-.28),(.07,.07,.37))
for sy in (-1,1):
    box("dakrib",(0,sy*.07,ROOF_Z+.77),(2*(R+OV)+.1,.18,.035),(-sy*.4,0,0))
# gevelbalken en kleine lamp
for sx in (-1, 1):
    beam("paal", (sx * R, -R, ROOF_Z), (sx * R, R, ROOF_Z), w=0.12)
    beam("paal", (sx * R, -R, ROOF_Z), (sx * R, 0, ROOF_Z + 0.65), w=0.08)
    beam("paal", (sx * R, R, ROOF_Z), (sx * R, 0, ROOF_Z + 0.65), w=0.08)
beam("metaal", (0.9, 0, ROOF_Z), (0.9, 0, ROOF_Z - 0.18), w=0.03)
box("lamp", (0.9, 0, ROOF_Z - 0.3), (0.16, 0.16, 0.2))

# ---- klimladder tegen de +X zijde: twee leuningen, sporten en een paar beugels
LX0, LX1 = 1.75, 1.32          # x onderaan (grond) en bovenaan (platform), de ladder staat iets schuin
LZT = H + 0.95                 # de leuningen steken boven het platform uit
def lx(z):
    return LX0 + (LX1 - LX0) * min(1.0, z / H)
for sy in (-1, 1):
    beam("paal", (lx(0), sy * 0.34, -0.05), (lx(H), sy * 0.34, H), w=0.09, w2=0.07)
    beam("paal", (lx(H), sy * 0.34, H), (lx(H), sy * 0.34, LZT), w=0.09, w2=0.07)
z = 0.3
while z < H + 0.8:
    box("plank3", (lx(z), 0, z), (0.07, 0.68, 0.06))
    z += 0.3
# bevestiging aan de poten
for zz in (1.0, 2.6, 4.2):
    for sy in (-1, 1):
        beam("metaal", (lx(zz), sy * 0.34, zz), (1.1 - 0.15 * zz / H, sy * 0.9, zz), w=0.05, w2=0.05)

# ---- zandzakken rond de voet (open bij de trap)
for ang in range(0, 360, 24):
    a = math.radians(ang)
    if abs(math.degrees(math.atan2(math.sin(a), math.cos(a)))) < 28:
        continue
    r = 1.95
    blob("zak", (math.cos(a) * r, math.sin(a) * r, 0.12), (0.62, 0.36, 0.24), a + math.pi / 2)
    if ang % 48 == 0:
        blob("zak", (math.cos(a + 0.2) * (r - 0.05), math.sin(a + 0.2) * (r - 0.05), 0.33), (0.58, 0.34, 0.22), a + 1.4)

# VQ2 structural joinery: galvanised shoes, straps, hex fasteners and deck rim.
for sx in (-1,1):
    for sy in (-1,1):
        box("metaal",(sx*FB,sy*FB,.07),(.30,.30,.16))
        for zz in (2.0,3.6,H-.25):
            px,py,_=at(sx,sy,zz)
            box("metaal",(px,py-sy*.075,zz),(.19,.025,.26))
            for dz in (-.075,.075):
                bolt(bms["metaal"],(px,py-sy*.095,zz+dz),(0,-sy,0))
        # Knee braces form a believable support between posts and roof beams.
        beam("paal",(sx*R,sy*R,H+1.65),(sx*.72,sy*R,ROOF_Z-.02),w=.085)
for sy in (-1,1):
    beam("paal",(-R-.07,sy*(R+.03),H-.12),(R+.07,sy*(R+.03),H-.12),w=.13,w2=.20)
    for xx in (-1.0,-.55,0,.55,1.0):
        bolt(bms["metaal"],(xx,sy*(R+.11),H-.12),(0,sy,0),.017)
    for zz in (1.0,2.6,4.2):
        bolt(bms["metaal"],(lx(zz)+.055,sy*.34,zz),(1,0,0),.022)
for zz in (.3,.6,.9,1.2,1.5,1.8,2.1,2.4,2.7,3.0,3.3,3.6,3.9,4.2,4.5,4.8,5.1):
    # Non-slip treads fitted to the existing +X climbing route, without narrowing its opening.
    box("metaal",(lx(zz)+.04,0,zz+.032),(.025,.61,.014))

families={"paal":"timber","plank1":"timber","plank2":"timber","plank3":"timber",
          "dak":"roof","dakrib":"roof","metaal":"steel","zak":"canvas","kist":"olive"}
for k,family in families.items():
    M[k]=pbr(family)

for k, bm in bms.items():
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    me = bpy.data.meshes.new(k)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(M[k])
    obj=bpy.data.objects.new("Toren_"+k,me); scene.collection.objects.link(obj)
    finish_mesh(obj,families.get(k,"steel"),0 if k=="dak" else .006)
export_and_save(OUT,"wachttoren")
