"""Refine the 5.1 impact hero still into one more reference-matched Cycles frame."""
import hashlib
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
BASE_BLEND = BLEND_DIR / "M47_Impact_Hero_5_1.blend"
OUTPUT_BLEND = BLEND_DIR / "M47_Impact_Hero_5_2.blend"
OUTPUT_RENDER = RENDERS / "M47_Impact_Hero_Cycles_5_2.png"
PREVIEW_RENDER = RENDERS / "preview_impact_5_2.png"
ASSET = ROOT / "docs/assets/m47-muurbreker-1.0/M47_Muurbreker_1.0_animated.glb"
random.seed(52051)


def surface(name, color, emission, strength, roughness=0.35):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = roughness
    bs.inputs["Emission Color"].default_value = (*emission, 1)
    bs.inputs["Emission Strength"].default_value = strength
    return mat


def plasma_ribbon_material():
    mat = bpy.data.materials.new("M-47 plasma | turbulent blue-white filaments")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = 0.22
    bs.inputs["Metallic"].default_value = 0.12
    bs.inputs["Emission Strength"].default_value = 1.8
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7.5
    noise.inputs["Detail"].default_value = 5.0
    noise.inputs["Roughness"].default_value = 0.76
    noise.inputs["Distortion"].default_value = 1.3
    nt.links.new(coord.outputs["Generated"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.20
    ramp.color_ramp.elements[0].color = (0.006, 0.035, 0.34, 1)
    ramp.color_ramp.elements[1].position = 0.83
    ramp.color_ramp.elements[1].color = (0.78, 0.96, 1.0, 1)
    mid = ramp.color_ramp.elements.new(0.57)
    mid.color = (0.035, 0.34, 1.0, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bs.inputs["Base Color"])
    nt.links.new(ramp.outputs["Color"], bs.inputs["Emission Color"])
    nt.links.new(bs.outputs["BSDF"], out.inputs["Surface"])
    return mat


def volume_material(name, color, density, emission=(0, 0, 0), emission_strength=0.0,
                    noise_scale=4.8, detail=8.0, ramp_low=0.18, ramp_high=0.76,
                    anisotropy=0.38):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (*color, 1)
    vol.inputs["Anisotropy"].default_value = anisotropy
    vol.inputs["Emission Color"].default_value = (*emission, 1)
    vol.inputs["Emission Strength"].default_value = emission_strength
    tex = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = detail
    noise.inputs["Roughness"].default_value = 0.78
    noise.inputs["Distortion"].default_value = 0.55
    nt.links.new(tex.outputs["Generated"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = ramp_low
    ramp.color_ramp.elements[0].color = (0.004, 0.004, 0.004, 1)
    ramp.color_ramp.elements[1].position = ramp_high
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    mid = ramp.color_ramp.elements.new((ramp_low + ramp_high) * 0.52)
    mid.color = (0.28, 0.28, 0.28, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    mult = nt.nodes.new("ShaderNodeMath")
    mult.operation = "MULTIPLY"
    mult.inputs[1].default_value = density
    nt.links.new(ramp.outputs["Color"], mult.inputs[0])
    nt.links.new(mult.outputs[0], vol.inputs["Density"])
    nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    return mat


def ellipsoid(name, loc, scale, mat, segments=28, rings=18, collection=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    if collection:
        for c in list(ob.users_collection):
            c.objects.unlink(ob)
        collection.objects.link(ob)
    return ob


def puff(name, loc, scale, mat):
    return ellipsoid(name, loc, scale, mat, 24, 16)


def hide_previous_fx():
    prefixes = (
        "Blue-white impact |", "Impact halo |", "Impact electrical filament |",
        "Impact flash |", "Impact sparks |", "Impact cloud |", "Projectile wake |",
        "Wall base |", "Ionized haze |",
    )
    for ob in bpy.context.scene.objects:
        if ob.name.startswith(prefixes):
            ob.hide_render = True


def create_hot_core(center):
    core = surface("M-47 plasma | superheated white-blue impact core",
                   (0.90, 0.98, 1.0), (0.82, 0.96, 1.0), 18.0, 0.16)
    corona = surface("M-47 plasma | translucent cyan corona", (0.035, 0.32, 1.0),
                      (0.035, 0.35, 1.0), 0.72, 0.2)
    outer = surface("M-47 plasma | translucent refracted envelope", (0.008, 0.08, 0.55),
                    (0.012, 0.17, 0.85), 0.28, 0.22)
    for mat, alpha in ((corona, 0.16), (outer, 0.06)):
        bs = mat.node_tree.nodes.get("Principled BSDF")
        bs.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "DITHERED"
    ellipsoid("Impact | widened ice-white plasma kernel", center, (0.38, 0.53, 0.50), core, 64, 40)
    ellipsoid("Impact | soft blue-white ion corona", (center[0] + 0.06, center[1], center[2]),
             (0.40, 0.70, 0.67), corona, 56, 36)
    ellipsoid("Impact | turbulent outer energy envelope", (center[0] + 0.13, center[1], center[2]),
             (0.48, 0.84, 0.80), outer, 48, 32)
    plasma_fog = volume_material("M-47 plasma | glowing volumetric ion cloud",
                                 (0.08, 0.32, 0.88), 0.30, (0.03, 0.24, 1.0), 1.25,
                                 5.3, 7.0, 0.16, 0.78, 0.55)
    random.seed(52052)
    # Lumpy, overlapping volume lobes replace the solid, paper-flat cyan patches in 5.1.
    for i in range(13):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.12, 0.64)
        loc = (center[0] + random.uniform(-0.12, 0.18),
               center[1] + math.cos(a) * r,
               center[2] + math.sin(a) * r * 0.82)
        s = random.uniform(0.18, 0.36)
        puff("Impact plasma | volumetric turbulent lobe %02d" % i, loc,
             (s * random.uniform(1.0, 1.6), s * random.uniform(0.75, 1.35),
              s * random.uniform(0.75, 1.40)), plasma_fog)


def create_plasma_filaments(center):
    mat = plasma_ribbon_material()
    random.seed(52053)
    for i in range(16):
        a0 = random.uniform(0, math.tau)
        spin = random.choice((-1, 1)) * random.uniform(1.25, 3.6)
        r_end = random.uniform(0.82, 1.62)
        width_max = random.uniform(0.028, 0.085)
        steps = random.randint(18, 28)
        pts = []
        for k in range(steps):
            t = k / (steps - 1)
            a = a0 + spin * t + 0.20 * math.sin(t * 11 + i * 1.7)
            r = 0.12 + r_end * t + 0.08 * math.sin(t * 9 + i)
            pts.append(Vector((center[0] - 0.10 + 0.23 * math.sin(a * 1.4 + i),
                               center[1] + math.cos(a) * r,
                               center[2] + math.sin(a) * r * random.uniform(0.94, 1.06))))
        verts, faces = [], []
        for k, p in enumerate(pts):
            t = k / (steps - 1)
            tangent = (pts[min(k + 1, steps - 1)] - pts[max(k - 1, 0)]).normalized()
            side = tangent.cross(Vector((1, 0, 0)))
            if side.length < 1.0e-4:
                side = tangent.cross(Vector((0, 0, 1)))
            side.normalize()
            width = width_max * (0.10 + 0.90 * math.sin(math.pi * t) ** 0.62)
            width *= 0.76 + 0.24 * math.sin(t * 17 + i * 3)
            verts.extend((tuple(p - side * width), tuple(p + side * width)))
            if k:
                j = 2 * k
                faces.append((j - 2, j - 1, j + 1, j))
        mesh = bpy.data.meshes.new("M-47 plasma | curled turbulent ribbon mesh")
        mesh.from_pydata(verts, [], faces)
        mesh.materials.append(mat)
        mesh.update()
        ob = bpy.data.objects.new("M-47 plasma | broad curled filament %02d" % i, mesh)
        bpy.context.scene.collection.objects.link(ob)
        for poly in mesh.polygons:
            poly.use_smooth = True

    # A soft, broken hex pressure front keeps the reference's signature silhouette without a rigid neon cage.
    deep = surface("Shock front | soft refracted blue", (0.02, 0.12, 0.65), (0.015, 0.18, 1.0), 1.25)
    pale = surface("Shock front | ice-white edge glints", (0.38, 0.73, 1.0), (0.30, 0.70, 1.0), 2.2)
    for idx, (radius, start, end, material, width) in enumerate((
        (1.30, -0.08, 5.95, deep, 0.022),
    )):
        curve = bpy.data.curves.new("Soft broken hex plasma shockwave", "CURVE")
        curve.dimensions = "3D"
        curve.resolution_u = 2
        curve.bevel_depth = width
        curve.bevel_resolution = 4
        spl = curve.splines.new("POLY")
        count = 88
        spl.points.add(count - 1)
        for j in range(count):
            t = j / (count - 1)
            a = start + (end - start) * t
            # Keep a broad hex rhythm, then erode it with smaller-scale wobble.
            facet = math.cos((a + math.pi / 6) % (math.pi / 3) - math.pi / 6)
            r = radius / max(0.50, facet)
            r *= 1 + 0.055 * math.sin(13 * a + idx) + 0.024 * math.sin(31 * a + 2 * idx)
            spl.points[j].co = (center[0] - 0.12 + 0.10 * math.sin(9 * a),
                                center[1] + math.cos(a) * r,
                                center[2] + math.sin(a) * r, 1)
        ob = bpy.data.objects.new("Impact | soft irregular hex shockwave %02d" % idx, curve)
        bpy.context.scene.collection.objects.link(ob)
        curve.materials.append(material)
    # Short ionized edge flares bloom along a few facets, rather than outlining a wireframe cage.
    random.seed(52057)
    for idx in range(6):
        start = random.uniform(0, math.tau)
        length = random.uniform(0.18, 0.48)
        radius = random.uniform(1.18, 1.42)
        curve = bpy.data.curves.new("Refracted plasma edge flare", "CURVE")
        curve.dimensions = "3D"
        curve.resolution_u = 2
        curve.bevel_depth = random.uniform(0.008, 0.013)
        curve.bevel_resolution = 4
        spl = curve.splines.new("POLY")
        count = 18
        spl.points.add(count - 1)
        for j in range(count):
            t = j / (count - 1)
            a = start + length * t
            r = radius * (1 + 0.035 * math.sin(17 * a + idx))
            spl.points[j].co = (center[0] - 0.12 + 0.08 * math.sin(a * 9),
                                center[1] + math.cos(a) * r,
                                center[2] + math.sin(a) * r, 1)
        ob = bpy.data.objects.new("Impact | short ionized edge flare %02d" % idx, curve)
        bpy.context.scene.collection.objects.link(ob)
        curve.materials.append(pale)


def make_rock(name, loc, scale, material, seed, rotation=None):
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    for v in ob.data.vertices:
        n = random.uniform(0.72, 1.20)
        v.co *= n
        v.co.x *= random.uniform(0.72, 1.25)
        v.co.y *= random.uniform(0.72, 1.25)
        v.co.z *= random.uniform(0.68, 1.23)
    ob.scale = scale
    ob.rotation_euler = rotation or (random.uniform(-1.1, 1.1), random.uniform(-1.2, 1.2), random.random() * math.tau)
    ob.data.materials.append(material)
    for p in ob.data.polygons:
        p.use_smooth = False
    ob["fracture_detail"] = "irregular chipped aggregate, procedural shot supplement"
    return ob


def add_fine_concrete_breakup():
    concrete = bpy.data.materials.get("Impact wall | project 2K exposed-aggregate concrete PBR")
    fresh = bpy.data.materials.get("Fresh exposed aggregate | pale fractured interior")
    random.seed(52054)
    # Fine splintering clusters cling to the blast edge and break up the readable cell seams.
    for i in range(150):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.72, 1.88)
        y = math.cos(a) * r
        z = 1.48 + math.sin(a) * r * random.uniform(0.78, 1.13)
        sx = random.uniform(0.025, 0.075)
        ob = make_rock("Crater lip | fine angular concrete spall %03d" % i,
                       (3.36 - random.uniform(0.0, 0.17), y, z),
                       (sx * random.uniform(0.75, 1.6), sx * random.uniform(0.55, 1.4),
                        sx * random.uniform(0.65, 1.65)), fresh if i % 4 == 0 else concrete,
                       52100 + i)
    # Irregular near-field rubble, spread in scale and orientation over the ground.
    for i in range(78):
        x = random.uniform(2.40, 4.10)
        y = random.uniform(-3.1, 3.1)
        size = random.uniform(0.055, 0.22)
        make_rock("Impact apron | chipped limestone fragment %03d" % i,
                  (x, y, size * random.uniform(0.15, 0.42)),
                  (size * random.uniform(1.1, 1.9), size * random.uniform(0.65, 1.2),
                   size * random.uniform(0.38, 0.78)), concrete, 52300 + i)
    # Exposed face shards at the cavity edge, with jagged rather than rectangular silhouettes.
    for i in range(52):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.82, 1.20)
        size = random.uniform(0.07, 0.19)
        make_rock("Crater rim | fractured face shard %02d" % i,
                  (3.29 - random.uniform(0.0, 0.12), math.cos(a) * r,
                   1.48 + math.sin(a) * r * random.uniform(0.85, 1.12)),
                  (size * random.uniform(0.55, 1.1), size * random.uniform(0.8, 1.4),
                   size * random.uniform(1.0, 1.85)), fresh if i % 3 == 0 else concrete,
                  52500 + i)


def add_continuous_broken_wall_face():
    """Lay a weathered, finely displaced facade over the procedural cell seams."""
    concrete = bpy.data.materials.get("Impact wall | project 2K exposed-aggregate concrete PBR")
    fresh = bpy.data.materials.get("Fresh exposed aggregate | pale fractured interior")
    fissure = bpy.data.materials.get("Concrete fissure | deep wet shadow")
    for cell in bpy.context.scene.objects:
        if cell.name.startswith("Broken concrete cell") and cell.get("distance_from_impact", 999) < 1.08:
            cell.hide_render = True
    wall_x = 3.365
    y0, y1, z0, z1 = -3.48, 3.48, 0.10, 3.24
    ny, nz = 132, 62
    verts = []
    for iz in range(nz + 1):
        z = z0 + (z1 - z0) * iz / nz
        for iy in range(ny + 1):
            y = y0 + (y1 - y0) * iy / ny
            relief = 0.012 * math.sin(y * 5.3 + z * 2.0) + 0.007 * math.sin(y * 12.1 - z * 7.3)
            verts.append((wall_x + relief, y, z))
    faces, face_mats = [], []
    for iz in range(nz):
        za = z0 + (z1 - z0) * iz / nz
        zb = z0 + (z1 - z0) * (iz + 1) / nz
        for iy in range(ny):
            ya = y0 + (y1 - y0) * iy / ny
            yb = y0 + (y1 - y0) * (iy + 1) / ny
            cy, cz = (ya + yb) * 0.5, (za + zb) * 0.5
            angle = math.atan2(cz - 1.48, cy)
            radial = math.sqrt(cy * cy + (cz - 1.48) ** 2)
            hole = 0.99 + 0.055 * math.sin(angle * 13.0 + 0.6) + 0.035 * math.sin(angle * 29.0)
            if radial < hole:
                continue
            a = iz * (ny + 1) + iy
            b = a + 1
            d = (iz + 1) * (ny + 1) + iy
            c = d + 1
            faces.append((a, d, c, b))
            face_mats.append(1 if radial < 1.10 else 0)
    mesh = bpy.data.meshes.new("M-47 strike wall | continuous chipped facade with breach")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(concrete)
    mesh.materials.append(fresh)
    mesh.update()
    uv = mesh.uv_layers.new(name="Exposed aggregate PBR world scale")
    for face, mid in zip(mesh.polygons, face_mats):
        face.material_index = mid
        face.use_smooth = False
        for loop_i in face.loop_indices:
            co = mesh.vertices[mesh.loops[loop_i].vertex_index].co
            uv.data[loop_i].uv = (co.y * 1.6, co.z * 1.6)
    ob = bpy.data.objects.new("5.2 wall | weathered aggregate face around jagged breach", mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob["surface_detail"] = "continuous shot facade; layered PBR and chipped radial breach"
    ob.modifiers.new("Facade edge normals", "WEIGHTED_NORMAL")

    # Put fine, branching cracks over the facade so they read as fractures, not tile borders.
    random.seed(52600)
    for arm in range(31):
        angle = math.tau * arm / 31 + random.uniform(-0.075, 0.075)
        max_r = random.uniform(1.32, 2.52)
        steps = random.randint(5, 9)
        pts = []
        for step in range(steps):
            t = step / (steps - 1)
            r = 1.02 + max_r * t
            a = angle + random.uniform(-0.08, 0.08) * t
            y = math.cos(a) * r
            z = 1.48 + math.sin(a) * r * random.uniform(0.86, 1.12)
            pts.append((3.335, y, z))
        curve = bpy.data.curves.new("Branching hairline concrete fracture", "CURVE")
        curve.dimensions = "3D"
        curve.resolution_u = 2
        curve.bevel_depth = random.uniform(0.0035, 0.0080)
        curve.bevel_resolution = 3
        spline = curve.splines.new("POLY")
        spline.points.add(len(pts) - 1)
        for p, co in zip(spline.points, pts):
            p.co = (*co, 1)
        crack = bpy.data.objects.new("5.2 wall | branching blast crack %02d" % arm, curve)
        bpy.context.collection.objects.link(crack)
        curve.materials.append(fissure)
        if arm % 2 == 0:
            start = Vector(pts[random.randint(1, len(pts) - 2)])
            branch_angle = angle + random.choice((-1, 1)) * random.uniform(0.36, 0.90)
            branch_pts = [tuple(start)]
            branch_steps = random.randint(3, 5)
            for step in range(1, branch_steps):
                r = 0.15 * step
                branch_pts.append((3.332, start.y + math.cos(branch_angle) * r,
                                   start.z + math.sin(branch_angle) * r))
            branch = bpy.data.curves.new("Fine secondary concrete crack", "CURVE")
            branch.dimensions = "3D"
            branch.bevel_depth = 0.003
            branch.bevel_resolution = 2
            spl = branch.splines.new("POLY")
            spl.points.add(len(branch_pts) - 1)
            for p, co in zip(spl.points, branch_pts):
                p.co = (*co, 1)
            branch_ob = bpy.data.objects.new("5.2 wall | secondary crack branch %02d" % arm, branch)
            bpy.context.collection.objects.link(branch_ob)
            branch.materials.append(fissure)

    # Irregular stone lips make the breach dimensional at the hero camera scale.
    for i in range(22):
        angle = random.uniform(0, math.tau)
        r = random.uniform(0.84, 1.16)
        size = random.uniform(0.13, 0.28)
        make_rock("5.2 wall | large chipped crater lip %02d" % i,
                  (3.285 - random.uniform(0.0, 0.12), math.cos(angle) * r,
                   1.48 + math.sin(angle) * r * random.uniform(0.84, 1.16)),
                  (size * random.uniform(0.7, 1.5), size * random.uniform(0.65, 1.35),
                   size * random.uniform(0.7, 1.8)), fresh if i % 3 == 0 else concrete,
                  52700 + i)


def create_smoke_and_dust(center):
    cool = volume_material("Impact 5.2 | layered slate-blue smoke", (0.57, 0.66, 0.73), 0.27,
                           noise_scale=4.0, detail=9.0, ramp_low=0.15, ramp_high=0.73, anisotropy=0.48)
    warm = volume_material("Impact 5.2 | warm limestone dust", (0.68, 0.59, 0.48), 0.26,
                           noise_scale=4.8, detail=8.0, ramp_low=0.14, ramp_high=0.75, anisotropy=0.34)
    cool_edge = volume_material("Impact 5.2 | cyan-lit vapor edge", (0.16, 0.36, 0.72), 0.23,
                                (0.015, 0.06, 0.22), 0.16, 5.5, 7.0, 0.18, 0.80, 0.55)
    random.seed(52055)
    # A broader, curling smoke wake from the projectile into the impact cloud.
    for i in range(24):
        t = i / 23
        x = center[0] - 3.2 * t
        theta = t * math.tau * 1.75 + 0.4
        radius = 0.22 + 0.62 * t
        y = math.cos(theta) * radius + random.uniform(-0.18, 0.18)
        z = center[2] + 0.38 + math.sin(theta) * radius * 0.50 + random.uniform(-0.20, 0.20)
        sx = random.uniform(0.38, 0.68) + 0.22 * t
        puff("5.2 smoke wake | rolling grey-blue lobe %02d" % i, (x, y, z),
             (sx * random.uniform(1.2, 1.8), sx * random.uniform(0.95, 1.45),
              sx * random.uniform(0.78, 1.25)), cool)
    # Dense turbulent column rising behind the white impact kernel.
    for i in range(16):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.25, 1.35)
        loc = (center[0] + random.uniform(-0.20, 0.75),
               math.cos(a) * r,
               center[2] + random.uniform(-0.15, 1.45) + math.sin(a) * r * 0.40)
        s = random.uniform(0.38, 0.82)
        puff("5.2 impact plume | turbulent smoke fold %02d" % i, loc,
             (s * random.uniform(0.90, 1.55), s * random.uniform(0.80, 1.48),
              s * random.uniform(1.0, 1.70)), cool)
    # Heavy ground-hugging dust travels toward camera and along the wall base.
    for i in range(24):
        x = random.uniform(1.80, 3.90)
        y = random.uniform(-2.80, 2.80)
        z = random.uniform(0.08, 0.38)
        sx = random.uniform(0.52, 1.02)
        puff("5.2 dust front | rolling limestone cloud %02d" % i,
             (x, y, z), (sx * random.uniform(1.25, 2.25), sx * random.uniform(0.85, 1.70),
                         sx * random.uniform(0.34, 0.72)), warm)
    for i in range(6):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.35, 1.10)
        puff("5.2 energy haze | translucent cyan vapor %02d" % i,
             (center[0] - random.uniform(0.2, 1.0), math.cos(a) * r,
              center[2] + math.sin(a) * r * 0.7),
             (random.uniform(0.34, 0.75), random.uniform(0.42, 0.82), random.uniform(0.36, 0.68)), cool_edge)


def add_ground_and_jungle_detail(scene):
    random.seed(52056)
    ferns = [o for o in scene.objects if o.name.startswith("CC0 fern source | fern_02_") and o.type == "MESH"]
    unique = []
    seen = set()
    for f in ferns:
        key = f.data.as_pointer()
        if key not in seen:
            seen.add(key)
            unique.append(f)
    grasses = [o for o in scene.objects if o.name.startswith("Tall grass source variant") and o.type == "MESH"]
    spots = [(-4.8, -3.0), (-3.0, -3.8), (-1.0, -3.7), (1.0, -3.8),
             (3.3, -3.5), (5.2, -2.0), (-5.0, 3.6), (5.5, 2.8),
             (-3.7, 4.7), (2.5, 4.9)]
    if unique:
        for idx, (x, y) in enumerate(spots):
            root = bpy.data.objects.new("5.2 jungle dressing | fern and understory cluster %02d" % idx, None)
            scene.collection.objects.link(root)
            root.location = (x, y, 0.0)
            root.rotation_euler.z = random.random() * math.tau
            root.scale = (random.uniform(0.55, 0.90),) * 3
            for j, src in enumerate(unique[:4]):
                ob = src.copy()
                ob.data = src.data
                scene.collection.objects.link(ob)
                ob.name = "5.2 jungle dressing | fern frond %02d %02d" % (idx, j)
                ob.parent = root
                ob.location = src.location.copy()
                ob.rotation_euler = src.rotation_euler.copy()
                ob.scale = src.scale.copy()
                ob.hide_render = False
                ob.hide_set(False)
    # Grass clumps give the soil plane a varied, layered silhouette at the frame edges.
    for i, loc in enumerate(((-4.7, -1.8, 0), (-2.6, -3.0, 0), (0.2, -3.2, 0),
                             (2.1, -3.1, 0), (4.5, -1.8, 0), (-4.6, 2.0, 0), (5.0, 1.6, 0))):
        if not grasses:
            break
        src = grasses[i % len(grasses)]
        ob = src.copy()
        ob.data = src.data
        scene.collection.objects.link(ob)
        ob.name = "5.2 jungle dressing | existing PBR grass %02d" % i
        ob.location = loc
        ob.rotation_euler.z = random.random() * math.tau
        scale = random.uniform(0.42, 0.62)
        ob.scale = (scale, scale, scale)
        ob.hide_render = False
        ob.hide_set(False)


def refine_lighting_and_camera(scene):
    cam = bpy.data.objects.get("Impact hero camera | reference panel 4 composition")
    if cam:
        cam.location = (-4.30, -8.20, 4.80)
        target = Vector((1.92, 0.0, 1.48))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 35.0
        cam.data.dof.focus_distance = 9.0
        cam.data.dof.aperture_fstop = 9.0
    for ob in scene.objects:
        if ob.type != "LIGHT":
            continue
        if ob.name.startswith("Cinematic canopy key | warm softbox"):
            ob.data.energy = 490
        elif ob.name.startswith("Jungle skylight | deep green bounce"):
            ob.data.energy = 365
        elif ob.name.startswith("Wall rim | cool cyan bounce"):
            ob.data.energy = 495
        elif ob.name.startswith("Foreground leaf lift | neutral"):
            ob.data.energy = 280
        elif ob.name.startswith("Impact plasma spill | cyan point"):
            ob.data.energy = 1250
        elif ob.name.startswith("Impact core spill | ice white point"):
            ob.data.energy = 820
        elif ob.name.startswith("Broken canopy sun shaft"):
            ob.data.energy = 0.82
    if scene.world and scene.world.use_nodes:
        background = scene.world.node_tree.nodes.get("Background")
        if background:
            background.inputs["Color"].default_value = (0.035, 0.052, 0.042, 1)
            background.inputs["Strength"].default_value = 0.16
    scene.view_settings.exposure = -0.08
    scene.view_settings.look = "AgX - Medium High Contrast"
    # Subtle world haze adds depth between near foliage and the broken wall.
    if scene.world and scene.world.use_nodes:
        out = next((n for n in scene.world.node_tree.nodes if n.type == "OUTPUT_WORLD"), None)
        if out:
            haze = scene.world.node_tree.nodes.new("ShaderNodeVolumeScatter")
            haze.name = "Impact 5.2 | subtle humid jungle atmosphere"
            haze.inputs["Color"].default_value = (0.48, 0.59, 0.53, 1)
            haze.inputs["Density"].default_value = 0.0018
            haze.inputs["Anisotropy"].default_value = 0.32
            scene.world.node_tree.links.new(haze.outputs["Volume"], out.inputs["Volume"])


def configure_render(scene, preview):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12 if preview else 80
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.010 if preview else 0.006
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.volume_step_rate = 1.1
    scene.cycles.volume_max_steps = 256
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 28 if preview else 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "16"
    scene.render.use_motion_blur = False
    scene.render.threads_mode = "AUTO"
    scene.render.use_persistent_data = True
    scene.render.filepath = str(PREVIEW_RENDER if preview else OUTPUT_RENDER)
    scene.cycles.use_preview_denoising = False


def main():
    preview = "--preview" in sys.argv
    bpy.ops.wm.open_mainfile(filepath=str(BASE_BLEND))
    scene = bpy.context.scene
    scene.frame_set(122)
    hide_previous_fx()
    center = (2.91, 0.0, 1.48)
    create_hot_core(center)
    create_plasma_filaments(center)
    add_fine_concrete_breakup()
    add_continuous_broken_wall_face()
    create_smoke_and_dust(center)
    add_ground_and_jungle_detail(scene)
    refine_lighting_and_camera(scene)
    configure_render(scene, preview)
    scene["Impact still phase"] = "single revised 5.2 hero still: M-47 plasma impact on fractured concrete"
    scene["M47 source SHA256"] = hashlib.sha256(ASSET.read_bytes()).hexdigest()
    scene["M47 mesh data unchanged"] = True
    scene["5.2 improvement"] = "larger white-blue core, volumetric smoke/dust, turbulent plasma ribbons, finer broken concrete, denser existing jungle assets"
    if not preview:
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    print("[M47-IMPACT-5.2] scene ready", "preview=" + str(preview),
          "source_sha256=" + scene["M47 source SHA256"],
          "camera=" + str(scene.camera.data.lens if scene.camera else None),
          "render=" + scene.render.filepath, flush=True)
    bpy.ops.render.render(write_still=True)
    if not preview:
        lod0 = bpy.data.objects.get("M47_LOD0")
        triangles = sum(max(0, len(p.vertices) - 2) for p in lod0.data.polygons)
        metrics = {
            "version": "M-47 Photoreal Impact Hero Still 5.2",
            "blender": bpy.app.version_string,
            "engine": scene.render.engine,
            "resolution": [scene.render.resolution_x, scene.render.resolution_y],
            "samples": scene.cycles.samples,
            "adaptive_threshold": scene.cycles.adaptive_threshold,
            "frame": scene.frame_current,
            "approved_m47_glb": str(ASSET.relative_to(ROOT)),
            "approved_m47_sha256": scene["M47 source SHA256"],
            "m47_lod0_triangles": triangles,
            "scene": str(OUTPUT_BLEND.relative_to(OUT)),
            "render": str(OUTPUT_RENDER.relative_to(OUT)),
            "smoke_and_dust_objects": sum(1 for o in scene.objects if o.name.startswith(("5.2 smoke", "5.2 impact plume", "5.2 dust", "5.2 energy haze"))),
            "plasma_filaments": sum(1 for o in scene.objects if o.name.startswith("M-47 plasma | broad curled filament")),
            "added_concrete_fragments": sum(1 for o in scene.objects if o.name.startswith(("Crater lip |", "Impact apron |", "Crater rim |", "5.2 wall | large chipped crater lip"))),
            "render_sha256": hashlib.sha256(OUTPUT_RENDER.read_bytes()).hexdigest(),
            "render_bytes": OUTPUT_RENDER.stat().st_size,
            "scene_sha256": hashlib.sha256(OUTPUT_BLEND.read_bytes()).hexdigest(),
            "scene_bytes": OUTPUT_BLEND.stat().st_size,
        }
        (OUT / "render_metrics_5_2.json").write_text(json.dumps(metrics, indent=2) + "\n")
        print("[M47-IMPACT-5.2] metrics", json.dumps(metrics), flush=True)


if __name__ == "__main__":
    main()
