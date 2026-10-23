"""Kazerne voor Bloedjungle: houten barak 4,4 x 3,2 m met golfplaten dak, deur, ramen met luiken, bord, vlag en zandzakken.
De deur zit aan de -Y kant in Blender (= +Z in Godot). 1 eenheid = 1 meter, grond = 0."""
import math, sys, os, random
import bpy, bmesh
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
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
    r = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=0.5)
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
boards(-HW, -HD, -HW, HD, Z0, H, skip=(0.9, 1.9, 0.9, 1.7))
boards(HW, -HD, HW, HD, Z0, H, skip=(0.9, 1.9, 0.9, 1.7))
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
    box("Plank1", (0, -HD - 0.035, z), (W + 0.1, 0.04, 0.07))
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
    top = Vector((0, 0, RZ + 0.7)); edge = Vector((0, sy * (HD + OV), RZ - 0.05))
    d = edge - top; ln = d.length
    mid = (top + edge) / 2
    tilt = sy * -math.atan2(d.z, abs(d.y)) * -1
    box("Dak", (0, mid.y, mid.z), (W + 2 * OV, ln, 0.06), (tilt, 0, 0))
    n = int((W + 2 * OV) / 0.22)
    for i in range(n):
        xx = -(W / 2 + OV) + (i + 0.5) * (W + 2 * OV) / n
        box("Dakrib", (xx, mid.y, mid.z + 0.035), (0.07, ln, 0.04), (tilt, 0, 0))
box("Dakrib", (0, 0, RZ + 0.74), (W + 2 * OV + 0.1, 0.18, 0.1))
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
box("Donker", (0, -HD - 0.08, H + 0.0), (1.6, 0.05, 0.34))
box("Goud", (0, -HD - 0.11, H + 0.0), (1.3, 0.03, 0.07))
box("Goud", (0, -HD - 0.11, H + 0.11), (1.3, 0.03, 0.025))
# vlaggenmast met vlag
box("Metaal", (HW + 0.15, -HD + 0.1, 1.9), (0.06, 0.06, 3.8))
box("Vlag", (HW + 0.55, -HD + 0.1, 3.5), (0.75, 0.02, 0.45))
# zandzakken bij de deur
for sx in (-1, 1):
    for row in range(2):
        for i in range(2 - row):
            blob("Zak", (sx * (0.95 + 0.4 * i + 0.2 * row), -HD - 0.55, 0.28 + row * 0.25), (0.62, 0.36, 0.24), rnd.uniform(-0.2, 0.2) + 1.57)
# houten stoep voor de deur
box("Plank1", (0, -HD - 0.3, 0.14), (1.5, 0.6, 0.06))

for k, bm in bms.items():
    me = bpy.data.meshes.new(k)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(M[k])
    scene.collection.objects.link(bpy.data.objects.new("Kazerne_" + k, me))

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "kazerne.glb"), export_format="GLB", export_apply=True, export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "kazerne.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
print("TRIS", tris)
