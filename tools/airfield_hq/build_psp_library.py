"""Build the reusable WWII PSP plate asset library for Airfield HQ 2.3.

Reference dimensions: U.S. Army Center of Military History, "The U.S. Army GHQ
Maneuvers of 1941" (10 ft × 15 in, 87 pierced holes, 66.2 lb):
https://history.army.mil/portals/143/Images/Publications/catalog/70-41-1.pdf

The 0.14 in sheet thickness and the hole pattern's exact proportions are visual
approximations; the source supports the nominal length, width, hole count, and
weight. Run with Blender 4.5.15 in background mode.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "airfield_hq_v23" / "psp"
BLEND = ROOT / "source_assets" / "airfield_hq_v23" / "psp" / "PSP_plate_library.blend"
GLB = OUT / "PSP_plate_library.glb"
LENGTH = 3.048
WIDTH = 0.381
THICKNESS = 0.00356
HOLE_ROWS = 3
HOLE_COLUMNS = 29
HOLE_COUNT = HOLE_ROWS * HOLE_COLUMNS
HOLE_RADIUS = 0.022


def steel_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("PSP steel | phosphate grey")
    mat.diffuse_color = (0.20, 0.23, 0.22, 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (0.18, 0.21, 0.20, 1.0)
    principled.inputs["Metallic"].default_value = 0.68
    principled.inputs["Roughness"].default_value = 0.76
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 175.0
    noise.inputs["Detail"].default_value = 2.0
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.2
    ramp.color_ramp.elements[0].color = (0.145, 0.17, 0.16, 1.0)
    ramp.color_ramp.elements[1].position = 0.8
    ramp.color_ramp.elements[1].color = (0.205, 0.23, 0.22, 1.0)
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.11
    bump.inputs["Distance"].default_value = 0.0012
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], principled.inputs["Base Color"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], principled.inputs["Normal"])
    return mat


def ray_to_rect(cx: float, cy: float, angle: float, hx: float, hy: float) -> tuple[float, float]:
    dx, dy = math.cos(angle), math.sin(angle)
    tx = hx / abs(dx) if abs(dx) > 1e-8 else float("inf")
    ty = hy / abs(dy) if abs(dy) > 1e-8 else float("inf")
    distance = min(tx, ty)
    return cx + dx * distance, cy + dy * distance


def plate_geometry(name: str, rows: int, cols: int, raised_detail: bool) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    segments = 12
    pitch_x = WIDTH / rows
    pitch_y = LENGTH / cols
    radius = min(HOLE_RADIUS, pitch_x * 0.22, pitch_y * 0.22)
    z_top = THICKNESS

    def quad(points: tuple[tuple[float, float, float], ...]) -> None:
        start = len(vertices)
        vertices.extend(points)
        faces.append((start, start + 1, start + 2, start + 3))

    # Tile each cell with a ring of top faces around one real open perforation.
    # Adjacent cell borders share the same coordinates so no unintentional gaps
    # appear between holes.
    for row in range(rows):
        cx = -WIDTH * 0.5 + (row + 0.5) * pitch_x
        for col in range(cols):
            cy = -LENGTH * 0.5 + (col + 0.5) * pitch_y
            hx, hy = pitch_x * 0.5, pitch_y * 0.5
            for k in range(segments):
                a0 = math.tau * k / segments
                a1 = math.tau * (k + 1) / segments
                inner0 = (cx + radius * math.cos(a0), cy + radius * math.sin(a0))
                inner1 = (cx + radius * math.cos(a1), cy + radius * math.sin(a1))
                outer0 = ray_to_rect(cx, cy, a0, hx, hy)
                outer1 = ray_to_rect(cx, cy, a1, hx, hy)
                quad(((outer0[0], outer0[1], z_top), (outer1[0], outer1[1], z_top),
                      (inner1[0], inner1[1], z_top), (inner0[0], inner0[1], z_top)))
                # Inner perforation wall, open through the sheet thickness.
                quad(((inner0[0], inner0[1], z_top), (inner1[0], inner1[1], z_top),
                      (inner1[0], inner1[1], 0.0), (inner0[0], inner0[1], 0.0)))

    # Sheet edge thickness (the field-side underside is omitted to keep the
    # repeated plate mesh light; the runway/apron collision remains underneath).
    for x in (-WIDTH * 0.5, WIDTH * 0.5):
        quad(((x, -LENGTH * 0.5, 0.0), (x, LENGTH * 0.5, 0.0),
              (x, LENGTH * 0.5, z_top), (x, -LENGTH * 0.5, z_top)))
    for y in (-LENGTH * 0.5, LENGTH * 0.5):
        quad(((-WIDTH * 0.5, y, 0.0), (WIDTH * 0.5, y, 0.0),
              (WIDTH * 0.5, y, z_top), (-WIDTH * 0.5, y, z_top)))

    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    if raised_detail:
        detail_parts = [obj]
        # Shallow transverse press ribs in the inter-row land, plus end lips and
        # small coupling lugs. These are geometry, not painted markings.
        for index in range(1, cols, 4):
            y = -LENGTH * 0.5 + index * pitch_y
            bpy.ops.mesh.primitive_cube_add(size=1, location=(0.0, y, z_top + 0.0022))
            rib = bpy.context.object
            rib.name = name + " pressed cross rib"
            rib.dimensions = (WIDTH - 0.018, 0.010, 0.0044)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            detail_parts.append(rib)
        for x in (-WIDTH * 0.5 + 0.006, WIDTH * 0.5 - 0.006):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0.0, z_top + 0.003))
            rail = bpy.context.object
            rail.name = name + " folded edge rail"
            rail.dimensions = (0.012, LENGTH - 0.04, 0.006)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            detail_parts.append(rail)
        for y in (-LENGTH * 0.5 - 0.009, LENGTH * 0.5 + 0.009):
            for x in (-WIDTH * 0.5 + 0.03, WIDTH * 0.5 - 0.03):
                bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z_top + 0.002))
                lug = bpy.context.object
                lug.name = name + " interlocking end lug"
                lug.dimensions = (0.04, 0.022, 0.004)
                bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
                detail_parts.append(lug)
        bpy.ops.object.select_all(action="DESELECT")
        for part in detail_parts:
            part.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.join()
    return obj


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.collections):
        # Keep Blender's required Scene Collection.
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)

    mat = steel_material()
    root = bpy.context.scene.collection
    lod_collection = bpy.data.collections.new("PSP Plate Library | 10 ft × 15 in")
    root.children.link(lod_collection)
    variants = [
        plate_geometry("PSP_Plate_LOD0_87_perforations", 3, 29, True),
        plate_geometry("PSP_Plate_LOD1_24_perforations", 3, 8, False),
    ]
    # Lightweight far LOD: a steel sheet with rolled edge geometry, no holes.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.0, 0.0, THICKNESS * 0.5))
    far = bpy.context.object
    far.name = "PSP_Plate_LOD2_silhouette"
    far.dimensions = (WIDTH, LENGTH, THICKNESS)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    far.data.name = "PSP_Plate_LOD2_silhouette_mesh"
    variants.append(far)
    for obj in variants:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        lod_collection.objects.link(obj)
        obj.location = (0.0, 0.0, 0.0)
    variants[0]["nominal_length_m"] = LENGTH
    variants[0]["nominal_width_m"] = WIDTH
    variants[0]["nominal_perforations"] = HOLE_COUNT
    variants[0]["source_visual_thickness_m"] = THICKNESS

    # Keep LOD objects separate in the source library; Godot chooses the proper
    # mesh by camera range. The full GLB remains a tiny three-mesh library.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in variants:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = variants[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_materials="EXPORT")
    print(f"Created {BLEND} and {GLB}; LOD0 has {HOLE_COUNT} open perforations.")


if __name__ == "__main__":
    main()
