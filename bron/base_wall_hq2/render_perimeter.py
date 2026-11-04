#!/usr/bin/env python3
"""Render review views of the production wall mesh at the live base coordinates.

The views use the shipped GLB, the game's 60 segment centers, and the existing
gate/watchtower GLBs. The camera and ground are a Blender preview composition,
not a capture from a running iPhone build.
"""
import bpy
import bmesh
import math
import os
from mathutils import Matrix, Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/base_wall_hq2/screenshots"
WALL_GLB = ROOT / "assets/base_wall_hq2.glb"


def material(name, color, roughness=0.9, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Metallic"].default_value = metallic
    return m


def box(name, size, location, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("worn_edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
    return obj


def group_import(path, name, location, rotation=0.0):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = list(set(bpy.context.scene.objects) - before)
    group = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(group)
    group.location = location
    group.rotation_euler[2] = rotation
    for obj in imported:
        world = obj.matrix_world.copy()
        obj.parent = group
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = world
    return group


def add_wall_instances():
    bpy.ops.import_scene.gltf(filepath=str(WALL_GLB))
    lods = {obj.name: obj for obj in bpy.context.scene.objects if obj.type == "MESH" and "Wall_LOD" in obj.name}
    proto = lods["Wall_LOD0"]
    for name, obj in lods.items():
        if name != "Wall_LOD0":
            bpy.data.objects.remove(obj, do_unlink=True)
    proto.name = "Meshy_wall_LOD0_shared"
    # Same center and yaw math as BaseProps._wall(): 7 modules on both halves
    # of north/south (clear 7 m portals), and 16 on east/west.
    module = 3.5
    for side, y, angle in (("north", -28.0, 0.0), ("south", 28.0, math.pi)):
        for start in (-28.0, 3.5):
            for index in range(7):
                x = start + module * (index + 0.5)
                obj = proto if side == "north" and start == -28 and index == 0 else proto.copy()
                if obj is not proto:
                    obj.data = proto.data
                    bpy.context.scene.collection.objects.link(obj)
                obj.name = f"wall_{side}_{start}_{index}"
                obj.location = (x, y, 0)
                obj.rotation_mode = "XYZ"
                obj.rotation_euler[2] = angle
    for side, x, angle in (("west", -28.0, -math.pi / 2), ("east", 28.0, math.pi / 2)):
        for index in range(16):
            y = -28.0 + module * (index + 0.5)
            obj = proto.copy()
            obj.data = proto.data
            bpy.context.scene.collection.objects.link(obj)
            obj.name = f"wall_{side}_{index}"
            obj.location = (x, y, 0)
            obj.rotation_mode = "XYZ"
            obj.rotation_euler[2] = angle


def add_wall_berm():
    earth = material("Low-profile earth berm", (0.10, 0.085, 0.055), 0.98)
    verts = [
        (-0.5, -0.41, 0), (0.5, -0.41, 0), (0.5, 0.41, 0), (-0.5, 0.41, 0),
        (-0.5, -0.23, 0.22), (-0.5, 0.23, 0.22), (0.5, 0.23, 0.22), (0.5, -0.23, 0.22),
    ]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (3, 2, 6, 5), (1, 0, 4, 7), (2, 1, 7, 6), (0, 3, 5, 4)]
    runs = []
    for y in (-28.0, 28.0):
        for start in (-28.0, 3.5):
            end = start + 24.5
            runs.append(((start, y), (end, y), -0.42 if y < 0 else 0.42, 0.0,
                         0.41 if start == -28.0 else 0.0, 0.41 if end == 28.0 else 0.0))
    for x in (-28.0, 28.0):
        runs.append(((x, -28.0), (x, 28.0), -0.42 if x < 0 else 0.42,
                     -math.pi / 2 if x < 0 else math.pi / 2, 0.41, 0.41))
    for index, ((ax, ay), (bx, by), outward, yaw, extend_start, extend_end) in enumerate(runs):
        original_length = math.hypot(bx - ax, by - ay)
        direction = ((bx - ax) / original_length, (by - ay) / original_length)
        length = original_length + extend_start + extend_end
        cx, cy = (ax + bx) * 0.5, (ay + by) * 0.5
        cx += direction[0] * (extend_end - extend_start) * 0.5
        cy += direction[1] * (extend_end - extend_start) * 0.5
        if yaw == 0.0:
            cy += outward
        else:
            cx += outward
        mesh = bpy.data.meshes.new(f"Earth_berm_{index}_mesh")
        mesh.from_pydata(verts, [], faces)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(earth)
        obj = bpy.data.objects.new(f"Earth_berm_{index}", mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = (cx, cy, 0.0)
        obj.scale.x = length
        obj.rotation_mode = "XYZ"
        obj.rotation_euler[2] = yaw
    corner_base = 0.41
    corner_top = 0.23
    corner_height = 0.22
    corner_verts = [
        (-corner_base, -corner_base, 0), (corner_base, -corner_base, 0),
        (corner_base, corner_base, 0), (-corner_base, corner_base, 0),
        (-corner_top, -corner_top, corner_height), (corner_top, -corner_top, corner_height),
        (corner_top, corner_top, corner_height), (-corner_top, corner_top, corner_height),
    ]
    corner_faces = [(0, 3, 2, 1), (4, 5, 6, 7), (3, 2, 6, 7),
                    (1, 0, 4, 5), (2, 1, 5, 6), (0, 3, 7, 4)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            mesh = bpy.data.meshes.new("Earth_corner_berm_mesh")
            mesh.from_pydata(corner_verts, [], corner_faces)
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(mesh)
            bm.free()
            mesh.materials.append(earth)
            obj = bpy.data.objects.new("Earth_corner_berm", mesh)
            bpy.context.scene.collection.objects.link(obj)
            obj.location = (sx * 28.42, sy * 28.42, 0.0)


def add_gate_and_towers():
    concrete = material("Gate concrete posts", (0.28, 0.29, 0.25))
    olive = material("Olive drab gate steel", (0.22, 0.24, 0.15), 0.58, 0.38)
    yellow = material("Gate safety ochre", (0.56, 0.39, 0.1), 0.66, 0.12)
    dark = material("Gate safety black", (0.055, 0.06, 0.05), 0.72, 0.1)
    for side, y, rotation in (("north", -28.0, 0.0), ("south", 28.0, math.pi)):
        group_import(ROOT / "assets/poort.glb", f"Existing_{side}_sliding_gate", (0, y, 0), rotation)
        for x in (-3.7, 3.7):
            box(f"{side}_gate_post", (0.7, 0.7, 3.0), (x, y, 1.5), concrete, 0.04)
        box(f"{side}_gate_header", (8.0, 0.4, 0.18), (0, y, 3.08), olive, 0.025)
        for i in range(10):
            x = -3.4 + i * (6.8 / 9.0)
            box(f"{side}_header_mark_{i}", (0.22, 0.44, 0.16), (x, y, 2.92), yellow if i % 2 == 0 else dark, 0.01)
        # The runtime upper leaf is parented to the old moving panel and fills
        # from its measured 1.22 m top to the new 3 m parapet height.
        box(f"{side}_upper_gate_leaf", (6.8, 0.12, 1.78), (0, y - 0.63, 2.11), olive, 0.018)
    for sx in (-1, 1):
        for sy in (-1, 1):
            rotation = 0.0 if sx < 0 else math.pi
            group_import(ROOT / "assets/wachttoren.glb", f"Existing_watchtower_{sx}_{sy}", (sx * 26.2, sy * 26.2, 0), rotation)


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    add_wall_instances()
    add_wall_berm()
    add_gate_and_towers()
    soil = material("Subtle wet field earth", (0.27, 0.30, 0.22), 0.98)
    nodes = soil.node_tree.nodes
    links = soil.node_tree.links
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7.0
    noise.inputs["Detail"].default_value = 3.0
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.18
    ramp.color_ramp.elements[0].color = (0.17, 0.19, 0.13, 1)
    ramp.color_ramp.elements[1].position = 0.82
    ramp.color_ramp.elements[1].color = (0.42, 0.43, 0.32, 1)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], nodes.get("Principled BSDF").inputs["Base Color"])
    box("field_ground", (180, 180, 0.2), (0, 0, -0.1), soil)
    road = material("Compacted dirt track", (0.28, 0.255, 0.18), 0.98)
    box("north_supply_road", (5.5, 28, 0.035), (0, -14, 0.018), road)
    box("south_supply_road", (5.5, 28, 0.035), (0, 14, 0.018), road)
    bunker = material("HQ bunker concrete", (0.32, 0.34, 0.30), 0.88)
    box("HQ_Bunker_footprint", (4.6, 4.6, 2.0), (0, 0, 1.0), bunker, 0.08)
    world = bpy.data.worlds.new("Field overcast")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.38, 0.42, 0.46, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world
    sun = bpy.data.lights.new("Soft daylight", "SUN")
    sun.energy = 0.8
    sun.angle = math.radians(18.0)
    sun_obj = bpy.data.objects.new("Soft daylight", sun)
    bpy.context.scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(24.0), math.radians(-18.0), math.radians(-26.0))
    key = bpy.data.lights.new("Overcast key", "AREA")
    key.energy = 100000
    key.shape = "DISK"
    key.size = 38
    lamp = bpy.data.objects.new("Overcast key", key)
    bpy.context.scene.collection.objects.link(lamp)
    lamp.location = (-35, -45, 72)
    fill = bpy.data.lights.new("Soft fill", "AREA")
    fill.energy = 50000
    fill.size = 48
    fill_obj = bpy.data.objects.new("Soft fill", fill)
    bpy.context.scene.collection.objects.link(fill_obj)
    fill_obj.location = (48, 28, 56)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 12
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 93
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.25
    scene.camera = bpy.data.objects.new("Review camera", bpy.data.cameras.new("Review camera"))
    scene.collection.objects.link(scene.camera)
    scene.camera.data.type = "ORTHO"
    return scene


def render_view(scene, filename, camera_location, target, scale):
    cam = scene.camera
    cam.location = camera_location
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = scale
    scene.render.filepath = str(OUT / filename)
    bpy.ops.render.render(write_still=True)


def main():
    scene = setup_scene()
    views = {
        "01_perimeter_top.jpg": ((0, -82, 145), (0, 0, 0), 86),
        "02_perimeter_three_quarter.jpg": ((77, -92, 74), (0, 0, 1), 82),
        "03_corner_connection.jpg": ((-39, -40, 19), (-27.5, -27.5, 1.7), 18),
        "04_north_gate.jpg": ((4, -43, 8.2), (0, -28, 1.5), 19),
        "05_south_gate.jpg": ((-4, 43, 8.2), (0, 28, 1.5), 19),
    }
    selected = os.environ.get("WALL_VIEW")
    for filename, args in views.items():
        if selected and filename != selected:
            continue
        render_view(scene, filename, *args)


if __name__ == "__main__":
    main()
