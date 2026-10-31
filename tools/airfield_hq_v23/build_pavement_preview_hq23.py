"""Build the centered, small USDZ-review source for the production pavement module sizes.

The field itself remains generated and placed by Godot. This isolated source is
only a Quick Look library preview of one runway, taxi, apron, and PSP module.
"""

import bpy
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "source_assets/airfield_hq_v23/pavement/Airfield_Pavement_Modules_HQ23.blend"
ALBEDO = ROOT / "assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0_concrete_floor_01_diff_2k.jpg"
NORMAL = ROOT / "assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD0_concrete_floor_01_nor_gl_2k.jpg"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0

concrete = bpy.data.materials.new("HQ23 concrete paving | production source maps")
concrete.diffuse_color = (0.48, 0.47, 0.43, 1.0)
concrete.use_nodes = True
nodes = concrete.node_tree.nodes
links = concrete.node_tree.links
bsdf = nodes.get("Principled BSDF")
albedo = bpy.data.images.load(str(ALBEDO), check_existing=True)
albedo.colorspace_settings.name = "sRGB"
albedo_node = nodes.new("ShaderNodeTexImage")
albedo_node.image = albedo
links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])
normal = bpy.data.images.load(str(NORMAL), check_existing=True)
normal.colorspace_settings.name = "Non-Color"
normal_node = nodes.new("ShaderNodeTexImage")
normal_node.image = normal
normal_map = nodes.new("ShaderNodeNormalMap")
links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
bsdf.inputs["Roughness"].default_value = 0.88

def box(name, dimensions, center, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(center[0], center[1], dimensions[2] / 2.0))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    obj["preview_dimensions_m"] = list(dimensions)
    return obj

# Review library: the complete new 75 m sample runway plus isolated taxi/apron
# modules to the side. It is deliberately not a full-airfield overview.
for index in range(5):
    box("Runway slab module %02d | 15 × 18 × 0.22 m" % (index + 1), (18.0, 15.0, 0.22), (-30.0, -30.0 + index * 15.0), concrete)
for index in range(1, 5):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-30.0, -37.5 + index * 15.0, 0.217))
    joint = bpy.context.object
    joint.name = "Runway recessed expansion joint %02d" % index
    joint.dimensions = (18.0, 0.035, 0.006)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    joint_material = bpy.data.materials.new(joint.name + " | technical concrete joint")
    joint_material.diffuse_color = (0.13, 0.13, 0.12, 1.0)
    joint.data.materials.append(joint_material)
box("Taxiway slab module | 18.4 × 8 × 0.22 m", (18.4, 8.0, 0.22), (0.0, 20.0), concrete)
box("Apron slab module | 18 × 14 × 0.22 m", (18.0, 14.0, 0.22), (30.0, -15.0), concrete)

# A scaled PSP sample is included beside the apron module as an isolated library
# item; it does not extend or alter the in-game ground layout.
psp_path = ROOT / "assets/airfield_hq_v23/psp/PSP_plate_library.glb"
bpy.ops.import_scene.gltf(filepath=str(psp_path))
psp_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("PSP_Plate_LOD0_")]
if psp_meshes:
    source = psp_meshes[0]
    source.name = "PSP plate sample | LOD0"
    source.location = (30.0, -20.25, 0.225)
    source.rotation_euler = (0.0, 0.0, 0.0)
    source.scale = (1.0, 1.0, 1.0)
    for index in range(1, 8):
        duplicate = source.copy()
        duplicate.data = source.data
        duplicate.name = "PSP plate sample %02d | LOD0" % (index + 1)
        duplicate.location.x += (index - 3.5) * 0.381
        scene.collection.objects.link(duplicate)
for obj in list(scene.objects):
    if obj.name.startswith("PSP_Plate_LOD1_") or obj.name.startswith("PSP_Plate_LOD2_"):
        bpy.data.objects.remove(obj, do_unlink=True)

# Recenter the actual visible model bounds, rather than the object origins.
depsgraph = bpy.context.evaluated_depsgraph_get()
visible = [obj for obj in scene.objects if obj.type == "MESH" and obj.visible_get()]
points = [obj.matrix_world @ Vector(corner) for obj in visible for corner in obj.bound_box]
minimum = [min(p[i] for p in points) for i in range(3)]
maximum = [max(p[i] for p in points) for i in range(3)]
center = tuple((minimum[i] + maximum[i]) * 0.5 for i in range(3))
for obj in scene.objects:
    obj.location.x -= center[0]
    obj.location.y -= center[1]
    obj.location.z -= center[2]
scene["preview_bounds_m"] = [maximum[i] - minimum[i] for i in range(3)]
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 20
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(ROOT / "assets/airfield_hq_v23/tower/Pavement_Modules_HQ23_blender.png")
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.view_settings.view_transform = "AgX"
scene.world = bpy.data.worlds.new("Pavement module preview world")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.34, 0.39, 0.45, 1.0)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42

camera_data = bpy.data.cameras.new("Pavement module preview camera")
camera = bpy.data.objects.new("Pavement module preview camera", camera_data)
scene.collection.objects.link(camera)
camera.location = (0.0, -86.0, 68.0)
direction = Vector((0.0, 0.0, 0.0)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 92.0
scene.camera = camera

key_data = bpy.data.lights.new("Large soft key", type="AREA")
key_data.energy = 55000
key_data.shape = "DISK"
key_data.size = 36.0
key = bpy.data.objects.new("Large soft key", key_data)
scene.collection.objects.link(key)
key.location = (-22.0, -26.0, 54.0)
key.rotation_euler = (Vector((0.0, 0.0, 0.0)) - key.location).to_track_quat("-Z", "Y").to_euler()

fill_data = bpy.data.lights.new("Soft fill", type="AREA")
fill_data.energy = 28000
fill_data.size = 28.0
fill = bpy.data.objects.new("Soft fill", fill_data)
scene.collection.objects.link(fill)
fill.location = (34.0, 16.0, 40.0)
fill.rotation_euler = (Vector((0.0, 0.0, 0.0)) - fill.location).to_track_quat("-Z", "Y").to_euler()
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
print("HQ23_PAVEMENT_PREVIEW_BOUNDS_M", scene["preview_bounds_m"])
bpy.ops.render.render(write_still=True)
