"""Explosief vat voor Bloedjungle: omwentelingslichaam met gerolde boven- en onderrand, twee ribben, deuken, roest en een geel-zwarte
waarschuwingsband (kleuren als hoekkleuren, zodat het spel er een eigen materiaal op zet). Het deksel met twee afsluitdoppen is
een apart object (Deksel), zodat het spel het kan laten gloeien als het vat brandt.
Gebruik:  python maak_vat.py <uitmap>   ->  <uitmap>/vat.glb met Vat1..Vat3 en Deksel1..Deksel3 (zelfde maten, andere deuken en roest)"""
import bpy, bmesh, sys, os, math, random
from mathutils import Vector

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

R, H = 0.38, 0.96
SEG = 28

# profiel (straal, hoogte): onderrand, bol lichaam met twee ribben, bovenrand. Dubbele hoogtes geven scherpe kleurgrenzen.
def profile():
    pts = []
    def add(r, z):
        pts.append((r, z))
    add(0.0, 0.0)
    add(0.30, 0.0); add(0.355, 0.004); add(0.385, 0.03); add(0.392, 0.055)       # gerolde onderrand
    add(0.378, 0.075); add(0.372, 0.1)
    for z in (0.14, 0.18):
        add(0.376, z)
    add(0.376, 0.205); add(0.362, 0.22); add(0.362, 0.245); add(0.376, 0.26)     # onderste rib
    for z in (0.3, 0.36):
        add(0.38, z)
    add(0.38, 0.399); add(0.38, 0.401)                                            # begin geel-zwarte band
    for z in (0.43, 0.46, 0.49, 0.52, 0.55):
        add(0.381, z)
    add(0.381, 0.579); add(0.381, 0.581)                                          # einde band
    for z in (0.62, 0.68):
        add(0.38, z)
    add(0.376, 0.72); add(0.362, 0.735); add(0.362, 0.76); add(0.376, 0.775)     # bovenste rib
    for z in (0.81, 0.85):
        add(0.376, z)
    add(0.372, 0.87); add(0.378, 0.895); add(0.392, 0.915); add(0.385, 0.94); add(0.35, 0.958)   # gerolde bovenrand
    add(0.0, 0.96)
    return pts


def noise3(p, seed):
    # goedkope waardeverloop-ruis uit sinussen (herhaalbaar, geen extra pakket nodig)
    x, y, z = p
    return (math.sin(x * 9.1 + seed) * math.cos(y * 7.7 - seed * 1.3) + math.sin(z * 11.3 + seed * 0.7) * math.cos(x * 5.9 + y * 6.1)) * 0.5


def make_barrel(idx, seed):
    random.seed(seed)
    me = bpy.data.meshes.new("Vat%d" % idx)
    bm = bmesh.new()
    rows = []
    for (r, z) in profile():
        row = []
        for i in range(SEG):
            a = i / SEG * math.tau
            row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rows.append(row)
    for j in range(len(rows) - 1):
        for i in range(SEG):
            i2 = (i + 1) % SEG
            if rows[j][0].co.length < 1e-6 or (rows[j][0].co.x == 0 and rows[j][0].co.y == 0):
                pass
            try:
                bm.faces.new((rows[j][i], rows[j][i2], rows[j + 1][i2], rows[j + 1][i]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    # deuken: een paar ronde indrukken in het lichaam, plus zachte golving
    dents = []
    for _ in range(5):
        a = random.uniform(0, math.tau)
        dents.append((Vector((math.cos(a), math.sin(a), 0.0)), random.uniform(0.18, 0.72), random.uniform(0.07, 0.15), random.uniform(0.008, 0.02)))
    for v in bm.verts:
        r = math.hypot(v.co.x, v.co.y)
        if r < 0.05 or v.co.z < 0.01 or v.co.z > 0.95:
            continue
        d = Vector((v.co.x, v.co.y, 0.0)) / r
        push = noise3((v.co.x, v.co.y, v.co.z), seed) * 0.004
        for (dir_, z0, rad, depth) in dents:
            dist = math.sqrt(((v.co.z - z0) ** 2) + ((1.0 - d.dot(dir_)) * 0.38) ** 2 * 2.0)
            if dist < rad:
                push -= depth * (1.0 - dist / rad) ** 2
        v.co.x += d.x * push
        v.co.y += d.y * push
    # hoekkleuren
    col = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        fc = f.calc_center_median()
        ang = math.atan2(fc.y, fc.x)
        in_band = 0.40 <= fc.z <= 0.58
        for loop in f.loops:
            v = loop.vert
            p = (v.co.x, v.co.y, v.co.z)
            n = noise3((p[0] * 2.0, p[1] * 2.0, p[2] * 2.5), seed) * 0.5 + 0.5
            base = Vector((0.85, 0.1, 0.06)) * (0.88 + 0.25 * n)
            # roest: vooral bij de randen, onderin en in vlekken
            rim = max(0.0, 1.0 - min(abs(p[2] - 0.05), abs(p[2] - 0.93)) / 0.07)
            ribs = max(0.0, 1.0 - min(abs(p[2] - 0.23), abs(p[2] - 0.745)) / 0.035)
            patch = max(0.0, noise3((p[0] * 4.0, p[1] * 4.0, p[2] * 3.0), seed + 4.0) - 0.15)
            rust = min(1.0, rim * 0.8 + ribs * 0.35 + patch * 1.0)
            rustc = Vector((0.36, 0.15, 0.07)) * (0.8 + 0.4 * random.random())
            c = base.lerp(rustc, rust)
            # vuil onderin
            c = c.lerp(Vector((0.08, 0.06, 0.05)), max(0.0, 1.0 - p[2] / 0.18) * 0.3)
            if in_band:
                stripe = math.floor(ang / math.tau * 14 + fc.z * 9.0) % 2
                band = Vector((1.0, 0.8, 0.06)) if stripe == 0 else Vector((0.05, 0.05, 0.045))
                wear = max(0.0, noise3((fc.x * 5, fc.y * 5, fc.z * 6), seed + 9.0) - 0.25) * 1.2
                c = band.lerp(Vector((0.3, 0.14, 0.06)), min(wear, 0.7))
            loop[col] = (c.x, c.y, c.z, 1.0)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Vat%d" % idx, me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new("VatMat")
    mat.use_nodes = True
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mat.node_tree.links.new(attr.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.55
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return obj


def make_lid(idx, seed):
    random.seed(seed + 50)
    bm = bmesh.new()
    # deksel: schijf met opstaande rand, twee doppen met ring
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=SEG, radius1=0.345, radius2=0.335, depth=0.012, matrix=__import__("mathutils").Matrix.Translation((0, 0, 0.957)))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=SEG, radius1=0.348, radius2=0.348, depth=0.012, matrix=__import__("mathutils").Matrix.Translation((0, 0, 0.962)))
    for (x, y, r) in ((0.15, 0.06, 0.05), (-0.1, -0.15, 0.04)):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=r + 0.012, radius2=r + 0.012, depth=0.012, matrix=__import__("mathutils").Matrix.Translation((x, y, 0.968)))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=r, radius2=r * 0.92, depth=0.02, matrix=__import__("mathutils").Matrix.Translation((x, y, 0.978)))
    col = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for loop in f.loops:
            z = loop.vert.co.z
            c = (0.42, 0.42, 0.4) if z > 0.97 else (0.3, 0.3, 0.29)
            n = 0.85 + 0.3 * random.random() if False else 1.0
            loop[col] = (c[0] * n, c[1] * n, c[2] * n, 1.0)
    me = bpy.data.meshes.new("Deksel%d" % idx)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Deksel%d" % idx, me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.get("VatMat")
    me.materials.append(mat)
    return obj


for i, seed in enumerate((3.1, 7.7, 11.3), start=1):
    make_barrel(i, seed)
    make_lid(i, seed)

bpy.ops.export_scene.gltf(filepath=os.path.join(out, "vat.glb"), export_format='GLB', export_yup=True, export_attributes=True, export_vertex_color='MATERIAL', export_active_vertex_color_when_no_material=False)
print("KLAAR")
