"""Dennis' Meshy-dam en Meshy-sluisdeur in het bestaande dammodel (aangeroepen door maak_dam.py als DAM_MESHY gezet is).

Invoer = de uitvoer van de importstraat (tools/importstraat/straat.py):
  DAM_MESHY/dam/*.glb              (Meshy-dam, 14 m hoog, gebakken 4K, ~50k driehoeken)
  DAM_MESHY/sluisdeur/*.glb (Meshy-sluisdeur, 8 m breed, gebakken 2K)

Wat hier gebeurt (Dennis' dam is 31 m breed, het spel wil 60 m met drie deuren in het midden):
 1. Verbreden zonder vervormen: het vlakke muurstuk naast het midden wordt gespiegeld herhaald (C | T | spiegel(T) | rest),
    zodat elke naad twee gelijke doorsneden tegen elkaar legt (lijkt op de dilatatievoegen van een echte dam).
 2. Uitsparing voor de sluisdeuren: in het midden (|x| < 18) alles boven de drempel (10 m) weg, de bovenkant dicht.
 3. Blokken voor de breuk: het middenstuk onder de drempel in 8 x 3 blokken gezaagd (zelfde namen Blok_i_j, zaagvlakken dicht).
 4. Wat er overblijft (torens, slijtvloer, stenen, flanken) gaat naar Flank_L / Flank_R.
Alle Meshy-vlakken houden hun eigen UV's en gebakken textuur (materiaal DAM_Meshy en DAM_Sluis); zaagvlakken krijgen DAM_Beton.
"""
import bpy, bmesh, os, glob
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HALF = 30.0       # halve kroonbreedte in het spel
CEN = 18.0        # halve breedte van het middenstuk met de deuren
SILL = 10.0
LAYERS = [0.0, 3.5, 7.0, 10.0]
COLS = 8
UP_FACE_Y = 3.0   # de stuwmeerkant van de Meshy-muur komt op y = +3 (zoals de procedurele kroon, CW)
WALL_Y0 = -2.6    # wat stroomafwaarts van deze lijn ligt is slijtvloer (blijft liggen), de rest is muur
CORE = 2.0        # het echte midden |x| < 2 (met de deur) blijft uniek


def load_mesh(path):
    """Importeert een straat-glb en geeft één bmesh (wereldcoördinaten) en de naam van het materiaal."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    bm = bmesh.new()
    for o in new:
        if o.type != "MESH" or "colonly" in o.name:
            continue
        me = o.data.copy()
        me.transform(o.matrix_world)
        if me.uv_layers:
            me.uv_layers[0].name = "UVMap"
        while len(me.color_attributes):
            me.color_attributes.remove(me.color_attributes[0])
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    for o in new:
        bpy.data.objects.remove(o)
    return bm


def bisect(bm, co, no):
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no))


def part(bm, keep):
    """Kopie van bm met alleen de vlakken waarvan het midden aan keep(c) voldoet."""
    b = bm.copy()
    bmesh.ops.delete(b, geom=[f for f in b.faces if not keep(f.calc_center_median())], context="FACES")
    bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context="VERTS")
    return b


def append(dst, src, mat=Matrix.Identity(4), flip=False):
    me = bpy.data.meshes.new("_tmp")
    src.to_mesh(me)
    me.transform(mat)
    if flip:
        me.flip_normals()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def fill_plane(bm, edges, no, mat_index):
    """Vlakke zaagrand dicht met driehoeken (werkt ook voor holle/ingewikkelde doorsneden)."""
    edges = [e for e in edges if e.is_valid]
    if not edges:
        return 0
    faces = bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges, normal=Vector(no))["geom"]
    n = 0
    for f in faces:
        if isinstance(f, bmesh.types.BMFace):
            f.material_index = mat_index
            n += 1
    return n


def box_piece(src, lo, hi, mat_index):
    """Het stuk van src binnen het blok [lo, hi], met dichte zaagvlakken (6 keer zagen, elke keer de buitenkant weg en dicht)."""
    b = part(src, lambda c: all((lo[i] is None or lo[i] - 0.6 < c[i]) and (hi[i] is None or c[i] < hi[i] + 0.6) for i in range(3)))
    for ax in range(3):
        for sgn, val in ((-1, lo[ax]), (1, hi[ax])):
            if val is None:
                continue
            no = [0.0, 0.0, 0.0]; no[ax] = float(sgn)
            co = [0.0, 0.0, 0.0]; co[ax] = val
            r = bmesh.ops.bisect_plane(b, geom=b.verts[:] + b.edges[:] + b.faces[:], plane_co=Vector(co), plane_no=Vector(no), clear_outer=True)
            cut = [e for e in r["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
            fill_plane(b, cut, no, mat_index)
    return b


def remove_box(src, lo, hi, mat_index, cap_planes):
    """src zonder het blok [lo, hi]; de zaagranden op cap_planes [(as, waarde, normaal)] worden dichtgemaakt."""
    b = src.copy()
    for ax in range(3):
        for val in (lo[ax], hi[ax]):
            if val is None:
                continue
            no = [0.0, 0.0, 0.0]; no[ax] = 1.0
            co = [0.0, 0.0, 0.0]; co[ax] = val
            bmesh.ops.bisect_plane(b, geom=b.verts[:] + b.edges[:] + b.faces[:], plane_co=Vector(co), plane_no=Vector(no))
    inside = lambda c: all((lo[i] is None or c[i] > lo[i]) and (hi[i] is None or c[i] < hi[i]) for i in range(3))
    bmesh.ops.delete(b, geom=[f for f in b.faces if inside(f.calc_center_median())], context="FACES")
    bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context="VERTS")
    for ax, val, no in cap_planes:
        edges = [e for e in b.edges if e.is_boundary and all(abs(v.co[ax] - val) < 1e-3 for v in e.verts)
                 and all(all((lo[i] is None or v.co[i] >= lo[i] - 1e-3) and (hi[i] is None or v.co[i] <= hi[i] + 1e-3) for i in range(3) if i != ax) for v in e.verts)]
        fill_plane(b, edges, no, mat_index)
    return b


def widen(bm):
    """Verbreedt de Meshy-muur van ~31 m naar 60 m door het vlakke stuk naast het midden gespiegeld te herhalen."""
    xs = [v.co.x for v in bm.verts]
    half = (max(xs) - min(xs)) / 2
    D = HALF - half
    w = D / 2
    for x in (-CORE - w, -CORE, CORE, CORE + w):
        bisect(bm, (x, 0, 0), (1, 0, 0))
    out = bmesh.new()
    append(out, part(bm, lambda c: abs(c.x) < CORE))
    for s in (1, -1):
        a, b = CORE, CORE + w
        T = part(bm, lambda c, s=s: a < s * c.x < b)
        rest = part(bm, lambda c, s=s: s * c.x > CORE)
        append(out, T)                                                            # T op zijn plek
        mir = Matrix.Translation((s * 2 * b, 0, 0)) @ Matrix.Scale(-1, 4, (1, 0, 0))   # spiegel(T) rond x = s*b
        append(out, T, mir, flip=True)
        append(out, rest, Matrix.Translation((s * D, 0, 0)))                      # de rest (met de toren) naar buiten
    bmesh.ops.remove_doubles(out, verts=out.verts, dist=0.004)
    return out, D


def build(OBJ, MI, block_c, src_dir):
    """Vult de Ob-objecten van maak_dam.py met Meshy-geometrie. Geeft een BVH van de muur (voor scheuren/lekken) terug."""
    dam = load_mesh(glob.glob(os.path.join(src_dir, "dam", "*.glb"))[0])
    # stuwmeerkant op y = +3
    ymax = max(v.co.y for v in dam.verts if v.co.z > 4.0)
    bmesh.ops.translate(dam, verts=dam.verts, vec=(0, UP_FACE_Y - ymax, 0))
    for f in dam.faces:
        f.material_index = MI["DAM_Meshy"]
    dam, D = widen(dam)
    beton = MI["DAM_Beton"]
    big = 200.0
    # flanken: alles behalve het middenstuk (|x| < 18, stroomopwaarts van de slijtvloer, boven de vloer); zijkanten en voet dicht
    flank = remove_box(dam, (-CEN, WALL_Y0, 0.02), (CEN, big, big), beton,
                       [(0, -CEN, (1, 0, 0)), (0, CEN, (-1, 0, 0)), (2, 0.02, (0, 0, 1)), (1, WALL_Y0, (0, 1, 0))])
    # blokken: 8 kolommen x 3 lagen onder de drempel, elk dicht gezaagd; alles boven de drempel in het midden vervalt (deuren)
    blocks = {}
    for j in range(3):
        for i in range(COLS):
            x0 = -CEN + 2 * CEN / COLS * i
            z0 = 0.02 if j == 0 else LAYERS[j]
            b = box_piece(dam, (x0, WALL_Y0, z0), (x0 + 2 * CEN / COLS, None, LAYERS[j + 1]), beton)
            if b.faces:
                blocks[(i, j)] = b
    if "Slijtvloer" in OBJ:   # de slijtvloer (stroomafwaarts van de muur, tussen de geleidemuren) als eigen knoop, zoals in het oude model
        append(OBJ["Slijtvloer"].bm, part(flank, lambda c: c.y < WALL_Y0 and abs(c.x) < HALF - 3.5))
        flank = part(flank, lambda c: not (c.y < WALL_Y0 and abs(c.x) < HALF - 3.5))
    for side, s in (("L", -1), ("R", 1)):
        fb = part(flank, lambda c, s=s: s * c.x >= 0)
        append(OBJ["Flank_" + side].bm, fb)
    for (i, j), b in blocks.items():
        c = sum((v.co for v in b.verts), Vector()) / len(b.verts)
        nm = f"Blok_{i + 1}_{j + 1}"
        o = OBJ[nm]
        o.bm.clear()
        o.pivot = c
        block_c[(i, j)] = c
        append(o.bm, b, Matrix.Translation(-c))
    # BVH van de muur in wereldcoördinaten (scheuren en lekstralen leggen we hierop)
    tri = bmesh.new()
    append(tri, flank)
    for b in blocks.values():
        append(tri, b)
    bvh = BVHTree.FromBMesh(tri)
    stats = dict(meshy_dam_tris=sum(len(f.verts) - 2 for f in tri.faces), verbreed_m=round(2 * D, 2), blokken=len(blocks))
    return bvh, stats


def gate_mesh(src_dir, MI):
    g = load_mesh(glob.glob(os.path.join(src_dir, "sluisdeur", "*.glb"))[0])
    for f in g.faces:
        f.material_index = MI["DAM_Sluis"]
    return g


def snap_to_wall(ob, bvh, off=0.03):
    """Legt een scheur (Kraak_k) of de bron van een lekstraal (Lek_k) op het Meshy-achtervlak: straal vanaf stroomafwaarts naar +y."""
    def hit(p):
        r = bvh.ray_cast(Vector((p.x, -60.0, p.z)), Vector((0, 1, 0)), 120.0)
        if r[0] is None:
            return None
        return r[0] + r[1].normalized() * off * (1 if r[1].y < 0 else -1)
    return hit
