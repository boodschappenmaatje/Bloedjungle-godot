"""MCV kraan vast op de wagen (v200): kolomkraan met 3-delige telescoopgiek en vier stempels achter de cabine + platenrek (8 prefab-platen) op het cabinedak.
Gebruik: python3 stap7_kraan_vast.py <uitmap>   ->  <uitmap>/mcv_kraan.glb
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

M_OLIJF = mat("Kraan_olijf", (0.058, 0.060, 0.040), 0.72, 0.15)   # zelfde grijsolijf als de wagen
M_GEEL = mat("Kraan_geel", (0.36, 0.26, 0.03), 0.65, 0.15)   # gedempt: alleen accenten
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


# Assen (Blender, Z omhoog): de giek wijst in rust naar -Y (= +Z in Godot, naar de achterkant van de wagen).
# Knopen voor Godot: Kraan (voet, op de laadbak) > Stempel_L1/L2/R1/R2 (> Balk, > Poot) en Draaikrans (draai om Z) > GiekA (hef om X) > GiekB (schuift langs -Y) > GiekC (idem) > Kabel (> KabelMesh, Haak);
# Stapel (rek met pallets) > Plaat1..Plaat8. Kraan staat in de wagen op (0, 1.41, -0.35) Godot, Stapel op (0, 2.7, -2.4).
kraan = leeg("Kraan")
blok("Voet", kraan, (0, 0, 0.07), (1.1, 1.1, 0.14), M_STAAL)
for sx in (-1, 1):
    for sy in (-1, 1):
        cil("Bout", kraan, (sx * 0.45, sy * 0.45, 0.16), 0.04, 0.05, M_STAAL, seg=8)
blok("Stempelkast", kraan, (0, 0, 0.4), (1.0, 1.0, 0.5), M_OLIJF)
# stempels: balk schuift zijwaarts uit, poot zakt naar de grond (Godot schaalt Balk.x en Poot.z)
for naam, sx, sy in (("L1", -1, -0.33), ("L2", -1, 0.33), ("R1", 1, -0.33), ("R2", 1, 0.33)):
    st = leeg("Stempel_" + naam, kraan, (sx * 0.5, sy, 0.4))
    balk = leeg("Balk", st)
    blok("BalkMesh", balk, (sx * 0.5, 0, 0), (1.0, 0.18, 0.18), M_STAAL)
    poot = leeg("Poot", st, (sx * 1.0, 0, 0))
    pm = cil("PootMesh", poot, (0, 0, -0.5), 0.07, 1.0, M_GEEL, seg=10)
    cil("Voetplaat", poot, (0, 0, -1.02), 0.18, 0.04, M_STAAL, seg=12)
dr = leeg("Draaikrans", kraan, (0, 0, 0.65))
cil("Krans", dr, (0, 0, 0.06), 0.44, 0.12, M_STAAL, seg=24)
blok("Onderbouw", dr, (0, 0.1, 0.5), (0.95, 1.0, 0.8), M_OLIJF)
blok("Tegengewicht", dr, (0, 0.62, 0.55), (0.8, 0.3, 0.6), M_STAAL)
blok("Waarschuwing", dr, (0, 0.62, 0.88), (0.8, 0.31, 0.05), M_GEEL)
blok("Cabine", dr, (0.62, -0.05, 0.85), (0.45, 0.6, 0.5), M_OLIJF)
blok("Ruit", dr, (0.62, -0.36, 0.9), (0.38, 0.02, 0.3), M_GLAS)
blok("Kolom", dr, (0, -0.1, 1.2), (0.5, 0.5, 0.9), M_OLIJF)
cil("Zwaailamp", dr, (0.62, -0.05, 1.15), 0.06, 0.1, M_GEEL, seg=10)
ga = leeg("GiekA", dr, (0, 0, 1.55))
cil("Draaipunt", ga, (0, 0, 0), 0.16, 0.5, M_STAAL, rot=(0, math.pi / 2, 0), seg=12)
blok("GiekA_buis", ga, (0, -1.8, 0), (0.36, 3.6, 0.36), M_OLIJF)
blok("GiekA_band", ga, (0, -1.8, 0.19), (0.14, 3.6, 0.03), M_GEEL)
cil("Cilinder", ga, (0.0, -1.0, -0.3), 0.06, 1.9, M_STAAL, rot=(math.pi / 2, 0, 0), seg=10)
gb = leeg("GiekB", ga, (0, -0.3, 0))
blok("GiekB_buis", gb, (0, -1.7, 0), (0.28, 3.4, 0.28), M_STAAL)
gc = leeg("GiekC", gb, (0, -0.3, 0))
blok("GiekC_buis", gc, (0, -1.6, 0), (0.21, 3.2, 0.21), M_OLIJF)
cil("Schijf", gc, (0, -3.2, 0), 0.11, 0.1, M_STAAL, rot=(0, math.pi / 2, 0), seg=14)
kab = leeg("Kabel", gc, (0, -3.2, -0.1))
km = cil("KabelMesh", kab, (0, 0, -0.5), 0.012, 1.0, M_STAAL, seg=6)
haak = leeg("Haak", kab, (0, 0, -1.0))
blok("Haakblok", haak, (0, 0, -0.1), (0.16, 0.16, 0.2), M_GEEL)
blok("Haakbek", haak, (0, 0, -0.25), (0.05, 0.05, 0.1), M_STAAL)
bm_ = bmesh.new()
bmesh.ops.create_cone(bm_, cap_ends=False, segments=12, radius1=0.07, radius2=0.07, depth=0.03)
me = bpy.data.meshes.new("Haakring"); bm_.to_mesh(me); bm_.free()
hr = bpy.data.objects.new("Haakring", me); sc.collection.objects.link(hr)
hr.parent = haak; hr.location = (0, 0, -0.34); hr.rotation_euler = (math.pi / 2, 0, 0); hr.data.materials.append(M_STAAL)

# ---------------- platenrek op het cabinedak ----------------
stapel = leeg("Stapel")
PLAAT = (1.05, 1.3, 0.1)
blok("RekVloer", stapel, (0, 0, 0.04), (2.36, 1.5, 0.08), M_STAAL)
for sx in (-1, 1):
    for sy in (-1, 1):
        blok("RekPaal", stapel, (sx * 1.14, sy * 0.72, 0.28), (0.07, 0.07, 0.56), M_STAAL)
n = 0
for px in (-0.58, 0.58):
    blok("Pallet", stapel, (px, 0, 0.11), (1.1, 1.4, 0.06), M_HOUT)
    for lvl in range(4):
        n += 1
        z = 0.14 + PLAAT[2] * 0.5 + lvl * (PLAAT[2] + 0.01)
        p = leeg("Plaat%d" % n, stapel, (px, 0, z))
        blok("Beton", p, (0, 0, 0), PLAAT, M_BETON)
        blok("Kader_a", p, (0, PLAAT[1] / 2 - 0.03, 0.01), (PLAAT[0], 0.06, PLAAT[2] + 0.02), M_KADER)
        blok("Kader_b", p, (0, -PLAAT[1] / 2 + 0.03, 0.01), (PLAAT[0], 0.06, PLAAT[2] + 0.02), M_KADER)
        blok("Rib", p, (0, 0, PLAAT[2] / 2 + 0.01), (0.07, PLAAT[1] - 0.1, 0.03), M_KADER)
        for sx in (-1, 1):
            for sy in (-1, 1):
                blok("Lus", p, (sx * 0.38, sy * 0.45, PLAAT[2] / 2 + 0.03), (0.09, 0.09, 0.06), M_LUS)
    top = 0.14 + 4 * (PLAAT[2] + 0.01)
    blok("Band_a", stapel, (px - 0.3, 0, top + 0.01), (0.05, 1.42, 0.02), M_BAND)
    blok("Band_b", stapel, (px + 0.3, 0, top + 0.01), (0.05, 1.42, 0.02), M_BAND)

# ---------------- clip 'Kraan_uitklappen' (viewer; in het spel stuurt Godot) ----------------
def sleutel(ob, pad, idx, waarden):
    for f, v in waarden:
        getattr(ob, pad)[idx] = v
        ob.keyframe_insert(data_path=pad, index=idx, frame=f)

def naar_nla(ob, naam):
    ad = ob.animation_data
    act = ad.action
    act.name = naam + "_" + ob.name
    tr = ad.nla_tracks.new(); tr.name = naam
    tr.strips.new(naam, 0, act)
    ad.action = None

FPS = 30
sc.render.fps = FPS
balken = [o for o in bpy.data.objects if o.name.startswith("Balk") and o.type == "EMPTY"]
poten = [o for o in bpy.data.objects if o.name.startswith("Poot") and o.type == "EMPTY"]
acts = [dr, ga, gb, gc] + balken + poten
for ob in acts:
    ob.animation_data_create()
sleutel(dr, "rotation_euler", 2, [(0, math.pi), (60, math.pi), (100, 0), (120, 0)])
sleutel(ga, "rotation_euler", 0, [(0, math.radians(-3)), (70, math.radians(-3)), (120, math.radians(-40))])
sleutel(gb, "location", 1, [(0, -0.3), (90, -0.3), (120, -2.0)])
sleutel(gc, "location", 1, [(0, -0.3), (90, -0.3), (120, -1.5)])
for b in balken:
    sleutel(b, "scale", 0, [(0, 0.05), (40, 1.0), (120, 1.0)])
for p in poten:
    sx = 1 if p.parent.name.startswith("Stempel_R") else -1
    sleutel(p, "location", 0, [(0, sx * 0.05), (40, sx * 1.0), (120, sx * 1.0)])
    sleutel(p, "scale", 2, [(0, 0.05), (40, 0.05), (80, 1.5), (120, 1.5)])
for ob in acts:
    naar_nla(ob, "Kraan_uitklappen")

bpy.ops.export_scene.gltf(filepath=UIT.rstrip("/") + "/mcv_kraan.glb", export_format="GLB", use_selection=False, export_apply=True,
                          export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                          export_optimize_animation_size=False)
tris = sum(len(o.data.polygons) * 2 for o in bpy.data.objects if o.type == "MESH")
print("klaar; ongeveer", tris, "driehoeken")
