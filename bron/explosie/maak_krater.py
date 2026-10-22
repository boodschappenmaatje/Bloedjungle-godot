"""Krater voor Bloedjungle: een onregelmatige kuil met opgeworpen rand en zachte uitloop in de grond (alfa in de hoekkleuren).
Het terrein is vlak, dus de kuil leest door vorm en schaduw: een lage, zwartgeblakerde bodem, een opgewulfde rand van omgewoelde aarde
en daarbuiten een zachte rand die in de grond overloopt.
Gebruik:  python maak_krater.py <uitmap>  ->  <uitmap>/krater.glb met Krater1..Krater3 (straal ~1,35 m)"""
import bpy, bmesh, sys, os, math, random

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def lin(x):
    # Blender slaat hoekkleuren als sRGB-bytes op en de export neemt die ongewijzigd over: donkere waarden worden dan veel te licht.
    # Hier dus de gewenste kleur terugrekenen, zodat het spel precies de bedoelde kleur toont.
    return ((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92


RINGS = 22
SEG = 40
R_MAX = 1.35


def hnoise(a, r, seed):
    return (math.sin(a * 3 + seed) * 0.5 + math.sin(a * 7 - seed * 1.7) * 0.3 + math.sin(a * 13 + seed * 0.4) * 0.2)


def make(idx, seed):
    random.seed(seed)
    bm = bmesh.new()
    rows = []
    # per hoek een eigen straal van de rand, zodat de krater niet rond is
    rim_r = [0.78 * (1.0 + 0.16 * hnoise(i / SEG * math.tau, 0, seed)) for i in range(SEG)]
    for j in range(RINGS + 1):
        t = j / RINGS                       # 0 midden, 1 buitenrand
        row = []
        for i in range(SEG):
            a = i / SEG * math.tau
            r = t * R_MAX
            rr = rim_r[i]
            u = r / rr                      # 1 = op de rand
            if u < 1.0:
                # bodem: laag in het midden, steil omhoog naar de rand
                h = 0.01 + 0.17 * (u ** 2.2)
            else:
                # buiten de rand: de berm zakt weg tot de grond
                v = (r - rr) / max(R_MAX - rr, 1e-3)
                h = 0.18 * max(0.0, 1.0 - v) ** 1.6 + 0.01 * (1.0 - v)
            h += 0.02 * hnoise(a * 2.0, r, seed + 5.0) * (0.3 + u * 0.7) * (1.0 if r > 0.2 else 0.0)
            h = max(h, 0.0)
            row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, h)))
        rows.append(row)
    for j in range(RINGS):
        for i in range(SEG):
            i2 = (i + 1) % SEG
            if j == 0:
                try:
                    bm.faces.new((rows[0][0], rows[1][i], rows[1][i2]))
                except ValueError:
                    pass
            else:
                bm.faces.new((rows[j][i], rows[j][i2], rows[j + 1][i2], rows[j + 1][i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    col = bm.loops.layers.color.new("Col")
    for f in bm.faces:
        for loop in f.loops:
            v = loop.vert
            r = math.hypot(v.co.x, v.co.y)
            a = math.atan2(v.co.y, v.co.x)
            rr = 0.78 * (1.0 + 0.16 * hnoise(a, 0, seed))
            u = r / rr
            n = 0.5 + 0.5 * hnoise(a * 2.0 + r * 5.0, r, seed + 2.0)
            if u < 0.55:
                c = (0.035 + 0.02 * n, 0.03 + 0.015 * n, 0.026 + 0.012 * n)   # zwartgeblakerde bodem
            elif u < 1.0:
                w = (u - 0.55) / 0.45
                c = (0.035 + (0.30 - 0.035) * w * (0.8 + 0.4 * n), 0.03 + (0.20 - 0.03) * w * (0.8 + 0.4 * n), 0.026 + (0.12 - 0.026) * w)  # van roet naar aarde
            else:
                c = (0.30 * (0.8 + 0.4 * n), 0.2 * (0.8 + 0.4 * n), 0.12)    # omgewoelde aarde op de berm
            # roetwaaier: nog een beetje donker buiten de rand, zachte uitloop naar de grond
            v2 = max(0.0, (r - rr) / (R_MAX - rr))
            soot_out = max(0.0, 1.0 - v2) * 0.55
            c = tuple(c[k] * (1.0 - 0.5 * soot_out) for k in range(3))
            alpha = 1.0 if u < 1.0 else max(0.0, 1.0 - v2) ** 0.8
            loop[col] = (lin(c[0]), lin(c[1]), lin(c[2]), alpha)
    me = bpy.data.meshes.new("Krater%d" % idx)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("Krater%d" % idx, me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new("KraterMat")
    mat.use_nodes = True
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mat.node_tree.links.new(attr.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mat.node_tree.links.new(attr.outputs["Alpha"], mat.node_tree.nodes["Principled BSDF"].inputs["Alpha"])
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    me.materials.append(mat)
    return obj


for i, seed in enumerate((2.3, 6.1, 9.4), start=1):
    make(i, seed)

bpy.ops.export_scene.gltf(filepath=os.path.join(out, "krater.glb"), export_format='GLB', export_yup=True, export_vertex_color='MATERIAL', export_active_vertex_color_when_no_material=False)
print("KLAAR")
