"""Build the v78 military supply warehouse and export its editable source + GLB.

Usage: blender -b --python maak_magazijn.py [-- /path/to/godot/assets]
Blender uses -Y as forward; with glTF's Y-up export, the warehouse entrance faces
Godot +Z. Authored image maps are saved under assets/ and packed into the
editable blend; the GLB embeds its own texture data.
"""
import bpy
import bmesh
import json
import math
import os
import struct
import random
import sys
from array import array

SEED = 78023
random.seed(SEED)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(args[0]) if args else os.path.join(ROOT, "assets")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def make_texture(name, base, style, seed, size=512):
    """Generate a small tileable, authored weathering map and a matching normal."""
    rng = random.Random(seed)
    height = array("f", [0.0]) * (size * size)
    pixels = array("f")
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            broad = (math.sin(u * math.tau * 3.0 + seed) * math.sin(v * math.tau * 2.0 + seed * 0.31)
                     + math.sin(u * math.tau * 7.0 - v * math.tau * 5.0 + seed * 0.13) * 0.32)
            grit = rng.random() - 0.5
            streak = 0.0
            if style in ("plaster", "concrete", "metal", "roof"):
                streak = max(0.0, math.sin(v * math.tau * 2.0 + u * 1.5 + seed)) * 0.08
            if style == "roof":
                corrugation = 0.04 * math.cos(v * math.tau * 42.0)
                oxid = max(0.0, math.sin(u * math.tau * 4.0 + v * 1.6)) * 0.1
                factor = 1.0 + broad * 0.12 + grit * 0.08 + streak + corrugation + oxid
            elif style == "metal":
                factor = 1.0 + broad * 0.10 + grit * 0.06 + streak
            elif style == "wood":
                grain = math.sin(v * math.tau * 72.0 + math.sin(u * 9.0) * 1.4) * 0.08
                factor = 1.0 + broad * 0.08 + grit * 0.06 + grain
            else:
                factor = 1.0 + broad * 0.13 + grit * 0.055 + streak
            idx = y * size + x
            height[idx] = max(0.0, min(1.0, 0.5 + broad * 0.12 + grit * 0.025 + streak * 0.5))
            pixels.extend((max(0.0, min(1.0, base[0] * factor)),
                           max(0.0, min(1.0, base[1] * factor)),
                           max(0.0, min(1.0, base[2] * factor)), 1.0))
    image = bpy.data.images.new(name, width=size, height=size, alpha=False, float_buffer=False)
    image.pixels.foreach_set(pixels)
    image.filepath_raw = os.path.join(OUT, "magazijn_" + name.lower() + "_base.png")
    image.file_format = "PNG"
    image.save()

    normals = array("f")
    for y in range(size):
        ym, yp = (y - 1) % size, (y + 1) % size
        for x in range(size):
            xm, xp = (x - 1) % size, (x + 1) % size
            dx = (height[y * size + xp] - height[y * size + xm]) * 5.5
            dy = (height[yp * size + x] - height[ym * size + x]) * 5.5
            nx, ny, nz = -dx, -dy, 1.0
            inv = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz)
            normals.extend((nx * inv * 0.5 + 0.5, ny * inv * 0.5 + 0.5, nz * inv * 0.5 + 0.5, 1.0))
    normal = bpy.data.images.new(name + "_Normal", width=size, height=size, alpha=False, float_buffer=False)
    normal.pixels.foreach_set(normals)
    normal.filepath_raw = os.path.join(OUT, "magazijn_" + name.lower() + "_normal.png")
    normal.file_format = "PNG"
    normal.save()
    normal.colorspace_settings.name = "Non-Color"
    return image, normal


def material(name, base, roughness, metallic, style):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*base, 1.0)
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Metallic"].default_value = metallic
    color_img, normal_img = make_texture(name, base, style, SEED + len(bpy.data.materials) * 17)
    color_node = m.node_tree.nodes.new("ShaderNodeTexImage")
    color_node.name = name + " Base Color"
    color_node.image = color_img
    color_node.extension = "REPEAT"
    m.node_tree.links.new(color_node.outputs["Color"], p.inputs["Base Color"])
    normal_node = m.node_tree.nodes.new("ShaderNodeTexImage")
    normal_node.name = name + " Normal"
    normal_node.image = normal_img
    normal_node.extension = "REPEAT"
    map_node = m.node_tree.nodes.new("ShaderNodeNormalMap")
    map_node.inputs["Strength"].default_value = 0.42 if metallic < 0.3 else 0.28
    m.node_tree.links.new(normal_node.outputs["Color"], map_node.inputs["Color"])
    m.node_tree.links.new(map_node.outputs["Normal"], p.inputs["Normal"])
    return m


PLASTER = material("Pleister", (0.39, 0.37, 0.30), 0.92, 0.0, "plaster")
CONCRETE = material("Beton", (0.30, 0.31, 0.28), 0.93, 0.0, "concrete")
STEEL = material("Staal", (0.22, 0.25, 0.20), 0.64, 0.62, "metal")
ROOF = material("Golfplaat roest", (0.31, 0.23, 0.15), 0.77, 0.55, "roof")
WOOD = material("Verweerd hout", (0.32, 0.22, 0.12), 0.88, 0.0, "wood")
RUBBLE = material("Baksteen", (0.40, 0.28, 0.18), 0.96, 0.0, "concrete")
OLIVE = material("Militair olijfgroen", (0.24, 0.29, 0.20), 0.79, 0.12, "metal")
YELLOW = material("Waarschuwing geel", (0.72, 0.52, 0.10), 0.75, 0.08, "metal")
GLASS = bpy.data.materials.new("Vuil glas")
GLASS.diffuse_color = (0.24, 0.31, 0.27, 0.62)
GLASS.use_nodes = True
glass_bsdf = GLASS.node_tree.nodes.get("Principled BSDF")
glass_bsdf.inputs["Base Color"].default_value = (0.24, 0.31, 0.27, 1.0)
glass_bsdf.inputs["Roughness"].default_value = 0.24
glass_bsdf.inputs["Metallic"].default_value = 0.16
glass_bsdf.inputs["Alpha"].default_value = 0.62
GLASS.surface_render_method = "DITHERED"
LAMP = bpy.data.materials.new("Warm lampglas")
LAMP.use_nodes = True
lamp_bsdf = LAMP.node_tree.nodes.get("Principled BSDF")
lamp_bsdf.inputs["Base Color"].default_value = (1.0, 0.65, 0.25, 1.0)
lamp_bsdf.inputs["Emission Color"].default_value = (1.0, 0.42, 0.1, 1.0)
lamp_bsdf.inputs["Emission Strength"].default_value = 2.0
lamp_bsdf.inputs["Roughness"].default_value = 0.38

MATERIALS = [PLASTER, CONCRETE, STEEL, ROOF, WOOD, RUBBLE, OLIVE, YELLOW, GLASS, LAMP]


def normalize_glb_image_names(path):
    """Match embedded glTF image names to Godot's magazijn_<image>.png sidecars."""
    with open(path, "rb") as f:
        source = f.read()
    magic, version, _ = struct.unpack_from("<4sII", source, 0)
    if magic != b"glTF" or version != 2:
        raise RuntimeError("Blender did not write a valid GLB")
    chunks = []
    offset = 12
    found_json = False
    while offset < len(source):
        length, kind = struct.unpack_from("<I4s", source, offset)
        offset += 8
        payload = source[offset:offset + length]
        offset += length
        if kind == b"JSON":
            doc = json.loads(payload)
            for image in doc.get("images", []):
                name = image.get("name", "")
                if name.startswith("magazijn_"):
                    image["name"] = name[len("magazijn_"):]
            payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            payload += b" " * ((-len(payload)) % 4)
            found_json = True
        chunks.append((kind, payload))
    if not found_json:
        raise RuntimeError("GLB is missing its JSON chunk")
    output = bytearray(b"glTF" + struct.pack("<II", 2, 0))
    for kind, payload in chunks:
        output += struct.pack("<I4s", len(payload), kind) + payload
    struct.pack_into("<I", output, 8, len(output))
    with open(path, "wb") as f:
        f.write(output)


def empty(name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    obj.location = loc
    obj.rotation_euler = rot
    return obj


def block_mesh(name, parent, loc, dims, mat, rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(dims[0], dims[1], dims[2]), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    obj.rotation_euler = rot
    return obj


def compound_mesh(name, parent, blocks):
    """One mesh instance for a family of boxes, with one material surface per material."""
    bm = bmesh.new()
    material_indices = {}
    for loc, dims, mat, rot in blocks:
        if mat not in material_indices:
            material_indices[mat] = len(material_indices)
        part = bmesh.new()
        bmesh.ops.create_cube(part, size=1.0)
        bmesh.ops.scale(part, vec=dims, verts=part.verts)
        if rot != (0, 0, 0):
            from mathutils import Euler
            bmesh.ops.rotate(part, verts=part.verts, cent=(0, 0, 0), matrix=Euler(rot, "XYZ").to_matrix())
        bmesh.ops.translate(part, verts=part.verts, vec=loc)
        # Transfer vertices and faces so the resulting mesh has a single draw object.
        vmap = {v: bm.verts.new(v.co) for v in part.verts}
        for face in part.faces:
            nf = bm.faces.new([vmap[v] for v in face.verts])
            nf.material_index = material_indices[mat]
        part.free()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in material_indices:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def cylinder_mesh(name, parent, loc, radius, depth, mat, sides=12, axis="Z"):
    from mathutils import Matrix
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=depth,
                          matrix=Matrix.Identity(4))
    if axis == "X":
        from mathutils import Matrix
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        from mathutils import Matrix
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    return obj


def uv_world(obj):
    """World projected UVs give masonry and metal a sensible repeat scale."""
    if obj.type != "MESH":
        return
    mesh = obj.data
    uv = mesh.uv_layers.new(name="UVMap") if not mesh.uv_layers else mesh.uv_layers[0]
    world = obj.matrix_world
    for poly in mesh.polygons:
        normal = world.to_3x3() @ poly.normal
        axis = max(range(3), key=lambda k: abs(normal[k]))
        mat = mesh.materials[poly.material_index] if mesh.materials else PLASTER
        scale = 1.6
        if mat == PLASTER:
            scale = 2.4
        elif mat in (ROOF, STEEL, OLIVE, YELLOW):
            scale = 1.1
        elif mat == WOOD:
            scale = 0.8
        for li in poly.loop_indices:
            co = world @ mesh.vertices[mesh.loops[li].vertex_index].co
            if axis == 0:
                coords = (co.y, co.z)
            elif axis == 1:
                coords = (co.x, co.z)
            else:
                coords = (co.x, co.y)
            uv.data[li].uv = (coords[0] / scale, coords[1] / scale)


def box_component(blocks, x, y, z, sx, sy, sz, mat, rot=(0, 0, 0)):
    blocks.append(((x, y, z), (sx, sy, sz), mat, rot))


def wall_blocks(width, height, depth, window=False, doorway=False):
    blocks = []
    if doorway:
        # Keep a little headroom above the 2.15 m player capsule.
        door_width, door_height = 1.18, 2.40
        side = (width - door_width) / 2.0
        box_component(blocks, -(door_width + side) / 2, height / 2, 0, side, height, depth, PLASTER)
        box_component(blocks, (door_width + side) / 2, height / 2, 0, side, height, depth, PLASTER)
        box_component(blocks, 0, (height + door_height) / 2, 0, door_width, height - door_height, depth, PLASTER)
    elif window:
        # Small high slit window with a concrete sill and lintel.
        ww, bottom, wh = 0.82, 2.78, 0.66
        side = (width - ww) / 2
        box_component(blocks, -(ww + side) / 2, height / 2, 0, side, height, depth, PLASTER)
        box_component(blocks, (ww + side) / 2, height / 2, 0, side, height, depth, PLASTER)
        box_component(blocks, 0, bottom / 2, 0, ww, bottom, depth, PLASTER)
        box_component(blocks, 0, (bottom + wh + height) / 2, 0, ww, height - bottom - wh, depth, PLASTER)
    else:
        box_component(blocks, 0, height / 2, 0, width, height, depth, PLASTER)
    # A battered concrete plinth and painted steel frame, part of this segment's intact state.
    box_component(blocks, 0, 0.23, 0, width, 0.46, depth + 0.08, CONCRETE)
    box_component(blocks, -width / 2 + 0.08, height / 2, depth * 0.53, 0.12, height - 0.08, 0.16, STEEL)
    box_component(blocks, width / 2 - 0.08, height / 2, depth * 0.53, 0.12, height - 0.08, 0.16, STEEL)
    box_component(blocks, 0, height - 0.09, depth * 0.53, width, 0.16, 0.16, STEEL)
    # Top and bottom fasteners; a small number keeps the mobile mesh inexpensive.
    for x in (-width * 0.36, 0.0, width * 0.36):
        box_component(blocks, x, 0.72, depth * 0.55, 0.035, 0.07, 0.035, STEEL)
    return blocks


def damaged_wall_blocks(seed, width=2.0, height=4.35, depth=0.28):
    rng = random.Random(seed)
    blocks = []
    # Broken wall edges leave a low rubble lip and an irregular breach.
    box_component(blocks, 0, 0.22, 0, width, 0.44, depth + 0.04, RUBBLE)
    for side in (-1, 1):
        for row in range(2):
            h = rng.uniform(0.72, 1.18)
            x = side * rng.uniform(0.67, 0.88)
            y = 0.44 + h / 2 + row * 0.68
            box_component(blocks, x, y, rng.uniform(-0.03, 0.03), rng.uniform(0.38, 0.68), h,
                          depth, RUBBLE, (rng.uniform(-0.04, 0.04), 0, rng.uniform(-0.07, 0.07)))
    # A few broken upper masonry pieces and sheared steel angles.
    for i in range(3):
        x = rng.uniform(-0.78, 0.78)
        y = rng.uniform(2.45, 3.8)
        box_component(blocks, x, y, 0, rng.uniform(0.42, 1.05), rng.uniform(0.18, 0.43),
                      depth, PLASTER, (0, 0, rng.uniform(-0.16, 0.16)))
    for side in (-1, 1):
        box_component(blocks, side * 0.95, 2.45, 0.0, 0.1, 1.0, 0.12, STEEL,
                      (rng.uniform(-0.12, 0.12), 0, rng.uniform(-0.2, 0.2)))
    return blocks


root = empty("Magazijn")
ground = empty("Begane", root, rot=(math.pi / 2, 0, 0))
roof_root = empty("Dak", root)
roof_whole = None
roof_broken = None
ruins = empty("Ruine", root, rot=(math.pi / 2, 0, 0))
debris = empty("Puin", root, rot=(math.pi / 2, 0, 0))

# Foundation and worn loading platform.
block_mesh("Fundering", ground, (0, 0.03, 0), (12.0, 0.24, 8.0), CONCRETE)
block_mesh("Vloer beton", ground, (0, 0.17, 0), (11.75, 0.08, 7.75), CONCRETE)
block_mesh("Laadplatform", ground, (0, 0.16, 4.66), (7.8, 0.28, 1.35), CONCRETE)
for i in range(8):
    block_mesh("Laadrib", ground, (-3.55 + i * 1.02, 0.315, 4.66), (0.07, 0.78, 0.025), STEEL)

# Eighteen destructible wall modules. The front has a wide four-metre entrance;
# the left personnel door is cut into its own structural module.
wall_specs = []
wall_specs += [("voor", x, 3.86, (0, 0, 0), False, False) for x in (-5, -3, 3, 5)]
wall_specs += [("achter", x, -3.86, (0, math.pi, 0), x in (-3, 3), False) for x in (-5, -3, -1, 1, 3, 5)]
wall_specs += [("links", -5.86, -y, (0, -math.pi / 2, 0), False, y == -3) for y in (-3, -1, 1, 3)]
wall_specs += [("rechts", 5.86, -y, (0, math.pi / 2, 0), False, False) for y in (-3, -1, 1, 3)]
wall_groups = []
for i, (side, x, y, rot, window, doorway) in enumerate(wall_specs):
    seg = empty("M0%02d" % i, ground, (x, 0, y), rot)
    wall_groups.append(seg)
    heel = compound_mesh("M0%02d_heel" % i, seg, wall_blocks(2.0, 4.35, 0.28, window, doorway))
    kapot = compound_mesh("M0%02d_kapot" % i, seg, damaged_wall_blocks(SEED + i))
    if window:
        # Glass is decorative and deliberately has no collision mesh.
        block_mesh("Raamglas", heel, (0, 3.12, -0.02), (0.74, 0.56, 0.025), GLASS)
        for xoff in (-0.44, 0.44):
            block_mesh("Raamstijl", heel, (xoff, 3.11, -0.19), (0.08, 0.8, 0.08), STEEL)
        block_mesh("Raamdorpel", heel, (0, 2.75, -0.18), (0.98, 0.1, 0.12), CONCRETE)
    if doorway:
        block_mesh("Stalen kozijn links", heel, (-0.60, 1.20, -0.2), (0.09, 2.40, 0.12), STEEL)
        block_mesh("Stalen kozijn rechts", heel, (0.60, 1.20, -0.2), (0.09, 2.40, 0.12), STEEL)
        block_mesh("Stalen latei", heel, (0, 2.47, -0.2), (1.28, 0.12, 0.12), STEEL)

# Swinging front leaves. The script rotates each hinge open using the shared house system.
front_left = empty("DeurVoorL", ground, (-1.72, 0, 3.79))
front_right = empty("DeurVoorR", ground, (1.72, 0, 3.79), (0, math.pi, 0))
for hinge, s in ((front_left, 1), (front_right, -1)):
    panel = empty("Paneel", hinge)
    parts = []
    box_component(parts, s * 0.80, 2.05, 0, 1.62, 3.9, 0.11, OLIVE)
    for yy in (0.25, 0.62, 1.05, 1.52, 2.05, 2.55, 3.0, 3.48):
        box_component(parts, s * 0.80, yy, -0.07, 1.60, 0.055, 0.04, ROOF)
    box_component(parts, s * 0.80, 2.05, -0.11, 0.08, 3.9, 0.05, STEEL)
    box_component(parts, s * 1.52, 2.05, -0.11, 0.08, 3.9, 0.05, STEEL)
    box_component(parts, s * 0.80, 0.18, -0.12, 0.17, 0.11, 0.06, STEEL)
    compound_mesh("Schuifdeur paneel", panel, parts)

# Side personnel door is a single hinged leaf in the cut wall module.
side_door = empty("DeurZij", ground, (-5.79, 0, 3.59), (0, -math.pi / 2, 0))
personnel = empty("Paneel", side_door)
parts = []
box_component(parts, 0.54, 1.15, 0, 1.05, 2.30, 0.09, OLIVE)
for yy in (0.35, 0.75, 1.2, 1.65, 2.0, 2.24):
    box_component(parts, 0.54, yy, -0.06, 1.02, 0.045, 0.04, ROOF)
box_component(parts, 0.07, 1.08, -0.1, 0.07, 2.14, 0.06, STEEL)
box_component(parts, 1.01, 1.08, -0.1, 0.07, 2.14, 0.06, STEEL)
compound_mesh("Personeelsdeur", personnel, parts)

# Exterior military trim, signage, vents, lamps, drain pipes, and roof supports.
facade = empty("Buitendetails", ground)
detail_blocks = []
for y in (-3.76, 3.76):
    for x in (-5.7, -4.0, -2.05, 2.05, 4.0, 5.7):
        box_component(detail_blocks, x, 2.32, y, 0.12, 4.52, 0.18, STEEL)
    box_component(detail_blocks, 0, 4.33, y, 12.0, 0.16, 0.20, STEEL)
    box_component(detail_blocks, 0, 0.45, y, 12.0, 0.18, 0.34, CONCRETE)
for x in (-5.77, 5.77):
    for y in (-3.75, 3.75):
        box_component(detail_blocks, x, 2.37, y, 0.18, 4.55, 0.18, STEEL)
        box_component(detail_blocks, x + (0.22 if x < 0 else -0.22), 2.33, y, 0.10, 0.20, 0.10, OLIVE)
compound_mesh("Gevelbanden en stijlen", facade, detail_blocks)

# Long louvred ventilation panels on both end walls.
vent = empty("Ventilatieroosters", ground)
vent_blocks = []
for x, sign in ((-5.70, -1), (5.70, 1)):
    for zc in (-1.3, 1.3):
        box_component(vent_blocks, x, 3.65, zc, 0.18, 0.92, 1.22, OLIVE)
        for yy in (3.30, 3.47, 3.64, 3.81, 3.98):
            box_component(vent_blocks, x + sign * 0.12, yy, zc, 0.06, 0.045, 1.10, STEEL)
compound_mesh("Ventilatierooster mesh", vent, vent_blocks)

# A weathered depot sign and painted warning plates.
sign = empty("Waarschuwingsborden", ground)
sign_blocks = []
box_component(sign_blocks, 0, 4.05, 4.08, 2.7, 0.62, 0.10, OLIVE)
box_component(sign_blocks, 0, 3.58, 4.08, 2.7, 0.05, 0.08, YELLOW)
for x in (-4.35, 4.35):
    box_component(sign_blocks, x, 3.55, 4.08, 0.62, 0.75, 0.10, YELLOW)
    box_component(sign_blocks, x, 3.55, 4.15, 0.48, 0.58, 0.04, OLIVE)
compound_mesh("Depot borden", sign, sign_blocks)
txt = bpy.data.curves.new("DEPOT 07", "FONT")
txt.body = "DEPOT 07"
txt.size = 0.32
txt.extrude = 0.001
txt.align_x = "CENTER"
txt.align_y = "CENTER"
text_obj = bpy.data.objects.new("DEPOT 07 stencil", txt)
scene.collection.objects.link(text_obj)
text_obj.parent = sign
text_obj.location = (0, 4.08, 4.145)
txt.materials.append(YELLOW)
bpy.context.view_layer.objects.active = text_obj
text_obj.select_set(True)
bpy.ops.object.convert(target="MESH")
text_obj.select_set(False)

# Perimeter guttering and rainwater pipes.
drains = empty("Dakgoten en regenpijpen", ground)
drain_blocks = []
for x in (-6.03, 6.03):
    box_component(drain_blocks, x, 4.88, 0, 0.13, 0.16, 8.05, STEEL)
for y in (-3.9, 3.9):
    box_component(drain_blocks, 0, 4.88, y, 12.1, 0.13, 0.12, STEEL)
for x in (-5.72, 5.72):
    for y in (-3.82, 3.82):
        box_component(drain_blocks, x, 2.4, y, 0.10, 4.75, 0.10, ROOF)
compound_mesh("Regenafvoer mesh", drains, drain_blocks)

# Interior worklights, ceiling trusses, and reinforced rack aisle.
inside = empty("Inrichting0", ground)
structure = empty("Spanten en lampen", ground)
frame_blocks = []
for y in (-3.15, -1.7, -0.25, 1.2, 2.65, 3.35):
    box_component(frame_blocks, 0, 4.43, y, 11.4, 0.12, 0.12, STEEL)
    for x in (-5.55, 5.55):
        box_component(frame_blocks, x, 4.2, y, 0.13, 0.44, 0.13, STEEL)
    box_component(frame_blocks, -2.85, 5.0, y, 5.5, 0.10, 0.10, STEEL, (0, 0, -0.20))
    box_component(frame_blocks, 2.85, 5.0, y, 5.5, 0.10, 0.10, STEEL, (0, 0, 0.20))
compound_mesh("Dakspanten", structure, frame_blocks)

lights = empty("Wandlampen", ground)
lamp_blocks = []
for x in (-5.72, 5.72):
    for zc in (-1.4, 1.4):
        box_component(lamp_blocks, x, 3.25, zc, 0.18, 0.14, 0.48, STEEL)
        box_component(lamp_blocks, x - (0.12 if x < 0 else -0.12), 3.18, zc, 0.10, 0.20, 0.32, LAMP)
compound_mesh("Lampbehuizingen", lights, lamp_blocks)

# Heavy steel racks with timber shelves and repeated boxed stock. The open center
# aisle remains wider than three metres for the player and enemy navigation.
rack_blocks = []
for x in (-4.25, 4.25):
    for y in (-2.35, 2.35):
        for zc in (0.25, 1.45, 2.65):
            box_component(rack_blocks, x, zc, y, 1.28, 0.12, 0.12, STEEL)
    for zc in (0.2, 1.35, 2.5, 3.35):
        for y in (-3.0, -1.5, 0.0, 1.5, 3.0):
            box_component(rack_blocks, x - 0.55, zc, y, 0.10, 0.10, 0.12, STEEL)
            box_component(rack_blocks, x + 0.55, zc, y, 0.10, 0.10, 0.12, STEEL)
    for zc in (0.72, 1.90, 3.02):
        box_component(rack_blocks, x, zc, 0, 1.18, 0.08, 4.55, WOOD)
compound_mesh("Stellingen", inside, rack_blocks)

stock_blocks = []
def crate(x, y, z, sx=0.78, sy=0.62, sz=0.58, ammo=False):
    wood = OLIVE if ammo else WOOD
    box_component(stock_blocks, x, z + sz / 2, y, sx, sz, sy, wood)
    for xx in (-sx * 0.42, sx * 0.42):
        box_component(stock_blocks, x + xx, z + sz / 2, y - sy / 2 - 0.02, 0.055, sz * 0.92, 0.035, STEEL)
    box_component(stock_blocks, x, z + sz / 2, y - sy / 2 - 0.045, sx * 0.34, sz * 0.20, 0.04, YELLOW if ammo else STEEL)

for x in (-4.25, 4.25):
    for y in (-2.45, 0.0, 2.45):
        crate(x, y, 0.82, 0.78, 0.78, 0.54, ammo=True)
        crate(x, y, 1.98, 0.72, 0.62, 0.50, ammo=False)
for x, y in ((-2.15, -2.45), (2.15, -2.45), (-2.15, 2.45), (2.15, 2.45)):
    crate(x, y, 0.18, 0.92, 0.78, 0.66, ammo=True)
    crate(x + 0.05, y, 0.84, 0.84, 0.70, 0.64, ammo=False)

# Four timber pallets with slats and runners.
pallet_blocks = []
for x, y in ((-2.5, -0.95), (2.5, -0.95), (-2.5, 1.25), (2.5, 1.25)):
    for dx in (-0.36, -0.12, 0.12, 0.36):
        box_component(pallet_blocks, x + dx, 0.12, y, 0.18, 0.12, 0.92, WOOD)
    for dy in (-0.31, 0.31):
        box_component(pallet_blocks, x, 0.05, y + dy, 0.86, 0.10, 0.16, WOOD)
compound_mesh("Pallets", inside, pallet_blocks)

# Workbench, tool cabinets, cabinets, fuel drums and portable jerrycans.
workshop = empty("Werkbank en voorraad", inside)
work_blocks = []
box_component(work_blocks, -4.55, 0.95, -3.28, 1.65, 0.14, 0.65, WOOD)
for x in (-5.20, -3.90):
    box_component(work_blocks, x, 0.47, -3.28, 0.11, 0.90, 0.54, STEEL)
box_component(work_blocks, -4.53, 1.37, -3.25, 1.5, 0.70, 0.56, OLIVE)
for x in (-5.65, 5.65):
    for y in (-2.45, -0.75, 1.05, 2.75):
        box_component(work_blocks, x, 1.05, y, 0.38, 1.85, 0.48, OLIVE)
        for yy in (0.44, 1.0, 1.66):
            box_component(work_blocks, x - 0.21, yy, y, 0.04, 0.06, 0.34, YELLOW)
compound_mesh("Werkbank en gereedschapskasten", workshop, work_blocks)

drums = empty("Olievaten", inside)
for i, (x, y, col) in enumerate(((-2.6, -3.0, ROOF), (2.6, -3.0, OLIVE), (-2.7, 3.15, OLIVE), (2.7, 3.15, ROOF))):
    cylinder_mesh("Olievat", drums, (x, 0.55, y), 0.34, 1.10, col, 12, "Y")
    for zc in (0.24, 0.72, 0.92):
        cylinder_mesh("Vatband", drums, (x, zc, y), 0.355, 0.07, STEEL, 12, "Y")

jerry = empty("Jerrycans", inside)
can_blocks = []
for x, y in ((-3.0, -1.8), (3.0, -1.8), (-3.15, 1.75), (3.15, 1.75), (-1.8, 3.0), (1.8, 3.0)):
    box_component(can_blocks, x, 0.42, y, 0.42, 0.70, 0.24, OLIVE)
    box_component(can_blocks, x, 0.80, y, 0.18, 0.07, 0.14, STEEL)
    box_component(can_blocks, x, 0.78, y, 0.05, 0.09, 0.04, YELLOW)
compound_mesh("Jerrycans voorraad", jerry, can_blocks)

# Warning stencil text is converted to mesh, with a yellow/black hazard stripe.
warning = empty("Markeringen", ground)
warning_blocks = []
box_component(warning_blocks, 0, 0.12, 3.86, 2.7, 0.20, 0.24, YELLOW)
for x in (-1.0, -0.48, 0.04, 0.56, 1.08):
    box_component(warning_blocks, x, 0.12, 4.00, 0.20, 0.20, 0.04, STEEL, (0, 0, -0.55))
compound_mesh("Gevaarstrepen", warning, warning_blocks)
stencil_curve = bpy.data.curves.new("Munition stencil", "FONT")
stencil_curve.body = "MUNITIONS"
stencil_curve.size = 0.20
stencil_curve.extrude = 0.001
stencil_curve.align_x = "CENTER"
stencil = bpy.data.objects.new("MUNITIONS stencil", stencil_curve)
scene.collection.objects.link(stencil)
stencil.parent = warning
stencil.location = (0, 0.25, 4.02)
stencil_curve.materials.append(STEEL)
bpy.context.view_layer.objects.active = stencil
stencil.select_set(True)
bpy.ops.object.convert(target="MESH")
stencil.select_set(False)

# Corrugated two-slope roof. Corrugation is real geometry, not a normal-only trick.
def roof_panel(name, parent, damaged=False):
    x0, x1 = -6.18, 6.18
    nx, ny = 50, 112
    verts, faces = [], []
    for ix in range(nx + 1):
        x = x0 + (x1 - x0) * ix / nx
        for iy in range(ny + 1):
            y = -4.12 + 8.24 * iy / ny
            base_z = 5.42 - abs(x) * 0.082
            corr = 0.045 * math.cos(y * math.tau / 0.22)
            verts.append((x, y, base_z + corr))
    for ix in range(nx):
        for iy in range(ny):
            a = ix * (ny + 1) + iy
            b = a + ny + 1
            # leave the torn-out central patch in the damaged roof mesh
            cx = x0 + (x1 - x0) * (ix + 0.5) / nx
            cy = -4.12 + 8.24 * (iy + 0.5) / ny
            if damaged and -2.4 < cx < 1.2 and -1.1 < cy < 2.2:
                continue
            faces.append((a, b, b + 1, a + 1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(ROOF)
    mesh.update()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.parent = parent
    return obj

roof_whole = roof_panel("Dak_heel", roof_root)
roof_broken = roof_panel("Dak_kapot", roof_root, True)
broken_beams = []
for x, y, z, sx, sy, sz, rz in (
        (-2.5, -1.0, 5.05, 2.3, 0.12, 0.10, -0.18), (1.0, 2.2, 5.0, 2.0, 0.12, 0.11, 0.14),
        (3.0, -1.8, 5.02, 1.5, 0.13, 0.10, -0.25), (-4.7, 2.1, 5.04, 1.8, 0.12, 0.1, 0.11)):
    box_component(broken_beams, x, y, z, sx, sy, sz, STEEL, (0, 0, rz))
compound_mesh("Dakspanten beschadigd", roof_broken, broken_beams)

# Shared roof-edge bars, downpipes and interior rafters remain under the roof group.
roof_trim = empty("Goot en nok", roof_root)
roof_trim_blocks = []
for x in (-6.15, 6.15):
    box_component(roof_trim_blocks, x, 0, 4.92, 0.16, 8.25, 0.13, STEEL)
box_component(roof_trim_blocks, 0, 0, 5.45, 0.12, 8.25, 0.10, STEEL)
compound_mesh("Dakrand", roof_trim, roof_trim_blocks)

# Interior objects are merged per material group by component builder. Keep a clear central firing lane.

# Low cover colliders and independent shelving collision boxes are installed by Woonhuis._spec().

# Broken shell. The wall debris is a low, traversable rubble bed with a few usable cover slabs.
ruin_blocks = []
rng = random.Random(SEED + 99)
for i in range(28):
    x, y = rng.uniform(-5.2, 5.2), rng.uniform(-3.4, 3.4)
    sx, sy, sz = rng.uniform(0.7, 2.0), rng.uniform(0.25, 0.85), rng.uniform(0.35, 1.15)
    box_component(ruin_blocks, x, sy / 2, y, sx, sy, sz, RUBBLE if i % 3 else CONCRETE,
                  (rng.uniform(-0.05, 0.05), rng.uniform(-0.16, 0.16), rng.uniform(-0.1, 0.1)))
for x in (-4.8, -1.5, 2.4, 5.0):
    box_component(ruin_blocks, x, 1.1, rng.uniform(-2.5, 2.5), 0.16, 2.2, 0.18, STEEL,
                  (rng.uniform(-0.25, 0.25), 0, rng.uniform(-0.16, 0.16)))
compound_mesh("Ruine magazijn collapsed debris", ruins, ruin_blocks)

# Reusable, lightweight debris meshes for the shared destruction logic.
def debris_prop(name, boxes):
    parent = empty(name, debris)
    compound_mesh(name + " mesh", parent, boxes)

for i in range(4):
    debris_prop("Brok%d" % i, [((0, 0.14, 0), (0.30 + i * 0.05, 0.28, 0.26 + i * 0.035), RUBBLE, (0.05 * i, 0.0, -0.04 * i))])
debris_prop("PuinKlein", [
    ((-0.28, 0.16, 0), (0.55, 0.30, 0.44), RUBBLE, (0, 0, 0.06)),
    ((0.18, 0.12, 0.10), (0.42, 0.23, 0.33), CONCRETE, (0.02, 0, -0.08)),
    ((0.05, 0.31, -0.12), (0.35, 0.18, 0.26), RUBBLE, (0, 0.05, 0.12)),
])
debris_prop("PuinGroot", [
    ((-0.42, 0.24, -0.06), (0.92, 0.48, 0.74), RUBBLE, (0.02, 0.08, 0.06)),
    ((0.36, 0.20, 0.28), (0.75, 0.40, 0.58), CONCRETE, (0.0, -0.10, -0.06)),
    ((0.08, 0.45, -0.31), (0.80, 0.34, 0.54), RUBBLE, (0.07, 0.02, 0.12)),
    ((-0.12, 0.63, 0.12), (0.58, 0.24, 0.44), WOOD, (0.0, 0.12, -0.1)),
])

# UVs are generated after all transforms are evaluated; all image dependencies are packed in both outputs.
bpy.context.view_layer.update()
for obj in list(scene.objects):
    if obj.type == "MESH":
        uv_world(obj)

roof_broken.hide_set(True)
roof_broken.hide_render = True
ruins.hide_set(True)
ruins.hide_render = True
debris.hide_set(True)
debris.hide_render = True

# Select nothing so headless export doesn't accidentally become selection-scoped.
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.file.pack_all()
blend_path = os.path.join(SCRIPT_DIR, "magazijn.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
glb_path = os.path.join(OUT, "magazijn.glb")
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format="GLB",
    export_apply=True,
    export_yup=True,
    export_lights=False,
    export_cameras=False,
    use_visible=False,
    use_renderable=False,
)
normalize_glb_image_names(glb_path)

triangles = 0
meshes = 0
for obj in scene.objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        meshes += 1
dimensions = (12.36, 8.36, 5.56)
print("MAGAZIJN_EXPORT_OK", glb_path, "BLEND", blend_path)
print("MAGAZIJN_STATS", "meshes", meshes, "triangles", triangles, "dimensions", dimensions,
      "materials", len(MATERIALS), "door_nodes", 3, "wall_segments", len(wall_groups))
