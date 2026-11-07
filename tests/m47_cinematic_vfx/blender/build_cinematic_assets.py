"""Batch-build original concrete breach, animated debris and volume flipbooks.

Run from the repository root with Blender 4.3+ in background mode. The approved
M-47 model is deliberately not loaded or modified by this authoring script.
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parents[1]
BLENDER_OUT = OUT / "blender"
TEXTURES = ROOT / "assets/textures/vq2/concrete"
random.seed(47)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def image_node(nodes, path, x, y):
    node = nodes.new("ShaderNodeTexImage")
    node.image = bpy.data.images.load(str(path), check_existing=True)
    node.location = (x, y)
    return node


mat = bpy.data.materials.new("Concrete_PBR_OriginalTextures")
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links
bsdf = nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.9
albedo = image_node(nodes, TEXTURES / "albedo.jpg", -650, 300)
normal = image_node(nodes, TEXTURES / "normal.jpg", -650, -20)
normal.image.colorspace_settings.name = "Non-Color"
orm = image_node(nodes, TEXTURES / "orm.png", -650, -300)
orm.image.colorspace_settings.name = "Non-Color"
normal_map = nodes.new("ShaderNodeNormalMap")
normal_map.inputs["Strength"].default_value = 0.72
sep = nodes.new("ShaderNodeSeparateColor")
links.new(albedo.outputs["Color"], bsdf.inputs["Base Color"])
links.new(normal.outputs["Color"], normal_map.inputs["Color"])
links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
links.new(orm.outputs["Color"], sep.inputs["Color"])
links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])


def uv_project(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.012)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def cube(name, scale, loc=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Chipped concrete edges", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 3
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)
    uv_project(obj)
    return obj


intact = cube("Wall_Intact", (0.58, 3.75, 2.75))

# Annular wall: four thick quadrants joined around an irregular 24-point hole.
# Its front/back faces and rough inner rim give the passage actual depth.
count = 24
verts = []
for x in (-0.29, 0.29):
    for ring in (0, 1):
        for i in range(count):
            angle = 2 * math.pi * i / count
            c, s = math.cos(angle), math.sin(angle)
            if ring == 0:
                border = min(1.875 / max(abs(c), 0.0001), 1.375 / max(abs(s), 0.0001))
                y, z = border * c, border * s
            else:
                radius = 0.88 + 0.11 * math.sin(5 * angle + 0.4) + 0.07 * math.sin(11 * angle)
                y, z = radius * c, radius * s * 0.94
            if ring == 1 and x > 0:
                y += 0.035 * math.sin(7 * angle)
            verts.append((x, y, z))
faces = []
for i in range(count):
    j = (i + 1) % count
    faces += [
        (i, j, count + j, count + i),
        (2 * count + j, 2 * count + i, 3 * count + i, 3 * count + j),
        (count + i, count + j, 3 * count + j, 3 * count + i),
        (i, 2 * count + i, 2 * count + j, j),
    ]
mesh = bpy.data.meshes.new("Irregular_Breach_Mesh")
mesh.from_pydata(verts, [], faces)
mesh.update()
breach = bpy.data.objects.new("Wall_Permanent_Breach", mesh)
bpy.context.collection.objects.link(breach)
breach.data.materials.append(mat)
uv_project(breach)

# Thin raised crack geometry follows the damaged front face of the ring.
# It remains a child of the breached wall, so the intact wall stays clean.
crack_mat = bpy.data.materials.new("Concrete_Hairline_Fractures")
crack_mat.diffuse_color = (0.035, 0.039, 0.037, 1.0)
crack_mat.use_nodes = True
crack_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = crack_mat.diffuse_color
crack_mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 1.0
crack_segments = []
for k in range(19):
    angle = 2 * math.pi * k / 19 + random.uniform(-0.09, 0.09)
    last = Vector((-0.314, math.cos(angle) * 0.98, math.sin(angle) * 0.92))
    for part in range(3):
        radius = 1.08 + part * 0.17 + random.uniform(0.01, 0.08)
        end_angle = angle + random.uniform(-0.10, 0.10)
        next_point = Vector((-0.314, math.cos(end_angle) * radius, math.sin(end_angle) * radius * 0.91))
        vector = next_point - last
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.009 - part * 0.001, depth=vector.length,
                                             location=(last + next_point) * 0.5)
        segment = bpy.context.object
        segment.rotation_euler = vector.to_track_quat("Z", "Y").to_euler()
        segment.data.materials.append(crack_mat)
        crack_segments.append(segment)
        last = next_point
if crack_segments:
    bpy.ops.object.select_all(action="DESELECT")
    for segment in crack_segments:
        segment.select_set(True)
    bpy.context.view_layer.objects.active = crack_segments[0]
    bpy.ops.object.join()
    crack_network = bpy.context.object
    crack_network.name = "Fracture_Crack_Network"
    crack_network.parent = breach
    crack_network.matrix_parent_inverse = breach.matrix_world.inverted()


def rock(i):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1)
    obj = bpy.context.object
    obj.name = "Concrete_Fragment_%02d" % i
    for vertex in obj.data.vertices:
        vertex.co *= random.uniform(0.72, 1.24)
    obj.scale = (random.uniform(0.1, 0.32), random.uniform(0.13, 0.38), random.uniform(0.09, 0.3))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Fractured edge glints", "BEVEL")
    bevel.width = 0.018
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)
    uv_project(obj)
    return obj


fragments = []
for i in range(42):
    obj = rock(i)
    angle = random.uniform(0, 2 * math.pi)
    radial = random.uniform(0.04, 0.65)
    start = Vector((random.uniform(-0.2, 0.18), math.cos(angle) * radial, math.sin(angle) * radial))
    dest = Vector((random.uniform(-1.7, 1.3), math.cos(angle) * random.uniform(0.8, 2.6), -1.2 + random.uniform(0, 0.44)))
    obj.location = start
    obj.keyframe_insert(data_path="location", frame=1)
    obj.keyframe_insert(data_path="rotation_euler", frame=1)
    obj.location = start.lerp(dest, 0.46) + Vector((0, 0, random.uniform(0.25, 0.9)))
    obj.rotation_euler = (random.random() * 2, random.random() * 2, random.random() * 2)
    obj.keyframe_insert(data_path="location", frame=18)
    obj.keyframe_insert(data_path="rotation_euler", frame=18)
    obj.location = dest
    obj.rotation_euler = (random.random() * 5, random.random() * 5, random.random() * 5)
    obj.keyframe_insert(data_path="location", frame=52)
    obj.keyframe_insert(data_path="rotation_euler", frame=52)
    if obj.animation_data and obj.animation_data.action:
        obj.animation_data.action.name = "Breach_Fragment_%02d" % i
        action = obj.animation_data.action
        track = obj.animation_data.nla_tracks.new()
        track.name = "Breach"
        track.strips.new("Breach", 1, action)
        obj.animation_data.action = None
    fragments.append(obj)

bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(BLENDER_OUT / "M47_Cinematic_Breach_4_0.blend"))
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "cinematic_concrete_breach.glb"),
    export_format="GLB", export_animations=True, export_yup=True,
    export_image_format="AUTO", export_apply=True,
)
print("WALL_TRIANGLES", len(intact.data.polygons) * 2, len(breach.data.polygons) * 2)
print("FRAGMENTS", len(fragments), "TRIANGLES", sum(len(o.data.polygons) * 2 for o in fragments))
if "--wall-only" in sys.argv:
    print("WALL_ONLY_EXPORT_COMPLETE")
    raise SystemExit(0)

# Real Cycles volume renders, saved as alpha PNG frames for flipbook atlases.
for obj in list(bpy.context.scene.objects):
    obj.hide_render = True
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1)
volume_obj = bpy.context.object
volume_obj.name = "Cycles_Smoke_Density_Volume"
volume_obj.scale = (2.6, 2.0, 2.2)
volume_mat = bpy.data.materials.new("Animated_Procedural_Volume")
volume_mat.use_nodes = True
vn = volume_mat.node_tree.nodes
vn.clear()
vo = vn.new("ShaderNodeOutputMaterial")
vp = vn.new("ShaderNodeVolumePrincipled")
vp.inputs["Anisotropy"].default_value = 0.25
noise = vn.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value = 4.5
noise.inputs["Detail"].default_value = 5.0
tex = vn.new("ShaderNodeTexCoord")
mapping = vn.new("ShaderNodeVectorMath")
mapping.operation = "ADD"
mult = vn.new("ShaderNodeMath")
mult.operation = "MULTIPLY"
mult.inputs[1].default_value = 1.6
threshold = vn.new("ShaderNodeMath")
threshold.operation = "SUBTRACT"
threshold.inputs[1].default_value = 0.42
volume_mat.node_tree.links.new(tex.outputs["Generated"], mapping.inputs[0])
volume_mat.node_tree.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
volume_mat.node_tree.links.new(noise.outputs["Fac"], threshold.inputs[0])
volume_mat.node_tree.links.new(threshold.outputs["Value"], mult.inputs[0])
volume_mat.node_tree.links.new(mult.outputs["Value"], vp.inputs["Density"])
volume_mat.node_tree.links.new(vp.outputs["Volume"], vo.inputs["Volume"])
volume_obj.data.materials.append(volume_mat)

camera_data = bpy.data.cameras.new("Flipbook_Orthographic")
camera = bpy.data.objects.new("Flipbook_Orthographic", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (0, -5.5, 0)
camera.rotation_euler = (math.pi / 2, 0, 0)
camera_data.type = "ORTHO"
camera_data.ortho_scale = 3.8
bpy.context.scene.camera = camera
light_data = bpy.data.lights.new("Blue_Impact_Rim", "AREA")
light = bpy.data.objects.new("Blue_Impact_Rim", light_data)
bpy.context.collection.objects.link(light)
light.location = (1.2, -1.4, 1.2)
light_data.energy = 900
light_data.color = (0.36, 0.77, 1.0)
light_data.shape = "DISK"
light_data.size = 3.0
bpy.context.scene.render.engine = "CYCLES"
bpy.context.scene.cycles.samples = 16
bpy.context.scene.cycles.use_denoising = False
bpy.context.view_layer.cycles.use_denoising = False
bpy.context.scene.render.resolution_x = 192
bpy.context.scene.render.resolution_y = 192
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.film_transparent = True
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.image_settings.color_mode = "RGBA"
bpy.context.scene.world.color = (0, 0, 0)

# Save the complete editable source, including the Cycles volume material,
# animation-ready breach/debris, orthographic render setup and blue rim light.
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(BLENDER_OUT / "M47_Cinematic_Breach_4_0.blend"))

for kind in ("smoke", "dust"):
    folder = OUT / "flipbooks" / kind
    folder.mkdir(parents=True, exist_ok=True)
    if kind == "smoke":
        vp.inputs["Color"].default_value = (0.19, 0.35, 0.49, 1.0)
        mult.inputs[1].default_value = 1.6
        light_data.color = (0.24, 0.65, 1.0)
    else:
        vp.inputs["Color"].default_value = (0.49, 0.40, 0.30, 1.0)
        mult.inputs[1].default_value = 2.1
        light_data.color = (1.0, 0.62, 0.35)
    for frame in range(16):
        mapping.inputs[1].default_value = (0.12 * frame, -0.035 * frame, 0.075 * frame)
        volume_obj.rotation_euler.z = 0.09 * frame
        volume_obj.scale = (2.2 + frame * 0.058, 2.0, 1.75 + frame * 0.038)
        bpy.context.scene.render.filepath = str(folder / ("%02d.png" % frame))
        bpy.ops.render.render(write_still=True)
        print("FLIPBOOK_FRAME", kind, frame)
