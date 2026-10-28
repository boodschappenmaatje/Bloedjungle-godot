#!/usr/bin/env python3
"""Make one reproducible Cycles CPU showcase render from the focused player .blend."""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector


def args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args(raw)


def aim(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def render(source: Path, output: Path) -> dict:
    source = source.expanduser().resolve(strict=True)
    output = output.expanduser().resolve()
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite {output}")
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("The player blend has no visible meshes")

    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector((min(v.x for v in points), min(v.y for v in points), min(v.z for v in points)))
    high = Vector((max(v.x for v in points), max(v.y for v in points), max(v.z for v in points)))
    target = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z + (high.z - low.z) * 0.55))
    height = high.z - low.z

    ground_mat = bpy.data.materials.new("Preview ground · jungle charcoal")
    ground_mat.diffuse_color = (0.07, 0.09, 0.065, 1)
    ground_mat.use_nodes = True
    ground_bsdf = next(node for node in ground_mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    ground_bsdf.inputs["Base Color"].default_value = (0.07, 0.09, 0.065, 1)
    ground_bsdf.inputs["Roughness"].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=200, location=(target.x, target.y, low.z - 0.01))
    ground = bpy.context.object
    ground.name = "Preview_Ground"
    ground.data.materials.append(ground_mat)

    camera_data = bpy.data.cameras.new("Showcase camera")
    camera = bpy.data.objects.new("Showcase camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = target + Vector((height * 1.9, -height * 3.1, height * 1.25))
    aim(camera, target)
    camera_data.lens = 52
    scene.camera = camera

    def area(name: str, location: tuple[float, float, float], power: float, size: float, color: tuple[float, float, float]) -> None:
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = power
        light_data.shape = "DISK"
        light_data.size = size
        light_data.color = color
        light = bpy.data.objects.new(name, light_data)
        scene.collection.objects.link(light)
        light.location = target + Vector(location)
        aim(light, target)

    area("Key · neutral warm", (2.5, -3.2, 3.0), 900, 2.4, (1.0, 0.89, 0.76))
    area("Fill · cool canopy", (-2.4, -1.3, 1.5), 380, 2.8, (0.69, 0.78, 0.67))
    area("Rim · foliage edge", (0.4, 2.4, 2.1), 700, 1.8, (0.86, 0.92, 0.74))

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -0.35
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Jungle studio world")
    scene.world.use_nodes = True
    background = next(node for node in scene.world.node_tree.nodes if node.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.08, 0.09, 0.07, 1)
    background.inputs["Strength"].default_value = 0.22
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output)
    scene.frame_set(scene.frame_start + (scene.frame_end - scene.frame_start) // 2)
    output.parent.mkdir(parents=True, exist_ok=True)
    start = time.perf_counter()
    bpy.ops.render.render(write_still=True)
    elapsed = time.perf_counter() - start
    return {
        "status": "PASS",
        "source": str(source),
        "output": str(output),
        "engine": "Cycles CPU",
        "samples": scene.cycles.samples,
        "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        "render_seconds": round(elapsed, 3),
        "bounds_m": [list(low), list(high)],
        "active_animation": meshes[0].find_armature().animation_data.action.name if meshes[0].find_armature() and meshes[0].find_armature().animation_data and meshes[0].find_armature().animation_data.action else None,
    }


if __name__ == "__main__":
    print(json.dumps(render(**vars(args())), indent=2))
