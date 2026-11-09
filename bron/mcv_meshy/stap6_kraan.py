"""MCV opbouw: kraanarm voor op de laadbak van de wagen en twee stapels prefab-platen (8 stuks).
Gebruik: python3 stap6_kraan.py <uitmap>   ->  <uitmap>/mcv_kraan.glb
Assen (Blender, Z omhoog): de giek wijst in rust naar -Y (= +Z in Godot, naar de achterkant van de wagen).
Knopen (voor Godot): Kraan > Draaikrans (draai om Z) > GiekA (hef om X) > GiekB (schuift langs -Y) > Kabel (> KabelMesh, Haak)
en Stapel > Plaat1..Plaat8. Kraan staat in de wagen op (0, 1.41, 3.3) Godot; Stapel op (0, 1.41, 0).
Clip 'Werken' (8 s) is een demonstratie voor de viewer; in het spel stuurt Godot de kraan zelf."""
import sys, math
import bpy, bmesh
from mathutils import Vector

UIT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def mat(naam, kleur, ruw=0.6, metaal=0.0):
    m = bpy.data.materials.new(naam)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*kleur, 1.0)
    b.inputs["Roughness"].default_value = ruw
    b.inputs["Metallic"].default_value = metaal
    return m

M_OLIJF = mat("Kraan_olijf", (0.17, 0.20, 0.11), 0.65, 0.2)
M_GEEL = mat("Kraan_geel", (0.70, 0.50, 0.05), 0.55, 0.2)
M_STAAL = mat("Kraan_staal", (0.07, 0.07, 0.08), 0.45, 0.8)
M_GLAS = mat("Kraan_glas", (0.03, 0.05, 0.06), 0.15, 0.1)
M_BETON = mat("Plaat_beton", (0.50, 0.50, 0.47), 0.92, 0.0)
M_KADER = mat("Plaat_kader", (0.10, 0.11, 0.12), 0.5, 0.7)
M_LUS = mat("Plaat_lus", (0.75, 0.28, 0.04), 0.5, 0.3)
M_HOUT = mat("Pallet_hout", (0.38, 0.27, 0.15), 0.9, 0.0)
M_BAND = mat("Spanband", (0.05, 0.12, 0.30), 0.8, 0.0)

def leeg(naam, ouder=None, loc=(0, 0, 0)):
    o = bpy.data.objects.new(naam, None)
    sc.collection.objects.link(o)
    o.parent = ouder
    o.location = loc
    return o

def blok(naam, ouder, loc, maat, m, rot=None):
    me = bpy.data.meshes.new(naam)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= maat[0]; v.co.y *= maat[1]; v.co.z *= maat[2]
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(naam, me)
    sc.collection.objects.link(o)
    o.parent = ouder
    o.location = loc
    if rot: o.rotation_euler = rot
    o.data.materials.append(m)
    return o

def cil(naam, ouder, loc, r, h, m, rot=None, seg=16):
    me = bpy.data.meshes.new(naam)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=h)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(naam, me)
    sc.collection.objects.link(o)
    o.parent = ouder
    o.location = loc
    if rot: o.rotation_euler = rot
    o.data.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    return o

# ---------------- kraan ----------------
kraan = leeg("Kraan")
blok("Voet", kraan, (0, 0, 0.07), (1.1, 1.1, 0.14), M_STAAL)
for sx in (-1, 1):
    for sy in (-1, 1):
        cil("Bout", kraan, (sx * 0.45, sy * 0.45, 0.16), 0.04, 0.05, M_STAAL, seg=8)
dr = leeg("Draaikrans", kraan, (0, 0, 0.14))
cil("Krans", dr, (0, 0, 0.09), 0.44, 0.18, M_STAAL, seg=24)
blok("Onderbouw", dr, (0, 0.12, 0.38), (0.95, 1.1, 0.4), M_OLIJF)
blok("Cabine", dr, (0.36, -0.05, 0.78), (0.5, 0.6, 0.48), M_OLIJF)
blok("Ruit", dr, (0.36, -0.36, 0.82), (0.4, 0.02, 0.28), M_GLAS)
blok("Tegengewicht", dr, (0, 0.62, 0.5), (0.8, 0.36, 0.5), M_STAAL)
blok("Waarschuwing", dr, (0, 0.62, 0.78), (0.8, 0.37, 0.05), M_GEEL)
cil("Zwaailamp", dr, (0.36, -0.05, 1.08), 0.06, 0.1, M_GEEL, seg=10)
ga = leeg("GiekA", dr, (0, 0, 0.95))
cil("Draaipunt", ga, (0, 0, 0), 0.14, 0.4, M_STAAL, rot=(0, math.pi / 2, 0), seg=12)
blok("GiekA_buis", ga, (0, -1.6, 0), (0.30, 3.2, 0.30), M_OLIJF)
blok("GiekA_band", ga, (0, -1.6, 0.16), (0.12, 3.2, 0.03), M_GEEL)
cil("Cilinder", ga, (0.0, -0.9, -0.27), 0.055, 1.7, M_STAAL, rot=(math.pi / 2, 0, 0), seg=10)
gb = leeg("GiekB", ga, (0, -1.0, 0))
blok("GiekB_buis", gb, (0, -1.5, 0), (0.22, 3.0, 0.22), M_STAAL)
cil("Schijf", gb, (0, -3.0, 0), 0.10, 0.1, M_STAAL, rot=(0, math.pi / 2, 0), seg=14)
kab = leeg("Kabel", gb, (0, -3.0, -0.1))
km = cil("KabelMesh", kab, (0, 0, -0.5), 0.012, 1.0, M_STAAL, seg=6)
haak = leeg("Haak", kab, (0, 0, -1.0))
blok("Haakblok", haak, (0, 0, -0.1), (0.16, 0.16, 0.2), M_GEEL)
blok("Haakbek", haak, (0, 0, -0.25), (0.05, 0.05, 0.1), M_STAAL)
bm_ = bmesh.new()
bmesh.ops.create_cone(bm_, cap_ends=False, segments=12, radius1=0.07, radius2=0.07, depth=0.03)
me = bpy.data.meshes.new("Haakring"); bm_.to_mesh(me); bm_.free()
hr = bpy.data.objects.new("Haakring", me); sc.collection.objects.link(hr)
hr.parent = haak; hr.location = (0, 0, -0.34); hr.rotation_euler = (math.pi / 2, 0, 0); hr.data.materials.append(M_STAAL)

# ---------------- platenstapels ----------------
stapel = leeg("Stapel")
PLAAT = (1.5, 1.3, 0.14)
n = 0
for pi, (px, py) in enumerate([(0.0, -0.5), (0.0, -1.9)]):    # Blender-y = -(Godot-z)
    blok("Pallet", stapel, (px, py, 0.07), (1.7, 1.5, 0.14), M_HOUT)
    for lvl in range(4):
        n += 1
        z = 0.14 + PLAAT[2] * 0.5 + lvl * (PLAAT[2] + 0.015)
        p = leeg("Plaat%d" % n, stapel, (px, py, z))
        blok("Beton", p, (0, 0, 0), PLAAT, M_BETON)
        blok("Kader_a", p, (0, PLAAT[1] / 2 - 0.03, 0.01), (PLAAT[0], 0.06, PLAAT[2] + 0.02), M_KADER)
        blok("Kader_b", p, (0, -PLAAT[1] / 2 + 0.03, 0.01), (PLAAT[0], 0.06, PLAAT[2] + 0.02), M_KADER)
        blok("Rib", p, (0, 0, PLAAT[2] / 2 + 0.01), (0.08, PLAAT[1] - 0.1, 0.03), M_KADER)
        for sx in (-1, 1):
            for sy in (-1, 1):
                blok("Lus", p, (sx * 0.55, sy * 0.45, PLAAT[2] / 2 + 0.03), (0.1, 0.1, 0.06), M_LUS)
    blok("Band_a", stapel, (px - 0.4, py, 0.14 + 4 * (PLAAT[2] + 0.015) + 0.02), (0.05, 1.4, 0.02), M_BAND)
    blok("Band_b", stapel, (px + 0.4, py, 0.14 + 4 * (PLAAT[2] + 0.015) + 0.02), (0.05, 1.4, 0.02), M_BAND)

# ---------------- clip 'Werken' (viewer) ----------------
def sleutel(ob, pad, idx, waarden):
    for f, v in waarden:
        getattr(ob, pad)[idx] = v
        ob.keyframe_insert(data_path=pad, index=idx, frame=f)

def naar_nla(ob):
    ad = ob.animation_data
    act = ad.action
    act.name = "Werken_" + ob.name
    tr = ad.nla_tracks.new(); tr.name = "Werken"
    tr.strips.new("Werken", 0, act)
    ad.action = None

FPS = 30
sc.render.fps = FPS
for ob in (dr, ga, gb, kab, km, haak):
    ob.animation_data_create()
sleutel(dr, "rotation_euler", 2, [(0, 0), (60, math.radians(-80)), (120, math.radians(80)), (240, 0)])
sleutel(ga, "rotation_euler", 0, [(0, math.radians(-25)), (60, math.radians(-35)), (120, math.radians(-50)), (240, math.radians(-25))])
sleutel(gb, "location", 1, [(0, -1.0), (60, -1.8), (120, -3.0), (240, -1.0)])
sleutel(km, "scale", 2, [(0, 1.0), (40, 2.2), (60, 1.0), (140, 2.5), (170, 1.0), (240, 1.0)])
sleutel(km, "location", 2, [(0, -0.5), (40, -1.1), (60, -0.5), (140, -1.25), (170, -0.5), (240, -0.5)])
sleutel(haak, "location", 2, [(0, -1.0), (40, -2.2), (60, -1.0), (140, -2.5), (170, -1.0), (240, -1.0)])
for ob in (dr, ga, gb, km, haak):
    naar_nla(ob)

bpy.ops.export_scene.gltf(filepath=UIT.rstrip("/") + "/mcv_kraan.glb", export_format="GLB", use_selection=False, export_apply=True,
                          export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_optimize_animation_size=False)
tris = sum(len(o.data.polygons) * 2 for o in bpy.data.objects if o.type == "MESH")
print("klaar; ongeveer", tris, "driehoeken")
