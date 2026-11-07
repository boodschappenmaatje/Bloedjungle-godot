"""Build and render M-47 Photoreal Cinematic 5.0 in Blender 4.3.2+.

The approved M-47 GLB is imported as authored. This scene uses it as a reference
asset and never edits its source meshes or packed PBR images. Mantaflow smoke and
dust caches are baked beside the .blend file.

Usage (from repository root):
  blender -b -t 3 --python tests/m47_photoreal_vfx5/blender/build_cinematic.py -- --build
  blender -b tests/m47_photoreal_vfx5/blender/M47_Photoreal_Cinematic_5_0.blend -t 3 --python tests/m47_photoreal_vfx5/blender/build_cinematic.py -- --bake
  blender -b tests/m47_photoreal_vfx5/blender/M47_Photoreal_Cinematic_5_0.blend -t 3 --python tests/m47_photoreal_vfx5/blender/build_cinematic.py -- --stills
  blender -b tests/m47_photoreal_vfx5/blender/M47_Photoreal_Cinematic_5_0.blend -t 3 -a
"""
import bpy
import hashlib
import json
import math
import os
import random
import sys
from pathlib import Path

from mathutils import Euler, Vector, noise


ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parents[1]
BLEND_DIR = OUT / "blender"
RENDERS = OUT / "renders"
CACHE = BLEND_DIR / "cache"
ASSET = ROOT / "docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb"
SOLDIER = ROOT / "assets/soldaat_jungle_commando.glb"
random.seed(4730)


def log(*parts):
    print("[M47-CIN5]", *parts, flush=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.curves, bpy.data.meshes, bpy.data.cameras,
                       bpy.data.lights, bpy.data.volumes):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)
    for scene in bpy.data.scenes:
        scene.frame_start = 1
        scene.frame_end = 192
        scene.render.fps = 24


def image(path, noncolor=False):
    im = bpy.data.images.load(str(path), check_existing=True)
    if noncolor:
        im.colorspace_settings.name = "Non-Color"
    return im


def principled(name, color, roughness=0.6, metallic=0.0, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        else:
            bsdf.inputs["Emission"].default_value = (*emission, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def pbr_material(name, albedo_path, normal_path, rough_path, scale=(1.0, 1.0, 1.0), metallic_path=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = 0.78
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs["UV"], mapping.inputs["Vector"])
    alb = nt.nodes.new("ShaderNodeTexImage")
    alb.image = image(albedo_path)
    alb.interpolation = "Linear"
    nt.links.new(mapping.outputs["Vector"], alb.inputs["Vector"])
    nt.links.new(alb.outputs["Color"], bs.inputs["Base Color"])
    ntex = nt.nodes.new("ShaderNodeTexImage")
    ntex.image = image(normal_path, True)
    nt.links.new(mapping.outputs["Vector"], ntex.inputs["Vector"])
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 0.72
    nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
    # A fine physical bump sits on top of the source normal map without erasing it.
    noise_tex = nt.nodes.new("ShaderNodeTexNoise")
    noise_tex.inputs["Scale"].default_value = 42.0
    noise_tex.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Generated"], noise_tex.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.10
    bump.inputs["Distance"].default_value = 0.018
    nt.links.new(nmap.outputs["Normal"], bump.inputs["Normal"])
    nt.links.new(noise_tex.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bs.inputs["Normal"])
    if rough_path:
        rt = nt.nodes.new("ShaderNodeTexImage")
        rt.image = image(rough_path, True)
        nt.links.new(mapping.outputs["Vector"], rt.inputs["Vector"])
        # ORM sources encode roughness in G. Grayscale roughness maps work identically.
        separate = nt.nodes.new("ShaderNodeSeparateColor")
        separate.mode = "RGB"
        nt.links.new(rt.outputs["Color"], separate.inputs["Color"])
        nt.links.new(separate.outputs["Green"], bs.inputs["Roughness"])
    if metallic_path:
        mt = nt.nodes.new("ShaderNodeTexImage")
        mt.image = image(metallic_path, True)
        nt.links.new(mapping.outputs["Vector"], mt.inputs["Vector"])
        nt.links.new(mt.outputs["Color"], bs.inputs["Metallic"])
    nt.links.new(bs.outputs["BSDF"], out.inputs["Surface"])
    return mat


def weathered_concrete(concrete):
    """Layer measured concrete PBR with scale-aware mineral staining and aggregate."""
    nt = concrete.node_tree
    bs = nt.nodes.get("Principled BSDF")
    tc = next(n for n in nt.nodes if n.type == "TEX_COORD")
    rough_map = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and
                      n.image.filepath.lower().endswith(("orm.png", "roughness.jpg"))), None)
    if rough_map:
        separate_rough = nt.nodes.new("ShaderNodeSeparateColor")
        separate_rough.name = "PBR roughness channel | green from ORM"
        separate_rough.mode = "RGB"
        nt.links.new(rough_map.outputs["Color"], separate_rough.inputs["Color"])
        for link in list(bs.inputs["Roughness"].links):
            nt.links.remove(link)
        nt.links.new(separate_rough.outputs["Green"], bs.inputs["Roughness"])
    # Slow mottling breaks the clean repeating albedo without replacing the source map.
    macro = nt.nodes.new("ShaderNodeTexNoise")
    macro.name = "Concrete mineral weathering | large mottles"
    macro.inputs["Scale"].default_value = 5.2
    macro.inputs["Detail"].default_value = 7.0
    macro.inputs["Roughness"].default_value = 0.78
    nt.links.new(tc.outputs["Generated"], macro.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.name = "Iron-rich damp concrete palette"
    ramp.color_ramp.elements[0].position = 0.21
    ramp.color_ramp.elements[0].color = (0.23, 0.27, 0.29, 1)
    ramp.color_ramp.elements[1].position = 0.76
    ramp.color_ramp.elements[1].color = (0.69, 0.68, 0.62, 1)
    mid = ramp.color_ramp.elements.new(0.52)
    mid.color = (0.47, 0.50, 0.50, 1)
    nt.links.new(macro.outputs["Fac"], ramp.inputs["Fac"])
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and n.image.filepath.lower().endswith(("albedo.jpg", "base_color.jpg")))
    mix = nt.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MIX"
    mix.inputs["Fac"].default_value = 0.34
    nt.links.new(tex.outputs["Color"], mix.inputs["Color1"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["Color2"])
    nt.links.new(mix.outputs["Color"], bs.inputs["Base Color"])
    # Grain and exposed aggregate register as real bump at the still-camera distance.
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.name = "Concrete exposed aggregate | fine grain"
    fine.inputs["Scale"].default_value = 118.0
    fine.inputs["Detail"].default_value = 3.5
    fine.inputs["Roughness"].default_value = 0.82
    nt.links.new(tc.outputs["Generated"], fine.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.name = "Cast concrete aggregate relief"
    bump.inputs["Strength"].default_value = 0.28
    bump.inputs["Distance"].default_value = 0.055
    old_normal = bs.inputs["Normal"].links[0].from_socket if bs.inputs["Normal"].is_linked else None
    if old_normal:
        # Preserve the approved source normal map as the lower bump layer.
        lower = nt.nodes.new("ShaderNodeBump")
        lower.name = "Source concrete normal under aggregate"
        lower.inputs["Strength"].default_value = 0.78
        lower.inputs["Distance"].default_value = 0.035
        nt.links.new(old_normal, lower.inputs["Normal"])
        nt.links.new(lower.outputs["Normal"], bump.inputs["Normal"])
    nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bs.inputs["Normal"])
    return concrete


def node_image_material(name, color_path, normal_path=None, roughness=0.7, alpha=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    if alpha:
        mat.surface_render_method = "DITHERED"
    nt = mat.node_tree
    bs = nt.nodes.get("Principled BSDF")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image(color_path)
    tex.interpolation = "Linear"
    nt.links.new(tc.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bs.inputs["Base Color"])
    if "Alpha" in tex.outputs:
        nt.links.new(tex.outputs["Alpha"], bs.inputs["Alpha"])
    bs.inputs["Roughness"].default_value = roughness
    if normal_path:
        no = nt.nodes.new("ShaderNodeTexImage")
        no.image = image(normal_path, True)
        nt.links.new(tc.outputs["UV"], no.inputs["Vector"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(no.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bs.inputs["Normal"])
    return mat


def uv_mesh(name, vertices, faces, mat, uv_scale=0.8):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="WorldScaleUV")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (co.y * uv_scale, co.z * uv_scale)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def cube(name, dims, loc, mat, bevel=0.0, bevel_segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        ob.data.materials.append(mat)
    if bevel:
        mod = ob.modifiers.new("Soft broken arris", "BEVEL")
        mod.width = bevel
        mod.segments = bevel_segments
        mod.profile = 0.55
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return ob


def uv_sphere(name, loc, scale, mat, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def cylinder_between(name, a, b, radius_a, radius_b, mat, vertices=10):
    a, b = Vector(a), Vector(b)
    axis = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius_a, radius2=radius_b,
                                    depth=axis.length, location=(a + b) * 0.5)
    ob = bpy.context.object
    ob.name = name
    ob.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    if mat:
        ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def make_curve(name, points, bevel, mat, cyclic=False, parent=None, resolution=12):
    curve = bpy.data.curves.new(name + "Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
    curve.bevel_depth = bevel
    curve.bevel_resolution = 3
    spl = curve.splines.new("POLY")
    spl.points.add(len(points) - 1)
    for p, v in zip(spl.points, points):
        p.co = (*Vector(v), 1.0)
    spl.use_cyclic_u = cyclic
    ob = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(ob)
    curve.materials.append(mat)
    if parent:
        ob.parent = parent
    return ob


def new_empty(name, loc=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    return ob


def parent_preserve(ob, parent):
    world = ob.matrix_world.copy()
    ob.parent = parent
    ob.matrix_world = world


def ground_scene(ground_mat, rock_mat, leaf_mat, fern_mat, bark_mat):
    # Dense, gently rolling, hand-built forest floor with true tiled jungle PBR.
    verts, faces, n = [], [], 72
    size = 25.0
    for j in range(n + 1):
        y = -size + 2 * size * j / n
        for i in range(n + 1):
            x = -size + 2 * size * i / n
            wobble = noise.fractal(Vector((x * 0.12, y * 0.12, 0.7)), 1.0, 2.0, 3) * 0.11
            z = -0.08 + wobble
            verts.append((x, y, z))
    for j in range(n):
        for i in range(n):
            a = j * (n + 1) + i
            faces.append((a, a + 1, a + n + 2, a + n + 1))
    mesh = bpy.data.meshes.new("JungleSoilTerrain")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="GroundUV_12m")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = ((v.x + size) / size * 6.0, (v.y + size) / size * 6.0)
    terrain = bpy.data.objects.new("Dense_Jungle_Forest_Floor_PBR", mesh)
    bpy.context.collection.objects.link(terrain)
    terrain.data.materials.append(ground_mat)
    for p in mesh.polygons:
        p.use_smooth = True

    # Keep the firing footprint readable while dressing the surrounding forest floor.
    fallen_leaf_litter(9000)

    pebble_mat = principled("Damp basalt gravel | dark volcanic mineral", (0.075, 0.085, 0.072), 0.94)
    pebble_bsdf = pebble_mat.node_tree.nodes.get("Principled BSDF")
    pebble_noise = pebble_mat.node_tree.nodes.new("ShaderNodeTexNoise")
    pebble_noise.inputs["Scale"].default_value = 56.0
    pebble_bump = pebble_mat.node_tree.nodes.new("ShaderNodeBump")
    pebble_bump.inputs["Strength"].default_value = 0.22
    pebble_bump.inputs["Distance"].default_value = 0.035
    pebble_links = pebble_mat.node_tree.links
    pebble_links.new(pebble_noise.outputs["Fac"], pebble_bump.inputs["Height"])
    pebble_links.new(pebble_bump.outputs["Normal"], pebble_bsdf.inputs["Normal"])
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=(0, 0, 0))
    template = bpy.context.object
    template_vertices = [v.co.copy() for v in template.data.vertices]
    template_faces = [tuple(p.vertices) for p in template.data.polygons]
    bpy.data.objects.remove(template, do_unlink=True)
    pebble_vertices, pebble_faces = [], []
    for _ in range(380):
        x, y = random.uniform(-9, 7), random.uniform(-8, 8)
        if -2.9 < x < 2.8 and abs(y) < 1.25:
            continue
        radius = random.uniform(0.035, 0.13)
        scale = Vector((random.uniform(1.1, 2.0), random.uniform(0.7, 1.35),
                        random.uniform(0.32, 0.62))) * radius
        rotation = Euler((random.uniform(-0.15, 0.15), random.random() * math.tau,
                          random.random() * math.tau)).to_matrix()
        center = Vector((x, y, random.uniform(-0.01, 0.025)))
        base = len(pebble_vertices)
        pebble_vertices.extend(tuple(center + rotation @ (v * scale) for v in template_vertices))
        pebble_faces.extend(tuple(base + index for index in face) for face in template_faces)
    pebble_mesh = bpy.data.meshes.new("Angular laterite and basalt | 380 piece scatter")
    pebble_mesh.from_pydata(pebble_vertices, [], pebble_faces)
    pebble_mesh.update()
    pebble_scatter = bpy.data.objects.new("Angular laterite and basalt pebble scatter", pebble_mesh)
    bpy.context.collection.objects.link(pebble_scatter)
    pebble_mesh.materials.append(pebble_mat)
    for face in pebble_mesh.polygons:
        face.use_smooth = False

    return terrain


def fallen_leaf_litter(count=3600):
    """Dense ground-contact litter mesh with varied leaf tones, curves and curled tips."""
    mats = [principled("Wet fallen leaf | dark olive", (0.075, 0.095, 0.038), 0.78),
            principled("Wet fallen leaf | umber", (0.14, 0.085, 0.034), 0.83),
            principled("Wet fallen leaf | chlorophyll", (0.055, 0.12, 0.044), 0.72),
            principled("Wet fallen leaf | pale underside", (0.19, 0.16, 0.075), 0.88)]
    verts, faces, material_indices = [], [], []
    for _ in range(count):
        x, y = random.uniform(-10, 7), random.uniform(-8, 8)
        # Leave only a small boot-clearance around the commando; the target shot has
        # leaf and mineral breakup across the firing lane, not a broad bare patch.
        if (x + 2.58) ** 2 + y ** 2 < 0.38 ** 2:
            continue
        center = Vector((x, y, random.uniform(-0.025, 0.045)))
        angle = random.random() * math.tau
        direction = Vector((math.cos(angle), math.sin(angle), random.uniform(-0.2, 0.2)))
        side = Vector((-direction.y, direction.x, 0)) * random.uniform(0.012, 0.035)
        length = random.uniform(0.07, 0.18)
        mid = center + direction * length * 0.55
        tip = center + direction * length + Vector((0, 0, random.uniform(-0.025, 0.045)))
        base = len(verts)
        verts.extend((tuple(center), tuple(mid + side), tuple(mid - side), tuple(tip + Vector((0, 0, 0.003))),
                      tuple(center - Vector((0, 0, 0.003))), tuple(mid - side), tuple(mid + side),
                      tuple(tip - Vector((0, 0, 0.003)))))
        faces.extend(((base, base + 1, base + 3), (base, base + 3, base + 2),
                      (base + 4, base + 7, base + 5), (base + 4, base + 6, base + 7)))
        mat = random.choices((0, 1, 2), (5, 3, 2))[0]
        material_indices.extend((mat, mat, 3, 3))
    mesh = bpy.data.meshes.new("Jungle floor | dense wet leaf-litter surface")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for mat in mats:
        mesh.materials.append(mat)
    for i, poly in enumerate(mesh.polygons):
        poly.material_index = material_indices[i]
    obj = bpy.data.objects.new("Damp fallen broadleaf litter | dense scatter", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def foliage_mesh(name, height=3.6, leaf_count=170, palm=False):
    """One dense, detailed broadleaf/palm clump, with stems and sculpted leaves."""
    bark = principled("Jungle bark | wet ridges", (0.115, 0.073, 0.038), 0.88)
    greens = [principled("Canopy leaf | deep chlorophyll", (0.025, 0.13, 0.042), 0.46),
              principled("Canopy leaf | emerald highlights", (0.045, 0.23, 0.072), 0.42),
              principled("Canopy leaf | waxed underside", (0.09, 0.28, 0.105), 0.34)]
    for leafmat in greens:
        b = leafmat.node_tree.nodes.get("Principled BSDF")
        b.inputs["Subsurface Weight"].default_value = 0.035
        b.inputs["Coat Weight"].default_value = 0.08
        b.inputs["Coat Roughness"].default_value = 0.38
    verts, faces, mids = [], [], []

    def add_taper(a, b, ra, rb, sides=7, material_index=0):
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        u = axis.cross(Vector((0, 1, 0))).normalized()
        if u.length < 1e-4:
            u = axis.cross(Vector((1, 0, 0))).normalized()
        v = axis.cross(u).normalized()
        start = len(verts)
        for c, r in ((a, ra), (b, rb)):
            for i in range(sides):
                q = c + (u * math.cos(math.tau * i / sides) + v * math.sin(math.tau * i / sides)) * r
                verts.append(tuple(q))
        for i in range(sides):
            faces.append((start + i, start + (i + 1) % sides,
                          start + sides + (i + 1) % sides, start + sides + i))
            mids.append(material_index)

    def add_leaf(start, direction, length, width, material_index):
        s = Vector(start); d = Vector(direction).normalized()
        side = d.cross(Vector((0, 0, 1))).normalized()
        if side.length < 0.001:
            side = d.cross(Vector((0, 1, 0))).normalized()
        up = side.cross(d).normalized()
        rows, across = 5, 3
        base = len(verts)
        for underside in (False, True):
            for ri in range(rows):
                t = ri / (rows - 1)
                taper = max(0.012, math.sin(math.pi * t) ** 0.78)
                center = s + d * (length * t) + up * (length * 0.045 * math.sin(math.pi * t))
                for ci in range(across):
                    u = ci / (across - 1) * 2.0 - 1.0
                    lift = width * 0.19 * (1.0 - u * u) * math.sin(math.pi * t)
                    p = center + side * (u * width * taper) + up * lift
                    p += up * (-0.002 if underside else 0.002)
                    verts.append(tuple(p))
        row_stride = across
        layer_size = rows * across
        for layer in (0, 1):
            offset = base + layer * layer_size
            for ri in range(rows - 1):
                for ci in range(across - 1):
                    a = offset + ri * row_stride + ci
                    quad = (a, a + 1, a + row_stride + 1, a + row_stride)
                    faces.append(quad if layer == 0 else tuple(reversed(quad)))
                    mids.append(material_index)

    # Tapered trunk with knobbly basal flare.
    add_taper((0, 0, 0), (0.03, -0.015, height * 0.55), 0.20, 0.105, 12, 0)
    add_taper((0.03, -0.015, height * 0.55), (0.08, 0.02, height), 0.105, 0.045, 10, 0)
    branch_count = 9
    for k in range(branch_count):
        angle = k * math.tau / branch_count + random.uniform(-0.14, 0.14)
        z = height * random.uniform(0.47, 0.84)
        length = height * random.uniform(0.22, 0.41)
        end = (0.08 + math.cos(angle) * length, math.sin(angle) * length, z + length * random.uniform(0.28, 0.72))
        start = (0.02, 0, z)
        add_taper(start, end, 0.030, 0.008, 7, 0)
        leaves_per = max(3, leaf_count // (branch_count * 2))
        for j in range(leaves_per):
            t = (j + 1) / (leaves_per + 1)
            base = Vector(start).lerp(Vector(end), t)
            side_dir = Vector((-math.sin(angle), math.cos(angle), random.uniform(-0.04, 0.16)))
            for sign in (-1, 1):
                d = Vector((math.cos(angle) * 0.40, math.sin(angle) * 0.40, random.uniform(-0.04, 0.24))) + side_dir * (sign * random.uniform(0.5, 0.9))
                l = random.uniform(0.17, 0.34) if not palm else random.uniform(0.20, 0.40)
                add_leaf(base, d, l, l * random.uniform(0.075, 0.14), random.choices([1, 2, 3], [5, 3, 2])[0])
        for j in range(3):
            d = Vector((math.cos(angle), math.sin(angle), random.uniform(0.1, 0.8)))
            add_leaf(end, d, random.uniform(0.22, 0.42), random.uniform(0.025, 0.055), random.choice([1, 2, 3]))

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for material in [bark] + greens:
        mesh.materials.append(material)
    for i, poly in enumerate(mesh.polygons):
        poly.material_index = mids[i]
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def dense_jungle(rock_mat, grass_mat):
    # Repeat actual high-poly, multi-leaf plants as linked instances around the clear firing lane.
    broad = foliage_mesh("Tropical broadleaf tree master", 4.7, 150)
    fern = foliage_mesh("Layered understory fern master", 1.15, 95, True)
    for i in range(34):
        ob = broad.copy(); ob.data = broad.data; bpy.context.collection.objects.link(ob)
        ob.name = "Dense broadleaf canopy %02d" % i
        if i < 22:
            # Dense canopy beyond the breach, leaving a clean sightline along the weapon's axis.
            ob.location = (random.uniform(4.8, 13.0), random.uniform(-10.0, 10.0), random.uniform(-0.12, 0.15))
        else:
            # Perimeter foliage frames the action without crossing the five camera corridors.
            side = random.choice([-1, 1])
            y = random.uniform(7.6, 11.5) if side > 0 else random.uniform(-12.5, -9.0)
            ob.location = (random.uniform(-8.0, 8.0), y, random.uniform(-0.12, 0.15))
        ob.rotation_euler.z = random.random() * math.tau
        s = random.uniform(0.8, 1.75)
        ob.scale = (s, s * random.uniform(0.72, 1.15), s)
    for i in range(68):
        ob = fern.copy(); ob.data = fern.data; bpy.context.collection.objects.link(ob)
        ob.name = "Layered jungle understory %03d" % i
        if i < 40:
            side = random.choice([-1, 1])
            y = random.uniform(4.1, 8.4) if side > 0 else random.uniform(-11.5, -8.4)
            ob.location = (random.uniform(-8, 11), y, random.uniform(-0.08, 0.06))
        else:
            ob.location = (random.uniform(4.0, 12), random.uniform(-8, 8), random.uniform(-0.08, 0.06))
        ob.rotation_euler.z = random.random() * math.tau
        s = random.uniform(0.45, 1.25)
        ob.scale = (s, s, s)


def load_blend_object(path, name):
    """Load a real CC0 Poly Haven tree/fern mesh with its source PBR dependencies."""
    with bpy.data.libraries.load(str(path), link=False, relative=True) as (source, target):
        if name not in source.objects:
            raise RuntimeError("Missing object %s in %s" % (name, path))
        target.objects = [name]
    obj = target.objects[0]
    bpy.context.scene.collection.objects.link(obj)
    obj.name = "CC0 | " + name
    return obj


def dense_jungle_real():
    src = OUT / "assets/polyhaven"
    tree_specs = [
        ("island_tree_01_1k.blend", "island_tree_01_LOD1", (4.4, 4.2, -0.10), 1.28, 0.15),
        ("island_tree_02_1k.blend", "island_tree_02_LOD1", (5.4, -4.4, -0.10), 1.16, -0.25),
        ("island_tree_01_1k.blend", "island_tree_01_LOD1", (9.5, 8.2, -0.12), 1.48, -0.35),
        ("island_tree_02_1k.blend", "island_tree_02_LOD1", (9.2, -8.3, -0.10), 1.25, 0.30),
        ("island_tree_01_1k.blend", "island_tree_01_LOD1", (6.2, 11.0, -0.12), 1.38, 0.55),
        ("island_tree_02_1k.blend", "island_tree_02_LOD1", (12.5, -1.6, -0.10), 1.42, -0.10),
        ("island_tree_01_1k.blend", "island_tree_01_LOD1", (5.8, -11.2, -0.12), 1.16, 0.40),
    ]
    source_trees = {}
    for asset, object_name, loc, scale, yaw in tree_specs:
        if asset not in source_trees:
            with bpy.data.libraries.load(str(src / asset), link=True, relative=True) as (source, target):
                target.collections = [object_name]
            source_trees[asset] = target.collections[0]
        ob = bpy.data.objects.new("Photogrammetry jungle canopy | " + object_name.replace("_", " "), None)
        bpy.context.scene.collection.objects.link(ob)
        ob.instance_type = "COLLECTION"
        ob.instance_collection = source_trees[asset]
        ob.location = loc
        ob.rotation_euler.z = yaw
        ob.scale = (scale, scale, scale)

    # The Poly Haven fern has four individual detailed clumps in a 2x2 source arrangement.
    fern_file = src / "fern_02_1k.blend"
    with bpy.data.libraries.load(str(fern_file), link=False, relative=True) as (source, target):
        fern_names = [n for n in source.objects if n in {"fern_02_a", "fern_02_b", "fern_02_c", "fern_02_d"}]
        target.objects = fern_names
    fern_sources = [obj for obj in target.objects if obj]
    for obj in fern_sources:
        bpy.context.scene.collection.objects.link(obj)
        obj.name = "CC0 fern source | " + obj.name
        obj.hide_render = True
    for i in range(48):
        root = new_empty("Island fern patch %02d | detailed fronds" % i)
        if i < 8:
            root.location = (random.uniform(-3.6, -0.4), random.choice([-1, 1]) * random.uniform(1.9, 2.8), 0.0)
        else:
            root.location = (random.uniform(3.7, 7.4), random.choice([-1, 1]) * random.uniform(3.4, 5.4), 0.0)
        root.rotation_euler.z = random.random() * math.tau
        scale = random.uniform(0.62, 1.08)
        root.scale = (scale, scale, scale)
        for source in fern_sources:
            obj = source.copy()
            obj.data = source.data
            bpy.context.scene.collection.objects.link(obj)
            obj.parent = root
            obj.location = source.location.copy()
            obj.rotation_euler = source.rotation_euler.copy()
            obj.scale = source.scale.copy()
            obj.hide_render = False

    # High-detail 2K local grass models break up the fern silhouettes at the forest floor.
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/grass/grass_tall_lod0.glb"))
    grass_objects = [ob for ob in set(bpy.context.scene.objects) - before if ob.type == "MESH" and ob.name != "Cube"]
    for idx, source in enumerate(grass_objects):
        source.name = "Tall grass source variant %02d" % idx
        source.hide_render = True
    for i in range(240):
        x = random.uniform(-8, 12)
        if x < 3.8:
            y = random.uniform(4.8, 7.4)
        else:
            y = random.choice([-1, 1]) * random.uniform(2.8, 6.7)
        source = random.choice(grass_objects)
        ob = source.copy()
        ob.data = source.data
        bpy.context.scene.collection.objects.link(ob)
        ob.name = "PBR broadleaf grass clump %03d" % i
        ob.location = (x, y, -0.03)
        ob.rotation_euler.z = random.random() * math.tau
        scale = random.uniform(0.36, 0.82)
        ob.scale = (scale, scale, scale)
        ob.hide_render = False


def rough_masonry_block(name, wall_x, y0, y1, z0, z1, depth, material):
    """Closed fractured stone with a warped, triangulated cast face and chipped perimeter."""
    ny, nz = 7, 6
    front, back = [], []
    edge_y = {}
    edge_z = {}
    for j in range(nz):
        t = j / (nz - 1)
        edge_y[j] = (y0 + random.uniform(-0.035, 0.035),
                     y1 + random.uniform(-0.035, 0.035))
    for i in range(ny):
        t = i / (ny - 1)
        edge_z[i] = (z0 + random.uniform(-0.025, 0.025),
                     z1 + random.uniform(-0.025, 0.025))
    for side, dst in ((0, front), (1, back)):
        for j in range(nz):
            vz = j / (nz - 1)
            for i in range(ny):
                uy = i / (ny - 1)
                y = edge_y[j][0] * (1 - uy) + edge_y[j][1] * uy
                z = edge_z[i][0] * (1 - vz) + edge_z[i][1] * vz
                if 0 < i < ny - 1 and 0 < j < nz - 1:
                    y += random.uniform(-0.035, 0.035)
                    z += random.uniform(-0.026, 0.026)
                x = wall_x - random.uniform(0.012, 0.052) if side == 0 else wall_x + depth + random.uniform(-0.015, 0.015)
                if side == 0:
                    x += random.uniform(-0.026, 0.026)
                dst.append((x, y, z))
    nface = ny * nz
    vertices = front + back
    faces = []
    # Slightly non-planar triangular panels catch the grazing light and interrupt the brick-like face.
    for j in range(nz - 1):
        for i in range(ny - 1):
            a = j * ny + i
            b, c, d = a + 1, a + ny + 1, a + ny
            if (i + j) % 2:
                faces.extend([(a, b, d), (b, c, d)])
            else:
                faces.extend([(a, b, c), (a, c, d)])
            aa, bb, cc, dd = (nface + a, nface + b, nface + c, nface + d)
            if (i + j) % 2:
                faces.extend([(aa, dd, bb), (bb, dd, cc)])
            else:
                faces.extend([(aa, cc, bb), (aa, dd, cc)])
    boundary = list(range(ny)) + [j * ny + ny - 1 for j in range(1, nz)] + \
               list(range((nz - 1) * ny + ny - 2, (nz - 1) * ny - 1, -1)) + \
               [j * ny for j in range(nz - 2, 0, -1)]
    for a, b in zip(boundary, boundary[1:] + boundary[:1]):
        faces.append((a, b, nface + b, nface + a))
    mesh = bpy.data.meshes.new(name + "_fractured_surface")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="Concrete world scale")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (co.y * 1.55, co.z * 1.55)
    origin = Vector((wall_x, (y0 + y1) * 0.5, (z0 + z1) * 0.5))
    for vertex in mesh.vertices:
        vertex.co -= origin
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    ob.location = origin
    ob.data.materials.append(material)
    # Smooth only the warped front/back micro-panels; exposed fractures stay hard edged.
    for poly in mesh.polygons:
        poly.use_smooth = len(poly.vertices) == 3
    return ob


def fractured_fragment(name, radius, location, material):
    """Angular cast-concrete shard with a broken perimeter and chipped fracture faces."""
    sides = random.randint(7, 10)
    phase = random.random() * math.tau
    rings = []
    dims = (radius * random.uniform(0.85, 1.45),
            radius * random.uniform(0.75, 1.40),
            radius * random.uniform(0.48, 0.92))
    for level, zbase in enumerate((-dims[2] * 0.52, -dims[2] * random.uniform(-0.05, 0.08),
                                   dims[2] * 0.52)):
        ring = []
        for i in range(sides):
            angle = phase + math.tau * i / sides + random.uniform(-0.16, 0.16)
            radial = random.uniform(0.73, 1.18)
            x = math.cos(angle) * dims[0] * radial
            y = math.sin(angle) * dims[1] * radial
            z = zbase + random.uniform(-dims[2] * 0.18, dims[2] * 0.18)
            ring.append((x, y, z))
        rings.append(ring)
    vertices = [v for ring in rings for v in ring]
    lower_center = len(vertices); vertices.append((0, 0, -dims[2] * 0.58))
    upper_center = len(vertices); vertices.append((random.uniform(-0.08, 0.08) * radius,
                                                    random.uniform(-0.08, 0.08) * radius,
                                                    dims[2] * 0.58))
    faces = []
    for band in range(2):
        a0, b0 = band * sides, (band + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            a, b, c, d = a0 + i, a0 + j, b0 + i, b0 + j
            if (i + band) % 2:
                faces.extend([(a, b, c), (b, d, c)])
            else:
                faces.extend([(a, b, d), (a, d, c)])
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((lower_center, j, i))
        a, b = 2 * sides + i, 2 * sides + j
        faces.append((upper_center, a, b))
    mesh = bpy.data.meshes.new(name + "_angular_fracture_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    # A simple subdivision adds real chipped facets while preserving the shard silhouette.
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    ob.location = location
    ob.data.materials.append(material)
    detail = ob.modifiers.new("Fracture-face microfacets", "SUBSURF")
    detail.subdivision_type = "SIMPLE"
    detail.levels = 1
    detail.render_levels = 1
    texture = bpy.data.textures.new(name + " | concrete fracture noise", type="CLOUDS")
    texture.noise_scale = random.uniform(0.12, 0.24)
    texture.noise_depth = 2
    relief = ob.modifiers.new("Rough snapped aggregate", "DISPLACE")
    relief.texture = texture
    relief.strength = radius * 0.10
    relief.mid_level = 0.52
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    return ob


def wall_and_fracture(concrete, rebar_mat, moss_mat):
    wall_x = 3.55
    width, height = 6.8, 3.0
    cols, rows = 11, 7
    bw, bh = width / cols, height / rows
    static = []
    fracture = []
    wall_parts = []
    for row in range(rows):
        row_shift = (bw * 0.47 if row % 2 else 0.0)
        for col in range(cols):
            y0 = -width * 0.5 + col * bw + row_shift + random.uniform(-0.025, 0.025)
            y1 = y0 + bw * random.uniform(0.87, 1.12)
            if y0 < -width * 0.5:
                y0 = -width * 0.5 + 0.01
            if y1 > width * 0.5:
                y1 = width * 0.5 - 0.01
            if y1 - y0 < bw * 0.55:
                continue
            z0 = 0.12 + row * bh + random.uniform(-0.018, 0.018)
            z1 = z0 + bh * random.uniform(0.89, 1.10)
            cy, cz = (y0 + y1) * 0.5, (z0 + z1) * 0.5
            # Irregular central aperture is defined by stone centroids, not a rectangular cutout.
            dist = math.sqrt((cy / 1.0) ** 2 + ((cz - 1.45) / 0.95) ** 2)
            is_core = dist < 1.28
            depth = random.uniform(0.34, 0.56)
            ob = rough_masonry_block("Wall stone %02d-%02d" % (row, col), wall_x,
                                     y0, y1, z0, z1, depth, concrete)
            if is_core:
                ob.name = "Fracture stone %02d-%02d" % (row, col)
                fracture.append(ob)
            else:
                static.append(ob)
            wall_parts.append(ob)
    # Merge only the untouched field courses; the central pieces stay discrete for a lasting jagged opening.
    bpy.ops.object.select_all(action="DESELECT")
    for ob in static:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = static[0]
    bpy.ops.object.join()
    merged = bpy.context.object
    merged.name = "Rough cast concrete wall | intact outer field"
    merged.data.name = "PBR masonry relief and chipped edges"
    # Deep footing creates contact shadow, wet grime and small vegetation at the wall base.
    footing = cube("Wall foundation | exposed aggregate", (0.68, width + 0.25, 0.24),
                   (wall_x + 0.15, 0, 0.03), concrete, 0.035, 3)
    # Dark, rusty reinforcement reveals the wall's construction as the fragments move.
    for i in range(9):
        y = -2.3 + i * 0.58
        points = [(wall_x + 0.18, y, 0.2), (wall_x + 0.18, y + random.uniform(-0.04, 0.04), 1.2),
                  (wall_x + 0.16, y + random.uniform(-0.05, 0.05), 2.95)]
        for a, b in zip(points, points[1:]):
            cylinder_between("Ribbed steel rebar | exposed", a, b, 0.017, 0.014, rebar_mat, 8)
    # Moss-rich seams and small fern roots cling to the shaded wall toe.
    for i in range(38):
        y = random.uniform(-3.2, 3.2)
        z = random.uniform(0.10, 0.24)
        ob = uv_sphere("Moss tuft at damp wall joint", (wall_x - 0.045, y, z),
                       (random.uniform(0.06, 0.18), random.uniform(0.04, 0.13), random.uniform(0.025, 0.055)),
                       moss_mat, 12, 7)

    # Long branching cracks remain visible around the aperture after the animated blocks leave.
    crack_mat = principled("Fracture interior | deep aggregate shadow", (0.018, 0.024, 0.021), 0.96)
    crack_edge = principled("Fresh broken concrete | pale blue-grey", (0.28, 0.30, 0.27), 0.8)
    crack_parent = new_empty("Impact crack reveal")
    crack_parent.location = (wall_x - 0.065, 0, 0)
    for arm in range(18):
        angle = math.tau * arm / 18 + random.uniform(-0.12, 0.12)
        radius = random.uniform(0.76, 0.96)
        pts = []
        for step in range(5):
            t = step / 4
            r = radius + t * random.uniform(0.25, 0.68)
            a = angle + random.uniform(-0.10, 0.10)
            pts.append((0, math.cos(a) * r, 1.43 + math.sin(a) * r * 0.84))
        c = make_curve("Jagged aggregate fracture seam", pts, random.uniform(0.006, 0.014), crack_mat, False, crack_parent)
        # chipped, lighter splinters flank a subset of the branching dark fissures
        if arm % 2 == 0:
            epts = [(0.006, y + 0.024, z) for _, y, z in pts]
            make_curve("Fresh exposed crack lip", epts, 0.006, crack_edge, False, crack_parent)
    for ob in crack_parent.children:
        ob.scale = (0, 0, 0); ob.keyframe_insert(data_path="scale", frame=1)
        ob.scale = (0, 0, 0); ob.keyframe_insert(data_path="scale", frame=114)
        ob.scale = (1, 1, 1); ob.keyframe_insert(data_path="scale", frame=122)
        ob.scale = (1, 1, 1); ob.keyframe_insert(data_path="scale", frame=192)

    # Impact stones start flush in the wall then punch toward the camera and fall into real rubble.
    for i, ob in enumerate(fracture):
        world = ob.location.copy()
        ob.keyframe_insert(data_path="location", frame=1)
        ob.keyframe_insert(data_path="rotation_euler", frame=1)
        ob.keyframe_insert(data_path="location", frame=115)
        ob.keyframe_insert(data_path="rotation_euler", frame=115)
        direction = Vector((random.uniform(-0.75, -0.25), random.uniform(-1, 1), random.uniform(0.1, 1.0)))
        direction.normalize()
        ob.location = world + direction * random.uniform(0.15, 0.55)
        ob.rotation_euler.rotate_axis("Y", random.uniform(-0.4, 0.4))
        ob.rotation_euler.rotate_axis("Z", random.uniform(-0.8, 0.8))
        ob.keyframe_insert(data_path="location", frame=126)
        ob.keyframe_insert(data_path="rotation_euler", frame=126)
        ob.location = (wall_x - random.uniform(0.1, 1.0), random.uniform(-2.4, 2.4), random.uniform(0.15, 0.9))
        ob.rotation_euler.rotate_axis("Y", random.uniform(-0.6, 0.6))
        ob.rotation_euler.rotate_axis("Z", random.uniform(-1.2, 1.2))
        ob.keyframe_insert(data_path="location", frame=153)
        ob.keyframe_insert(data_path="rotation_euler", frame=153)
        ob.keyframe_insert(data_path="location", frame=192)
        ob.keyframe_insert(data_path="rotation_euler", frame=192)
        for frame in (115, 126, 153, 192):
            ob.keyframe_insert(data_path="scale", frame=frame)

    # Large angular debris is built from subdivided, displaced ico-rocks, then settled across foreground.
    rubble_mat = concrete
    for i in range(56):
        radius = random.uniform(0.18, 0.46)
        loc = (wall_x + 0.35, random.uniform(-2.8, 2.8), random.uniform(0.9, 1.8))
        ob = fractured_fragment("Large fractured concrete rubble %02d" % i, radius, loc, rubble_mat)
        # each fragment begins at the wall impact; the final positions retain a permanent debris apron
        ob.scale = (0.001, 0.001, 0.001); ob.keyframe_insert(data_path="scale", frame=112)
        ob.scale = (0.6, 0.6, 0.6); ob.location = loc; ob.keyframe_insert(data_path="scale", frame=119)
        ob.keyframe_insert(data_path="location", frame=119)
        ob.rotation_euler = (random.uniform(-0.2, 0.2), random.uniform(-1, 1), random.random() * math.tau)
        ob.keyframe_insert(data_path="rotation_euler", frame=119)
        ob.location = (wall_x - random.uniform(0.1, 2.0), random.uniform(-3.0, 3.0), radius * random.uniform(0.35, 0.65))
        ob.rotation_euler.rotate_axis("Y", random.uniform(-1.2, 1.2))
        ob.rotation_euler.rotate_axis("X", random.uniform(-0.8, 0.8))
        ob.scale = (1, 1, 1)
        ob.keyframe_insert(data_path="location", frame=random.randint(146, 161))
        ob.keyframe_insert(data_path="rotation_euler", frame=158)
        ob.keyframe_insert(data_path="scale", frame=158)
        ob.keyframe_insert(data_path="location", frame=192)
        ob.keyframe_insert(data_path="rotation_euler", frame=192)
        ob.keyframe_insert(data_path="scale", frame=192)
    return wall_x, fracture


def import_hero_assets():
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ASSET))
    m47_objs = list(set(bpy.context.scene.objects) - before)
    m47_before = [(ob.name, ob.data.as_pointer() if ob.type == "MESH" else None) for ob in m47_objs]
    lod0 = next(ob for ob in m47_objs if ob.name == "M47_LOD0")
    for ob in m47_objs:
        if ob.name in ("M47_LOD1", "M47_LOD2"):
            ob.hide_render = True
            ob.hide_set(True)
    root = new_empty("Approved M-47 | cinematic mount only")
    for ob in m47_objs:
        if ob.parent is None:
            parent_preserve(ob, root)
    # The source's authored muzzle faces -X; mount the complete imported rig to fire toward +X.
    root.location = (-2.12, 0.12, 1.18)
    root.rotation_euler.z = math.pi
    root.keyframe_insert(data_path="location", frame=1)
    root.keyframe_insert(data_path="location", frame=46)
    root.location.x -= 0.07
    root.keyframe_insert(data_path="location", frame=51)
    root.location.x -= 0.22
    root.keyframe_insert(data_path="location", frame=54)
    root.location.x += 0.26
    root.keyframe_insert(data_path="location", frame=59)
    root.location.x = -2.12
    root.keyframe_insert(data_path="location", frame=68)
    root.location = (-2.12, 0.12, 1.18)
    root.keyframe_insert(data_path="location", frame=192)
    rig = next(ob for ob in m47_objs if ob.type == "ARMATURE")
    if not rig.animation_data:
        rig.animation_data_create()
    ad = rig.animation_data
    ad.use_nla = True
    clip_spans = [("Idle", 1), ("Equip", 32), ("Aim", 67), ("Fire", 96), ("Reload", 120)]
    for label, start in clip_spans:
        action = next((a for a in bpy.data.actions if a.name.startswith(label + "_M47_Mechanism_Rig")), None)
        if action is None:
            log("WARNING missing approved clip", label)
            continue
        track = ad.nla_tracks.new()
        track.name = "GLB action | " + label
        strip = track.strips.new(label, start, action)
        strip.action_frame_start = action.frame_range[0]
        strip.action_frame_end = action.frame_range[1]
        strip.blend_type = "REPLACE"
        strip.extrapolation = "NOTHING"
        strip.blend_in = 2

    # Cinematic hero uses the project's already-approved woodland character mesh and rig.
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOLDIER))
    soldier_objs = list(set(bpy.context.scene.objects) - before)
    visible_meshes = {"Lijf_JungleCommando", "Uniform_Jacket_Shell", "Uniform_Trousers_Shell", "Hair_Cropped",
                      "Vest_JungleCommando", "Vest_JungleCommando_Back", "Vest_JungleCommando_Details",
                      "Koppel", "Laarzen", "Mag_Pouches", "Radio_Field", "IFAK_Pouch", "Gloves_Closed",
                      "Knee_Reinforcements", "Elbow_Reinforcements"}
    for ob in soldier_objs:
        if ob.type == "MESH" and ob.name not in visible_meshes:
            ob.hide_render = True
            ob.hide_set(True)
    sroot = new_empty("Woodland commando | shot-blocking")
    for ob in soldier_objs:
        if ob.parent is None:
            parent_preserve(ob, sroot)
    sroot.location = (-2.58, 0.0, 0)
    sroot.rotation_euler.z = math.pi / 2
    srig = next(ob for ob in soldier_objs if ob.type == "ARMATURE")
    action = next((a for a in bpy.data.actions if a.name == "schieten_Rig"), None)
    if action:
        srig.animation_data_create()
        srig.animation_data.action = action
    # Preserve all source objects/materials; only the cinematic root transform and LOD visibility differ.
    return m47_objs, m47_before, root, soldier_objs, sroot, lod0


def make_projectile(muzzle_x, muzzle_y, muzzle_z, energy_mat, white_mat, metal_mat):
    root = new_empty("M-47 unique blue-white energy projectile")
    core = uv_sphere("Plasma heart | white-hot center", (0, 0, 0), (0.28, 0.09, 0.09), white_mat, 32, 16)
    parent_preserve(core, root)
    mantle = uv_sphere("Coherent blue plasma envelope", (-0.12, 0, 0), (0.66, 0.205, 0.205), energy_mat, 32, 16)
    parent_preserve(mantle, root)
    # Dark metal collars, translucent-looking emissive glass bands and a focused front aperture.
    for i, x in enumerate([-0.52, -0.26, 0.08, 0.35, 0.50]):
        bpy.ops.mesh.primitive_torus_add(major_segments=40, minor_segments=12, major_radius=0.18 if i < 4 else 0.12,
                                         minor_radius=0.018 if i % 2 else 0.028, location=(x, 0, 0))
        ring = bpy.context.object
        ring.name = "Rotating containment hoop %02d" % i
        ring.rotation_euler.y = math.pi / 2
        ring.data.materials.append(metal_mat if i % 2 == 0 else energy_mat)
        for p in ring.data.polygons: p.use_smooth = True
        parent_preserve(ring, root)
        ring.rotation_euler.x = random.random() * 0.5
    # A separate, restrained saturated-blue line shader keeps ion strands blue after AgX and bloom.
    filament_mat = principled("Cinematic ion filaments | saturated blue", (0.008, 0.12, 0.68),
                              0.14, 0.12, (0.01, 0.16, 1.0), 1.25)
    # Six coaxial filaments wind around the plasma core with natural phase offsets and variable radius.
    for i in range(4):
        pts = []
        phase = math.tau * i / 6
        for j in range(88):
            t = j / 87
            x = -1.48 + t * 2.55
            ang = math.tau * (2.0 * t + phase / math.tau)
            r = 0.09 + 0.065 * math.sin(math.pi * t)
            pts.append((x, math.cos(ang) * r, math.sin(ang) * r))
        fil = make_curve("Liquid electric filament %02d" % i, pts, 0.012 if i % 2 else 0.006,
                         filament_mat if i % 2 else white_mat, False, root)
        fil.data.bevel_resolution = 4
    # Fine branching arcs and embers around the projectile's wake.
    sparkmat = principled("Blue ion spark", (0.04, 0.45, 1.0), 0.22, 0.0, (0.13, 0.65, 1.0), 12.0)
    for i in range(27):
        start = random.uniform(-1.3, 1.2)
        sign = random.choice([-1, 1])
        pts = [(start, sign * random.uniform(0.10, 0.22), random.uniform(-0.14, 0.14)),
               (start + random.uniform(0.05, 0.18), sign * random.uniform(0.22, 0.42), random.uniform(-0.24, 0.24)),
               (start + random.uniform(0.12, 0.35), sign * random.uniform(0.08, 0.31), random.uniform(-0.3, 0.3))]
        make_curve("Branching arc spark %02d" % i, pts, random.uniform(0.002, 0.005), sparkmat, False, root, 8)
    # Full-width atmospheric wake: intertwined curves with coherent volume, not a single glowing line.
    wake = new_empty("Blue-white helical wake")
    for i in range(4):
        pts = []
        phase = i * math.tau / 7
        for j in range(130):
            t = j / 129
            x = -2.4 + 2.0 * t
            ang = math.tau * (2.4 * t) + phase
            envelope = 0.055 + 0.15 * math.sin(math.pi * t) ** 0.7
            pts.append((x, math.cos(ang) * envelope, math.sin(ang) * envelope))
        make_curve("Long helicoidal plasma vapor filament", pts, 0.012 if i % 3 else 0.006,
                   filament_mat if i % 3 else white_mat, False, wake, 16)
    return root, wake


def weapon_core_ornament(center, parent, energy_mat, metal_mat):
    """Supplement the untouched M-47 mid-barrel with a rotating blue plasma mechanism."""
    root = new_empty("Cinematic VFX | rotating blue-white weapon core")
    root.location = center
    core_mat = principled("Cinematic core | contained blue plasma", (0.008, 0.09, 0.42), 0.24, 0.16,
                          (0.015, 0.30, 1.0), 1.4)
    core = uv_sphere("Contained plasma core | weapon mid-section", center,
                     (0.30, 0.08, 0.08), core_mat, 40, 20)
    parent_preserve(core, root)
    for i, offset in enumerate((-0.28, -0.12, 0.12, 0.28)):
        bpy.ops.mesh.primitive_torus_add(major_segments=56, minor_segments=12,
                                         major_radius=0.20 if i in (0, 3) else 0.225,
                                         minor_radius=0.025 if i % 2 else 0.030,
                                         location=(center[0] + offset, center[1], center[2]))
        ring = bpy.context.object
        ring.name = "Rotating weapon-core containment ring %02d" % i
        ring.rotation_euler.y = math.pi / 2
        ring.data.materials.append(energy_mat if i in (1, 2) else metal_mat)
        for polygon in ring.data.polygons:
            polygon.use_smooth = True
        parent_preserve(ring, root)
        ring.rotation_euler.x = 0.0
        ring.keyframe_insert(data_path="rotation_euler", frame=1)
        ring.rotation_euler.x = math.tau * (1.0 if i % 2 else -1.0)
        ring.keyframe_insert(data_path="rotation_euler", frame=96)
        ring.rotation_euler.x = math.tau * (2.0 if i % 2 else -2.0)
        ring.keyframe_insert(data_path="rotation_euler", frame=192)
        for curve in ring.animation_data.action.fcurves:
            for key in curve.keyframe_points:
                key.interpolation = "LINEAR"
    parent_preserve(root, parent)
    return root


def animate_key(obj, frame, prop="scale", value=None):
    if value is not None:
        setattr(obj, prop, value)
    obj.keyframe_insert(data_path=prop, frame=frame)


def make_flash(muzzle, white_mat, energy_mat):
    flashroot = new_empty("M-47 muzzle flash assembly")
    flashroot.location = muzzle
    sphere = uv_sphere("White-hot muzzle flash nucleus", (0, 0, 0), (0.17, 0.16, 0.16), white_mat, 24, 12)
    sphere.parent = flashroot
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=12,
                                     major_radius=0.34, minor_radius=0.022,
                                     location=(0.04, 0, 0))
    corona = bpy.context.object
    corona.name = "Cyan ionization collar | muzzle flash"
    corona.rotation_euler.y = math.pi / 2
    corona.data.materials.append(energy_mat)
    for face in corona.data.polygons:
        face.use_smooth = True
    corona.parent = flashroot
    # Layered, asymmetrical flame petals point along the bore, with a broad volume-like corona.
    for i in range(13):
        ang = math.tau * i / 13 + random.uniform(-0.12, 0.12)
        radius = random.uniform(0.04, 0.22)
        z = math.sin(ang) * radius
        y = math.cos(ang) * radius
        length = random.uniform(0.45, 1.15)
        tip = (length, y * random.uniform(2.2, 3.2), z * random.uniform(2.2, 3.2))
        cone = cylinder_between("Muzzle flash spear", (0, y, z), tip, random.uniform(0.035, 0.105), 0.0,
                                white_mat if i % 3 else energy_mat, 10)
        cone.parent = flashroot
    for ob in [flashroot] + list(flashroot.children):
        ob.scale = (0.001, 0.001, 0.001); ob.keyframe_insert(data_path="scale", frame=1)
        ob.keyframe_insert(data_path="scale", frame=46)
        ob.scale = (0.25, 0.25, 0.25); ob.keyframe_insert(data_path="scale", frame=49)
        ob.scale = (1.0, 1.0, 1.0); ob.keyframe_insert(data_path="scale", frame=51)
        ob.scale = (0.68, 0.68, 0.68); ob.keyframe_insert(data_path="scale", frame=53)
        ob.scale = (0.001, 0.001, 0.001); ob.keyframe_insert(data_path="scale", frame=58)
        ob.keyframe_insert(data_path="scale", frame=192)
    return flashroot


def hex_shockwave(wall_x, energy_mat, white_mat):
    center = new_empty("Impact center | hexagonal pressure front")
    center.location = (wall_x - 0.24, 0, 1.43)
    for layer, radius in enumerate([0.65, 0.96, 1.38, 1.78]):
        for segment in range(6):
            a0 = math.tau * segment / 6
            a1 = math.tau * (segment + 1) / 6
            v0 = Vector((0, math.cos(a0) * radius, math.sin(a0) * radius))
            v1 = Vector((0, math.cos(a1) * radius, math.sin(a1) * radius))
            points = []
            for j in range(9):
                t = 0.08 + 0.84 * j / 8
                p = v0.lerp(v1, t)
                # Small electrical fractures keep the polygon readable without turning it into a ring.
                if 0 < j < 8:
                    p.y += random.uniform(-0.018, 0.018)
                    p.z += random.uniform(-0.018, 0.018)
                points.append(tuple(p))
            ob = make_curve("Fractured hexagonal pressure arc", points, 0.021 if layer < 2 else 0.013,
                            white_mat if (segment + layer) % 4 == 0 else energy_mat, False, center, 12)
            ob.data.bevel_resolution = 4
    # Bright dielectric nodes illuminate the polygon joints rather than a continuous wireframe.
    for i in range(24):
        r = random.choice([0.56, 0.76, 0.98, 1.22])
        a = math.tau * i / 6
        node = uv_sphere("Ionized hexagon vertex", (0, math.cos(a) * r, math.sin(a) * r),
                         (0.018, 0.032, 0.032), white_mat, 12, 8)
        node.parent = center
    for ob in [center] + list(center.children):
        ob.scale = (0.001, 0.001, 0.001); ob.keyframe_insert(data_path="scale", frame=1)
        ob.keyframe_insert(data_path="scale", frame=108)
        ob.scale = (0.45, 0.45, 0.45); ob.keyframe_insert(data_path="scale", frame=114)
        ob.scale = (1.0, 1.0, 1.0); ob.keyframe_insert(data_path="scale", frame=122)
        ob.scale = (1.12, 1.12, 1.12); ob.keyframe_insert(data_path="scale", frame=126)
        ob.scale = (0.001, 0.001, 0.001); ob.keyframe_insert(data_path="scale", frame=142)
        ob.keyframe_insert(data_path="scale", frame=192)
    return center


def make_impact_flash(wall_x, energy_mat, white_mat):
    root = new_empty("Concrete impact | blue-white flash and sparks")
    root.location = (wall_x - 0.88, 0.0, 1.43)
    impact_white = principled("Impact | white incandescent core", (0.86, 0.97, 1.0), 0.1,
                              0.0, (0.82, 0.96, 1.0), 36.0)
    core = uv_sphere("Impact white-hot pressure core", (0, 0, 0), (0.08, 0.24, 0.24),
                     impact_white, 32, 16)
    core.parent = root
    corona = uv_sphere("Impact cyan ionized corona", (-0.02, 0, 0), (0.08, 0.43, 0.43),
                       energy_mat, 32, 16)
    corona.parent = root
    for i in range(16):
        a = math.tau * i / 16 + random.uniform(-0.05, 0.05)
        r0 = random.uniform(0.10, 0.24)
        r1 = random.uniform(0.56, 1.02)
        start = (-0.03, math.cos(a) * r0, math.sin(a) * r0)
        tip = (random.uniform(-0.10, 0.03), math.cos(a) * r1, math.sin(a) * r1)
        ray = cylinder_between("Impact radial plasma shard", start, tip,
                               random.uniform(0.014, 0.042), 0.0,
                               white_mat if i % 3 else energy_mat, 8)
        ray.parent = root
    sparks = principled("Concrete impact | amber aggregate sparks", (1.0, 0.22, 0.035), 0.2,
                        0.0, (1.0, 0.12, 0.015), 7.5)
    for i in range(28):
        a = random.uniform(0, math.tau)
        elev = random.uniform(-0.8, 0.8)
        direction = Vector((random.uniform(-0.25, 0.35), math.cos(a), math.sin(a) + elev * 0.35)).normalized()
        length = random.uniform(0.18, 0.72)
        points = [tuple(direction * 0.10),
                  tuple(direction * (length * 0.65) + Vector((0, random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08)))),
                  tuple(direction * length)]
        spark = make_curve("Concrete impact | flying incandescent grain", points,
                           random.uniform(0.0025, 0.006), sparks, False, root, 8)
    for frame, scale in [(1, 0.001), (113, 0.001), (116, 0.55), (119, 1.0),
                         (122, 0.78), (126, 0.32), (132, 0.001), (192, 0.001)]:
        root.scale = (scale, scale, scale)
        root.keyframe_insert(data_path="scale", frame=frame)
    return root


def gas_domain(name, center, dimensions, color, cache_path, resolution=48, noise_scale=2,
               density_multiplier=0.30, emission=(0.08, 0.24, 0.46), emission_strength=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    domain = bpy.context.object
    domain.name = name
    domain.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = domain.modifiers.new("Mantaflow gas volume simulation", "FLUID")
    mod.fluid_type = "DOMAIN"
    ds = mod.domain_settings
    ds.domain_type = "GAS"
    ds.cache_type = "MODULAR"
    ds.cache_data_format = "OPENVDB"
    ds.cache_directory = str(cache_path)
    ds.cache_frame_start = 1
    ds.cache_frame_end = 192
    ds.resolution_max = resolution
    ds.use_adaptive_domain = True
    ds.use_noise = True
    ds.noise_scale = noise_scale
    ds.vorticity = 0.35
    ds.time_scale = 1.0
    ds.cfl_condition = 3.0
    ds.cache_resumable = True
    ds.cache_noise_format = "OPENVDB"
    vol = bpy.data.materials.new(name + " | real density field")
    vol.use_nodes = True
    nt = vol.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    pv = nt.nodes.new("ShaderNodeVolumePrincipled")
    pv.inputs["Color"].default_value = (*color, 1.0)
    pv.inputs["Anisotropy"].default_value = 0.38
    pv.inputs["Emission Color"].default_value = (*emission, 1.0)
    pv.inputs["Emission Strength"].default_value = emission_strength
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "density"
    density_scale = nt.nodes.new("ShaderNodeMath")
    density_scale.operation = "MULTIPLY"
    density_scale.inputs[1].default_value = density_multiplier
    nt.links.new(attr.outputs["Fac"], density_scale.inputs[0])
    nt.links.new(density_scale.outputs[0], pv.inputs["Density"])
    nt.links.new(pv.outputs["Volume"], out.inputs["Volume"])
    domain.data.materials.append(vol)
    domain.display_type = "WIRE"
    domain.hide_viewport = True
    # Hidden physical emitters are keyed in world space and release mass only during the action.
    return domain, ds


def flow_sphere(name, loc, radius, flow_type="SMOKE", density=1.3, temp=1.2, velocity=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.hide_render = True
    ob.display_type = "WIRE"
    fm = ob.modifiers.new("Animated Mantaflow source", "FLUID")
    fm.fluid_type = "FLOW"
    fs = fm.flow_settings
    fs.flow_type = flow_type
    fs.flow_behavior = "INFLOW"
    fs.flow_source = "MESH"
    fs.density = density
    fs.temperature = temp
    fs.use_initial_velocity = True
    fs.velocity_coord = velocity
    fs.surface_distance = 1.25
    return ob, fs


def animate_volume_density(domain, keys):
    material = next(m for m in domain.data.materials if m and m.use_nodes)
    density_scale = next(n for n in material.node_tree.nodes
                         if n.type == "MATH" and n.operation == "MULTIPLY")
    socket = density_scale.inputs[1]
    for frame, value in keys:
        socket.default_value = value
        socket.keyframe_insert(data_path="default_value", frame=frame, group="Cinematic volume density")
    if material.node_tree.animation_data and material.node_tree.animation_data.action:
        for curve in material.node_tree.animation_data.action.fcurves:
            for point in curve.keyframe_points:
                point.interpolation = "LINEAR"


def create_cameras(scene):
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.name = "Cinematic five-shot camera"
    cam.data.lens = 40
    cam.data.dof.use_dof = True
    cam.data.dof.aperture_fstop = 7.1
    cam.data.dof.focus_distance = 9.0
    scene.camera = cam
    views = [
        # Wide, low three-quarter views preserve the source-board subject placement and show context.
        (1, (-3.5, -6.0, 3.4), (-1.0, 0.0, 1.05), 42),
        (49, (-3.5, -6.0, 3.4), (-1.0, 0.0, 1.05), 42),
        (73, (-0.55, -5.8, 2.45), (0.40, 0.0, 1.25), 28),
        (109, (-4.5, -6.5, 3.5), (0.95, 0.0, 1.40), 28),
        (145, (-4.0, -7.5, 3.35), (3.35, 0.0, 1.20), 32),
    ]
    for frame, pos, target, focal_length in views:
        cam.location = pos
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = focal_length
        cam.keyframe_insert(data_path="location", frame=frame)
        cam.keyframe_insert(data_path="rotation_euler", frame=frame)
        cam.data.keyframe_insert(data_path="lens", frame=frame)
    if cam.animation_data and cam.animation_data.action:
        for fc in cam.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"
    if cam.data.animation_data and cam.data.animation_data.action:
        for fc in cam.data.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"
    return cam


def light(name, kind, loc, target, color, power, size=3.0):
    data = bpy.data.lights.new(name, kind)
    data.energy = power
    data.color = color
    if kind == "AREA":
        data.shape = "DISK"
        data.size = size
    elif kind == "POINT":
        data.shadow_soft_size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    if kind != "POINT":
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def compositor(scene):
    scene.use_nodes = True
    nodes = scene.node_tree.nodes
    nodes.clear()
    render = nodes.new("CompositorNodeRLayers")
    glare = nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.quality = "HIGH"
    glare.threshold = 1.5
    glare.size = 8
    comp = nodes.new("CompositorNodeComposite")
    scene.node_tree.links.new(render.outputs["Image"], glare.inputs["Image"])
    scene.node_tree.links.new(glare.outputs["Image"], comp.inputs["Image"])


def make_scene():
    clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.015
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 3
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.frame_start = 1
    scene.frame_end = 192
    scene.render.fps = 24
    scene.render.fps_base = 1.0
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -0.45
    scene.view_settings.gamma = 1.0
    scene.render.film_transparent = False
    scene.render.image_settings.color_depth = "8"
    scene.render.filepath = str(RENDERS / "cinematic_####")
    scene.world.color = (0.006, 0.011, 0.009)
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.015, 0.025, 0.023, 1)
    bg.inputs["Strength"].default_value = 0.22
    scene.render.use_persistent_data = True
    scene.cycles.volume_step_rate = 0.8
    scene.cycles.volume_max_steps = 256
    compositor(scene)

    # Existing local PBR sets; no third-party or replacement texture look is introduced.
    ground_mat = pbr_material("Photoreal wet jungle soil | Airfield HQ PBR",
                              ROOT / "assets/airfield_hq_v21/runtime/Bloedjungle_Airfield_HQ_2_1_LOD0_dirt_diff_1024.jpg",
                              ROOT / "assets/airfield_hq_v21/runtime/Bloedjungle_Airfield_HQ_2_1_LOD0_dirt_nor_gl_1024.jpg",
                              ROOT / "assets/airfield_hq_v21/runtime/Bloedjungle_Airfield_HQ_2_1_LOD0_dirt_arm_1024.jpg", (4.5, 4.5, 1))
    concrete = pbr_material("Concrete rubble | approved VQ2 PBR maps",
                            ROOT / "assets/textures/vq2/concrete/albedo.jpg",
                            ROOT / "assets/textures/vq2/concrete/normal.jpg",
                            ROOT / "assets/textures/vq2/concrete/orm.png", (1.4, 1.4, 1.0))
    weathered_concrete(concrete)
    rock_mat = pbr_material("Laterite and volcanic stones | PBR",
                            ROOT / "assets/textures/buildings/concrete/base_color.jpg",
                            ROOT / "assets/textures/buildings/concrete/normal_gl.jpg",
                            ROOT / "assets/textures/buildings/concrete/roughness.jpg", (1.0, 1.0, 1.0))
    leaf_mat = principled("Broadleaf foliage base", (0.035, 0.19, 0.055), 0.43)
    fern_mat = principled("Fern leaf base", (0.055, 0.23, 0.075), 0.46)
    bark_mat = principled("Wet tropical hardwood", (0.10, 0.06, 0.032), 0.86)
    moss_mat = principled("Moss and ground lichen", (0.035, 0.125, 0.042), 0.84)
    metal_mat = principled("Parkerized forged steel", (0.036, 0.052, 0.069), 0.29, 0.86)
    rust_mat = principled("Oxidized rebar steel", (0.105, 0.045, 0.021), 0.65, 0.74)
    energy_mat = principled("M-47 plasma | blue cyan emission", (0.013, 0.16, 0.68), 0.17, 0.18, (0.018, 0.21, 1.0), 3.0)
    white_mat = principled("M-47 plasma | white blue-hot emission", (0.72, 0.93, 1.0), 0.11, 0.0, (0.78, 0.95, 1.0), 2.3)

    ground_scene(ground_mat, rock_mat, leaf_mat, fern_mat, bark_mat)
    dense_jungle_real()
    wall_x, fracture_parts = wall_and_fracture(concrete, rust_mat, moss_mat)

    m47_objs, m47_before, gun_root, soldier_objs, soldier_root, lod0 = import_hero_assets()
    # At the source's rest transform this aligns the approved M-47 with the commando's two-handed aim pose.
    muzzle = (-1.18, 0.12, 1.20)
    weapon_core_ornament((-2.25, 0.12, 1.35), gun_root, energy_mat, metal_mat)
    flash = make_flash(muzzle, white_mat, energy_mat)
    projectile, wake = make_projectile(muzzle[0] + 0.42, muzzle[1], muzzle[2], energy_mat, white_mat, metal_mat)
    projectile.location = (muzzle[0] + 0.43, muzzle[1], muzzle[2])
    projectile.keyframe_insert(data_path="location", frame=1)
    projectile.scale = (0.001, 0.001, 0.001); projectile.keyframe_insert(data_path="scale", frame=1)
    projectile.keyframe_insert(data_path="location", frame=67)
    projectile.keyframe_insert(data_path="scale", frame=67)
    projectile.scale = (1, 1, 1); projectile.keyframe_insert(data_path="scale", frame=72)
    projectile.location.x = muzzle[0] + 0.65; projectile.keyframe_insert(data_path="location", frame=72)
    projectile.location.x = wall_x - 0.72; projectile.keyframe_insert(data_path="location", frame=104)
    projectile.location.x = wall_x - 0.48; projectile.keyframe_insert(data_path="location", frame=108)
    projectile.scale = (0.001, 0.001, 0.001); projectile.keyframe_insert(data_path="scale", frame=112)
    projectile.keyframe_insert(data_path="scale", frame=192)
    # Animate the wake root only: child curves retain their authored helical local coordinates.
    wake.location = projectile.location
    wake.keyframe_insert(data_path="location", frame=1)
    wake.scale = (0.001, 0.001, 0.001); wake.keyframe_insert(data_path="scale", frame=1)
    wake.keyframe_insert(data_path="location", frame=68)
    wake.keyframe_insert(data_path="scale", frame=68)
    wake.scale = (1, 1, 1); wake.keyframe_insert(data_path="scale", frame=73)
    wake.location = projectile.location; wake.keyframe_insert(data_path="location", frame=73)
    projectile.location.x = wall_x - 0.72
    wake.location = projectile.location; wake.keyframe_insert(data_path="location", frame=104)
    wake.scale = (0.001, 0.001, 0.001); wake.keyframe_insert(data_path="scale", frame=112)
    wake.keyframe_insert(data_path="scale", frame=192)
    # Core rings spin continuously during flight; the GLB's native five clips animate the weapon mechanism.
    for ob in projectile.children:
        if "Rotating containment hoop" in ob.name:
            ob.rotation_euler.x = 0.0; ob.keyframe_insert(data_path="rotation_euler", frame=72)
            ob.rotation_euler.x = math.tau * 1.5; ob.keyframe_insert(data_path="rotation_euler", frame=108)
            for fc in ob.animation_data.action.fcurves:
                for kp in fc.keyframe_points: kp.interpolation = "LINEAR"
    hex_shockwave(wall_x, energy_mat, white_mat)
    make_impact_flash(wall_x, energy_mat, white_mat)

    # Physical key and rim sources create grounded glossy reflections; transient lights are keyed to events.
    light("Large soft warm canopy key", "AREA", (-3.6, -5.0, 8.5), (1, 0, 0.6), (1.0, 0.78, 0.56), 360, 6.0)
    light("Soft commando and muzzle fill", "AREA", (-4.2, -1.4, 4.4), (-1.8, 0.1, 1.2), (0.56, 0.72, 1.0), 320, 3.2)
    light("Cool cyan wall rim", "AREA", (5.4, 1.7, 5.4), (2.6, 0, 1.2), (0.16, 0.42, 1.0), 650, 4.5)
    light("Soft jungle skylight", "AREA", (-2.0, 4.5, 6.5), (0, 0, 0.1), (0.30, 0.55, 0.37), 420, 7.0)
    canopy_sun = light("Low raking tropical sun", "SUN", (-7.0, -6.0, 8.0), (0, 0, 0.4),
                       (1.0, 0.83, 0.66), 1.25)
    canopy_sun.data.angle = 0.12
    flashlight = light("Muzzle flash light", "POINT", muzzle, (0, 0, 0), (0.55, 0.8, 1.0), 0, 0.45)
    for frame, power in [(1, 0), (48, 0), (50, 1800), (52, 1100), (56, 0), (192, 0)]:
        flashlight.data.energy = power; flashlight.data.keyframe_insert(data_path="energy", frame=frame)
    impact_light = light("Impact bloom light", "POINT", (wall_x - 0.05, 0, 1.4), (0, 0, 0), (0.40, 0.75, 1.0), 0, 1.1)
    for frame, power in [(1, 0), (112, 0), (116, 5200), (120, 3300), (127, 900), (135, 0), (192, 0)]:
        impact_light.data.energy = power; impact_light.data.keyframe_insert(data_path="energy", frame=frame)
    flightlight = light("Projectile travelling point light", "POINT", (-1, 0, 1.2), (0, 0, 0), (0.12, 0.45, 1.0), 500, 0.65)
    for frame, x in [(68, muzzle[0]), (72, muzzle[0] + 0.65), (104, wall_x - 0.72), (108, wall_x - 0.48)]:
        flightlight.location.x = x; flightlight.keyframe_insert(data_path="location", frame=frame)
    for frame, power in [(1, 0), (68, 0), (72, 900), (102, 600), (108, 400), (112, 0), (192, 0)]:
        flightlight.data.energy = power; flightlight.data.keyframe_insert(data_path="energy", frame=frame)

    # Two independently baked Mantaflow gas fields: cool kinetic smoke and warm mineral dust.
    smoke_domain, smoke_settings = gas_domain("Volumetric simulation | blue-grey projectile smoke",
                                                (-0.15, 0.0, 1.45), (5.3, 3.0, 3.1),
                                                (0.56, 0.68, 0.82), CACHE / "smoke", 48, 2,
                                                0.30, (0.08, 0.24, 0.46), 0.012)
    animate_volume_density(smoke_domain, [(1, 0.30), (68, 0.30), (72, 0.18), (104, 0.16),
                                          (116, 0.13), (126, 0.15), (150, 0.20), (171, 0.24), (192, 0.15)])
    trail_flow, tfs = flow_sphere("Moving smoke source | projectile wake", (-0.9, 0.12, 1.2), 0.16,
                                  "SMOKE", 0.9, 0.2, (2.6, 0.12, 0.08))
    for frame, x, dens in [(1, -0.9, 0), (67, -0.9, 0), (72, -0.25, 0.95), (104, 2.7, 1.2), (108, 3.0, 1.4), (112, 3.15, 0.2), (120, 3.15, 0), (192, 3.15, 0)]:
        trail_flow.location.x = x; trail_flow.keyframe_insert(data_path="location", frame=frame)
        tfs.density = dens; tfs.keyframe_insert(data_path="density", frame=frame)
    impact_flow, ifs = flow_sphere("Impact smoke emitter | fracture cloud", (3.38, 0, 0.65), 0.43,
                                   "SMOKE", 2.5, 1.4, (-0.4, 0, 0.6))
    for frame, dens in [(1, 0), (106, 0), (112, 1.5), (119, 2.1), (132, 1.8), (152, 0.7), (172, 0.15), (192, 0)]:
        ifs.density = dens; ifs.keyframe_insert(data_path="density", frame=frame)

    dust_domain, dust_settings = gas_domain("Volumetric simulation | warm concrete dust",
                                              (3.8, 0.0, 1.3), (5.6, 5.4, 3.0),
                                              (0.56, 0.32, 0.18), CACHE / "dust", 48, 2,
                                              0.28, (0.30, 0.18, 0.06), 0.018)
    animate_volume_density(dust_domain, [(1, 0.28), (108, 0.28), (116, 0.16), (123, 0.16),
                                         (136, 0.30), (150, 0.72), (171, 1.0), (188, 0.40), (192, 0.25)])
    dust_flow, dfs = flow_sphere("Ground-hugging dust emitter | wall base", (3.1, 0, 0.18), 0.52,
                                 "SMOKE", 2.5, -0.15, (-0.25, 0.0, 0.3))
    for frame, dens in [(1, 0), (108, 0), (114, 1.8), (126, 2.5), (143, 2.1), (160, 1.2), (180, 0.45), (192, 0.2)]:
        dfs.density = dens; dfs.keyframe_insert(data_path="density", frame=frame)

    create_cameras(scene)
    # A faint physical scattering atmosphere gives distant foliage depth; simulated dust remains separate.
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.28
    scene.frame_set(24)
    # Pack PBR image maps for a self-contained .blend while keeping Mantaflow VDB data beside it.
    bpy.ops.file.pack_all()
    BLEND_DIR.mkdir(parents=True, exist_ok=True)
    RENDERS.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_DIR / "M47_Photoreal_Cinematic_5_0.blend"))
    source_hash = hashlib.sha256(ASSET.read_bytes()).hexdigest()
    tris = {}
    for name in ("M47_LOD0", "M47_LOD1", "M47_LOD2"):
        ob = next(o for o in m47_objs if o.name == name)
        tris[name] = sum(max(0, len(p.vertices) - 2) for p in ob.data.polygons)
    report = {
        "blender_version": bpy.app.version_string,
        "engine": scene.render.engine,
        "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        "fps": scene.render.fps,
        "duration_seconds": (scene.frame_end - scene.frame_start + 1) / scene.render.fps,
        "approved_m47_source": ASSET.relative_to(ROOT).as_posix(),
        "approved_m47_sha256": source_hash,
        "m47_lod_triangles": tris,
        "lod0_visible": not lod0.hide_render,
        "lod1_lod2_render_hidden": all(next(o for o in m47_objs if o.name == n).hide_render for n in ("M47_LOD1", "M47_LOD2")),
        "m47_actions": sorted(a.name for a in bpy.data.actions if any(a.name.startswith(n + "_M47_Mechanism_Rig") for n in ("Idle", "Equip", "Aim", "Fire", "Reload"))),
        "m47_material_names": sorted({m.name for ob in m47_objs if ob.type == "MESH" for m in ob.data.materials if m}),
        "volumetric_domains": [smoke_domain.name, dust_domain.name],
        "volumetric_source_count": 3,
        "mantaflow": {
            "cache_format": "OpenVDB",
            "cache_frames": [1, 192],
            "domain_resolution": 48,
            "detail_noise_scale": 2,
            "bake_type": "modular data and noise caches",
        },
        "photogrammetry_tree_instances": sum(1 for o in scene.objects
                                               if o.name.startswith("Photogrammetry jungle canopy | ")),
        "photogrammetry_fern_patches": sum(1 for o in scene.objects
                                             if o.name.startswith("Island fern patch ")),
        "pbr_grass_clumps": sum(1 for o in scene.objects
                                  if o.name.startswith("PBR broadleaf grass clump ")),
        "planned_video": {"resolution": [960, 540], "fps": 24, "frames": 192,
                           "samples": 3, "engine": "Cycles CPU"},
        "planned_stills": {"resolution": [960, 540], "samples": 8, "engine": "Cycles CPU"},
        "masonry_stones": len(wall_parts),
        "fracture_stones_animated": len(fracture_parts),
        "large_concrete_debris": 56,
        "render_notes": "Cycles CPU, AgX high contrast, OpenImageDenoise; 24 fps x 192 frames = 8.0 seconds.",
    }
    (OUT / "build_metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    log("BUILT", json.dumps(report, ensure_ascii=False))


def bake_volumes(selected=None):
    scene = bpy.context.scene
    all_domains = ("Volumetric simulation | blue-grey projectile smoke", "Volumetric simulation | warm concrete dust")
    for domain_name in (selected or all_domains):
        domain = bpy.data.objects[domain_name]
        mod = next(m for m in domain.modifiers if m.type == "FLUID")
        ds = mod.domain_settings
        bpy.ops.object.select_all(action="DESELECT")
        domain.hide_viewport = False
        domain.hide_set(False)
        domain.select_set(True)
        bpy.context.view_layer.objects.active = domain
        if ds.cache_directory.startswith("//"):
            ds.cache_directory = str((BLEND_DIR / ds.cache_directory[2:]).resolve())
        Path(ds.cache_directory).mkdir(parents=True, exist_ok=True)
        if not ds.has_cache_baked_data:
            log("BAKE DATA START", domain_name, "resolution", ds.resolution_max, "frames", ds.cache_frame_end)
            bpy.ops.fluid.bake_data()
            log("BAKE DATA DONE", domain_name)
        if ds.use_noise and not ds.has_cache_baked_noise:
            log("BAKE NOISE START", domain_name)
            bpy.ops.fluid.bake_noise()
            log("BAKE NOISE DONE", domain_name)
        # Store portable, project-relative cache locations in the saved source file.
        ds.cache_directory = bpy.path.relpath(ds.cache_directory, start=str(BLEND_DIR))
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_DIR / "M47_Photoreal_Cinematic_5_0.blend"))
    log("VOLUME_BAKE_COMPLETE")


def render_stills():
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_percentage = 75
    scene.cycles.samples = 8
    scene.cycles.adaptive_threshold = 0.012
    shots = [(24, "01_load_core_rotation.png", "Laden / kernrotatie"),
             (53, "02_muzzle_fire.png", "Afvuren / mechanische terugslag"),
             (91, "03_projectile_flight.png", "Projectiel in vlucht"),
             (122, "04_impact_shockwave.png", "Impact / zeshoekige schokgolf"),
             (171, "05_permanent_breach.png", "Muurdoorbraak / puin en stof")]
    manifest = []
    for frame, filename, label in shots:
        scene.frame_set(frame)
        scene.render.filepath = str(RENDERS / filename)
        log("RENDER STILL", label, frame, scene.camera.name, scene.render.filepath)
        bpy.ops.render.render(write_still=True)
        manifest.append({"frame": frame, "label": label, "file": filename})
    (RENDERS / "stills.json").write_text(json.dumps(manifest, indent=2) + "\n")


def render_video():
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
    scene.render.ffmpeg.ffmpeg_preset = "GOOD"
    scene.render.ffmpeg.video_bitrate = 14000
    scene.render.ffmpeg.gopsize = 24
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.resolution_percentage = 100
    scene.render.fps = 24
    scene.cycles.samples = 8
    scene.cycles.adaptive_threshold = 0.02
    scene.render.filepath = str(OUT / "M47_Photoreal_Cinematic_5_0")
    log("RENDER VIDEO START", scene.frame_start, scene.frame_end, scene.render.fps,
        scene.render.resolution_x, scene.render.resolution_y, scene.cycles.samples, "Cycles samples")
    bpy.ops.render.render(animation=True)
    log("RENDER VIDEO COMPLETE", scene.render.filepath)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["--build"]
    if "--build" in args:
        make_scene()
    elif not bpy.data.filepath:
        raise RuntimeError("Open the saved M47_Photoreal_Cinematic_5_0.blend before bake/render operations")
    if "--bake" in args:
        bake_volumes()
    if "--bake-smoke" in args:
        bake_volumes(["Volumetric simulation | blue-grey projectile smoke"])
    if "--bake-dust" in args:
        bake_volumes(["Volumetric simulation | warm concrete dust"])
    if "--stills" in args:
        render_stills()
    if "--video" in args:
        render_video()


if __name__ == "__main__":
    main()
