"""Uitrusting voor het mannetje van Bloedjungle: helm, rugzak met slaaprol en riemen, borstzakken, koppel met pouches en veldfles, laarzen.
Alle maten staan in Godot-assen (x rechts, y omhoog, z vooruit) in de ruimte van assets/soldaat.glb in de 'stil'-pose; de functies
gbox/gcyl/gsphere zetten dat om naar Blender (Blender y = -Godot z). Elk deel heet naar de botten waaraan het in het spel hangt.
Gebruik: python3 maak_uitrusting.py <uitmap>  ->  uitrusting.glb, uitrusting.blend"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Matrix, Vector

OUT = os.path.abspath(sys.argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------- materialen ----------
def mat(name, color, rough=0.8, metal=0.0, image=None, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    if emit:
        p.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in emit], 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def link(obj, parent=None):
    scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def empty(name, parent=None, loc=(0, 0, 0)):
    e = link(bpy.data.objects.new(name, None), parent)
    e.location = loc
    return e


def mesh_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(40))
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    o.location = loc
    return link(o, parent)


def box(name, size, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    o = mesh_obj(name, bm, material, parent, loc)
    o.rotation_euler = rot
    return o


def cyl(name, r1, r2, depth, material, axis="Z", segs=12, parent=None, loc=(0, 0, 0), smooth=True, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    o = mesh_obj(name, bm, material, parent, loc, smooth)
    o.rotation_euler = rot
    return o


def sphere(name, r, material, parent=None, loc=(0, 0, 0), scale=(1, 1, 1), half=False):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r)
    if half:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return mesh_obj(name, bm, material, parent, loc, True)


def prism_x(name, profile_yz, width, material, parent=None, loc=(0, 0, 0)):
    bm = bmesh.new()
    left = [bm.verts.new((-width / 2, y, z)) for y, z in profile_yz]
    right = [bm.verts.new((width / 2, y, z)) for y, z in profile_yz]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    for i in range(len(profile_yz)):
        j = (i + 1) % len(profile_yz)
        bm.faces.new([left[i], left[j], right[j], right[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, parent, loc)


def bevel(o, w=0.015, segs=1):
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = segs
    m.limit_method = "ANGLE"


def join(target, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target




# ---------- hulpjes in Godot-assen ----------
def B(p):
    return (p[0], -p[2], p[1])


def gbox(name, size, loc, material, parent, rot_y=0.0):
    o = box(name, (size[0], size[2], size[1]), material, parent, B(loc))
    o.rotation_euler = (0, 0, -rot_y)
    return o


def gcyl(name, r, h, loc, material, parent, axis="y", segs=12, squash=(1, 1)):
    """Cilinder met as in Godot-richting; squash maakt hem ovaal (x, z)."""
    ax = {"x": "X", "y": "Z", "z": "Y"}[axis]
    o = cyl(name, r, r, h, material, ax, segs, parent, B(loc))
    if squash != (1, 1):
        o.scale = (squash[0], squash[1], 1) if axis == "y" else (1, 1, 1)
    return o


def gcyl_between(name, r, p0, p1, material, parent, segs=10):
    p0, p1 = Vector(B(p0)), Vector(B(p1))
    d = p1 - p0
    o = cyl(name, r, r, d.length, material, "Z", segs, parent, tuple((p0 + p1) / 2))
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return o


def gsphere(name, r, loc, material, parent, scale=(1, 1, 1), half=False):
    return sphere(name, r, material, parent, B(loc), (scale[0], scale[2], scale[1]), half)


HELM = mat("Helm", (0.24, 0.27, 0.16), 0.55, 0.1)
HELMBAND = mat("Helmband", (0.14, 0.15, 0.09), 0.8)
CANVAS = mat("Canvas", (0.21, 0.23, 0.13), 0.95)
ROL = mat("Slaaprol", (0.33, 0.30, 0.19), 0.95)
LEER = mat("Leer", (0.22, 0.14, 0.07), 0.7)
LAARS = mat("Laars", (0.12, 0.085, 0.06), 0.65)
STAALG = mat("Metaal", (0.28, 0.28, 0.27), 0.4, 0.8)
KHAKI = mat("Khaki", (0.25, 0.25, 0.15), 0.9)
OLIJFD = mat("Olijf", (0.20, 0.23, 0.13), 0.8)


_UIT = None


def uitrusting_mat():
    """Eén materiaal met hoekkleuren: een heel onderdeel is dan één tekenopdracht in het spel."""
    global _UIT
    if _UIT is None:
        m = bpy.data.materials.new("Uitrusting")
        m.use_nodes = True
        p = m.node_tree.nodes["Principled BSDF"]
        p.inputs["Roughness"].default_value = 0.75
        p.inputs["Metallic"].default_value = 0.0
        vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        m.node_tree.links.new(vc.outputs["Color"], p.inputs["Base Color"])
        _UIT = m
    return _UIT


def finish(root):
    """Kleurt elk deel (hoekkleur = zijn materiaalkleur), voegt alles samen tot één mesh met één materiaal."""
    parts = [o for o in root.children if o.type == "MESH"]
    for o in parts:
        base = o.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        ca = o.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for i in range(len(o.data.loops)):
            ca.data[i].color = (base[0], base[1], base[2], 1.0)
        o.data.materials.clear()
        o.data.materials.append(uitrusting_mat())
    target = parts[0]
    if len(parts) > 1:
        join(target, parts[1:])
    target.name = root.name + "_Mesh"
    target.data.name = target.name


CX = -0.03  # middenlijn van het lichaam in de 'stil'-pose


def helm():
    r = empty("Helm")   # hangt aan DEF-head
    hc = (-0.05, 1.635, 0.02)
    gsphere("Koepel", 0.142, hc, HELM, r, (1.0, 0.86, 1.12), half=True)
    gcyl("Rand", 0.172, 0.016, (hc[0], hc[1] - 0.005, hc[2]), HELM, r, "y", 20, (1.0, 1.12))
    gcyl("Band", 0.146, 0.022, (hc[0], hc[1] + 0.012, hc[2] - 0.0), HELMBAND, r, "y", 16, (1.0, 1.1))
    for i, a in enumerate((-0.07, 0.07)):
        gbox("Riempje", (0.012, 0.09, 0.012), (hc[0] + a * 2, hc[1] - 0.06, hc[2] + 0.14), HELMBAND, r)
    finish(r)
    return r


def rugzak():
    r = empty("Rugzak")   # hangt aan DEF-spine003
    gbox("Zak", (0.28, 0.31, 0.12), (CX, 1.23, -0.28), CANVAS, r)
    gbox("Klep", (0.26, 0.10, 0.14), (CX, 1.38, -0.28), KHAKI, r)
    gbox("Zijzak", (0.08, 0.18, 0.1), (CX - 0.17, 1.17, -0.27), KHAKI, r)
    gbox("Zijzak", (0.08, 0.18, 0.1), (CX + 0.17, 1.17, -0.27), KHAKI, r)
    gcyl("Slaaprol", 0.052, 0.32, (CX, 1.46, -0.29), ROL, r, "x", 14)
    for sx in (-0.11, 0.11):
        gbox("Schouderband", (0.045, 0.40, 0.02), (CX + sx, 1.25, 0.045), KHAKI, r)
        gbox("Bandboven", (0.045, 0.02, 0.36), (CX + sx, 1.44, -0.12), KHAKI, r)
    for dx in (-0.1, 0.1):
        gbox("Gesp", (0.03, 0.018, 0.012), (CX + dx, 1.36, -0.357), LEER, r)
    for i, dx in enumerate((-0.12, 0.0, 0.12)):
        gbox("Borstzak", (0.085, 0.1, 0.05), (CX + dx, 1.16, 0.075), OLIJFD, r)
        gbox("Borstklep", (0.085, 0.03, 0.055), (CX + dx, 1.205, 0.078), KHAKI, r)
    finish(r)
    return r


def koppel():
    r = empty("Koppel")   # hangt aan DEF-hips
    gcyl("Riem", 0.195, 0.05, (0.0, 0.985, -0.05), LEER, r, "y", 18, (1.0, 0.78))
    gbox("Gesp", (0.05, 0.045, 0.012), (0.0, 0.985, 0.075), STAALG, r)
    for dx in (-0.11, 0.11):
        gbox("Pouch", (0.075, 0.10, 0.055), (dx, 0.945, 0.07), OLIJFD, r)
        gbox("Pouchklep", (0.075, 0.03, 0.06), (dx, 0.995, 0.073), KHAKI, r)
    gcyl("Veldfles", 0.048, 0.15, (0.2, 0.9, -0.09), OLIJFD, r, "y", 12)
    gcyl("Dop", 0.036, 0.04, (0.2, 0.99, -0.09), STAALG, r, "y", 10)
    gbox("Holster", (0.05, 0.16, 0.09), (-0.2, 0.88, -0.06), LEER, r)
    gbox("Schep", (0.03, 0.2, 0.012), (0.0, 0.88, -0.19), STAALG, r)
    finish(r)
    return r


def laarzen():
    for naam, foot, shin, toe in (("LaarsL", (0.1, 0.13, 0.17), (0.1, 0.56, 0.17), (0.15, 0.03, 0.31)),
                                   ("LaarsR", (-0.06, 0.14, -0.22), (-0.16, 0.53, -0.07), (-0.18, 0.04, -0.15))):
        r = empty(naam)   # hangt aan DEF-footL / DEF-footR
        d = Vector(shin) - Vector(foot)
        top = Vector(foot) + d.normalized() * 0.26
        gcyl_between("Schacht", 0.068, (foot[0], foot[1] - 0.02, foot[2]), tuple(top), LAARS, r, 12)
        gcyl_between("Rand", 0.074, tuple(Vector(foot) + d.normalized() * 0.24), tuple(top), LEER, r, 12)
        mid = (Vector(foot) + Vector(toe)) / 2
        o = gbox("Voet", (0.11, 0.075, 0.27), (mid.x, 0.045, mid.z), LAARS, r)
        o.rotation_euler = (0, 0, -math.atan2(toe[0] - foot[0], toe[2] - foot[2]))
        gbox("Zool", (0.115, 0.02, 0.28), (mid.x, 0.01, mid.z), LEER, r).rotation_euler = o.rotation_euler
        finish(r)


helm(); rugzak(); koppel(); laarzen()

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "uitrusting.glb"), export_format="GLB", export_apply=True,
                          export_yup=True, export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "uitrusting.blend"))
for root in [o for o in scene.objects if o.type == "EMPTY"]:
    tris = 0
    for o in root.children:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    print("TRIS", root.name, tris, "delen", len(root.children))
