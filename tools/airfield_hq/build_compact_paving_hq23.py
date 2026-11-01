"""Create high-quality, beveled compact runway/apron/taxi GLB modules.

The approved HQ23 pavement .blend is input-only. Outputs are a new editable
review .blend and Godot GLBs under assets/airfield_hq_v23/pavement/.
Run with Blender 4.5.15: blender -b <pavement-source.blend> --python this.py
"""
from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "source_assets/airfield_hq_v23/pavement/Airfield_Pavement_Modules_HQ23.blend"
REVIEW = ROOT / "source_assets/airfield_hq_v23/pavement/Airfield_HQ_23_Compact_Paving_Review.blend"
OUT = ROOT / "assets/airfield_hq_v23/pavement"
OUT.mkdir(parents=True, exist_ok=True)


def collection(name: str) -> bpy.types.Collection:
    found = bpy.data.collections.get(name)
    if found:
        return found
    found = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(found)
    return found


def move_to(obj: bpy.types.Object, target: bpy.types.Collection) -> None:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def bevel(obj: bpy.types.Object, width: float, segments: int) -> None:
    modifier = obj.modifiers.new("Manufactured slab edge bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(25.0)
    modifier.harden_normals = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    normals = obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    normals.keep_sharp = True
    normals.weight = 30
    bpy.ops.object.modifier_apply(modifier=normals.name)


def triangulate(obj: bpy.types.Object) -> None:
    modifier = obj.modifiers.new("glTF tangent-safe triangles", "TRIANGULATE")
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def setup_uvs(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.015)
    bpy.ops.object.mode_set(mode="OBJECT")


def export_one(obj: bpy.types.Object, name: str, lod: int, description: str) -> dict:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = OUT / f"{name}_LOD{lod}.glb"
    options = {
        "filepath": str(path), "export_format": "GLB", "use_selection": True,
        "export_apply": True, "export_texcoords": True, "export_normals": True,
        "export_tangents": True, "export_materials": "EXPORT",
        "export_image_format": "AUTO", "export_animations": False,
        "export_cameras": False, "export_lights": False,
    }
    allowed = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
    result = bpy.ops.export_scene.gltf(**{k: v for k, v in options.items() if k in allowed})
    if "FINISHED" not in result:
        raise RuntimeError(f"glTF export failed for {path}")
    tri = sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)
    metrics = {"asset": description, "blender": bpy.app.version_string, "lod": lod,
               "triangles": tri, "vertices": len(obj.data.vertices),
               "material_slots": len(obj.material_slots), "units": "metres",
               "glb": str(path.relative_to(ROOT)), "bytes": path.stat().st_size}
    (OUT / f"{name}_LOD{lod}_metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    return metrics


bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
concrete = bpy.data.materials.get("HQ23 concrete paving | production source maps")
if concrete is None:
    raise RuntimeError("Approved 2K HQ23 concrete PBR material was not found")

runway_source = next((o for o in bpy.data.objects if o.name.startswith("Runway slab module 01")), None)
apron_source = next((o for o in bpy.data.objects if o.name.startswith("Apron slab module")), None)
if runway_source is None or apron_source is None:
    raise RuntimeError("Approved runway/apron slab prototypes are missing")

review = collection("Compact HQ23 paving review modules")
lod0_col = collection("Compact HQ23 paving LOD0")
lod1_col = collection("Compact HQ23 paving LOD1")
lod2_col = collection("Compact HQ23 paving LOD2")

prototypes = {}
for kind, source, name, radius in [
    ("runway", runway_source, "Airfield Runway Slab 15x18", 0.08),
    ("apron", apron_source, "Airfield Apron Slab 18x14", 0.08),
]:
    source.hide_render = True
    base_mesh = source.data.copy()
    for lod, segments, width, target_col in [(0, 3, radius, lod0_col), (1, 2, 0.055, lod1_col), (2, 1, 0.04, lod2_col)]:
        mesh = base_mesh.copy()
        obj = bpy.data.objects.new(f"{name} LOD{lod}", mesh)
        target_col.objects.link(obj)
        obj.location = source.location.copy()
        obj.rotation_euler = source.rotation_euler.copy()
        obj.scale = source.scale.copy()
        if obj.data.materials:
            obj.data.materials.clear()
        obj.data.materials.append(concrete)
        bevel(obj, width, segments)
        triangulate(obj)
        setup_uvs(obj)
        prototypes[(kind, lod)] = obj


def taxi_ribbon(name: str, lod: int, target_col: bpy.types.Collection) -> bpy.types.Object:
    points = [(9.0, 17.0), (16.0, 17.0)]
    for i in range(1, 65):
        angle = math.pi * 0.5 - (math.pi * 0.5) * i / 64.0
        points.append((16.0 + 12.0 * math.cos(angle), 5.0 + 12.0 * math.sin(angle)))
    points.append((28.0, -11.0))
    vertices: list[tuple[float, float, float]] = []
    left: list[tuple[float, float]] = []
    right: list[tuple[float, float]] = []
    half = 9.0
    for i, point in enumerate(points):
        p = Vector(point)
        before = Vector(points[max(0, i - 1)])
        after = Vector(points[min(len(points) - 1, i + 1)])
        tangent = (after - before).normalized()
        normal = Vector((-tangent.y, tangent.x))
        left.append((p.x + normal.x * half, p.y + normal.y * half))
        right.append((p.x - normal.x * half, p.y - normal.y * half))
    outline = left + list(reversed(right))
    thickness = 0.22
    vertices.extend((x, y, thickness) for x, y in outline)
    vertices.extend((x, y, 0.0) for x, y in outline)
    n = len(outline)
    faces = [tuple(range(n)), tuple(range(n, 2 * n))[::-1]]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(concrete)
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target_col.objects.link(obj)
    bevel(obj, [0.08, 0.055, 0.04][lod], [3, 2, 1][lod])
    triangulate(obj)
    setup_uvs(obj)
    return obj


taxi_objects = {}
for lod, target in [(0, lod0_col), (1, lod1_col), (2, lod2_col)]:
    taxi_objects[lod] = taxi_ribbon(f"Airfield Taxiway Apron-to-Runway LOD{lod}", lod, target)

# Store source templates and one illustrative layout in the editable derivative.
for kind in ("runway", "apron"):
    prototype = prototypes[(kind, 0)]
    preview = prototype.copy()
    preview.data = prototype.data.copy()
    review.objects.link(preview)
    preview.name = f"Review preview | {kind} module"
    preview.location = Vector((-16.0 if kind == "runway" else 16.0, 0.0, 0.11))
taxi_preview = taxi_objects[0].copy()
taxi_preview.data = taxi_objects[0].data.copy()
review.objects.link(taxi_preview)
taxi_preview.name = "Review preview | curved taxiway"
for col in (lod0_col, lod1_col, lod2_col):
    col.hide_render = True

bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(REVIEW))

for lod in range(3):
    for kind, description in [("runway", "15 x 18 m beveled 3D concrete runway slab, source HQ23 2K PBR"),
                              ("apron", "18 x 14 m beveled 3D concrete apron slab, source HQ23 2K PBR")]:
        export_one(prototypes[(kind, lod)], f"Airfield_{kind.title()}_Slab_HQ23", lod, description)
    export_one(taxi_objects[lod], f"Airfield_Taxiway_HQ23_Compact", lod,
               "18 m wide continuous curved solid concrete taxi strip, connected from apron to runway")

print("COMPACT_PAVING_HQ23_EXPORT", json.dumps({"source": str(SOURCE), "review_blend": str(REVIEW),
      "runway_lod0_vertices": len(prototypes[("runway", 0)].data.vertices),
      "apron_lod0_vertices": len(prototypes[("apron", 0)].data.vertices),
      "taxi_lod0_vertices": len(taxi_objects[0].data.vertices), "taxi_curve_segments": 64,
      "runway_dimensions_m": [15.0, 18.0, 0.22], "apron_dimensions_m": [18.0, 14.0, 0.22],
      "taxi_width_m": 18.0}))
