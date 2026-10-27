"""Jungle voor Bloedjungle: drie rotsen met mos en drie palmen (elk met een verre variant), geometrie met vertexkleuren.
Blender Z = omhoog (wordt Godot Y), 1 eenheid = 1 meter, oorsprong aan de voet. Materialen worden in Godot gezet:
- rotsen: PBR-rotstextuur (assets/textures/nature/rock_material, triplanar) x vertexkleur (steen/mos)
- palmen: oppervlak 0 = stam (schors: assets/textures/nature/tree_bark via UV), oppervlak 1 = kroon (bladtextuur, UV t/v zoals Foliage._frond)
De alfa van de vertexkleur is de windgewicht (0 = vast, 1 = losse bladpunt), zoals shaders/foliage.gdshader verwacht.
Gebruik: python3 maak_jungle.py <uitmap>  ->  jungle.glb, jungle.blend"""
import math, os, random, sys
import bpy, bmesh
from mathutils import Vector, noise

OUT = os.path.abspath(sys.argv[-1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    return m


M_ROTS = mat("Rots", (0.5, 0.5, 0.48))
M_STAM = mat("Palm_Stam", (0.5, 0.38, 0.26))
M_BLAD = mat("Palm_Blad", (0.3, 0.5, 0.2))
B_STAM = mat("Boom_Stam", (0.42, 0.33, 0.24))
B_BLAD = mat("Boom_Blad", (0.3, 0.5, 0.2))
B_LIAAN = mat("Boom_Liaan", (0.2, 0.3, 0.12))


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def make_obj(name, bm, materials, uv_bm=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in materials:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    return o


def color_layer(bm):
    return bm.verts.layers.float_color.get("Color") or bm.verts.layers.float_color.new("Color")


# ---------- rotsen ----------
def rock(name, seed, squash, size):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.5)
    off = Vector((rnd.random() * 50, rnd.random() * 50, rnd.random() * 50))
    for v in bm.verts:
        p = v.co.normalized()
        n = noise.noise(p * 1.7 + off) * 0.16 + noise.noise(p * 3.9 + off) * 0.07 + noise.noise(p * 8.0 + off) * 0.025
        r = 0.5 * (1.0 + n * 2.0)
        v.co = Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2])) * r * size
    # het onderste stuk plat: de rots rust op de grond (iets in de grond)
    for v in bm.verts:
        v.co.z = max(v.co.z, -0.22 * size)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(14), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.normal_update()
    lay = color_layer(bm)
    for v in bm.verts:
        nz = v.normal.z + noise.noise(v.co * 7.0 + off) * 0.35
        moss = smooth(0.3, 0.75, nz)
        shade = 0.82 + 0.25 * noise.noise(v.co * 5.0 + off * 2) + (0.12 if v.co.z > 0.1 else 0.0)
        stone = (0.60 * shade, 0.60 * shade, 0.56 * shade)
        green = (0.30 * shade, 0.40 * shade, 0.16 * shade)
        c = [stone[i] * (1 - moss) + green[i] * moss for i in range(3)]
        low = smooth(0.0, -0.18, v.co.z)   # onderaan donkerder (vuil)
        v[lay] = (c[0] * (1 - 0.35 * low), c[1] * (1 - 0.35 * low), c[2] * (1 - 0.3 * low), 0.0)
    for f in bm.faces:
        f.smooth = False
    return make_obj(name, bm, [M_ROTS])


# ---------- palmen ----------
def frond(bm, lay, uvl, origin, yaw, length, width, rise, droop, c0, c1, segs, brown=False):
    d = Vector((math.cos(yaw), math.sin(yaw), 0))
    side = Vector((-d.y, d.x, 0))
    rows = []
    for i in range(segs + 1):
        t = i / segs
        c = origin + d * length * t + Vector((0, 0, math.sin(t * math.pi * 0.6) * rise - t * t * droop))
        col = tuple(c0[k] + (c1[k] - c0[k]) * t for k in range(3)) + (t,)
        w = width * (0.75 + 0.25 * math.sin(min(t * 1.4, 1.0) * math.pi * 0.5))
        rows.append([(c - side * w + Vector((0, 0, -w * 0.3)), (t, 0.0), col),
                     (c + Vector((0, 0, w * 0.1)), (t, 0.5), col),
                     (c + side * w + Vector((0, 0, -w * 0.3)), (t, 1.0), col)])
    for i in range(segs):
        for k in range(2):
            quad = [rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]]
            vs = []
            for co, uv, col in quad:
                v = bm.verts.new(co)
                v[lay] = col
                vs.append((v, uv))
            f = bm.faces.new([a for a, _ in vs])
            f.material_index = 1
            for loop, (_, uv) in zip(f.loops, vs):
                loop[uvl].uv = uv


def palm(name, seed, height, lean, ring_n, fronds, far=False):
    rnd = random.Random(seed)
    bm = bmesh.new()
    lay = color_layer(bm)
    uvl = bm.loops.layers.uv.new("UVMap")
    segs = 5 if far else ring_n
    sides = 5 if far else 8
    lean_dir = rnd.random() * math.tau
    lx, ly = math.cos(lean_dir) * lean, math.sin(lean_dir) * lean
    rings = []
    top = Vector((0, 0, 0))
    for i in range(segs + 1):
        t = i / segs
        c = Vector((lx * t * t, ly * t * t, height * t))
        top = c
        flare = 1.0 + 0.85 * math.exp(-t * 16)
        bulge = 1.0 + (0.16 if i % 2 == 0 else 0.0) * (1.0 if not far else 0.4)
        r = (0.27 * (1 - t) + 0.13 * t) * bulge * flare
        shade = 0.82 if i % 2 == 0 else 1.0
        rings.append((c, r, shade, t))
    for i in range(segs):
        for j in range(sides):
            quad = []
            for (ii, jj, uu) in ((i, j, j), (i + 1, j, j), (i + 1, j + 1, j + 1), (i, j + 1, j + 1)):
                c, r, shade, t = rings[ii]
                a = math.tau * jj / sides
                v = bm.verts.new(c + Vector((math.cos(a) * r, math.sin(a) * r, 0)))
                v[lay] = (0.52 * shade, 0.40 * shade, 0.28 * shade, 0.04 * ii / segs)
                quad.append((v, (uu / sides * 2.0, t * height / 1.1)))
            f = bm.faces.new([a for a, _ in quad])
            f.material_index = 0
            for loop, (_, uv) in zip(f.loops, quad):
                loop[uvl].uv = uv
    white = (0.78, 0.9, 0.7)
    dark = (0.5, 0.64, 0.42)
    n = max(7, int(fronds * (0.6 if far else 1.0)))
    for k in range(n):
        yaw = math.tau * k / n + rnd.uniform(-0.2, 0.2)
        frond(bm, lay, uvl, top + Vector((0, 0, 0.05)), yaw, rnd.uniform(2.6, 3.5), rnd.uniform(0.62, 0.86), rnd.uniform(0.9, 1.6), rnd.uniform(1.0, 2.0), dark, white, 3 if far else 7)
    for k in range(0 if far else 6):   # korte, rechtopstaande jonge bladeren in het hart
        frond(bm, lay, uvl, top + Vector((0, 0, 0.1)), math.tau * k / 6 + 0.3, 1.5, 0.45, 1.3, 0.3, dark, white, 4)
    if not far:   # twee verdorde, hangende bladeren onder de kroon
        for k in range(2):
            frond(bm, lay, uvl, top + Vector((0, 0, -0.15)), rnd.random() * math.tau, rnd.uniform(1.6, 2.1), 0.5, 0.2, 2.2, (0.38, 0.30, 0.16), (0.55, 0.46, 0.26), 4)
    bm.normal_update()
    return make_obj(name, bm, [M_STAM, M_BLAD])


rock("Rots1", 3, (1.15, 0.95, 0.85), 1.0)
rock("Rots2", 11, (1.0, 1.25, 0.7), 1.0)
rock("Rots3", 27, (0.9, 0.9, 1.1), 1.0)
VARIANTS = [("Palm1", 5, 5.4, 0.9, 10, 12), ("Palm2", 17, 6.3, 1.5, 12, 14), ("Palm3", 31, 4.6, 0.5, 9, 15)]
for name, seed, h, lean, rn, fr in VARIANTS:
    palm(name, seed, h, lean, rn, fr)
    palm(name + "_far", seed, h, lean, rn, fr, far=True)


# ---------- jungleboom: hoge stam met plankwortels, brede kroon, lianen ----------
def quad(bm, lay, uvl, pts, col, midx):
    """pts = [(co, uv), ...] vier hoeken; kleur col (rgba)."""
    vs = []
    for co, uv in pts:
        v = bm.verts.new(co)
        v[lay] = col(co) if callable(col) else col
        vs.append((v, uv))
    f = bm.faces.new([a for a, _ in vs])
    f.material_index = midx
    for loop, (_, uv) in zip(f.loops, vs):
        loop[uvl].uv = uv


def jungle_tree(name, seed, height, far=False):
    rnd = random.Random(seed)
    bm = bmesh.new()
    lay = color_layer(bm)
    uvl = bm.loops.layers.uv.new("UVMap")
    segs = 4 if far else 9
    sides = 5 if far else 8
    ang0 = rnd.random() * math.tau
    bend = (rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5))
    def centre(t):
        return Vector((bend[0] * t * t, bend[1] * t * t, height * t))
    rings = []
    for i in range(segs + 1):
        t = i / segs
        flare = 1.0 + 0.5 * math.exp(-t * 14)
        r = (0.36 * (1 - t) + 0.2 * t) * flare * (1.0 + 0.06 * math.sin(i * 2.1 + seed))
        rings.append((centre(t), r, t))
    for i in range(segs):
        shade = 0.9 + 0.1 * math.sin(i * 1.7)
        for j in range(sides):
            pts = []
            for ii, jj in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)):
                c, r, t = rings[ii]
                a = ang0 + math.tau * jj / sides
                pts.append((c + Vector((math.cos(a) * r, math.sin(a) * r, 0)), (jj / sides * 2.0, t * height / 1.4)))
            quad(bm, lay, uvl, pts, (0.50 * shade, 0.45 * shade, 0.38 * shade, 0.02 * i / segs), 0)
    top = rings[-1][0]
    # plankwortels: platte, uitlopende platen rond de voet
    n_fin = 3 if far else rnd.choice((4, 5))
    for k in range(n_fin):
        a = ang0 + math.tau * (k + rnd.uniform(-0.15, 0.15)) / n_fin
        d = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-d.y, d.x, 0))
        reach = rnd.uniform(1.5, 2.1)
        hmax = rnd.uniform(2.0, 3.0)
        th = 0.07
        steps = 3 if far else 5
        prof = []
        for s in range(steps + 1):
            u = s / steps
            rr = 0.28 + reach * u
            zt = hmax * (1 - u) ** 1.8 + 0.05
            prof.append((rr, zt))
        for s in range(steps):
            (r0, z0), (r1, z1) = prof[s], prof[s + 1]
            for sg in (-1, 1):
                o = side * th * sg
                quad(bm, lay, uvl, [(d * r0 + o + Vector((0, 0, -0.05)), (r0, 0.0)), (d * r1 + o + Vector((0, 0, -0.05)), (r1, 0.0)),
                                    (d * r1 + o + Vector((0, 0, z1)), (r1, z1 / 1.4)), (d * r0 + o + Vector((0, 0, z0)), (r0, z0 / 1.4))],
                     (0.42, 0.37, 0.30, 0.0), 0)
            quad(bm, lay, uvl, [(d * r0 + side * -th + Vector((0, 0, z0)), (r0, 0.0)), (d * r1 + side * -th + Vector((0, 0, z1)), (r1, 0.0)),
                                (d * r1 + side * th + Vector((0, 0, z1)), (r1, 0.1)), (d * r0 + side * th + Vector((0, 0, z0)), (r0, 0.1))],
                 (0.42, 0.37, 0.30, 0.0), 0)
    leaf0, leaf1 = (0.6, 0.7, 0.55), (1.0, 1.0, 0.9)
    def clump(origin, count, scale, up):
        for k in range(count):
            yaw = math.tau * k / count + rnd.uniform(-0.25, 0.25)
            frond(bm, lay, uvl, origin, yaw, rnd.uniform(2.0, 3.0) * scale, rnd.uniform(0.9, 1.25) * scale,
                  rnd.uniform(0.5, 1.2) * scale + up, rnd.uniform(0.7, 1.4) * scale, leaf0, leaf1, 3 if far else 5)
    anchors = [top]
    clump(top + Vector((0, 0, 0.1)), 6 if far else 11, 1.0, 0.3)
    if not far:
        clump(top + Vector((0, 0, 0.6)), 6, 0.55, 0.6)
    # twee zijtakken met eigen bladerbos
    for k in range(1 if far else 2):
        a = ang0 + math.tau * (k * 0.5 + 0.25) + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        base = centre(0.62 + 0.08 * k)
        tip = base + d * rnd.uniform(1.8, 2.5) + Vector((0, 0, rnd.uniform(0.9, 1.5)))
        side = Vector((-d.y, d.x, 0))
        for wdt in (0.14, 0.14):
            quad(bm, lay, uvl, [(base + side * wdt, (0, 0)), (base - side * wdt, (1, 0)), (tip - side * 0.05, (1, 1)), (tip + side * 0.05, (0, 1))], (0.4, 0.35, 0.28, 0.0), 0)
            break
        anchors.append(tip)
        clump(tip, 4 if far else 7, 0.7, 0.2)
    # lianen: dunne hangende linten onder de kroon en de takken
    for k in range(2 if far else 7):
        o = anchors[k % len(anchors)] + Vector((rnd.uniform(-0.7, 0.7), rnd.uniform(-0.7, 0.7), -0.4))
        drop = rnd.uniform(3.0, min(7.0, height * 0.7))
        w = 0.05
        sg = 3 if far else 6
        sway = Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 0))
        for i in range(sg):
            t0, t1 = i / sg, (i + 1) / sg
            def pt(t):
                return o + Vector((0, 0, -drop * t)) + sway * math.sin(t * 3.0)
            col0 = (0.18, 0.28, 0.10, t0)
            col1 = (0.18, 0.28, 0.10, t1)
            p0, p1 = pt(t0), pt(t1)
            verts = []
            for p, cc in ((p0 - Vector((w, 0, 0)), col0), (p1 - Vector((w, 0, 0)), col1), (p1 + Vector((w, 0, 0)), col1), (p0 + Vector((w, 0, 0)), col0)):
                v = bm.verts.new(p)
                v[lay] = cc
                verts.append(v)
            f = bm.faces.new(verts)
            f.material_index = 2
            for loop, uv in zip(f.loops, ((0, t0), (0, t1), (1, t1), (1, t0))):
                loop[uvl].uv = uv
    bm.normal_update()
    return make_obj(name, bm, [B_STAM, B_BLAD, B_LIAAN])


for name, seed, h in (("Boom1", 41, 11.0), ("Boom2", 53, 13.5)):
    jungle_tree(name, seed, h)
    jungle_tree(name + "_far", seed, h, far=True)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "jungle.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_animations=False, export_vertex_color="ACTIVE", export_materials="EXPORT")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "jungle.blend"))
for o in scene.objects:
    o.data.calc_loop_triangles()
    print("TRIS", o.name, len(o.data.loop_triangles), "materialen", len(o.data.materials))
