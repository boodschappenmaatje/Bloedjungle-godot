"""Build one Cycles impact hero still using the unchanged approved M-47 GLB."""
import importlib.util
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parents[1]
BLEND_DIR = OUT / "blender"
RENDERS = OUT / "renders"
REF_DIR = OUT / "reference"
ASSET = ROOT / "docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb"
BUILD_SCRIPT = ROOT / "tests/m47_photoreal_vfx5/blender/build_cinematic.py"
random.seed(51047)


def load_base_builder():
    spec = importlib.util.spec_from_file_location("m47_vfx5_builder", BUILD_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.OUT = OUT
    mod.BLEND_DIR = BLEND_DIR
    mod.RENDERS = RENDERS
    mod.CACHE = BLEND_DIR / "cache"
    return mod


def make_surface(name, color, roughness=0.65, metallic=0.0, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = roughness
    bs.inputs["Metallic"].default_value = metallic
    if emission:
        bs.inputs["Emission Color"].default_value = (*emission, 1)
        bs.inputs["Emission Strength"].default_value = strength
    return mat


def make_volume(name, color, density, scale, detail=6.0, anisotropy=0.3):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    volume = nt.nodes.new("ShaderNodeVolumePrincipled")
    volume.inputs["Color"].default_value = (*color, 1)
    volume.inputs["Anisotropy"].default_value = anisotropy
    texcoord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    noise.inputs["Roughness"].default_value = 0.72
    nt.links.new(texcoord.outputs["Generated"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[0].color = (0.015, 0.015, 0.015, 1)
    ramp.color_ramp.elements[1].position = 0.72
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    mid = ramp.color_ramp.elements.new(0.49)
    mid.color = (0.22, 0.22, 0.22, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    mult = nt.nodes.new("ShaderNodeMath")
    mult.operation = "MULTIPLY"
    mult.inputs[1].default_value = density
    nt.links.new(ramp.outputs["Color"], mult.inputs[0])
    nt.links.new(mult.outputs[0], volume.inputs["Density"])
    nt.links.new(volume.outputs["Volume"], out.inputs["Volume"])
    return mat


def volume_billow(name, loc, scale, material, seed):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=18, radius=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(material)
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.name = name + " | volumetric boundary"
    ob["noise_seed"] = seed
    return ob


def material_with_pbr_noise(name, base, roughness=0.82, bump_strength=0.28):
    mat = make_surface(name, base, roughness)
    nt = mat.node_tree
    bs = nt.nodes.get("Principled BSDF")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 26.0
    noise.inputs["Detail"].default_value = 6.2
    noise.inputs["Roughness"].default_value = 0.78
    nt.links.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.16
    ramp.color_ramp.elements[0].color = (base[0] * 0.43, base[1] * 0.45, base[2] * 0.43, 1)
    ramp.color_ramp.elements[1].position = 0.83
    ramp.color_ramp.elements[1].color = (min(1, base[0] * 1.52), min(1, base[1] * 1.48), min(1, base[2] * 1.43), 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bs.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = bump_strength
    bump.inputs["Distance"].default_value = 0.065
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bs.inputs["Normal"])
    return mat


def clip_polygon(poly, nx, nz, limit):
    """Clip a Y/Z polygon by nx*y + nz*z <= limit."""
    if not poly:
        return []
    out = []
    for p, q in zip(poly, poly[1:] + poly[:1]):
        fp = nx * p[0] + nz * p[1] - limit
        fq = nx * q[0] + nz * q[1] - limit
        inp, inq = fp <= 1.0e-7, fq <= 1.0e-7
        if inp and inq:
            out.append(q)
        elif inp and not inq:
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
        elif not inp and inq:
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
            out.append(q)
    return out


def voronoi_wall(front_mat, fracture_mat, wall_x=3.55):
    """A shot-specific, irregular fractured slab with a jagged energy-breach aperture."""
    y0, y1, z0, z1 = -3.48, 3.48, 0.10, 3.24
    seeds = []
    # Stratified-free point placement makes irregular, varied fracture cells rather than a brick grid.
    attempts = 0
    while len(seeds) < 48 and attempts < 4000:
        attempts += 1
        candidate = (random.uniform(y0, y1), random.uniform(z0, z1))
        if all((candidate[0] - p[0]) ** 2 + (candidate[1] - p[1]) ** 2 > 0.34 ** 2 for p in seeds):
            seeds.append(candidate)
    wall_collection = bpy.data.collections.new("Impact wall | irregular fracture field")
    bpy.context.scene.collection.children.link(wall_collection)
    for idx, (sy, sz) in enumerate(seeds):
        poly = [(y0, z0), (y1, z0), (y1, z1), (y0, z1)]
        for oy, oz in seeds:
            if (oy, oz) == (sy, sz):
                continue
            nx, nz = oy - sy, oz - sz
            limit = (oy * oy + oz * oz - sy * sy - sz * sz) * 0.5
            poly = clip_polygon(poly, nx, nz, limit)
            if len(poly) < 3:
                break
        if len(poly) < 3:
            continue
        cy = sum(p[0] for p in poly) / len(poly)
        cz = sum(p[1] for p in poly) / len(poly)
        radial = math.sqrt((cy / 1.02) ** 2 + ((cz - 1.48) / 0.96) ** 2)
        if radial < random.uniform(0.68, 0.91):
            continue
        inset = random.uniform(0.014, 0.032)
        poly = [(cy + (y - cy) * (1 - inset), cz + (z - cz) * (1 - inset)) for y, z in poly]
        chipped = []
        for p, q in zip(poly, poly[1:] + poly[:1]):
            edge = Vector((q[0] - p[0], q[1] - p[1]))
            normal = Vector((-edge[1], edge[0])).normalized()
            chipped.append(p)
            for t in (0.34, 0.69):
                v = Vector(p).lerp(Vector(q), t) + normal * random.uniform(-0.016, 0.016)
                chipped.append((v[0], v[1]))
        poly = chipped
        n = len(poly)
        front_x = wall_x - random.uniform(0.015, 0.070)
        depth = random.uniform(0.40, 0.72)
        verts = []
        for y, z in poly:
            verts.append((front_x + random.uniform(-0.018, 0.018), y, z))
        center_index = len(verts)
        verts.append((front_x - random.uniform(0.005, 0.045), cy, cz))
        back_start = len(verts)
        for y, z in poly:
            verts.append((front_x + depth + random.uniform(-0.035, 0.035), y, z))
        faces, material_ids = [], []
        for i in range(n):
            j = (i + 1) % n
            faces.append((center_index, i, j)); material_ids.append(0)
            faces.append((i, back_start + i, back_start + j, j)); material_ids.append(1)
        faces.append(tuple(back_start + i for i in range(n))); material_ids.append(0)
        mesh = bpy.data.meshes.new("Irregular fractured slab %03d" % idx)
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        uv = mesh.uv_layers.new(name="World-scale concrete PBR")
        for face in mesh.polygons:
            for li in face.loop_indices:
                co = mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv = (co.y * 1.6, co.z * 1.6)
        ob = bpy.data.objects.new("Broken concrete cell %03d" % idx, mesh)
        wall_collection.objects.link(ob)
        mesh.materials.append(front_mat)
        mesh.materials.append(fracture_mat)
        for face, mid in zip(mesh.polygons, material_ids):
            face.material_index = mid
            face.use_smooth = False
        bevel = ob.modifiers.new("Fresh chipped arris", "BEVEL")
        bevel.width = 0.013
        bevel.segments = 2
        bevel.profile = 0.46
        ob.modifiers.new("Stone face normals", "WEIGHTED_NORMAL")
        ob["fracture_cell"] = idx
        ob["distance_from_impact"] = radial


def make_irregular_chunk(name, loc, scale, material, rotation=None, sides=None):
    """Faceted, multi-plane concrete debris with weathered aggregate texture."""
    sides = sides or random.randint(9, 15)
    sx, sy, sz = scale
    verts, faces = [], []
    levels = [-0.52, -0.22, 0.19, 0.51]
    phase = random.uniform(0, math.tau)
    for li, h in enumerate(levels):
        offset = random.uniform(-0.10, 0.10)
        for i in range(sides):
            angle = phase + math.tau * i / sides + random.uniform(-0.10, 0.10)
            radial = random.uniform(0.72, 1.18)
            x = math.cos(angle) * sx * radial
            y = math.sin(angle) * sy * radial
            z = h * sz + offset * sz + random.uniform(-0.09, 0.09) * sz
            verts.append((x, y, z))
    low = len(verts); verts.append((random.uniform(-0.1, 0.1) * sx, random.uniform(-0.1, 0.1) * sy, -0.58 * sz))
    high = len(verts); verts.append((random.uniform(-0.1, 0.1) * sx, random.uniform(-0.1, 0.1) * sy, 0.57 * sz))
    for band in range(len(levels) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            a, b = band * sides + i, band * sides + j
            c, d = (band + 1) * sides + i, (band + 1) * sides + j
            if (i + band) % 2:
                faces.extend(((a, b, c), (b, d, c)))
            else:
                faces.extend(((a, b, d), (a, d, c)))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((low, j, i))
        faces.append((high, (len(levels) - 1) * sides + i, (len(levels) - 1) * sides + j))
    mesh = bpy.data.meshes.new(name + " | chipped stone geometry")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="Concrete fragment PBR")
    for face in mesh.polygons:
        for li in face.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (co.x * 1.75 + loc[1], co.y * 1.75 + loc[2])
        face.use_smooth = False
    mesh.materials.append(material)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.scale = (1, 1, 1)
    ob.rotation_euler = rotation or (random.uniform(-0.65, 0.65), random.uniform(-0.9, 0.9), random.random() * math.tau)
    ob["shard_faces"] = len(faces)
    bevel = ob.modifiers.new("Edge spall highlights", "BEVEL")
    bevel.width = min(scale) * 0.035
    bevel.segments = 2
    bevel.profile = 0.4
    ob.modifiers.new("Fracture face normals", "WEIGHTED_NORMAL")
    return ob


def create_impact_rubble(material):
    # Broad, irregular fragments hang in the blast plume; larger blocks collect at the wall toe.
    for i in range(14):
        a = random.uniform(0, math.tau)
        d = random.uniform(0.48, 1.38)
        loc = (3.34 - random.uniform(0.12, 0.55), math.cos(a) * d, 1.48 + math.sin(a) * d * 0.72)
        s = random.uniform(0.12, 0.33)
        make_irregular_chunk("Airborne fractured concrete %02d" % i, loc,
                             (s * random.uniform(1.0, 1.7), s * random.uniform(0.78, 1.45), s * random.uniform(0.72, 1.28)),
                             material)
    for i in range(36):
        y = random.uniform(-2.5, 2.5)
        x = random.uniform(2.75, 3.65)
        s = random.uniform(0.08, 0.36)
        loc = (x, y, max(0.08, s * random.uniform(0.15, 0.35)))
        make_irregular_chunk("Rubble apron | broken aggregate %02d" % i, loc,
                             (s * random.uniform(1.0, 1.75), s * random.uniform(0.65, 1.5), s * random.uniform(0.38, 0.82)),
                             material,
                             rotation=(random.uniform(-0.18, 0.18), random.uniform(-0.8, 0.8), random.random() * math.tau))
    # Hundreds of small chipped flakes, packed into one mesh to add scale at the camera distance.
    verts, faces = [], []
    for _ in range(180):
        x = random.uniform(2.50, 3.68)
        y = random.uniform(-2.4, 2.4)
        z = random.uniform(0.02, 0.22)
        size = random.uniform(0.012, 0.075)
        base = len(verts)
        verts.extend(((x, y, z), (x + random.uniform(-size, size), y + size, z + random.uniform(0, size * 0.6)),
                      (x + size, y - size * 0.45, z + random.uniform(0, size * 0.35)),
                      (x - size * 0.65, y - size * 0.3, max(0, z - size * 0.25))))
        faces.extend(((base, base + 1, base + 2), (base, base + 2, base + 3), (base, base + 3, base + 1)))
    mesh = bpy.data.meshes.new("Blast field | 180 fine concrete chips")
    mesh.from_pydata(verts, [], faces); mesh.update(); mesh.materials.append(material)
    ob = bpy.data.objects.new("Blast field | fine aggregate and chips", mesh)
    bpy.context.scene.collection.objects.link(ob)


def hide_old_impact_and_wall():
    prefixes = (
        "Wall stone ", "Fracture stone ", "Rough cast concrete wall", "Wall foundation", "Ribbed steel rebar",
        "Moss tuft at damp wall joint", "Large fractured concrete rubble", "Jagged aggregate fracture seam",
        "Fresh exposed crack lip", "Fractured hexagonal pressure arc", "Ionized hexagonal vertex",
        "Impact white-hot pressure core", "Impact cyan ionized corona", "Impact radial plasma shard",
        "Concrete impact | flying incandescent grain", "Volumetric simulation |", "Moving smoke source |",
        "Impact smoke emitter |", "Ground-hugging dust emitter |", "Fracture stone", "Fracture",
        "Liquid electric filament", "Branching arc spark", "Long helicoidal plasma vapor filament",
        "Muzzle flash spear", "Cyan ionization collar",
    )
    old_light_prefixes = ("Large soft warm canopy key", "Soft commando and muzzle fill", "Cool cyan wall rim",
                          "Soft jungle skylight", "Low raking tropical sun", "Muzzle flash light",
                          "Impact bloom light", "Projectile travelling point light")
    for ob in bpy.context.scene.objects:
        if ob.name.startswith(prefixes) or ob.name == "Impact crack reveal" or ob.name == "Impact center | hexagonal pressure front" or ob.name == "Concrete impact | blue-white flash and sparks":
            ob.hide_render = True
        if ob.type == "LIGHT" and ob.name.startswith(old_light_prefixes):
            ob.hide_render = True
        if ob.name.startswith("Fracture stone"):
            ob.hide_render = True


def build_crack_network(wall_x, dark_mat, fresh_mat):
    center_y, center_z = 0.0, 1.48
    for arm in range(24):
        angle = math.tau * arm / 24 + random.uniform(-0.08, 0.08)
        dist = random.uniform(1.05, 2.65)
        steps = random.randint(5, 9)
        pts = []
        for s in range(steps):
            t = s / (steps - 1)
            r = 0.58 + dist * t
            a = angle + random.uniform(-0.055, 0.055)
            pts.append((wall_x - 0.093, center_y + math.cos(a) * r,
                        center_z + math.sin(a) * r * random.uniform(0.85, 1.10)))
        c = bpy.data.curves.new("Deep branching concrete fissure", "CURVE")
        c.dimensions = "3D"; c.resolution_u = 1; c.bevel_depth = random.uniform(0.006, 0.014); c.bevel_resolution = 2
        s = c.splines.new("POLY"); s.points.add(len(pts) - 1)
        for v, p in zip(s.points, pts): v.co = (*p, 1)
        ob = bpy.data.objects.new("Radial fracture | deep shadow", c); bpy.context.scene.collection.objects.link(ob); c.materials.append(dark_mat)
        if arm % 2 == 0:
            branch_start = random.randint(2, max(2, steps - 2))
            origin = Vector(pts[branch_start])
            branch_angle = angle + random.choice([-1, 1]) * random.uniform(0.28, 0.82)
            branch = [tuple(origin)]
            for step in range(random.randint(2, 4)):
                r = 0.18 + step * random.uniform(0.16, 0.3)
                branch.append((wall_x - 0.095, origin.y + math.cos(branch_angle) * r,
                               origin.z + math.sin(branch_angle) * r))
            bc = bpy.data.curves.new("Secondary concrete fracture", "CURVE"); bc.dimensions = "3D"; bc.resolution_u = 1
            bc.bevel_depth = random.uniform(0.003, 0.007); bc.bevel_resolution = 2
            sp = bc.splines.new("POLY"); sp.points.add(len(branch) - 1)
            for v, p in zip(sp.points, branch): v.co = (*p, 1)
            bo = bpy.data.objects.new("Radial fracture branch | shadow", bc); bpy.context.scene.collection.objects.link(bo); bc.materials.append(dark_mat)


def hex_radius(angle, radius):
    local = (angle + math.pi / 6) % (math.pi / 3) - math.pi / 6
    return radius * math.cos(math.pi / 6) / max(0.35, math.cos(local))


def create_energy_membrane(wall_x, energy, pale, deep):
    center = Vector((wall_x - 0.48, 0.0, 1.48))
    # Wide, broken hexagonal plasma shell. The mesh body gives the arc depth and volume beyond filaments.
    count = 144
    verts, faces = [], []
    for i in range(count):
        a = math.tau * i / count
        wobble = 1.0 + 0.048 * math.sin(11 * a + 0.3) + 0.028 * math.sin(23 * a + 1.2)
        outer = hex_radius(a, 1.24) * wobble
        inner = hex_radius(a, 0.67) * (1.0 + 0.03 * math.sin(9 * a))
        x = center.x + 0.09 * math.sin(7 * a) + 0.045 * math.sin(17 * a)
        verts.extend(((x, center.y + math.cos(a) * outer, center.z + math.sin(a) * outer),
                      (x + 0.02 * math.sin(13 * a), center.y + math.cos(a) * inner, center.z + math.sin(a) * inner)))
    for i in range(count):
        j = (i + 1) % count
        faces.append((i * 2, j * 2, j * 2 + 1, i * 2 + 1))
    mesh = bpy.data.meshes.new("Hex impact | broad irregular plasma membrane")
    mesh.from_pydata(verts, [], faces); mesh.update(); mesh.materials.append(energy)
    shell = bpy.data.objects.new("Blue-white impact | broad hexagonal plasma shell", mesh)
    bpy.context.scene.collection.objects.link(shell)
    shell["description"] = "Shot-specific volumetric-looking membrane with irregular hexagonal silhouette"
    # Physical folded lobes bridge the outer shell to the hot impact core.
    for i in range(10):
        a0 = math.tau * i / 10 + random.uniform(-0.06, 0.06)
        a1 = a0 + random.uniform(0.10, 0.26)
        r0 = random.uniform(0.25, 0.55)
        r1 = random.uniform(0.62, 1.22)
        p0 = (center.x - 0.03, math.cos(a0) * r0, center.z + math.sin(a0) * r0)
        p1 = (center.x + random.uniform(-0.08, 0.08), math.cos(a1) * r1, center.z + math.sin(a1) * r1)
        mid = (center.x - random.uniform(0.02, 0.15), (p0[1] + p1[1]) * 0.5 + random.uniform(-0.12, 0.12),
               (p0[2] + p1[2]) * 0.5 + random.uniform(-0.12, 0.12))
        mesh = bpy.data.meshes.new("Folded plasma lobe mesh")
        mesh.from_pydata((p0, mid, p1, (mid[0] + 0.03, mid[1] * 0.76, mid[2] * 0.76)), [], ((0, 1, 3), (1, 2, 3)))
        mesh.materials.append(energy if i % 3 else pale); mesh.update()
        ob = bpy.data.objects.new("Blue-white impact | folded energy lobe %02d" % i, mesh); bpy.context.collection.objects.link(ob)
    # A dimmer, offset pressure halo softens the hex facets and reads as refracted energy.
    for layer, radius, mat, width in ((0, 1.52, deep, 0.018), (1, 1.02, pale, 0.011)):
        points = []
        for i in range(73):
            a = math.tau * i / 72
            r = hex_radius(a, radius) * (1 + 0.028 * math.sin(13 * a + layer))
            points.append((center.x + 0.10 * math.sin(8 * a), math.cos(a) * r, center.z + math.sin(a) * r))
        curve = bpy.data.curves.new("Broken impact halo filament", "CURVE"); curve.dimensions = "3D"; curve.resolution_u = 1
        curve.bevel_depth = width; curve.bevel_resolution = 3
        sp = curve.splines.new("POLY"); sp.points.add(len(points) - 1)
        for v, p in zip(sp.points, points): v.co = (*p, 1)
        ob = bpy.data.objects.new("Impact halo | refracted outer arc", curve); bpy.context.collection.objects.link(ob); curve.materials.append(mat)
    # Forked electric tendrils run from the white core into masonry cracks.
    for i in range(18):
        start_angle = random.uniform(0, math.tau)
        start_r = random.uniform(0.16, 0.44)
        end_r = random.uniform(0.9, 2.25)
        steps = random.randint(5, 9)
        points = []
        phase = random.uniform(-0.14, 0.14)
        for step in range(steps):
            t = step / (steps - 1)
            a = start_angle + phase * t + random.uniform(-0.055, 0.055)
            r = start_r + (end_r - start_r) * t
            points.append((center.x + random.uniform(-0.07, 0.07), math.cos(a) * r,
                           center.z + math.sin(a) * r * random.uniform(0.92, 1.08)))
        c = bpy.data.curves.new("Forked ionized tendril", "CURVE"); c.dimensions = "3D"; c.resolution_u = 2
        c.bevel_depth = random.uniform(0.003, 0.008); c.bevel_resolution = 3
        sp = c.splines.new("POLY"); sp.points.add(len(points) - 1)
        for v, p in zip(sp.points, points): v.co = (*p, 1)
        ob = bpy.data.objects.new("Impact electrical filament | branching %02d" % i, c); bpy.context.collection.objects.link(ob)
        c.materials.append(pale if i % 5 == 0 else energy)
        if i % 4 == 0:
            origin = Vector(points[random.randint(2, steps - 2)])
            branch_points = [tuple(origin)]
            branch_a = start_angle + random.choice((-1, 1)) * random.uniform(0.4, 1.0)
            for k in range(1, 4):
                rr = 0.11 * k
                branch_points.append((center.x + random.uniform(-0.04, 0.04), origin.y + math.cos(branch_a) * rr,
                                      origin.z + math.sin(branch_a) * rr))
            bc = bpy.data.curves.new("Ionization branch tip", "CURVE"); bc.dimensions = "3D"; bc.resolution_u = 1
            bc.bevel_depth = 0.0038; bc.bevel_resolution = 2
            bs = bc.splines.new("POLY"); bs.points.add(len(branch_points) - 1)
            for v, p in zip(bs.points, branch_points): v.co = (*p, 1)
            bo = bpy.data.objects.new("Impact electrical filament | fork", bc); bpy.context.collection.objects.link(bo)
            bc.materials.append(pale)
    # Incandescent ionized center and broad blue-white spill.
    core_mat = make_surface("M-47 impact | white-hot plasma core", (0.8, 0.95, 1.0), 0.11, emission=(0.68, 0.92, 1.0), strength=14)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=56, ring_count=36, radius=1, location=(wall_x - 0.64, 0.0, 1.48))
    core = bpy.context.object; core.name = "Impact flash | white-hot center"; core.scale = (0.15, 0.20, 0.20); core.data.materials.append(core_mat)
    for p in core.data.polygons: p.use_smooth = True
    halo_mat = make_surface("M-47 impact | ionized blue halo", (0.02, 0.22, 0.9), 0.2, emission=(0.015, 0.18, 1.0), strength=2.0)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=28, radius=1, location=(wall_x - 0.68, 0.0, 1.48))
    halo = bpy.context.object; halo.name = "Impact flash | wide ionized envelope"; halo.scale = (0.32, 0.42, 0.42); halo.data.materials.append(halo_mat)
    for p in halo.data.polygons: p.use_smooth = True


def make_sparks(orange_mat, blue_mat):
    verts, faces, ids = [], [], []
    for i in range(190):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.18, 2.0)
        center = Vector((3.10 - random.uniform(0.1, 1.1), math.cos(a) * r, 1.48 + math.sin(a) * r * 0.75))
        direction = Vector((random.uniform(-0.55, 0.6), math.cos(a) + random.uniform(-0.7, 0.7), math.sin(a) + random.uniform(-0.4, 0.5))).normalized()
        length = random.uniform(0.035, 0.27)
        side = direction.cross(Vector((0, 0, 1))).normalized()
        if side.length < 0.001: side = Vector((0, 1, 0))
        w = random.uniform(0.002, 0.011)
        base = len(verts)
        verts.extend((tuple(center - side * w), tuple(center + side * w), tuple(center + direction * length),
                      tuple(center + direction * length * 0.72 + side * w * 0.2)))
        faces.extend(((base, base + 1, base + 2), (base, base + 2, base + 3)))
        ids.extend((1 if i % 5 == 0 else 0, 1 if i % 5 == 0 else 0))
    mesh = bpy.data.meshes.new("Impact spark shower | 190 ballistic fragments")
    mesh.from_pydata(verts, [], faces); mesh.update(); mesh.materials.append(orange_mat); mesh.materials.append(blue_mat)
    for face, mid in zip(mesh.polygons, ids): face.material_index = mid
    ob = bpy.data.objects.new("Impact sparks | orange aggregate and blue plasma", mesh)
    bpy.context.scene.collection.objects.link(ob)


def create_bent_rebar(metal):
    for i in range(13):
        y = random.uniform(-1.55, 1.55)
        z = random.uniform(0.38, 2.55)
        if abs(z - 1.48) < 0.55 and abs(y) < 0.65: continue
        points = [(3.73, y, z), (3.20, y + random.uniform(-0.06, 0.06), z + random.uniform(-0.12, 0.10)),
                  (2.74, y + random.uniform(-0.16, 0.16), z + random.uniform(-0.26, 0.24)),
                  (2.52, y + random.uniform(-0.24, 0.24), z + random.uniform(-0.34, 0.32))]
        c = bpy.data.curves.new("Rusted bent rebar | exposed in fracture", "CURVE"); c.dimensions = "3D"; c.resolution_u = 2
        c.bevel_depth = random.uniform(0.012, 0.023); c.bevel_resolution = 4
        s = c.splines.new("POLY"); s.points.add(len(points)-1)
        for v, p in zip(s.points, points): v.co = (*p,1)
        ob = bpy.data.objects.new("Bent reinforcement rod | blast torn", c); bpy.context.collection.objects.link(ob); c.materials.append(metal)


def create_smoke_and_dust():
    cool = make_volume("Impact smoke | cool grey-blue billows", (0.36, 0.48, 0.62), 0.90, 9.5, 9.0, 0.38)
    warm = make_volume("Concrete dust | warm limestone haze", (0.49, 0.39, 0.29), 0.68, 9.0, 8.0, 0.25)
    blue = make_volume("Ionized blue pressure haze", (0.06, 0.20, 0.68), 0.36, 10.0, 7.0, 0.48)
    # Uneven helicoidal wake intersects the impact bloom and carries smoke back toward the weapon.
    for i in range(14):
        t = i / 13
        x = -0.85 + 3.65 * t
        theta = t * math.tau * 2.65
        radius = 0.16 + 0.31 * t
        y = math.cos(theta) * radius + random.uniform(-0.13, 0.13)
        z = 1.46 + math.sin(theta) * radius * 0.72 + random.uniform(-0.14, 0.14)
        s = 0.24 + t * 0.19 + random.uniform(0.025, 0.075)
        volume_billow("Projectile wake | curled volumetric smoke %02d" % i, (x, y, z),
                      (s * random.uniform(1.3, 2.4), s, s * random.uniform(0.78, 1.35)), cool, i)
    # Break the impact cloud into overlapping lobes with varied scale and light transmission.
    for i in range(12):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.25, 1.45)
        loc = (3.15 - random.uniform(0.25, 1.35), math.cos(a) * r, 1.47 + math.sin(a) * r * 0.65)
        s = random.uniform(0.15, 0.40)
        volume_billow("Impact cloud | cool volumetric fold %02d" % i, loc,
                      (s * random.uniform(1.2, 1.8), s * random.uniform(0.75, 1.4), s * random.uniform(0.9, 1.5)), cool, 30+i)
    for i in range(10):
        y = random.uniform(-2.5, 2.5)
        x = random.uniform(2.35, 3.35)
        z = random.uniform(0.10, 0.58)
        s = random.uniform(0.16, 0.40)
        volume_billow("Wall base | ground-hugging limestone dust %02d" % i, (x, y, z),
                      (s * random.uniform(1.2, 2.4), s * random.uniform(1.2, 2.2), s * random.uniform(0.35, 0.75)), warm, 60+i)
    for i in range(5):
        a = math.tau * i / 7
        volume_billow("Ionized haze | blue rim lobe %02d" % i,
                      (3.05 - random.uniform(0.15, 0.55), math.cos(a) * random.uniform(0.45, 1.05),
                       1.48 + math.sin(a) * random.uniform(0.35, 0.85)),
                      (0.26, random.uniform(0.28, 0.64), random.uniform(0.28, 0.64)), blue, 80+i)


def add_lighting_and_camera(scene, builder):
    # The camera holds the target board's left-to-right shot direction and closes in on the strike.
    bpy.ops.object.camera_add(location=(-4.30, -8.20, 4.80))
    cam = bpy.context.object
    cam.name = "Impact hero camera | reference panel 4 composition"
    cam.rotation_euler = (Vector((1.55, 0.0, 1.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 37.0
    cam.data.sensor_width = 36
    cam.data.dof.use_dof = True
    cam.data.dof.focus_object = None
    cam.data.dof.focus_distance = 9.1
    cam.data.dof.aperture_fstop = 8.0
    scene.camera = cam
    # The broad soft key retains natural green/brown PBR color; the rim reveals chips and foliage.
    builder.light("Cinematic canopy key | warm softbox", "AREA", (-3.8, -4.6, 7.8), (1.0, 0, 0.7), (1.0, 0.76, 0.54), 260, 7.0)
    builder.light("Jungle skylight | deep green bounce", "AREA", (-1.5, 3.6, 6.8), (1.4, 0, 0.7), (0.32, 0.58, 0.38), 180, 7.0)
    builder.light("Wall rim | cool cyan bounce", "AREA", (4.6, 3.7, 4.8), (3.3, 0, 1.25), (0.20, 0.46, 1.0), 520, 3.4)
    builder.light("Foreground leaf lift | neutral", "AREA", (-5.8, -0.9, 3.4), (-0.3, 0, 0.4), (0.65, 0.77, 0.63), 125, 4.0)
    builder.light("Impact plasma spill | cyan point", "POINT", (2.88, 0, 1.48), (0,0,0), (0.10, 0.45, 1.0), 850, 1.05)
    builder.light("Impact core spill | ice white point", "POINT", (2.84, 0, 1.50), (0,0,0), (0.68, 0.86, 1.0), 300, 0.58)
    sun = builder.light("Broken canopy sun shaft", "SUN", (-4.0, -6.0, 8.0), (2.0, 0, 0.7), (1.0, 0.79, 0.56), 0.62)
    sun.data.angle = 0.18
    world = scene.world.node_tree.nodes.get("Background")
    world.inputs["Color"].default_value = (0.025, 0.039, 0.030, 1)
    world.inputs["Strength"].default_value = 0.09
    scene.view_settings.exposure = -0.58
    scene.view_settings.look = "AgX - Medium High Contrast"


def add_pbr_jungle_frame(scene):
    """Pull approved project grass and CC0 fern assets into the shot margins."""
    grasses = [o for o in scene.objects if o.name.startswith("Tall grass source variant") and o.type == "MESH"]
    grass_spots = [(-4.5, -1.8, 0.0), (-4.2, 2.0, 0.0), (-0.3, -3.8, 0.0),
                   (4.6, -2.8, 0.0), (5.4, 2.5, 0.0), (1.1, 4.4, 0.0)]
    for i, loc in enumerate(grass_spots):
        if not grasses: break
        src = grasses[i % len(grasses)]
        ob = src.copy(); ob.data = src.data; scene.collection.objects.link(ob)
        ob.name = "Impact framing | project PBR grass %02d" % i
        ob.hide_render = False; ob.hide_set(False)
        ob.location = loc; ob.rotation_euler.z = random.random() * math.tau
        scale = random.uniform(0.34, 0.62)
        ob.scale = tuple(scale * v for v in src.scale)
    ferns = [o for o in scene.objects if o.name.startswith("CC0 fern source | ") and o.type == "MESH"]
    fern_spots = [(-4.8, -0.4, 0.0), (-4.0, 3.6, 0.0), (-1.0, -4.6, 0.0),
                  (3.9, -4.0, 0.0), (6.0, 1.2, 0.0)]
    for i, loc in enumerate(fern_spots):
        root = bpy.data.objects.new("Impact framing | CC0 fern patch %02d" % i, None)
        scene.collection.objects.link(root); root.location = loc
        root.rotation_euler.z = random.random() * math.tau
        root.scale = (random.uniform(0.34, 0.55),) * 3
        for src in ferns:
            ob = src.copy(); ob.data = src.data; scene.collection.objects.link(ob)
            ob.name = "Impact framing fern frond | " + src.name
            ob.parent = root; ob.location = src.location.copy(); ob.rotation_euler = src.rotation_euler.copy()
            ob.scale = src.scale.copy(); ob.hide_render = False; ob.hide_set(False)
    trees = [o for o in scene.objects if o.instance_collection and o.name.startswith("Photogrammetry jungle canopy |")]
    tree_spots = [(5.2, 7.0, 0.0), (7.4, -2.0, 0.0), (8.0, 4.2, 0.0), (4.6, -7.0, 0.0)]
    for i, loc in enumerate(tree_spots):
        if not trees: break
        src = trees[i % len(trees)]
        ob = src.copy(); scene.collection.objects.link(ob)
        ob.name = "Impact framing | photogrammetry canopy %02d" % i
        ob.location = loc; ob.rotation_euler.z = random.uniform(-0.9, 0.9)
        scale = random.uniform(1.0, 1.45)
        ob.scale = tuple(scale * v for v in src.scale)


def configure_render(scene, preview=False):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 20 if preview else 96
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.015 if preview else 0.006
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.volume_step_rate = 0.65
    scene.cycles.volume_max_steps = 512
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 35 if preview else 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "16"
    scene.render.film_transparent = False
    scene.render.use_motion_blur = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.use_persistent_data = True
    scene.render.filepath = str(RENDERS / ("preview_impact.png" if preview else "M47_Impact_Hero_Cycles.png"))
    scene.world.color = (0.01, 0.016, 0.012)
    scene.use_nodes = True
    nt = scene.node_tree; nt.nodes.clear()
    layers = nt.nodes.new("CompositorNodeRLayers")
    glare = nt.nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"; glare.quality = "HIGH"; glare.threshold = 1.45; glare.size = 8
    glare.mix = -0.88
    comp = nt.nodes.new("CompositorNodeComposite")
    nt.links.new(layers.outputs["Image"], glare.inputs["Image"])
    nt.links.new(glare.outputs["Image"], comp.inputs["Image"])


def main():
    preview = "--preview" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True); BLEND_DIR.mkdir(parents=True, exist_ok=True); RENDERS.mkdir(parents=True, exist_ok=True); REF_DIR.mkdir(parents=True, exist_ok=True)
    # Resolve shared Poly Haven source libraries through the parent approved branch without copying them.
    assets_link = OUT / "assets"
    if not assets_link.exists():
        assets_link.symlink_to(Path("../m47_photoreal_vfx5/assets"), target_is_directory=True)
    builder = load_base_builder()
    original_wall_builder = builder.wall_and_fracture
    def wall_builder_with_real_count(*args, **kwargs):
        wall_x, fracture_parts = original_wall_builder(*args, **kwargs)
        static_wall = bpy.data.objects["Rough cast concrete wall | intact outer field"]
        # Each authored masonry cell has 84 vertices before the static field is joined.
        builder.wall_parts = [None] * (len(static_wall.data.vertices) // 84 + len(fracture_parts))
        return wall_x, fracture_parts
    builder.wall_and_fracture = wall_builder_with_real_count
    builder.make_scene()
    # The shared builder saves an intermediate 5.0 scene and manifest before this shot is added.
    # The in-memory scene is complete, so keep only this branch's final impact source and report.
    for generated in (BLEND_DIR / "M47_Photoreal_Cinematic_5_0.blend",
                      BLEND_DIR / "M47_Photoreal_Cinematic_5_0.blend1",
                      OUT / "build_metrics.json"):
        generated.unlink(missing_ok=True)
    scene = bpy.context.scene
    scene.frame_set(122)
    hide_old_impact_and_wall()

    concrete = builder.pbr_material(
        "Impact wall | project 2K exposed-aggregate concrete PBR",
        ROOT / "assets/airfield_hq_v21/runtime/Bloedjungle_Airfield_HQ_2_1_LOD0_concrete_floor_01_diff_2k.jpg",
        ROOT / "assets/airfield_hq_v21/runtime/Bloedjungle_Airfield_HQ_2_1_LOD0_concrete_floor_01_nor_gl_2k.jpg",
        ROOT / "assets/airfield_hq_v21/runtime/Bloedjungle_Airfield_HQ_2_1_LOD0_concrete_floor_01_arm_2k.jpg",
        (1.0, 1.0, 1.0))
    fresh = material_with_pbr_noise("Fresh exposed aggregate | pale fractured interior", (0.43, 0.45, 0.43), 0.91, 0.34)
    fissure = make_surface("Concrete fissure | deep wet shadow", (0.018, 0.023, 0.021), 0.98)
    steel = make_surface("Torn reinforcement | oxidized steel", (0.12, 0.052, 0.025), 0.61, 0.78)
    voronoi_wall(concrete, fresh)
    build_crack_network(3.55, fissure, fresh)
    create_impact_rubble(concrete)
    create_bent_rebar(steel)

    energy = make_surface("Impact membrane | electric cobalt", (0.018, 0.16, 0.66), 0.22, 0.16, (0.012, 0.21, 1.0), 3.6)
    pale = make_surface("Impact membrane | blue-white ion edge", (0.55, 0.85, 1.0), 0.16, 0.05, (0.40, 0.76, 1.0), 5.4)
    deep = make_surface("Impact membrane | refracted deep blue", (0.008, 0.045, 0.22), 0.23, 0.28, (0.01, 0.10, 0.55), 1.5)
    create_energy_membrane(3.55, energy, pale, deep)
    make_sparks(make_surface("Incandescent concrete sparks | warm", (1.0, 0.22, 0.035), 0.22, emission=(1.0,0.12,0.01), strength=7.8),
                make_surface("Plasma sparks | cyan-white", (0.52, 0.88, 1.0), 0.18, emission=(0.3,0.72,1.0), strength=5.6))
    create_smoke_and_dust()
    add_lighting_and_camera(scene, builder)
    add_pbr_jungle_frame(scene)
    configure_render(scene, preview)

    source_sha = __import__("hashlib").sha256(ASSET.read_bytes()).hexdigest()
    scene.frame_set(122)
    m47 = next(o for o in scene.objects if o.name == "M47_LOD0")
    scene["M47 source SHA256"] = source_sha
    scene["M47 mesh data unchanged"] = True
    scene["Impact still reference"] = "../m47_photoreal_vfx5/reference/M47_VFX_2_1_TARGET.jpg"
    scene["Impact still phase"] = "single frame: energy projectile strikes irregular concrete wall"
    if not preview:
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_DIR / "M47_Impact_Hero_5_1.blend"))
    print("[M47-IMPACT-5.1] scene ready", "frame=122", "asset_sha256=" + source_sha,
          "m47_triangles=" + str(sum(max(0, len(p.vertices)-2) for p in m47.data.polygons)),
          "render=" + scene.render.filepath, flush=True)
    bpy.ops.render.render(write_still=True)
    if not preview:
        details = {"blender": bpy.app.version_string, "engine": scene.render.engine,
                   "resolution": [scene.render.resolution_x, scene.render.resolution_y],
                   "samples": scene.cycles.samples, "frame": scene.frame_current,
                   "approved_m47_glb": str(ASSET.relative_to(ROOT)), "approved_m47_sha256": source_sha,
                   "m47_lod0_triangles": sum(max(0, len(p.vertices)-2) for p in m47.data.polygons),
                   "render": "renders/M47_Impact_Hero_Cycles.png", "scene": "blender/M47_Impact_Hero_5_1.blend",
                   "smoke_puffs": sum(1 for o in scene.objects if o.name.startswith(("Projectile wake |", "Impact cloud |", "Wall base |", "Ionized haze |"))),
                   "rubble_objects": sum(1 for o in scene.objects if o.name.startswith(("Airborne fractured concrete", "Rubble apron |"))),
                   "comparison": "renders/impact_vs_target.png"}
        (OUT / "render_metrics.json").write_text(json.dumps(details, indent=2) + "\n")
        print("[M47-IMPACT-5.1] metrics", json.dumps(details), flush=True)


if __name__ == "__main__":
    main()
