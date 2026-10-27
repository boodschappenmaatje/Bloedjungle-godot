"""Props voor Bloedjungle (VQ2): zandzakken (3 vormen), houten kist en munitiekist.
Z = omhoog (Godot Y), 1 eenheid = 1 meter. Zandzakken staan met het middelpunt op de oorsprong (lengte langs X),
kisten met de onderkant op de grond. Materialen = de VQ2-families uit assets/textures/vq2 (canvas, timber, olive, steel).
Gebruik: python3 maak_props.py [uitmap]  ->  props.glb, props.blend"""
import math, os, random, sys
import bpy, bmesh
from mathutils import Matrix, Vector, noise
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vq2_common import pbr, finish_mesh, export_and_save

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = os.path.abspath(ARGS[0] if ARGS else str(Path(__file__).parent / "uit"))
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def link(name, bm, materials, family, bevel=0.0, flat=False):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = not flat
    for m in materials:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    finish_mesh(o, family, bevel)
    return o


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------- zandzakken ----------
def bag(name, seed, tint, pinch_end, size=(0.62, 0.38, 0.22)):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
    off = Vector((rnd.random() * 40, rnd.random() * 40, rnd.random() * 40))
    e = 0.62
    for v in bm.verts:
        d = v.co.normalized()
        # superellips: een kussen in plaats van een bol
        x = math.copysign(abs(d.x) ** e, d.x)
        y = math.copysign(abs(d.y) ** e, d.y)
        z = math.copysign(abs(d.z) ** e, d.z)
        n = noise.noise(d * 2.2 + off) * 0.07
        co = Vector((x, y, z)) * (1.0 + n)
        if pinch_end:   # dichtgebonden hoek: de zak loopt aan een kant uit in een puntje
            k = smooth(0.55, 1.0, co.x)
            co.y *= 1.0 - 0.55 * k
            co.z *= 1.0 - 0.45 * k
        v.co = Vector((co.x * size[0] / 2, co.y * size[1] / 2, co.z * size[2] / 2))
    # onderkant plat, zodat hij op de vorige laag rust
    for v in bm.verts:
        v.co.z = max(v.co.z, -size[2] * 0.42)
    o = link(name, bm, [pbr("canvas", tint, "_" + name)], "canvas", 0.0)
    for d in o.data.uv_layers.active.data:   # fijner weefsel: een zak is maar 60 cm
        d.uv = (d.uv[0] * 2.4, d.uv[1] * 2.4)
    return o


bag("Zandzak1", 3, (0.80, 0.72, 0.54), False)
bag("Zandzak2", 11, (0.72, 0.67, 0.50), True)
bag("Zandzak3", 27, (0.68, 0.68, 0.54), False)


# ---------- kisten ----------
def box(bm, loc, size, mat=0, rot_z=0.0):
    r = bmesh.ops.create_cube(bm, size=1.0)
    for v in r["verts"]:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if rot_z:
        bmesh.ops.rotate(bm, verts=r["verts"], cent=(0, 0, 0), matrix=Matrix.Rotation(rot_z, 3, "Z"))
    bmesh.ops.translate(bm, verts=r["verts"], vec=Vector(loc))
    faces = {f for v in r["verts"] for f in v.link_faces}
    for f in faces:
        f.material_index = mat


def wooden_crate():
    rnd = random.Random(5)
    bm = bmesh.new()
    W, D, H = 1.0, 1.0, 0.85
    post = 0.075
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, ((W / 2 - post / 2) * sx, (D / 2 - post / 2) * sy, H / 2), (post, post, H))
    slat_h, gap = 0.165, 0.03
    for i in range(4):
        z = 0.06 + i * (slat_h + gap) + slat_h / 2
        j = rnd.uniform(-0.004, 0.004)
        for sy in (-1, 1):
            box(bm, (0, (D / 2 - 0.0125) * sy, z + j), (W - 2 * post + 0.01, 0.025, slat_h))
        for sx in (-1, 1):
            box(bm, ((W / 2 - 0.0125) * sx, 0, z - j), (0.025, D - 2 * post + 0.01, slat_h))
    # bodem en deksel (vijf planken met twee dwarslatten)
    box(bm, (0, 0, 0.03), (W - 0.02, D - 0.02, 0.03))
    for i in range(5):
        px = -0.4 + i * 0.2
        box(bm, (px, 0, H + 0.015 + rnd.uniform(0, 0.004)), (0.19, D - 0.02, 0.03), rot_z=rnd.uniform(-0.01, 0.01))
    for sy in (-0.3, 0.3):
        box(bm, (0, sy, H + 0.045), (W - 0.1, 0.07, 0.03))
    return link("Kist_Hout", bm, [pbr("timber")], "timber", 0.0, flat=True)


def ammo_crate():
    bm = bmesh.new()
    W, D, H = 0.62, 0.30, 0.30
    box(bm, (0, 0, H / 2 - 0.02), (W, D, H - 0.04), 0)
    box(bm, (0, 0, H - 0.04), (W + 0.012, D + 0.012, 0.012), 0)   # rand van het deksel
    box(bm, (0, 0, H - 0.015), (W - 0.02, D - 0.02, 0.025), 0)
    for sx in (-0.2, 0.2):  # sloten
        box(bm, (sx, D / 2 + 0.008, H - 0.075), (0.05, 0.016, 0.07), 1)
    for sx in (-1, 1):  # handvatten: bovenbeugel en twee oogjes
        box(bm, (0.31 * sx, 0, H - 0.09), (0.016, 0.1, 0.014), 1)
        box(bm, (0.318 * sx, -0.045, H - 0.115), (0.016, 0.014, 0.05), 1)
        box(bm, (0.318 * sx, 0.045, H - 0.115), (0.016, 0.014, 0.05), 1)
    for sx in (-0.26, 0.26):  # verstevigingsribben
        box(bm, (sx, 0, H / 2 - 0.02), (0.02, D + 0.01, H - 0.045), 0)
    return link("Kist_Munitie", bm, [pbr("olive"), pbr("steel")], "olive", 0.004, flat=True)


wooden_crate()
ammo_crate()
export_and_save(OUT, "props")
