"""Wapens voor Bloedjungle: M1911, Thompson, M1 Garand, Winchester M1897 trench gun, MG 42, M1 Bazooka, plus
een huls en een raket. Blender +Y = loop-richting (wordt +/-Z in Godot, zie soldier_model.gd), Z omhoog, 1 eenheid = 1 meter.
De oorsprong van elk wapen ligt in de greep van de rechterhand.
Gebruik: python3 maak_wapens.py <uitmap>  ->  wapens.glb, wapens.blend"""
import json, math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[-1])
HQ = os.path.join(OUT, "high_quality")
GAME = os.path.join(OUT, "game_optimized")
TEXTURES = os.path.join(OUT, "textures")
REPORTS = os.path.join(OUT, "reports")
for folder in (HQ, GAME, TEXTURES, REPORTS):
    os.makedirs(folder, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- materialen ----------
def _texture(name, kind, color, rough, metal):
    """Original deterministic 512px PBR tiles; no third-party images or upscaled maps."""
    size = 512
    seed = sum(ord(c) for c in name) * 37 + 19
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, 1.0, (size, size)).astype(np.float32)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    grain = np.sin(x * (0.025 if "Hout" in name else 0.008) + np.sin(y * 0.013) * 2.0)
    if "Hout" in name:
        variation = noise * 0.018 + grain * 0.035 + np.sin(x * 0.12 + y * 0.003) * 0.012
    elif "Staal" in name or "Parker" in name:
        scratches = np.where(np.abs(np.sin(x * 0.33 + np.sin(y * 0.07))) > 0.992, -0.10, 0.0)
        variation = noise * 0.025 + grain * 0.012 + scratches
    else:
        variation = noise * 0.035 + grain * 0.01
    base = np.array(color, dtype=np.float32)[None, None, :]
    rgb = np.clip(base * (1.0 + variation[:, :, None]), 0.0, 1.0)
    albedo = bpy.data.images.new(name + "_BaseColor_512", size, size, alpha=True, float_buffer=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    albedo.pixels.foreach_set(rgba.ravel())
    albedo.filepath_raw = os.path.join(TEXTURES, albedo.name + ".png")
    albedo.file_format = "PNG"
    albedo.save()

    rough_map = np.clip(rough + noise * 0.045 + np.abs(grain) * 0.025, 0.12, 0.98)
    rough_img = bpy.data.images.new(name + "_Roughness_512", size, size, alpha=True, float_buffer=False)
    rgba[:, :, :3] = rough_map[:, :, None]
    rough_img.pixels.foreach_set(rgba.ravel())
    rough_img.filepath_raw = os.path.join(TEXTURES, rough_img.name + ".png")
    rough_img.file_format = "PNG"
    rough_img.save()

    height = noise * 0.007 + grain * (0.01 if "Hout" in name else 0.002)
    dx = np.gradient(height, axis=1)
    dy = np.gradient(height, axis=0)
    normal_rgb = np.stack((0.5 - dx * 4.0, 0.5 - dy * 4.0, np.ones_like(dx)), axis=2)
    normal_img = bpy.data.images.new(name + "_Normal_512", size, size, alpha=True, float_buffer=False)
    rgba[:, :, :3] = np.clip(normal_rgb, 0.0, 1.0)
    normal_img.pixels.foreach_set(rgba.ravel())
    normal_img.filepath_raw = os.path.join(TEXTURES, normal_img.name + ".png")
    normal_img.file_format = "PNG"
    normal_img.save()

    metal_img = bpy.data.images.new(name + "_Metallic_512", size, size, alpha=True, float_buffer=False)
    rgba[:, :, :3] = metal
    metal_img.pixels.foreach_set(rgba.ravel())
    metal_img.filepath_raw = os.path.join(TEXTURES, metal_img.name + ".png")
    metal_img.file_format = "PNG"
    metal_img.save()
    return albedo, rough_img, normal_img, metal_img


def mat(name, color, rough=0.8, metal=0.0, image=None, emit=None, strength=0.0):
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
    if emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = strength
    if name in {"Staal", "Parkerized", "Hout", "HoutDonker", "PompHout", "PompDonker", "Messing", "Olijf", "Riem", "Lood"}:
        maps = _texture(name, "pbr", color, rough, metal)
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = maps[0]
        tex.label = "Original Base Color 512"
        m.node_tree.links.new(tex.outputs["Color"], p.inputs["Base Color"])
        rough_node = m.node_tree.nodes.new("ShaderNodeTexImage")
        rough_node.image = maps[1]
        rough_node.label = "Roughness 512"
        rough_node.image.colorspace_settings.name = "Non-Color"
        m.node_tree.links.new(rough_node.outputs["Color"], p.inputs["Roughness"])
        metal_node = m.node_tree.nodes.new("ShaderNodeTexImage")
        metal_node.image = maps[3]
        metal_node.label = "Metallic 512"
        metal_node.image.colorspace_settings.name = "Non-Color"
        m.node_tree.links.new(metal_node.outputs["Color"], p.inputs["Metallic"])
        normal_node = m.node_tree.nodes.new("ShaderNodeTexImage")
        normal_node.image = maps[2]
        normal_node.label = "Tangent Normal 512"
        normal_node.image.colorspace_settings.name = "Non-Color"
        bump = m.node_tree.nodes.new("ShaderNodeNormalMap")
        bump.inputs["Strength"].default_value = 0.18
        m.node_tree.links.new(normal_node.outputs["Color"], bump.inputs["Color"])
        m.node_tree.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    return m


def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def empty(name, parent=None, loc=(0, 0, 0)):
    e = link(bpy.data.objects.new(name, None), parent)
    e.location = loc
    return e


def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(40))
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = loc
    return link(o, parent)


def box(name, size, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    # Soft, three-segment edge breaks make pressed metal, wood and bakelite read as manufactured parts.
    width = max(0.0007, min(size) * 0.14)
    bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges), offset=width, segments=3, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    o = mesh_obj(name, bm, material, parent, loc, True)
    o.rotation_euler = rot
    return o


def cyl(name, r1, r2, depth, material, axis="Z", segs=24, parent=None, loc=(0, 0, 0), smooth=True, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    o = mesh_obj(name, bm, material, parent, loc, smooth)
    o.rotation_euler = rot
    return o


def stock(name, profile, material, parent=None, sides=20):
    """Loft a softly rounded, tapered stock along +Y. Each row is y, center-x, center-z, half-width, half-depth."""
    bm = bmesh.new()
    rings = []
    for y, cx, cz, rx, rz in profile:
        row = []
        for i in range(sides):
            a = math.tau * i / sides
            row.append(bm.verts.new((cx + math.cos(a) * rx, y, cz + math.sin(a) * rz)))
        rings.append(row)
    for ring_i in range(len(rings) - 1):
        a, b = rings[ring_i], rings[ring_i + 1]
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, smooth=True)


def sphere(name, r, material, parent=None, loc=(0, 0, 0), scale=(1, 1, 1), half=False):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r)
    if half:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
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


def bevel(o, w=0.015, segs=1):
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = segs
    m.limit_method = "ANGLE"


def join(target, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target




# ---------- materialen voor de wapens ----------
STAAL = mat("Staal", (0.20, 0.20, 0.21), 0.42, 0.85)
BRUIN = mat("Parkerized", (0.09, 0.095, 0.10), 0.5, 0.7)   # donker gebrand staal
HOUT = mat("Hout", (0.36, 0.21, 0.09), 0.62)
HOUT_D = mat("HoutDonker", (0.22, 0.12, 0.05), 0.7)
# Los materiaal zodat de Winchester-pomp met het handvat kan bewegen, zonder de kolf mee te nemen.
POMP_HOUT = mat("PompHout", (0.36, 0.21, 0.09), 0.62)
POMP_HOUT_D = mat("PompDonker", (0.22, 0.12, 0.05), 0.7)
MESSING = mat("Messing", (0.82, 0.60, 0.22), 0.3, 1.0)
OLIJF = mat("Olijf", (0.25, 0.28, 0.16), 0.7, 0.1)
RIEM = mat("Riem", (0.20, 0.19, 0.11), 0.9)
LOOD = mat("Lood", (0.38, 0.38, 0.40), 0.4, 0.9)

X_ROT = lambda a: (a, 0, 0)


def deel(root, name):
    """Bewegend onderdeel (slede, hendel, pomp): een eigen knoop onder het wapen, die in een echte clip beweegt.
    Zijn delen worden apart samengevoegd, zodat ze los van de rest van het wapen kunnen schuiven."""
    return empty(f"{root.name}_{name}", root)


def finish(root):
    """Voegt alle delen met hetzelfde materiaal samen: een wapen kost zo maar een paar tekenopdrachten."""
    groups = {}
    for o in list(root.children):
        if o.type == "MESH":
            groups.setdefault(o.data.materials[0].name, []).append(o)
    for name, parts in groups.items():
        target = parts[0]
        if len(parts) > 1:
            join(target, parts[1:])
        target.name = f"{root.name}_{name}"
        target.data.name = target.name
    for sub in [o for o in root.children if o.type == "EMPTY"]:
        finish(sub)


def ring(root, y, r, depth, material, rot=0):
    return cyl("ring", r, r, depth, material, "Y", 10, root, (0, y, 0))


def perforated_tube(name, radius, length, material, parent, loc=(0, 0, 0), sides=48, rows=30):
    """Thin ventilated shroud with actual through-open slots; the barrel underneath remains visible."""
    bm = bmesh.new()
    y0 = -length * 0.5
    # A staggered grid of open windows around the full tube wall, not painted or raised hole blocks.
    skip = set()
    for row in range(2, rows - 2):
        if row % 2:
            continue
        for sector in range(1, sides, 4):
            skip.add((row, sector))
            skip.add((row + 1, sector))
    outer = []
    inner = []
    for row in range(rows + 1):
        y = y0 + length * row / rows
        out_ring, in_ring = [], []
        for sector in range(sides):
            a = math.tau * sector / sides
            out_ring.append(bm.verts.new((radius * math.cos(a), y, radius * math.sin(a))))
            in_ring.append(bm.verts.new(((radius - 0.003) * math.cos(a), y, (radius - 0.003) * math.sin(a))))
        outer.append(out_ring)
        inner.append(in_ring)
    for row in range(rows):
        for sector in range(sides):
            nxt = (sector + 1) % sides
            if (row, sector) in skip:
                continue
            bm.faces.new((outer[row][sector], outer[row][nxt], outer[row + 1][nxt], outer[row + 1][sector]))
            bm.faces.new((inner[row + 1][sector], inner[row + 1][nxt], inner[row][nxt], inner[row][sector]))
    for row in (0, rows):
        for sector in range(sides):
            nxt = (sector + 1) % sides
            if row == 0:
                bm.faces.new((outer[row][nxt], outer[row][sector], inner[row][sector], inner[row][nxt]))
            else:
                bm.faces.new((outer[row][sector], outer[row][nxt], inner[row][nxt], inner[row][sector]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, loc, True)


# ---------- M1911 ----------
def m1911():
    r = empty("M1911")
    sl = deel(r, "Slede")
    box("Slede", (0.03, 0.2, 0.036), BRUIN, sl, (0, 0.06, 0.092))
    for i in range(5):
        box("Groef", (0.032, 0.006, 0.03), STAAL, sl, (0, -0.02 - i * 0.011, 0.094))
    box("Uitwerppoort", (0.004, 0.05, 0.016), STAAL, sl, (0.0155, 0.04, 0.098))
    box("Frame", (0.026, 0.17, 0.022), BRUIN, r, (0, 0.04, 0.063))
    cyl("Loop", 0.008, 0.008, 0.03, STAAL, "Y", 8, r, (0, 0.17, 0.09))
    box("Greep", (0.028, 0.045, 0.1), BRUIN, r, (0, 0, 0), X_ROT(-0.2))
    for sx in (-1, 1):
        box("Paneel", (0.006, 0.04, 0.085), HOUT_D, r, (sx * 0.016, 0, 0.0), X_ROT(-0.2))
    box("Beugelvoor", (0.008, 0.012, 0.03), BRUIN, r, (0, 0.062, 0.035))
    box("BeugelOnder", (0.008, 0.07, 0.007), BRUIN, r, (0, 0.03, 0.02))
    box("Trekker", (0.006, 0.008, 0.022), STAAL, r, (0, 0.025, 0.045))
    box("Hamer", (0.008, 0.016, 0.02), STAAL, r, (0, -0.045, 0.117), X_ROT(0.3))
    box("Korrel", (0.005, 0.01, 0.01), STAAL, sl, (0, 0.155, 0.116))
    box("Kimmen", (0.014, 0.01, 0.01), STAAL, sl, (0, -0.03, 0.116))
    box("Magazijn", (0.024, 0.04, 0.012), STAAL, r, (0, -0.012, -0.056), X_ROT(-0.2))
    finish(r)
    return r


# ---------- Thompson M1928 ----------
def thompson():
    r = empty("Thompson")
    box("Huis", (0.048, 0.38, 0.064), BRUIN, r, (0, 0.13, 0.085))
    box("Ribbels", (0.05, 0.12, 0.02), STAAL, r, (0, 0.12, 0.125))
    cyl("Loop", 0.012, 0.012, 0.26, BRUIN, "Y", 10, r, (0, 0.43, 0.095))
    for i in range(7):
        cyl("Koelrib", 0.022, 0.022, 0.009, BRUIN, "Y", 10, r, (0, 0.32 + i * 0.027, 0.095))
    box("Compensator", (0.03, 0.05, 0.03), BRUIN, r, (0, 0.57, 0.095))
    box("Voorhout", (0.056, 0.13, 0.04), HOUT, r, (0, 0.27, 0.06))
    box("Voorgreep", (0.03, 0.035, 0.13), HOUT, r, (0, 0.3, -0.01), X_ROT(0.08))
    stock("Kolf", [(-0.39, 0, 0.04, 0.01, 0.035), (-0.34, 0, 0.04, 0.026, 0.043), (-0.18, 0, 0.04, 0.022, 0.04), (-0.04, 0, 0.035, 0.018, 0.03)], HOUT, r)
    box("Kolfplaat", (0.046, 0.012, 0.1), BRUIN, r, (0, -0.375, 0.04))
    box("Pistoolgreep", (0.034, 0.04, 0.105), HOUT, r, (0, 0.02, -0.01), X_ROT(-0.25))
    box("Beugel", (0.01, 0.07, 0.008), BRUIN, r, (0, 0.07, 0.03))
    cyl("Trommel", 0.072, 0.072, 0.048, BRUIN, "X", 16, r, (0, 0.17, 0.0))
    cyl("Trommelkap", 0.03, 0.03, 0.052, STAAL, "X", 10, r, (0, 0.17, 0.0))
    kn = deel(r, "Repeerknop")
    box("Repeerknop", (0.03, 0.03, 0.025), STAAL, kn, (0.04, 0.19, 0.12))
    box("Repeersteel", (0.036, 0.014, 0.012), STAAL, kn, (0.026, 0.19, 0.112))
    box("Korrel", (0.006, 0.012, 0.02), STAAL, r, (0, 0.5, 0.115))
    box("Kimmen", (0.03, 0.02, 0.025), STAAL, r, (0, 0.27, 0.13))
    finish(r)
    return r


# ---------- M1 Garand ----------
def garand():
    r = empty("Garand")
    stock("Kolf", [(-0.46, 0, 0.03, 0.012, 0.045), (-0.41, 0, 0.03, 0.025, 0.05), (-0.24, 0, 0.03, 0.021, 0.041), (-0.03, 0, 0.03, 0.018, 0.034), (0.12, 0, 0.035, 0.022, 0.036)], HOUT, r)
    box("Kolfplaat", (0.044, 0.014, 0.11), BRUIN, r, (0, -0.445, 0.03))
    box("Pols", (0.036, 0.3, 0.07), HOUT, r, (0, 0.0, 0.03))
    box("Huis", (0.036, 0.34, 0.052), BRUIN, r, (0, 0.27, 0.062))
    sl = deel(r, "Sluiting")
    box("Sluiting", (0.03, 0.05, 0.02), STAAL, sl, (0, 0.2, 0.1))
    box("Spanhendel", (0.016, 0.034, 0.014), STAAL, sl, (0.03, 0.2, 0.094))
    box("Hendelsteel", (0.03, 0.012, 0.01), STAAL, sl, (0.019, 0.2, 0.097))
    box("Magazijn", (0.026, 0.05, 0.03), STAAL, r, (0, 0.2, 0.035))
    box("Voorhout", (0.04, 0.4, 0.04), HOUT, r, (0, 0.62, 0.058))
    box("Handbeschermer", (0.034, 0.34, 0.026), HOUT, r, (0, 0.66, 0.088))
    cyl("Loop", 0.011, 0.011, 0.3, BRUIN, "Y", 10, r, (0, 0.97, 0.082))
    cyl("Gascilinder", 0.014, 0.014, 0.12, BRUIN, "Y", 10, r, (0, 0.84, 0.098))
    box("Korrel", (0.006, 0.014, 0.022), STAAL, r, (0, 1.1, 0.098))
    box("Diopter", (0.02, 0.02, 0.025), STAAL, r, (0, 0.3, 0.1))
    box("Beugel", (0.008, 0.12, 0.007), BRUIN, r, (0, 0.14, 0.035))
    box("Trekker", (0.006, 0.008, 0.024), STAAL, r, (0, 0.13, 0.04))
    finish(r)
    return r


# ---------- Winchester M1897 trench gun ----------
def trench():
    r = empty("Trench")
    stock("Kolf", [(-0.37, 0, 0.025, 0.011, 0.047), (-0.33, 0, 0.025, 0.025, 0.052), (-0.17, 0, 0.035, 0.021, 0.046), (-0.02, 0, 0.04, 0.018, 0.036), (0.12, 0, 0.045, 0.022, 0.036)], HOUT, r)
    box("Kolfplaat", (0.046, 0.012, 0.11), BRUIN, r, (0, -0.36, 0.02), X_ROT(0.08))
    box("Pols", (0.036, 0.26, 0.07), HOUT, r, (0, 0.07, 0.04))
    box("Huis", (0.04, 0.17, 0.058), BRUIN, r, (0, 0.16, 0.08))
    box("Vensterkant", (0.042, 0.06, 0.03), STAAL, r, (0, 0.14, 0.08))
    box("Hamer", (0.01, 0.014, 0.034), STAAL, r, (0, 0.06, 0.12), X_ROT(0.5))
    cyl("Loop", 0.016, 0.016, 0.62, BRUIN, "Y", 12, r, (0, 0.6, 0.095))
    cyl("Magazijnbuis", 0.013, 0.013, 0.5, BRUIN, "Y", 10, r, (0, 0.5, 0.052))
    perforated_tube("Hitteschild", 0.026, 0.29, STAAL, r, (0, 0.62, 0.108), 48, 32)
    pp = deel(r, "Pomp")
    cyl("Pomp", 0.032, 0.032, 0.17, POMP_HOUT, "Y", 12, pp, (0, 0.42, 0.052))
    for i in range(4):
        cyl("Groefje", 0.034, 0.034, 0.006, POMP_HOUT_D, "Y", 12, pp, (0, 0.37 + i * 0.03, 0.052))
    box("Beugel", (0.008, 0.1, 0.008), BRUIN, r, (0, 0.12, 0.04))
    box("Trekker", (0.006, 0.008, 0.026), STAAL, r, (0, 0.1, 0.05))
    box("Bajonetpen", (0.012, 0.03, 0.014), STAAL, r, (0, 0.88, 0.07))
    box("Korrel", (0.006, 0.012, 0.014), STAAL, r, (0, 0.9, 0.116))
    finish(r)
    return r


# ---------- MG 42 ----------
def mg42():
    r = empty("MG42")
    box("Huis", (0.068, 0.52, 0.1), BRUIN, r, (0, 0.18, 0.095))
    box("Voedingsdeksel", (0.06, 0.18, 0.026), STAAL, r, (0, 0.14, 0.157))
    box("Deksel", (0.07, 0.07, 0.03), BRUIN, r, (0, 0.2, 0.172))
    cyl("LoopmantelBinnenloop", 0.014, 0.014, 0.58, STAAL, "Y", 24, r, (0, 0.70, 0.115))
    perforated_tube("Loopmantel", 0.038, 0.46, BRUIN, r, (0, 0.67, 0.115), 48, 32)
    cyl("Mondingsversterker", 0.046, 0.034, 0.07, STAAL, "Y", 12, r, (0, 0.94, 0.115))
    cyl("Loop", 0.014, 0.014, 0.1, STAAL, "Y", 8, r, (0, 1.0, 0.115))
    gr = deel(r, "Repeergreep")
    box("Repeergreep", (0.016, 0.04, 0.022), STAAL, gr, (0.044, 0.2, 0.128))
    box("Repeerslede", (0.02, 0.1, 0.01), STAAL, gr, (0.036, 0.2, 0.128))
    stock("Kolf", [(-0.45, 0, 0.05, 0.012, 0.047), (-0.40, 0, 0.05, 0.028, 0.054), (-0.23, 0, 0.05, 0.024, 0.047), (-0.05, 0, 0.055, 0.019, 0.036), (0.03, 0, 0.06, 0.022, 0.04)], HOUT_D, r)
    box("Kolfplaat", (0.05, 0.012, 0.11), BRUIN, r, (0, -0.435, 0.05))
    box("Pistoolgreep", (0.034, 0.04, 0.1), HOUT_D, r, (0, 0.0, 0.0), X_ROT(-0.2))
    box("Beugel", (0.008, 0.1, 0.008), BRUIN, r, (0, 0.06, 0.04))
    box("Draaggreep", (0.02, 0.16, 0.025), BRUIN, r, (0, 0.38, 0.19))
    box("Draagstijl", (0.016, 0.014, 0.03), BRUIN, r, (0, 0.3, 0.17))
    box("Draagstijl", (0.016, 0.014, 0.03), BRUIN, r, (0, 0.46, 0.17))
    box("Korrel", (0.01, 0.014, 0.03), STAAL, r, (0, 0.9, 0.175))
    # munitiedoos aan de linkerkant (x < 0 = links van het wapen) met gordel
    box("Doos", (0.07, 0.13, 0.12), OLIJF, r, (-0.09, 0.1, 0.06))
    box("Doosdeksel", (0.072, 0.134, 0.012), RIEM, r, (-0.09, 0.1, 0.128))
    for i in range(7):
        cyl("Patroon", 0.0075, 0.0075, 0.034, MESSING, "X", 8, r, (-0.065 + i * 0.0105 * -0.4, 0.1 - i * 0.012, 0.135 + i * 0.003))
    for i in range(4):
        cyl("Patroon", 0.0075, 0.0075, 0.034, MESSING, "X", 8, r, (-0.04 + i * 0.01, 0.205 + i * 0.0, 0.132))
    # bipod, ingeklapt langs de loopmantel
    for sx in (-1, 1):
        cyl("Bipodpoot", 0.0075, 0.0075, 0.4, STAAL, "Y", 6, r, (sx * 0.03, 0.55, 0.07), rot=(0.0, 0.0, sx * 0.03))
    box("Bipodscharnier", (0.07, 0.025, 0.02), STAAL, r, (0, 0.38, 0.065))
    finish(r)
    return r


# ---------- M1 Bazooka ----------
def bazooka():
    r = empty("Bazooka")
    cyl("Buis", 0.047, 0.047, 1.3, OLIJF, "Y", 16, r, (0, 0.28, 0.11))
    cyl("Achtertrechter", 0.07, 0.049, 0.1, OLIJF, "Y", 16, r, (0, -0.4, 0.11))
    cyl("Voorrand", 0.052, 0.052, 0.03, STAAL, "Y", 16, r, (0, 0.94, 0.11))
    # The tube is empty in the ready pose; the separate Raket root is spawned by Godot when fired.
    box("Pistoolgreep", (0.034, 0.04, 0.1), HOUT, r, (0, 0.0, 0.0), X_ROT(-0.2))
    box("Beugel", (0.008, 0.09, 0.008), BRUIN, r, (0, 0.05, 0.035))
    box("Trekkerhuis", (0.045, 0.14, 0.06), BRUIN, r, (0, 0.02, 0.055))
    box("Voorgreep", (0.03, 0.03, 0.12), HOUT, r, (0, 0.5, 0.02), X_ROT(0.08))
    box("Greepblok", (0.05, 0.06, 0.03), BRUIN, r, (0, 0.5, 0.07))
    # schouderkussen: twee strippen en een plaat
    box("Schouderplaat", (0.06, 0.02, 0.14), HOUT_D, r, (0, -0.2, 0.18))
    for sx in (-1, 1):
        box("Schouderstrip", (0.012, 0.2, 0.012), STAAL, r, (sx * 0.03, -0.1, 0.14))
    box("Draagriem", (0.012, 0.3, 0.006), RIEM, r, (0.05, 0.1, 0.06))
    # vizier
    box("Vizierstijl", (0.016, 0.02, 0.07), STAAL, r, (0, 0.55, 0.19))
    box("Vizierraam", (0.05, 0.015, 0.04), STAAL, r, (0, 0.55, 0.23))
    box("Korrel", (0.01, 0.014, 0.05), STAAL, r, (0, 0.9, 0.19))
    cyl("Kabel", 0.004, 0.004, 0.9, BRUIN, "Y", 4, r, (0.04, 0.3, 0.075))
    finish(r)
    return r


def huls():
    r = empty("Huls")
    cyl("Hulslijf", 0.0045, 0.0042, 0.04, MESSING, "Y", 8, r, (0, 0, 0))
    cyl("Hulsrand", 0.0055, 0.0055, 0.003, MESSING, "Y", 8, r, (0, -0.0205, 0))
    cyl("Hulshals", 0.0042, 0.003, 0.008, MESSING, "Y", 8, r, (0, 0.024, 0))
    finish(r)
    return r


def raket():
    r = empty("Raket")
    cyl("Lijf", 0.03, 0.03, 0.4, OLIJF, "Y", 12, r, (0, 0, 0))
    cyl("Kop", 0.03, 0.006, 0.12, BRUIN, "Y", 12, r, (0, 0.26, 0))
    cyl("Staart", 0.028, 0.02, 0.08, STAAL, "Y", 12, r, (0, -0.24, 0))
    for rot in (0, math.pi / 2):
        box("Vin", (0.008, 0.08, 0.1), STAAL, r, (0, -0.22, 0), (0, rot, 0) if False else (0, 0, 0))
    box("VinA", (0.1, 0.08, 0.006), STAAL, r, (0, -0.22, 0))
    finish(r)
    return r


for fn in (m1911, thompson, garand, trench, mg42, bazooka, huls, raket):
    fn()

# Keep historically credible overall lengths while retaining the existing grip origins and clip names.
TARGET_LENGTH = {"M1911": 0.216, "Thompson": 0.875, "Garand": 1.105, "Trench": 1.000, "MG42": 1.220, "Bazooka": 1.400}
for root in [o for o in scene.objects if o.type == "EMPTY" and o.parent is None]:
    if root.name not in TARGET_LENGTH:
        continue
    bpy.context.view_layer.update()
    pts = [root.matrix_world @ Vector(corner) for obj in root.children_recursive if obj.type == "MESH" for corner in obj.bound_box]
    if pts:
        length = max(p.y for p in pts) - min(p.y for p in pts)
        root.scale.y *= TARGET_LENGTH[root.name] / max(length, 1e-5)

# Every exported primitive gets UVs for its material's original 512px maps.
mesh_objects = [o for o in scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for obj in mesh_objects:
    obj.select_set(True)
if mesh_objects:
    bpy.context.view_layer.objects.active = mesh_objects[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.008)
    bpy.ops.object.mode_set(mode="OBJECT")


# ---------- echte clips voor de bewegende delen (60 beelden per seconde) ----------
# Elke clip beweegt een of meer delen langs de looprichting (Blender Y); terug = negatief. Tijden in beelden.
scene.render.fps = 60
CLIPS = {
    # naam: {deel: [(beeld, verschuiving in meters), ...]}
    # let op de volgorde: de laatste NLA-spoor wint in de rustpose; "schot" moet de rustpose bepalen, dus "leeg" eerst
    "M1911_leeg": {"M1911_Slede": [(0, -0.0335), (3, -0.034)]},   # leeg magazijn: de slede blijft open staan
    "M1911_schot": {"M1911_Slede": [(0, 0.0), (3, -0.034), (10, 0.0)]},
    "Thompson_schot": {"Thompson_Repeerknop": [(0, 0.0), (1, -0.022), (4, 0.0)]},
    "Garand_schot": {"Garand_Sluiting": [(0, 0.0), (4, -0.045), (14, 0.0)]},
    "Trench_schot": {"Trench_Pomp": [(0, 0.0), (8, 0.0), (13, -0.07), (18, -0.07), (24, 0.0)]},
    "MG42_schot": {"MG42_Repeergreep": [(0, 0.0), (1, -0.03), (3, 0.0)]},
}
for clip_name, parts in CLIPS.items():
    for part_name, keys in parts.items():
        obj = bpy.data.objects[part_name]
        base = Vector(obj.location)
        obj.animation_data_create()
        act = bpy.data.actions.new(clip_name)
        obj.animation_data.action = act
        for frame, dy in keys:
            obj.location = base + Vector((0, dy, 0))
            obj.keyframe_insert("location", frame=frame + 1)
        obj.location = base
        track = obj.animation_data.nla_tracks.new()
        track.name = clip_name
        track.strips.new(clip_name, 1, act)
        obj.animation_data.action = None
scene.frame_start = 1
scene.frame_end = 30
scene.frame_set(1)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.file.pack_all()
bpy.context.scene["asset_role"] = "High Quality Showcase editable source"
bpy.context.scene["source_license"] = "Original procedural geometry and 512px PBR maps generated by this repository; no third-party assets."
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HQ, "wapens_hq.blend"))

# Separate, mobile-ready editable copy. Keep source parts and animation hierarchy intact.
bpy.context.scene["asset_role"] = "Bloedjungle mobile game variant"
for obj in scene.objects:
    if obj.type == "MESH":
        for modifier in list(obj.modifiers):
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            try:
                bpy.ops.object.modifier_apply(modifier=modifier.name)
            except RuntimeError:
                pass
            obj.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(GAME, "wapens_game.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    if obj.type == "EMPTY" or obj.parent is not None:
        obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(GAME, "wapens.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_force_sampling=True)
for root in [o for o in scene.objects if o.type == "EMPTY" and o.parent is None]:
    tris = 0
    meshes = [o for o in root.children_recursive if o.type == "MESH"]
    for o in meshes:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    print("TRIS", root.name, tris, "delen", len(meshes))
print("EXPORTED", os.path.join(GAME, "wapens.glb"))
