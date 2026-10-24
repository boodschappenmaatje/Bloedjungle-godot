"""Kazerne voor Bloedjungle: houten barak 4,4 x 3,2 m met golfplaten dak, deur, ramen met luiken, bord, vlag en zandzakken.
De deur zit aan de -Y kant in Blender (= +Z in Godot). 1 eenheid = 1 meter, grond = 0."""
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
rnd = random.Random(21)

def mat(name, color, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m

M = {
    "Wand1": mat("Wand1", (0.34, 0.38, 0.22)),
    "Wand2": mat("Wand2", (0.30, 0.34, 0.20)),
    "Wand3": mat("Wand3", (0.38, 0.42, 0.25)),
    "Plank1": mat("Plank1", (0.42, 0.31, 0.19)),
    "Paal": mat("Paal", (0.26, 0.19, 0.11)),
    "Dak": mat("Dak", (0.36, 0.40, 0.30), 0.6, 0.5),
    "Dakrib": mat("Dakrib", (0.28, 0.32, 0.23), 0.6, 0.5),
    "Beton": mat("Beton", (0.42, 0.42, 0.39)),
    "Zak": mat("Zak", (0.50, 0.44, 0.28)),
    "Donker": mat("Donker", (0.05, 0.045, 0.04)),
    "Goud": mat("Goud", (0.78, 0.62, 0.15), 0.4, 0.3),
    "Vlag": mat("Vlag", (0.24, 0.42, 0.17)),
    "Metaal": mat("Metaal", (0.45, 0.45, 0.42), 0.4, 0.8),
}
bms = {k: bmesh.new() for k in M}
WAND = ["Wand1", "Wand2", "Wand3"]

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

W, D, H = 4.4, 3.2, 2.2   # breedte (x), diepte (y), muurhoogte
HW, HD = W / 2, D / 2

# vloerplaat
box("Beton", (0, 0, 0.08), (W + 0.2, D + 0.2, 0.16))

def boards(x0, y0, x1, y1, z0, z1, skip=None):
    """Verticale planken tussen twee punten (op de grond), met optioneel een gat [t0,t1] langs de lengte."""
    p0, p1 = Vector((x0, y0)), Vector((x1, y1))
    L = (p1 - p0).length
    n = int(L / 0.2)
    a = math.atan2(p1.y - p0.y, p1.x - p0.x)
    for i in range(n):
        t = (i + 0.5) / n
        c = p0 + (p1 - p0) * t
        d = L * t
        zz0, zz1 = z0, z1
        if skip:
            s0, s1, lo, hi = skip   # gat tussen s0..s1 (afstand langs de wand), alleen planken onder lo/boven hi bestaan nog
            if s0 <= d <= s1:
                if lo is not None and hi is not None:
                    # twee stukken: onder het gat en boven het gat
                    box(rnd.choice(WAND), (c.x, c.y, (z0 + lo) / 2 + 0.0), (L / n - 0.012, 0.06, lo - z0), (0, 0, a)) if lo > z0 else None
                    box(rnd.choice(WAND), (c.x, c.y, (hi + z1) / 2), (L / n - 0.012, 0.06, z1 - hi), (0, 0, a))
                    continue
        h = zz1 - zz0 + rnd.uniform(-0.01, 0.01)
        box(rnd.choice(WAND), (c.x, c.y, zz0 + h / 2), (L / n - 0.012, 0.06, h), (0, 0, a))

Z0 = 0.16
# achterwand (+Y) en zijwanden (+/-X)
boards(-HW, HD, HW, HD, Z0, H)
boards(-HW, -HD, -HW, HD, Z0, H, skip=(1.1, 2.1, 0.9, 1.7))
boards(HW, -HD, HW, HD, Z0, H, skip=(1.1, 2.1, 0.9, 1.7))
# voorwand (-Y) met deur van 1,1 m breed en 1,7 m hoog in het midden
boards(-HW, -HD, -0.55, -HD, Z0, H)
boards(0.55, -HD, HW, -HD, Z0, H)
box(rnd.choice(WAND), (0, -HD, (1.7 + H) / 2 + 0.08), (1.1, 0.06, H - 1.7 - 0.16))
box("Donker", (0, -HD + 0.12, 0.16 + 0.85), (1.1, 0.04, 1.7))   # donkere deuropening
# deurkozijn
for s in (-1, 1):
    box("Paal", (s * 0.58, -HD - 0.03, 0.16 + 0.88), (0.1, 0.1, 1.78))
box("Paal", (0, -HD - 0.03, 0.16 + 1.74), (1.26, 0.1, 0.1))
# hoekpalen en horizontale liggers
for sx in (-1, 1):
    for sy in (-1, 1):
        box("Paal", (sx * HW, sy * HD, H / 2 + 0.1), (0.14, 0.14, H + 0.1))
for z in (0.9, 1.6, H - 0.05):
    if z > 1.9:
        box("Plank1", (0, -HD - 0.035, z), (W + 0.1, 0.04, 0.07))
    else:
        for sx in (-1,1):
            box("Plank1",(sx*(HW+.55)/2,-HD-.035,z),(HW-.55,.04,.07))
    box("Plank1", (0, HD + 0.035, z), (W + 0.1, 0.04, 0.07))
    for sx in (-1, 1):
        box("Plank1", (sx * (HW + 0.035), 0, z), (0.04, D + 0.1, 0.07))
# ramen met luiken in de zijwanden
for sx in (-1, 1):
    box("Donker", (sx * (HW + 0.0), 0.0, 1.3), (0.04, 0.8, 0.8))
    box("Plank1", (sx * (HW + 0.05), 0.0, 1.3 - 0.44), (0.05, 0.9, 0.06))
    box("Plank1", (sx * (HW + 0.05), 0.0, 1.3 + 0.44), (0.05, 0.9, 0.06))
    for sy in (-1, 1):
        box("Plank1", (sx * (HW + 0.07), sy * 0.52, 1.3), (0.04, 0.2, 0.86), (0, 0, sy * sx * 0.25))

# dak: twee hellende golfplaten langs de x-as met nok, overstek en ribbels
RZ = H + 0.1
OV = 0.45
for sy in (-1, 1):
    corrugated(bms["Dak"], W+2*OV, HD+OV, RZ+.7, RZ-.05, sy)
    tilt = -sy*math.atan2(.75, HD+OV)
    # Sheet laps, screwed seams, and a real eave/gutter shadow.
    for xx in (-1.76, 0, 1.76):
        box("Dakrib", (xx, sy*(HD+OV)*.5, RZ+.325), (.025, math.hypot(HD+OV,.75), .035), (tilt,0,0))
        for f in (.18,.65,.94):
            bolt(bms["Metaal"], (xx,sy*(HD+OV)*f,RZ+.7-.75*f+.035), radius=.019)
    box("Dakrib", (0,sy*(HD+OV),RZ-.08),(W+2*OV,.07,.09))
    box("Paal", (0,sy*HD,H+.04),(W+.08,.09,.16))
for sy in (-1,1):
    box("Dakrib", (0,sy*.065,RZ+.72),(W+2*OV+.08,.16,.035),(-sy*.33,0,0))
# gevelvullingen (driehoek) voor en achter
def prism(k, pts_yz, x0, x1):
    bm = bms[k]
    left = [bm.verts.new((x0, y, z)) for y, z in pts_yz]
    right = [bm.verts.new((x1, y, z)) for y, z in pts_yz]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    n = len(pts_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([left[i], left[j], right[j], right[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
prism("Wand2", [(-HD, H - 0.05), (HD, H - 0.05), (HD, RZ + 0.0), (0, RZ + 0.64), (-HD, RZ + 0.0)], -W / 2 - 0.01, W / 2 + 0.01)

# bord boven de deur
box("Donker", (0, -HD - 0.08, 2.035), (1.6, 0.05, 0.21))
box("Goud", (0, -HD - 0.11, 2.13), (1.5, 0.015, 0.012))
font = bpy.data.curves.new("Kazerne naamplaat", "FONT")
font.body = "KAZERNE"; font.align_x = "CENTER"; font.size = .155; font.extrude = .001
sign = bpy.data.objects.new("Kazerne_naamplaat", font); scene.collection.objects.link(sign)
sign.location = (0,-HD-.115,1.975); sign.rotation_euler.x = math.pi/2
font.materials.append(M["Goud"])
# vlaggenmast met vlag
box("Metaal", (HW + 0.15, -HD + 0.1, 1.9), (0.06, 0.06, 3.8))
for i in range(12):
    xx=HW+.175+i*.0625
    box("Vlag", (xx,-HD+.1+.04*math.sin(i*.55),3.5-.015*i/12),(.063,.012,.45-.025*i/12))
# zandzakken bij de deur
for sx in (-1, 1):
    for row in range(2):
        for i in range(2 - row):
            blob("Zak", (sx * (0.95 + 0.4 * i + 0.2 * row), -HD - 0.55, 0.28 + row * 0.25), (0.62, 0.36, 0.24), rnd.uniform(-0.2, 0.2) + 1.57)
# houten stoep voor de deur
box("Plank1", (0, -HD - 0.3, 0.14), (1.5, 0.6, 0.06))

# VQ2: recessed sill, ventilation louvers, door hardware and localized foundation grime.
for sx in (-1,1):
    box("Paal", (sx*(HW+.025),0,.25),(.08,D,.11))
    for yy in (-.39,.39):
        box("Plank1", (sx*(HW+.075),yy,1.3),(.07,.06,.88))
    box("Plank1", (sx*(HW+.09),0,.86),(.15,1.02,.08))
    for yy in (-.21,0,.21):
        box("Metaal", (sx*(HW+.05),yy,1.31),(.025,.018,.72))
    for zz in (.43,1.35,1.9):
        bolt(bms["Metaal"],(sx*.58,-HD-.09,zz),(0,-1,0))
    for xx in (-1.6,-.95,.95,1.6):
        bolt(bms["Metaal"],(xx,HD+.055,1.62),(0,1,0),.016)
for xx in (-1.6,1.6):
    box("Donker", (xx,-HD-.04,1.95),(.42,.025,.20))
    for zz in (1.88,1.93,1.98,2.03):
        box("Metaal", (xx,-HD-.065,zz),(.40,.04,.018),(.2,0,0))
box("Donker",(0,-HD+.09,.22),(1.06,.05,.08))
for i in range(4):
    box("Wand2",(-.43+i*.18,-HD+.085,.99),(.172,.05,1.6))
for zz in (.55,1.43):
    box("Metaal",(-.46,-HD+.048,zz),(.13,.025,.04))
box("Metaal",(.13,-HD+.04,1.02),(.025,.04,.16))
for i in range(5):
    box("Plank1",(-.6+i*.3,-HD-.29,.183),(.285,.58,.035))

families = {"Wand1":"painted_timber","Wand2":"painted_timber","Wand3":"painted_timber",
            "Plank1":"timber","Paal":"timber","Dak":"roof","Dakrib":"roof",
            "Beton":"concrete","Zak":"canvas","Metaal":"steel","Vlag":"canvas"}
for k,family in families.items():
    M[k] = pbr(family, (.7,.8,.55) if k=="Vlag" else (1,1,1))

for k, bm in bms.items():
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(k)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(M[k])
    obj=bpy.data.objects.new("Kazerne_" + k, me); scene.collection.objects.link(obj)
    finish_mesh(obj, families.get(k,"steel"), 0 if k=="Dak" else .006)
export_and_save(OUT,"kazerne")
