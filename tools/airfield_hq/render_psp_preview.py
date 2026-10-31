"""Render a review image of the three authored PSP library LOD meshes."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "source_assets" / "airfield_hq_v23" / "psp" / "PSP_plate_library.blend"
OUTPUT = ROOT / "assets" / "airfield_hq_v23" / "psp" / "PSP_plate_library_preview.png"


def aim(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.context.scene
    lods = [
        ("PSP_Plate_LOD0_87_perforations", "LOD 0 · 87 perforations", -3.2),
        ("PSP_Plate_LOD1_24_perforations", "LOD 1 · 24 perforations", 0.0),
        ("PSP_Plate_LOD2_silhouette", "LOD 2 · distant silhouette", 3.2),
    ]
    for name, _label, x in lods:
        obj = bpy.data.objects[name]
        obj.location = (x, 0.0, 0.025)
    floor_mat = bpy.data.materials.new("Preview neutral grey")
    floor_mat.diffuse_color = (0.11, 0.13, 0.14, 1.0)
    floor_mat.use_nodes = True
    floor_bsdf = next(n for n in floor_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    floor_bsdf.inputs["Base Color"].default_value = (0.11, 0.13, 0.14, 1.0)
    floor_bsdf.inputs["Roughness"].default_value = 0.94
    label_mat = bpy.data.materials.new("Preview label ivory")
    label_mat.diffuse_color = (0.82, 0.80, 0.68, 1.0)
    label_mat.use_nodes = True
    label_bsdf = next(n for n in label_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    label_bsdf.inputs["Base Color"].default_value = (0.82, 0.80, 0.68, 1.0)
    label_bsdf.inputs["Roughness"].default_value = 0.82
    bpy.ops.mesh.primitive_plane_add(size=13.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "Temporary preview floor"
    floor.data.materials.append(floor_mat)
    for _name, label, x in lods:
        bpy.ops.object.text_add(location=(x - 1.15, -0.6, 0.009))
        text_obj = bpy.context.object
        text_obj.name = "Temporary preview label " + label
        text_obj.data.body = label
        text_obj.data.size = 0.19
        text_obj.data.extrude = 0.0008
        text_obj.data.materials.append(label_mat)
    bpy.ops.object.camera_add(location=(1.3, -6.2, 7.8))
    camera = bpy.context.object
    camera.name = "Temporary PSP preview camera"
    aim(camera, Vector((0.0, 0.0, 0.0)))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 10.3
    scene.camera = camera
    for name, location, energy, size in [
        ("Preview key", (-3.0, -2.0, 6.0), 1100.0, 4.0),
        ("Preview fill", (3.5, 1.0, 4.5), 650.0, 3.0),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        aim(light, Vector((0.0, 0.0, 0.0)))
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 20
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 820
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.world.color = (0.06, 0.07, 0.08)
    scene.render.filepath = str(OUTPUT)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {OUTPUT}")


if __name__ == "__main__":
    main()
