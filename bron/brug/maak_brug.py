"""Houten brug voor Bloedjungle: maak_brug.py uit/  ->  uit/brug.blend en uit/brug.glb (1 eenheid = 1 meter).
De brug ligt langs Blender-Y (Godot -Z), 12 m lang, dek 5 m breed zodat de tank (3,9 m) en de jeep erover kunnen.
Bovenkant dek op z = 0,03 (de grond in het spel is z = 0), onder het dek balken en palen die in de bedding staan,
langs beide kanten een leuning. Materialen heten Hout1/Hout2/Hout3/Balk/Paal; het spel hangt er foto-texturen aan (Kit.skin 'brug')."""
import math, sys, os, random
import bpy, bmesh
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
random.seed(4)

L = 12.0       # lengte
DW = 5.0       # breedte dek
TOP = 0.03     # bovenkant dek


def mat(name, color, rough=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    return m


M = {
    "Hout1": mat("Hout1", (0.55, 0.40, 0.25)),
    "Hout2": mat("Hout2", (0.46, 0.33, 0.20)),
    "Hout3": mat("Hout3", (0.62, 0.46, 0.30)),
    "Balk": mat("Balk", (0.30, 0.21, 0.13)),
    "Paal": mat("Paal", (0.24, 0.17, 0.10)),
}
B = {k: bmesh.new() for k in M}


def box(k, loc, size, rot=(0, 0, 0)):
    r = bmesh.ops.create_cube(B[k], size=1)
    v = r["verts"]
    bmesh.ops.scale(B[k], vec=size, verts=v)
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(B[k], verts=v, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(B[k], verts=v, vec=loc)


def cyl(k, loc, radius, depth, seg=8, rot=(0, 0, 0)):
    r = bmesh.ops.create_cone(B[k], cap_ends=True, segments=seg, radius1=radius, radius2=radius * 0.92, depth=depth)
    v = r["verts"]
    rm = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    bmesh.ops.rotate(B[k], verts=v, cent=(0, 0, 0), matrix=rm)
    bmesh.ops.translate(B[k], verts=v, vec=loc)


# ---- dek: losse planken met kleine verschillen
n = int(L / 0.4)
for i in range(n):
    y = -L / 2 + 0.2 + i * 0.4
    k = random.choice(["Hout1", "Hout2", "Hout3"])
    w = DW - random.uniform(0.0, 0.05)
    box(k, (random.uniform(-0.01, 0.01), y, TOP - 0.05 + random.uniform(-0.006, 0.006)), (w, 0.36, 0.1), (0, 0, random.uniform(-0.012, 0.012)))
# ---- onderbouw: langsbalken, dwarsbalken, palen met kruisverbanden
for x in (-1.8, 0.0, 1.8):
    box("Balk", (x, 0, -0.2), (0.3, L + 0.4, 0.3))
for i in range(7):
    y = -L / 2 + i * (L / 6)
    box("Balk", (0, y, -0.45), (DW + 0.5, 0.3, 0.28))
for y in (-3.2, 0.0, 3.2):
    for x in (-2.1, 2.1):
        cyl("Paal", (x, y, -0.65), 0.19, 1.7)
        box("Balk", (x, y, 0.1), (0.5, 0.5, 0.1))
    d = math.hypot(4.2, 0.9)
    ang = math.atan2(0.9, 4.2)
    box("Balk", (0, y, -0.9), (d, 0.12, 0.12), (0, -ang, 0))
    box("Balk", (0, y, -0.9), (d, 0.12, 0.12), (0, ang, 0))
# ---- leuningen: palen, bovenrail, middenrail, schoren
for sx in (-1, 1):
    x = sx * (DW / 2 + 0.2)
    for k in range(9):
        y = -L / 2 + 0.2 + k * (L - 0.4) / 8
        box("Paal", (x, y, 0.62), (0.2, 0.2, 1.24))
        box("Hout3", (x, y, 1.26), (0.26, 0.26, 0.05))
    box("Hout2", (x, 0, 1.12), (0.18, L, 0.14))
    box("Hout1", (x, 0, 0.62), (0.12, L, 0.1))
    for k in range(8):
        y = -L / 2 + 0.2 + (k + 0.5) * (L - 0.4) / 8
        box("Balk", (x, y, 0.36), (0.08, 0.08, 0.72), (0.6 * (1 if k % 2 else -1), 0, 0))
# ---- koppen: balken op de oevers en een helling van planken naar de grond
for sy in (-1, 1):
    box("Balk", (0, sy * (L / 2 + 0.2), -0.12), (DW + 0.6, 0.4, 0.4))
    for j in range(3):
        y = sy * (L / 2 + 0.55 + j * 0.4)
        box("Hout2", (0, y, TOP - 0.05 - 0.012 * (j + 1)), (DW - 0.1, 0.36, 0.1), (math.radians(-3 * sy), 0, 0))

root = bpy.data.objects.new("Brug", None)
scene.collection.objects.link(root)
for k, bm in B.items():
    me = bpy.data.meshes.new("Brug_" + k)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(M[k])
    ob = bpy.data.objects.new("Brug_" + k, me)
    scene.collection.objects.link(ob)
    ob.parent = root

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "brug.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "brug.glb"), export_format="GLB", export_apply=True, export_yup=True)
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
print("TRIS", tris)
