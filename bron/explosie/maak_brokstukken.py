"""Brokstukken voor de explosies: gescheurde stukken vatblik (rood met kale rand), een verbrande houtsplinter,
een kluit aarde en een vatband. Elk stuk is een eigen object; exporteert uit/brokstukken.glb.
Gebruik:  python maak_brokstukken.py <uitmap>"""
import bpy, bmesh, sys, os, math, random

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(7)


def material(name, color, rough, metal):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


red = material("VatRood", (0.55, 0.07, 0.05, 1), 0.55, 0.45)
raw = material("VatKaal", (0.38, 0.36, 0.34, 1), 0.45, 0.8)
soot = material("Roet", (0.05, 0.045, 0.04, 1), 0.9, 0.0)
wood = material("Hout", (0.22, 0.13, 0.07, 1), 0.85, 0.0)
earth = material("Aarde", (0.2, 0.13, 0.08, 1), 0.95, 0.0)


def finish(obj, name, mats):
    obj.name = name
    for m in mats:
        obj.data.materials.append(m)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def jagged_plate(name, w, h, seed):
    """Een gebogen stuk blik met gescheurde rand: een raster dat is gebogen en waarvan de randpunten zijn verschoven."""
    random.seed(seed)
    bm = bmesh.new()
    nx, ny = 6, 5
    verts = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx - 0.5, j / ny - 0.5
            edge = i in (0, nx) or j in (0, ny)
            jx = random.uniform(-0.09, 0.09) * w if edge else 0.0
            jy = random.uniform(-0.09, 0.09) * h if edge else 0.0
            x, y = u * w + jx, v * h + jy
            z = 0.5 * (x * x) / w * 0.9 + random.uniform(-0.01, 0.01)  # kromming van het vat
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
    # er een paar hoeken afscheuren
    for _ in range(2):
        c = random.choice([v for row in verts for v in row if (abs(v.co.x) > w * 0.4 and abs(v.co.y) > h * 0.35)] or [verts[0][0]])
        c.co *= 0.7
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    sol = obj.modifiers.new("Dikte", 'SOLIDIFY')
    sol.thickness = 0.012
    sol.offset = 0.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=sol.name)
    # buitenkant rood, rand en binnenkant kaal/roet
    for p in obj.data.polygons:
        p.material_index = 0
    finish(obj, name, [red])
    return obj


def splinter(name, length, seed):
    random.seed(seed)
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (length, 0.05, 0.035)
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for v in bm.verts:
        v.co.y += random.uniform(-0.012, 0.012)
        v.co.z += random.uniform(-0.01, 0.01)
        if v.co.x > 0:
            v.co.y *= 0.3   # splinterpunt
            v.co.z *= 0.4
    bm.to_mesh(o.data)
    bm.free()
    return finish(o, name, [wood])


def clod(name, r, seed):
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r)
    o = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for v in bm.verts:
        v.co *= random.uniform(0.7, 1.2)
    bm.to_mesh(o.data)
    bm.free()
    return finish(o, name, [earth])


def band(name):
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.38, depth=0.05)
    o = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    # een open, verbogen ring: top en bodem eruit, een stuk weggescheurd
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.normal.z) > 0.9], context='FACES')
    for v in bm.verts:
        v.co.x += random.uniform(-0.03, 0.03)
        v.co.y += random.uniform(-0.03, 0.03)
    for f in [f for f in bm.faces if f.calc_center_median().x > 0.3 and abs(f.calc_center_median().y) < 0.2]:
        bm.faces.remove(f)
    bm.to_mesh(o.data)
    bm.free()
    return finish(o, name, [soot])


jagged_plate("Plaat1", 0.55, 0.4, 1)
jagged_plate("Plaat2", 0.4, 0.34, 2)
jagged_plate("Plaat3", 0.3, 0.26, 3)
splinter("Splinter1", 0.5, 4)
splinter("Splinter2", 0.32, 5)
clod("Kluit1", 0.1, 6)
clod("Kluit2", 0.07, 7)
band("Band")

bpy.ops.export_scene.gltf(filepath=os.path.join(out, "brokstukken.glb"), export_format='GLB', export_apply=True, export_yup=True)
print("KLAAR")
