"""AH-64 Apache voor Bloedjungle. Blender +Y = voorkant (wordt -Z in Godot), Z omhoog, 1 eenheid = 1 meter.
Onderdelen: Apache > RompMesh, Rotor (draait om Z), Staartrotor (draait om X)."""
import math, sys, os
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- textuur: legergroen met vlekken, vuil en paneelnaden ----------
def od_image(size=512):
    rng = np.random.default_rng(3)
    def noise(scale):
        g = rng.random((size // scale + 2, size // scale + 2))
        y, x = np.mgrid[0:size, 0:size] / scale
        x0, y0 = x.astype(int), y.astype(int)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx
        b = g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx
        return a * (1 - fy) + b * fy
    base = np.array([0.25, 0.27, 0.20])  # matte olive drab (sRGB)
    n = noise(64) * 0.5 + noise(24) * 0.3 + noise(6) * 0.2
    img = base[None, None, :] * (0.86 + 0.28 * n[..., None])
    vuil = np.clip((noise(32) - 0.6) * 2.5, 0, 1)[..., None]
    img = img * (1 - 0.25 * vuil) + np.array([0.20, 0.18, 0.14]) * 0.25 * vuil
    # paneelnaden: donkere lijnen in een raster
    yy, xx = np.mgrid[0:size, 0:size]
    naad = ((xx % 256) < 2) | ((yy % 160) < 2)
    img[naad] *= 0.8
    # klinknagels
    nagel = ((xx % 128) == 6) & ((yy % 12) < 2) | ((yy % 96) == 6) & ((xx % 12) < 2)
    img[nagel] *= 0.8
    img = np.clip(img + (noise(2)[..., None] - 0.5) * 0.03, 0, 1)
    im = bpy.data.images.new("apache_olijf", size, size)
    rgba = np.concatenate([img, np.ones((size, size, 1))], axis=2)[::-1]
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw = os.path.join(OUT, "apache_olijf.png")
    im.file_format = "PNG"
    im.save()
    return im


def mat(name, color, rough=0.8, metal=0.0, image=None, alpha=1.0):
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


OLIJF = mat("Olijf", (0.25, 0.27, 0.2), 0.7, 0.1, od_image())
DONKER = mat("Donker", (0.15, 0.16, 0.13), 0.75, 0.1)
ZWART = mat("Zwart", (0.05, 0.05, 0.05), 0.6, 0.2)
METAAL = mat("Metaal", (0.35, 0.35, 0.33), 0.4, 0.8)
BAND = mat("Band", (0.05, 0.05, 0.05), 0.95)
GLAS = mat("Glas", (0.10, 0.14, 0.15), 0.05, 0.6)
RAKET = mat("Raket", (0.30, 0.31, 0.24), 0.6, 0.2)
LENS = mat("Lens", (0.25, 0.10, 0.05), 0.05, 0.9)


def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False, sharp=35):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(sharp))
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = loc
    return link(o, parent)


def loft(name, sections, material, parent=None, segs=16, smooth=True, sharp=50):
    """sections: (y, breedte, hoogte, z_midden, rondheid[, x_midden]); rondheid 2 = ellips, hoger = hoekiger."""
    bm = bmesh.new()
    rings = []
    for s in sections:
        y, w, h, zc, p = s[:5]
        xc = s[5] if len(s) > 5 else 0.0
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs + math.pi / segs
            c, sn = math.cos(a), math.sin(a)
            x = xc + w / 2 * math.copysign(abs(c) ** (2 / p), c)
            z = zc + h / 2 * math.copysign(abs(sn) ** (2 / p), sn)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new([r0[i], r0[j], r1[j], r1[i]])
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, smooth=smooth, sharp=sharp)


def box(name, size, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    o = mesh_obj(name, bm, material, parent, loc)
    o.rotation_euler = rot
    return o


def cyl(name, r1, r2, depth, material, axis="Z", segs=12, parent=None, loc=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    return mesh_obj(name, bm, material, parent, loc, smooth)


def sphere(name, r, material, parent=None, loc=(0, 0, 0), scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return mesh_obj(name, bm, material, parent, loc, True)


def prism_x(name, profile_yz, width, material, parent=None, loc=(0, 0, 0)):
    bm = bmesh.new()
    left = [bm.verts.new((-width / 2, y, z)) for y, z in profile_yz]
    right = [bm.verts.new((width / 2, y, z)) for y, z in profile_yz]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    for i in range(len(profile_yz)):
        j = (i + 1) % len(profile_yz)
        bm.faces.new([left[i], left[j], right[j], right[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, loc)


def bevel(o, w=0.02, segs=1):
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = segs
    m.limit_method = "ANGLE"


root = link(bpy.data.objects.new("Apache", None))

# ---------- romp: smalle neus, brede middenromp, lange staartboom ----------
loft("Romp", [
    (7.75, 0.35, 0.45, 1.30, 2.6),
    (7.45, 0.80, 0.85, 1.30, 2.8),
    (6.80, 1.00, 1.05, 1.32, 3.0),
    (5.60, 1.10, 1.20, 1.35, 3.2),
    (4.30, 1.25, 1.40, 1.42, 3.4),
    (2.80, 1.45, 1.70, 1.50, 3.6),
    (1.00, 1.50, 1.85, 1.58, 3.6),
    (-0.60, 1.40, 1.70, 1.66, 3.4),
    (-2.00, 1.00, 1.15, 1.80, 3.0),
    (-3.20, 0.62, 0.78, 1.95, 2.6),
    (-6.80, 0.46, 0.58, 2.10, 2.4),
    (-8.30, 0.36, 0.52, 2.20, 2.4),
], OLIJF, root, segs=20)

# getrapte tandem-cockpit: schutter voor (laag), piloot achter (hoog)
loft("Kap", [
    (6.95, 0.30, 0.10, 1.82, 2.4),
    (6.40, 0.95, 0.62, 1.95, 3.0),
    (5.20, 1.02, 0.78, 2.00, 3.2),
    (4.60, 1.04, 1.12, 2.16, 3.4),
    (3.50, 1.08, 1.22, 2.26, 3.4),
    (2.55, 1.02, 0.95, 2.36, 3.2),
    (2.00, 0.60, 0.40, 2.45, 2.6),
], GLAS, root, segs=14, sharp=25)
# kozijnen over het glas
for y, z, h in ((5.25, 2.00, 0.80), (4.62, 2.16, 1.14), (3.55, 2.26, 1.24)):
    box(f"Kozijn{y}", (0.6, 0.07, 0.05), DONKER, root, (0, y, z + h / 2 - 0.01))
box("KozijnMidden", (0.06, 4.2, 0.06), DONKER, root, (0, 4.5, 2.62))

# rugkap achter de cockpit met de rotoras erin
loft("Rugkap", [
    (2.40, 0.50, 0.30, 2.40, 2.6),
    (1.80, 1.15, 0.75, 2.50, 3.4),
    (0.20, 1.20, 0.85, 2.55, 3.6),
    (-1.40, 0.95, 0.65, 2.45, 3.2),
    (-2.60, 0.40, 0.30, 2.25, 2.6),
], OLIJF, root)

# motorgondels links en rechts, met uitlaat naar achteren-buiten
for sx in (-1, 1):
    loft(f"Motor{sx}", [
        (1.60, 0.40, 0.40, 2.30, 2.4, sx * 1.02),
        (1.20, 0.68, 0.72, 2.32, 2.8, sx * 1.02),
        (-0.60, 0.72, 0.76, 2.34, 3.0, sx * 1.02),
        (-1.90, 0.58, 0.60, 2.30, 2.8, sx * 1.00),
        (-2.40, 0.36, 0.36, 2.28, 2.4, sx * 0.98),
    ], OLIJF, root)
    cyl(f"Inlaat{sx}", 0.2, 0.2, 0.06, ZWART, "Y", 12, root, (sx * 1.02, 1.62, 2.30))
    uit = box(f"Uitlaat{sx}", (0.35, 0.55, 0.32), DONKER, root, (sx * 1.32, -1.95, 2.25), (0, 0, sx * 0.35))
    bevel(uit, 0.05)
    box(f"UitlaatGat{sx}", (0.06, 0.40, 0.22), ZWART, root, (sx * 1.50, -2.08, 2.25), (0, 0, sx * 0.35))

# zijkasten (avionica) onder de motoren
for sx in (-1, 1):
    k = box(f"Zijkast{sx}", (0.35, 2.6, 0.75), OLIJF, root, (sx * 0.78, 1.6, 1.25))
    bevel(k, 0.08, 2)

# ---------- staart: schuine kielvin, stabilisator, staartwiel ----------
vin = prism_x("Kielvin", [(-7.0, 2.1), (-8.45, 2.1), (-9.05, 4.05), (-8.45, 4.15), (-7.6, 2.75)], 0.16, OLIJF, root)
bevel(vin, 0.03)
stab = prism_x("Stabilisator", [(-7.85, 0), (-8.75, 0), (-8.75, 0.07), (-7.9, 0.09)], 3.3, OLIJF, root, (0, 0, 2.18))
bevel(stab, 0.02)
box("Staartwielpoot", (0.08, 0.08, 1.75), METAAL, root, (0, -7.85, 1.15), (math.radians(-12), 0, 0))
cyl("Staartwiel", 0.2, 0.2, 0.12, BAND, "X", 12, root, (0, -8.05, 0.2))

# ---------- neus: TADS-sensor en het 30 mm kanon onder de kin ----------
cyl("TADSas", 0.2, 0.2, 0.25, DONKER, "Y", 10, root, (0, 7.82, 1.15))
tads = cyl("TADS", 0.36, 0.36, 0.62, DONKER, "X", 14, root, (0, 8.02, 1.12))
for sx in (-1, 1):
    cyl(f"Lens{sx}", 0.13, 0.13, 0.04, LENS, "Y", 10, root, (sx * 0.15, 8.37, 1.14))
box("PNVS", (0.3, 0.32, 0.26), DONKER, root, (0, 7.82, 1.62))
sphere("KanonToren", 0.3, DONKER, root, (0, 5.2, 0.62), (1, 1, 0.7))
cyl("Kanon", 0.05, 0.045, 1.9, ZWART, "Y", 8, root, (0, 6.1, 0.55))
cyl("KanonMantel", 0.09, 0.09, 0.7, DONKER, "Y", 10, root, (0, 5.55, 0.56))

# ---------- landingsgestel ----------
for sx in (-1, 1):
    box(f"Poot{sx}", (0.1, 0.1, 1.3), METAAL, root, (sx * 1.05, 3.4, 0.85), (0, math.radians(sx * 28), 0))
    box(f"Steun{sx}", (0.08, 1.0, 0.08), METAAL, root, (sx * 1.15, 3.6, 0.55))
    cyl(f"Wiel{sx}", 0.38, 0.38, 0.2, BAND, "X", 16, root, (sx * 1.42, 3.4, 0.38))
    cyl(f"Velg{sx}", 0.2, 0.2, 0.22, METAAL, "X", 10, root, (sx * 1.42, 3.4, 0.38))

# ---------- vleugelstompjes met Hellfires en raketbakken ----------
for sx in (-1, 1):
    v = box(f"Vleugel{sx}", (2.6, 1.1, 0.14), OLIJF, root, (sx * 1.95, 0.9, 1.95), (0, math.radians(sx * -4), 0))
    bevel(v, 0.04)
    box(f"Vleugeltip{sx}", (0.22, 0.9, 0.22), DONKER, root, (sx * 3.25, 0.85, 1.86))
    for i, x in enumerate((1.55, 2.6)):
        px = sx * x
        box(f"Pyloon{sx}{i}", (0.16, 0.7, 0.35), DONKER, root, (px, 0.9, 1.7))
        if i == 1:  # buiten: 4 Hellfires op een rek
            box(f"Rek{sx}", (0.55, 1.5, 0.1), DONKER, root, (px, 1.0, 1.48))
            for cx in (-0.15, 0.15):
                for cz in (1.3, 1.02):
                    cyl(f"HF{sx}{cx}{cz}", 0.09, 0.09, 1.5, RAKET, "Y", 8, root, (px + cx, 1.0, cz))
                    cyl(f"HFneus{sx}{cx}{cz}", 0.09, 0.02, 0.22, DONKER, "Y", 8, root, (px + cx, 1.86, cz))
                    box(f"HFvin{sx}{cx}{cz}", (0.3, 0.12, 0.02), RAKET, root, (px + cx, 0.33, cz))
        else:  # binnen: raketbak met 19 Hydra-raketten
            cyl(f"Raketbak{sx}", 0.3, 0.3, 1.55, OLIJF, "Y", 14, root, (px, 0.9, 1.22))
            cyl(f"Raketvoor{sx}", 0.27, 0.27, 0.03, ZWART, "Y", 14, root, (px, 1.68, 1.22))
            cyl(f"Raketband{sx}", 0.31, 0.31, 0.12, DONKER, "Y", 14, root, (px, 1.3, 1.22))

# antennes en kleine details
box("Antenne1", (0.04, 0.5, 0.06), ZWART, root, (0, -3.8, 2.3))
box("Antenne2", (0.04, 0.04, 0.4), ZWART, root, (0.2, -1.0, 2.95))
box("Stap", (0.3, 0.05, 0.12), DONKER, root, (-0.78, 4.8, 0.95))
for sx in (-1, 1):
    sphere(f"Waarschuwing{sx}", 0.08, ZWART, root, (sx * 0.62, 7.0, 1.55))

# ---------- hoofdrotor (draait om Z) ----------
rotor = link(bpy.data.objects.new("Rotor", None), root)
rotor.location = (0, 0.25, 3.25)
cyl("Mast", 0.14, 0.12, 0.6, METAAL, "Z", 10, rotor, (0, 0, -0.25))
cyl("Naaf", 0.32, 0.28, 0.22, DONKER, "Z", 12, rotor, (0, 0, 0.05))
for i in range(4):
    a = i * math.pi / 2 + math.pi / 4
    blad = box(f"Blad{i}", (7.0, 0.53, 0.06), DONKER, rotor, (math.cos(a) * 3.85, math.sin(a) * 3.85, 0.05), (math.radians(3), 0, a))
    box(f"Bladtip{i}", (0.3, 0.53, 0.065), METAAL, rotor, (math.cos(a) * 7.2, math.sin(a) * 7.2, 0.05), (0, 0, a))
    box(f"Bladhouder{i}", (0.6, 0.22, 0.12), METAAL, rotor, (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.05), (0, 0, a))

# ---------- staartrotor (draait om X), 4 bladen in schaarstand ----------
staart = link(bpy.data.objects.new("Staartrotor", None), root)
staart.location = (-0.24, -8.75, 3.6)
cyl("StaartNaaf", 0.12, 0.12, 0.2, METAAL, "X", 10, staart)
for i, a in enumerate((0, math.radians(55), math.pi, math.pi + math.radians(55))):
    box(f"StaartBlad{i}", (0.05, 0.2, 1.4), DONKER, staart, (-0.06, math.sin(a) * 0.7, math.cos(a) * 0.7), (-a, 0, 0))

# ---------- UV's, samenvoegen per bewegend deel, export ----------
for o in list(scene.objects):
    if o.type == "MESH":
        bpy.context.view_layer.objects.active = o
        for s in scene.objects:
            s.select_set(s == o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=3.0)
        bpy.ops.object.mode_set(mode="OBJECT")
for o in scene.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = next(o for o in scene.objects if o.type == "MESH")
bpy.ops.object.convert(target="MESH")
for parent, naam in ((root, "RompMesh"), (rotor, "RotorMesh"), (staart, "StaartrotorMesh")):
    delen = [o for o in parent.children if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in delen:
        o.select_set(True)
    bpy.context.view_layer.objects.active = delen[0]
    bpy.ops.object.join()
    o = delen[0]
    o.name = o.data.name = naam
    # oorsprong gelijk aan die van het ouderknooppunt, zodat de mesh-node op (0,0,0) staat
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.data.images["apache_olijf"].pack()
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "apache.glb"), export_format="GLB", export_apply=True, export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "apache.blend"))
tris = 0
for o in scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
print("TRIS", tris)
