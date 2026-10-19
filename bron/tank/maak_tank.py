"""Low-poly tank voor Bloedjungle. Blender +Y = voorkant (wordt -Z in Godot), 1 eenheid = 1 meter."""
import math, sys, os
import bpy, bmesh
import numpy as np
from mathutils import Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------- camo-textuur ----------
def camo_image(size=256):
    rng = np.random.default_rng(7)
    def noise(scale):
        g = rng.random((size // scale + 2, size // scale + 2))
        y, x = np.mgrid[0:size, 0:size] / scale
        x0, y0 = x.astype(int), y.astype(int)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
        b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
        return a * (1 - fy) + b * fy
    n1 = noise(48) * 0.6 + noise(20) * 0.3 + noise(6) * 0.1
    n2 = noise(40) * 0.6 + noise(16) * 0.3 + noise(5) * 0.1
    base = np.array([0.30, 0.34, 0.18])   # olijfgroen (sRGB)
    dark = np.array([0.17, 0.20, 0.11])
    brown = np.array([0.36, 0.29, 0.18])
    img = np.tile(base, (size, size, 1))
    img[n1 > 0.58] = dark
    img[(n2 > 0.62) & (n1 <= 0.58)] = brown
    grain = (noise(2) - 0.5) * 0.06
    img = np.clip(img + grain[..., None], 0, 1)
    im = bpy.data.images.new("tank_camo", size, size)
    rgba = np.concatenate([img, np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, "tank_camo.png")
    im.file_format = "PNG"
    im.save()
    return im

def mat(name, color, rough=0.8, metal=0.0, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    return m

CAMO = mat("Camo", (0.3, 0.34, 0.18), 0.75, 0.05, camo_image())
GROEN = mat("Donkergroen", (0.20, 0.23, 0.13), 0.8)
RUPS = mat("Rups", (0.10, 0.10, 0.09), 0.9, 0.3)
WIEL = mat("Wiel", (0.22, 0.24, 0.16), 0.8)
RUBBER = mat("Rubber", (0.06, 0.06, 0.06), 0.95)
METAAL = mat("Metaal", (0.18, 0.18, 0.17), 0.45, 0.7)
GLAS = mat("Lamp", (0.85, 0.82, 0.6), 0.2)
HOUT = mat("Kist", (0.33, 0.27, 0.17), 0.85)

def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj

def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = loc
    return link(o, parent)

def prism_x(name, profile_yz, width, material, parent=None, loc=(0, 0, 0)):
    """Profiel in Y/Z (zijaanzicht), geëxtrudeerd over X (breedte, gecentreerd)."""
    bm = bmesh.new()
    left = [bm.verts.new((-width / 2, y, z)) for y, z in profile_yz]
    right = [bm.verts.new((width / 2, y, z)) for y, z in profile_yz]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    n = len(profile_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([left[i], left[j], right[j], right[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, loc)

def box(name, size, material, parent=None, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    return mesh_obj(name, bm, material, parent, loc)

def cyl(name, r1, r2, depth, material, axis="Z", segs=12, parent=None, loc=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(-math.pi / 2, 3, "X"))
    o = mesh_obj(name, bm, material, parent, loc, smooth)
    if smooth:
        o.data.set_sharp_from_angle(angle=math.radians(40))
    return o

def bevel(o, w=0.03, segs=1):
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = segs
    m.limit_method = "ANGLE"

# ---------- romp ----------
root = link(bpy.data.objects.new("Tank", None))

romp = prism_x("Romp", [(-3.0, 0.55), (3.05, 0.55), (3.45, 0.95), (3.1, 1.45), (-2.85, 1.45), (-3.15, 1.1)],
               2.3, CAMO, root)
bevel(romp, 0.04)
# achterdek met motorroosters
dek = box("Motordek", (1.9, 1.5, 0.12), GROEN, root, (0, -2.05, 1.5))
bevel(dek, 0.02)
for i in range(6):
    box(f"Rooster{i}", (1.7, 0.08, 0.04), METAAL, root, (0, -2.65 + i * 0.24, 1.57))

# rupsbanden + spatborden
for side, sx in (("L", -1), ("R", 1)):
    x = sx * 1.47
    rups = prism_x(f"Rups{side}", [(-3.3, 0.55), (-3.0, 0.12), (-2.6, 0.0), (2.75, 0.0), (3.2, 0.2), (3.55, 0.75),
                                  (3.3, 1.02), (-3.2, 1.02), (-3.45, 0.8)], 0.66, RUPS, root, (x, 0, 0))
    bevel(rups, 0.05)
    # schakels als ribbels op de zichtbare onderkant voor/achter
    for i in range(18):
        box(f"Schakel{side}{i}", (0.7, 0.07, 0.04), RUBBER, root, (x, -2.55 + i * 0.3, -0.005))
    # loopwielen aan de buitenkant
    for i in range(6):
        y = -2.35 + i * 0.93
        cyl(f"Wiel{side}{i}", 0.4, 0.4, 0.12, WIEL, "X", 14, root, (x + sx * 0.34, y, 0.42))
        cyl(f"Naaf{side}{i}", 0.13, 0.1, 0.06, METAAL, "X", 8, root, (x + sx * 0.42, y, 0.42))
    cyl(f"Tandwiel{side}", 0.36, 0.36, 0.14, METAAL, "X", 10, root, (x + sx * 0.34, -3.05, 0.62))
    cyl(f"Spanwiel{side}", 0.32, 0.32, 0.14, WIEL, "X", 12, root, (x + sx * 0.34, 3.2, 0.62))
    for i in range(3):
        cyl(f"Steunrol{side}{i}", 0.1, 0.1, 0.1, METAAL, "X", 8, root, (x + sx * 0.34, -1.6 + i * 1.5, 0.93))
    sb = prism_x(f"Spatbord{side}", [(-3.25, 1.06), (3.3, 1.06), (3.55, 0.9), (3.55, 0.84), (3.25, 1.0), (-3.25, 1.0)],
                 0.78, GROEN, root, (x + sx * 0.02, 0, 0))
    # opbergkisten op het spatbord
    for i, y in enumerate((-1.9, -0.6)):
        k = box(f"Kist{side}{i}", (0.55, 1.05, 0.38), HOUT if i else GROEN, root, (x, y, 1.26))
        bevel(k, 0.03)
    # koplampen
    cyl(f"Lamp{side}", 0.11, 0.11, 0.14, GLAS, "Y", 10, root, (sx * 0.85, 3.25, 1.3))
    box(f"Lampkap{side}", (0.3, 0.12, 0.05), METAAL, root, (sx * 0.85, 3.25, 1.43))
# reservewiel / brandstofvaten achter
for i, x in enumerate((-0.6, 0.6)):
    cyl(f"Vat{i}", 0.26, 0.26, 0.8, GROEN, "X", 12, root, (x, -3.2, 1.25))
# bestuurdersluik
cyl("Bestuurderluik", 0.3, 0.28, 0.08, GROEN, "Z", 12, root, (0.55, 2.25, 1.5))

# ---------- toren (draait om Z) ----------
toren = link(bpy.data.objects.new("Toren", None), root)
toren.location = (0, 0.2, 1.45)
koepel = cyl("TorenKoepel", 1.45, 1.12, 0.75, CAMO, "Z", 16, toren, (0, 0, 0.37))
koepel.scale = (0.95, 1.25, 1.0)
koepel.location = (0, -0.1, 0.37)
rand = cyl("TorenRing", 1.3, 1.3, 0.1, METAAL, "Z", 16, toren, (0, 0, 0.03))
bm_achter = box("TorenAchterbak", (1.7, 0.9, 0.45), GROEN, toren, (0, -1.75, 0.38))
bevel(bm_achter, 0.04)
cyl("Commandokoepel", 0.38, 0.33, 0.32, GROEN, "Z", 12, toren, (-0.45, -0.45, 0.88))
cyl("Commandoluik", 0.33, 0.3, 0.07, METAAL, "Z", 12, toren, (-0.45, -0.45, 1.07))
cyl("Laderluik", 0.28, 0.27, 0.07, GROEN, "Z", 12, toren, (0.5, -0.3, 0.78))
# machinegeweer op de koepel
box("MGBody", (0.1, 0.55, 0.13), METAAL, toren, (-0.45, -0.25, 1.22))
cyl("MGLoop", 0.025, 0.025, 0.7, METAAL, "Y", 6, toren, (-0.45, 0.3, 1.24))
box("MGKist", (0.14, 0.16, 0.14), GROEN, toren, (-0.33, -0.3, 1.15))
# rookgranaatwerpers
for sx in (-1, 1):
    for i in range(3):
        cyl(f"Rook{sx}{i}", 0.06, 0.06, 0.3, METAAL, "Y", 8, toren, (sx * (0.95 + i * 0.1), 0.85 - i * 0.12, 0.45))
# antennes
cyl("Antenne1", 0.015, 0.008, 2.0, METAAL, "Z", 5, toren, (0.7, -2.0, 1.6), smooth=False)
cyl("Antenne2", 0.015, 0.008, 1.5, METAAL, "Z", 5, toren, (-0.7, -2.0, 1.35), smooth=False)

# ---------- kanon (kantelt om X) ----------
loop = link(bpy.data.objects.new("Loop", None), toren)
loop.location = (0, 1.25, 0.42)
mantel = box("Mantel", (0.75, 0.5, 0.55), GROEN, loop, (0, 0.1, 0))
bevel(mantel, 0.06, 2)
cyl("Kanon", 0.12, 0.1, 3.6, METAAL, "Y", 12, loop, (0, 2.1, 0))
cyl("Rookafzuiger", 0.16, 0.16, 0.5, GROEN, "Y", 12, loop, (0, 2.3, 0))
cyl("Mondingsrem", 0.15, 0.15, 0.3, METAAL, "Y", 8, loop, (0, 3.95, 0))
mond = link(bpy.data.objects.new("Monding", None), loop)
mond.location = (0, 4.15, 0)

# ---------- UV's ----------
for o in scene.objects:
    if o.type == "MESH":
        bpy.context.view_layer.objects.active = o
        for s in scene.objects:
            s.select_set(s == o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=2.5)
        bpy.ops.object.mode_set(mode="OBJECT")

# modifiers toepassen en per beweegbaar deel samenvoegen (minder draw calls in Godot)
for o in scene.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = next(o for o in scene.objects if o.type == "MESH")
bpy.ops.object.convert(target="MESH")
for parent, naam in ((root, "RompMesh"), (toren, "TorenMesh"), (loop, "LoopMesh")):
    delen = [o for o in parent.children if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in delen:
        o.select_set(True)
    bpy.context.view_layer.objects.active = delen[0]
    bpy.ops.object.join()
    delen[0].name = naam
    delen[0].data.name = naam
bpy.data.images["tank_camo"].pack()
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "tank.glb"), export_format="GLB",
                          export_apply=True, export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tank.blend"))
tris = sum(len(o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.loop_triangles) if False else 0 for o in [])
tris = sum(len(o.data.loop_triangles) for o in scene.objects if o.type == "MESH" and not o.data.calc_loop_triangles())
print("TRIS", tris)
print("KLAAR", len([o for o in scene.objects if o.type == "MESH"]), "meshes")
