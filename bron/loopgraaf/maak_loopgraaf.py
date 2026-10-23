"""Loopgraaf voor Bloedjungle: uitgegraven put (4.8 x 1.4 m, 0.95 m diep) met plankenwanden, looprooster,
ladder, aarden rand en zandzakken. Lange as = Blender X (= Godot X). Z = omhoog, grondniveau = 0."""
import math, sys, os, random
import bpy, bmesh
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rnd = random.Random(11)

def mat(name, color, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m

M = {
    "modder": mat("Modder", (0.16, 0.12, 0.08)),
    "aarde": mat("Aarde", (0.36, 0.27, 0.17)),
    "aarde2": mat("AardeDonker", (0.27, 0.20, 0.12)),
    "hout1": mat("Hout1", (0.40, 0.30, 0.18)),
    "hout2": mat("Hout2", (0.33, 0.25, 0.15)),
    "hout3": mat("Hout3", (0.45, 0.35, 0.22)),
    "balk": mat("Balk", (0.26, 0.19, 0.11)),
    "zak1": mat("Zak1", (0.52, 0.46, 0.30)),
    "zak2": mat("Zak2", (0.45, 0.40, 0.26)),
    "metaal": mat("Metaal", (0.20, 0.20, 0.19), 0.45, 0.7),
    "kist": mat("Kist", (0.28, 0.32, 0.18)),
}
bms = {k: bmesh.new() for k in M}

def box(k, loc, size, rot=(0, 0, 0)):
    bm = bms[k]
    r = bmesh.ops.create_cube(bm, size=1)
    verts = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=verts)
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(bm, verts=verts, vec=loc)

def blob(k, loc, size, rot=(0, 0, 0), seg=8, ring=5):
    bm = bms[k]
    r = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=0.5)
    verts = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=verts)
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(bm, verts=verts, vec=loc)

LX, LY, D = 2.35, 0.65, 0.95   # halve lengte, halve breedte, diepte
WOOD = ["hout1", "hout2", "hout3"]

# modderige bodem en aarden achterwand onder de planken
box("modder", (0, 0, -D - 0.02), (2 * LX, 2 * LY, 0.06))

# looprooster: twee lagen langsbalken met dwarslatten
for s in (-0.38, 0.38):
    box("balk", (0, s, -D + 0.07), (2 * LX - 0.3, 0.1, 0.1))
x = -LX + 0.25
while x < LX - 0.2:
    box(rnd.choice(WOOD), (x, rnd.uniform(-0.02, 0.02), -D + 0.15), (0.2, 1.0, 0.045), (0, 0, rnd.uniform(-0.05, 0.05)))
    x += 0.235

# plankenwanden: lange kanten
for s_ in (-1, 1):
    box("modder", (0, s_ * (LY - 0.005), -D / 2 - 0.01), (2 * LX, 0.03, D - 0.04))
    box("modder", (s_ * (LX - 0.005), 0, -D / 2 - 0.01), (0.03, 2 * LY, D - 0.04))
for s in (-1, 1):
    y = s * (LY - 0.04)
    x = -LX + 0.1
    while x < LX - 0.05:
        h = D + rnd.uniform(-0.05, 0.06)
        box(rnd.choice(WOOD), (x, y, -D + h / 2 + 0.0), (0.2, 0.06, h), (rnd.uniform(-0.01, 0.01), 0, 0))
        x += 0.215
    # palen, dwarsbalken en bovenrand
    px = -LX + 0.12
    while px < LX:
        box("balk", (px, s * (LY - 0.12), -D / 2 + 0.05), (0.14, 0.14, D + 0.12))
        px += 1.15
    box("balk", (0, s * (LY - 0.1), -0.05), (2 * LX, 0.14, 0.1))
    box("balk", (0, s * (LY - 0.1), -D * 0.55), (2 * LX, 0.1, 0.08))

# plankenwanden: korte kanten
for s in (-1, 1):
    x = s * (LX - 0.04)
    y = -LY + 0.14
    while y < LY - 0.1:
        h = D + rnd.uniform(-0.04, 0.05)
        box(rnd.choice(WOOD), (x, y, -D + h / 2), (0.06, 0.2, h))
        y += 0.215
    box("balk", (s * (LX - 0.1), 0, -0.05), (0.14, 2 * LY, 0.1))

# ladder op de linker korte kant
for yy in (-0.22, 0.22):
    box("hout3", (-LX + 0.13, yy, -D / 2 + 0.2), (0.06, 0.06, D + 0.5), (0, 0.12, 0))
for i in range(5):
    box("hout3", (-LX + 0.15 - i * 0.012, 0, -D + 0.18 + i * 0.2), (0.05, 0.5, 0.05))

# aarden rand rond de put: afdekking van de naad met de grond
def ring_dirt(x0, x1, y0, y1, n):
    for _ in range(n):
        px = rnd.uniform(x0, x1); py = rnd.uniform(y0, y1)
        blob(rnd.choice(["aarde", "aarde2"]), (px, py, 0.02), (rnd.uniform(0.4, 0.65), rnd.uniform(0.28, 0.42), rnd.uniform(0.14, 0.24)),
             (0, 0, rnd.uniform(0, 3.14)), 7, 4)
for s in (-1, 1):
    ring_dirt(-LX - 0.3, LX + 0.3, s * (LY + 0.22), s * (LY + 0.5), 22)
    ring_dirt(s * (LX + 0.22), s * (LX + 0.5), -LY, LY, 5)
    box("aarde2", (0, s * (LY + 0.16), 0.0), (2 * LX + 0.8, 0.34, 0.04))
    box("aarde2", (s * (LX + 0.16), 0, 0.0), (0.34, 2 * LY, 0.04))

# opgeworpen aarden wal aan de achterkant (-Y) en zandzakken aan de voorkant (+Y)
for i in range(16):
    px = -LX - 0.2 + i * (2 * LX + 0.4) / 15
    blob("aarde" if i % 2 else "aarde2", (px, -LY - 0.8, 0.0), (0.8, 0.55, 0.36 + 0.1 * math.sin(i * 1.3)), (0, 0, rnd.uniform(0, 3)), 8, 5)
for row in range(2):
    n = 8 - row
    for i in range(n):
        px = -LX + 0.1 + (i + 0.5 * row) * (2 * LX - 0.1) / (n - 0.5 * row) + 0.02
        blob("zak1" if (i + row) % 2 else "zak2", (px, LY + 0.3, 0.1 + row * 0.2 + 0.02),
             (0.62, 0.36, 0.22), (0, 0, rnd.uniform(-0.12, 0.12)), 8, 5)

# munitiekist op het rooster en een jerrycan als detail
box("kist", (1.4, 0.3, -D + 0.34), (0.5, 0.32, 0.26))
box("balk", (1.4, 0.3, -D + 0.48), (0.52, 0.34, 0.03))
box("metaal", (1.9, -0.3, -D + 0.3), (0.2, 0.12, 0.28))

for k, bm in bms.items():
    me = bpy.data.meshes.new(k)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(M[k])
    o = bpy.data.objects.new("Loopgraaf_" + k, me)
    scene.collection.objects.link(o)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "loopgraaf.glb"), export_format="GLB", export_apply=True, export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "loopgraaf.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
print("TRIS", tris)
