"""Zwaailamp voor de poortposten van Bloedjungle: voet, beugel, amberkleurige koepel en daarin een lamp met
een draaiende reflector (object "Draaier", animatie "draaien", 1 s per rondje, loopt rond). 1 eenheid = 1 meter.
De game zet in de Draaier een SpotLight3D, zodat de bundel echt rondzwaait."""
import math, sys, os
import bpy, bmesh
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

def mat(name, color, rough=0.5, metal=0.0, emit=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 2.0
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m

M = {
    "voet": mat("LampVoet", (0.16, 0.16, 0.15), 0.5, 0.7),
    "beugel": mat("LampBeugel", (0.52, 0.55, 0.58), 0.35, 0.9),
    "kap": mat("Lampkap", (1.0, 0.45, 0.05), 0.15, 0.0, emit=(1.0, 0.45, 0.05), alpha=0.6),
    "lamp": mat("Lampje", (1.0, 0.85, 0.4), 0.3, 0.0, emit=(1.0, 0.8, 0.3)),
    "refl": mat("Reflector", (0.85, 0.85, 0.8), 0.15, 1.0),
}

def mesh_obj(name, bm, m, parent=None, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = loc
    return ob

def cyl(bm, r1, r2, h, z, seg=20):
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, verts=r["verts"], vec=(0, 0, z + h / 2))

root = bpy.data.objects.new("Zwaailamp", None)
scene.collection.objects.link(root)

# voet: ronde plaat met een verhoogde ring en bouten, en een klein beugeltje
b = bmesh.new(); cyl(b, 0.2, 0.2, 0.05, 0.0); cyl(b, 0.16, 0.14, 0.05, 0.05)
mesh_obj("Lamp_voet", b, M["voet"], root)
b = bmesh.new()
for a in range(4):
    x, y = math.cos(a * math.pi / 2 + 0.78) * 0.17, math.sin(a * math.pi / 2 + 0.78) * 0.17
    r = bmesh.ops.create_cone(b, cap_ends=True, segments=6, radius1=0.018, radius2=0.018, depth=0.03)
    bmesh.ops.translate(b, verts=r["verts"], vec=(x, y, 0.06))
mesh_obj("Lamp_bouten", b, M["beugel"], root)
# beugelring rond de koepel
b = bmesh.new(); cyl(b, 0.15, 0.15, 0.02, 0.1)
bmesh.ops.create_cone  # (ring is een dunne plaat)
mesh_obj("Lamp_ring", b, M["beugel"], root)

# koepel: halve bol, doorzichtig amber
b = bmesh.new()
r = bmesh.ops.create_uvsphere(b, u_segments=20, v_segments=10, radius=0.145)
for v in list(b.verts):
    if v.co.z < -0.001:
        b.verts.remove(v)
bmesh.ops.translate(b, verts=b.verts, vec=(0, 0, 0.12))
mesh_obj("Lamp_kap", b, M["kap"], root)

# lampje midden onder de koepel (vast)
b = bmesh.new()
r = bmesh.ops.create_uvsphere(b, u_segments=10, v_segments=6, radius=0.035)
bmesh.ops.translate(b, verts=r["verts"], vec=(0, 0, 0.17))
mesh_obj("Lamp_bol", b, M["lamp"], root)

# draaiende reflector: een gebogen schermpje achter de lamp
dr_bm = bmesh.new()
r = bmesh.ops.create_cube(dr_bm, size=1)
bmesh.ops.scale(dr_bm, vec=(0.02, 0.1, 0.075), verts=r["verts"])
bmesh.ops.translate(dr_bm, verts=r["verts"], vec=(-0.05, 0.0, 0.0))
r = bmesh.ops.create_cube(dr_bm, size=1)
bmesh.ops.scale(dr_bm, vec=(0.06, 0.012, 0.012), verts=r["verts"])
bmesh.ops.translate(dr_bm, verts=r["verts"], vec=(-0.02, 0.0, 0.0))
dr = mesh_obj("Draaier", dr_bm, M["refl"], root, (0, 0, 0.17))
dr.rotation_mode = "XYZ"

# animatie: 1 s per rondje, zonder versnellen of afremmen
act = bpy.data.actions.new("draaien")
act.use_fake_user = True
dr.animation_data_create()
dr.animation_data.action = act
for fr, v in ((0, 0.0), (30, 2 * math.pi)):
    dr.rotation_euler = (0, 0, v)
    dr.keyframe_insert("rotation_euler", frame=fr)
for lay in act.layers:
    for st in lay.strips:
        for cb in st.channelbags:
            for fc in cb.fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
scene.frame_start, scene.frame_end = 0, 30
dr.rotation_euler = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "zwaailamp.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "zwaailamp.glb"), export_format="GLB", export_apply=True, export_yup=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True)
