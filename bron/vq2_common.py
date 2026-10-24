"""Shared Blender 4.3 VQ2 production helpers. All units metres; Z up.

Photographic textures are derived by tools/vq2_textures.py. This module only
extends the existing three generators; it is not a replacement game pipeline.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets/textures/vq2"
_images = {}
_materials = {}


def image(path, noncolor=False):
    path = str(path)
    if path not in _images:
        _images[path] = bpy.data.images.load(path, check_existing=True)
        if noncolor:
            _images[path].colorspace_settings.name = "Non-Color"
    return _images[path]


def pbr(family, tint=(1, 1, 1), suffix=""):
    key = (family, tuple(tint), suffix)
    if key in _materials:
        return _materials[key]
    mat = bpy.data.materials.new("VQ2_" + family + (suffix or ("_tint" if tint != (1, 1, 1) else "")))
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    color = nodes.new("ShaderNodeTexImage")
    color.image = image(TEX / family / "albedo.jpg")
    if tint != (1, 1, 1):
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1
        mix.inputs[2].default_value = (*tint, 1)
        links.new(color.outputs["Color"], mix.inputs[1])
        links.new(mix.outputs[0], bsdf.inputs["Base Color"])
    else:
        links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = image(TEX / family / "normal.jpg", True)
    bump = nodes.new("ShaderNodeNormalMap")
    bump.inputs["Strength"].default_value = .5 if family in ("olive", "steel") else .8
    links.new(normal.outputs["Color"], bump.inputs["Color"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    orm = nodes.new("ShaderNodeTexImage")
    orm.image = image(TEX / family / "orm.png", True)
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(orm.outputs["Color"], sep.inputs[0])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    _materials[key] = mat
    return mat


def projected_uv(obj, family="timber"):
    """Explicit metre-scaled face projection, with grain along each board/beam.

    No runtime triplanar shader: final UVs and standard glTF PBR work in Safari/Godot.
    """
    mesh = obj.data
    uv = mesh.uv_layers.active or mesh.uv_layers.new(name="VQ2_UV")
    for face in mesh.polygons:
        coords = [mesh.vertices[i].co for i in face.vertices]
        spans = [max(v[a] for v in coords)-min(v[a] for v in coords) for a in range(3)]
        axes = sorted(range(3), key=lambda a: spans[a], reverse=True)
        long, short = axes[0], axes[1]
        for li in face.loop_indices:
            p = mesh.vertices[mesh.loops[li].vertex_index].co
            if family == "roof":
                val = (p.x/1.8, p.y/2.4)
            elif family in ("timber", "painted_timber"):
                val = (p[short]/.58 + face.center[short]*.31, p[long]/2.8)
            else:
                val = (p[short]/1.4, p[long]/1.4)
            uv.data[li].uv = val


def finish_mesh(obj, family="timber", bevel=.006):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel:
        mod = obj.modifiers.new("VQ2 edge highlight", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        mod.angle_limit = .65
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for face in obj.data.polygons:
            face.use_smooth = True
        normals = obj.modifiers.new("VQ2 weighted corner normals", "WEIGHTED_NORMAL")
        normals.keep_sharp = True
        normals.weight = 50
        bpy.ops.object.modifier_apply(modifier=normals.name)
    projected_uv(obj, family)
    obj["visual_quality"] = "VQ2"
    obj.select_set(False)


def corrugated(bm, width, depth, ridge_z, edge_z, side, pitch=.16):
    """Thin roof with genuine sinusoidal corrugation, closed outer sheet edge."""
    n = math.ceil(width/pitch)*4
    rows = []
    for xindex in range(n+1):
        x = -width/2 + width*xindex/n
        ripple = .020*math.cos(x/pitch*math.tau)
        rows.append([bm.verts.new((x, 0, ridge_z+ripple)), bm.verts.new((x, side*depth, edge_z+ripple)),
                     bm.verts.new((x, 0, ridge_z+ripple-.025)), bm.verts.new((x, side*depth, edge_z+ripple-.025))])
    for i in range(n):
        a, b = rows[i], rows[i+1]
        for face in ((a[0],b[0],b[1],a[1]), (a[3],b[3],b[2],a[2]),
                     (a[1],b[1],b[3],a[3]), (a[2],b[2],b[0],a[0])):
            bm.faces.new(face)
    for a in (rows[0], rows[-1]):
        bm.faces.new((a[0],a[1],a[3],a[2]))


def bolt(bm, loc, direction=(0, 0, 1), radius=.022):
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                             radius1=radius, radius2=radius, depth=.018)
    q = Vector((0, 0, 1)).rotation_difference(Vector(direction))
    bmesh.ops.rotate(bm, verts=r["verts"], cent=(0, 0, 0), matrix=q.to_matrix())
    bmesh.ops.translate(bm, verts=r["verts"], vec=loc)


def export_and_save(out, name, blend_path=None):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(filepath=str(out/(name+".glb")), export_format="GLB", export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_cameras=False, export_lights=False)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path or out/(name+".blend")))
    tris = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
    print("VQ2_EXPORT", name, "triangles", tris)
