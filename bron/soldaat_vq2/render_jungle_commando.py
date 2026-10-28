#!/usr/bin/env python3
"""Render consistent showcase and gameplay-angle checks for Jungle Commando."""
import argparse
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector


def args():
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True, type=Path)
    p.add_argument("--output-dir", required=True, type=Path)
    p.add_argument("--action", default="stil")
    p.add_argument("--frame", type=int)
    p.add_argument("--views", action="append", choices=("jungle_commando_3q.png", "jungle_commando_front.png", "jungle_commando_back.png", "jungle_commando_side.png", "jungle_commando_gameplay_topdown.png"))
    return p.parse_args(raw)


def aim(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def main():
    opt = args()
    if not opt.source.is_file():
        raise FileNotFoundError(opt.source)
    opt.output_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(opt.source))
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == "MESH" and not o.hide_render]
    if len(meshes) < 7:
        raise RuntimeError("Focused commando preview is missing outfit parts")
    points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    target = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, (low.z + high.z) / 2))
    height = high.z - low.z

    ground_mat = bpy.data.materials.new("Jungle showcase ground")
    ground_mat.diffuse_color = (0.045, 0.06, 0.043, 1)
    ground_mat.use_nodes = True
    bsdf = next(n for n in ground_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.045, 0.06, 0.043, 1)
    bsdf.inputs["Roughness"].default_value = 0.92
    bpy.ops.mesh.primitive_plane_add(size=40, location=(target.x, target.y, low.z - 0.015))
    plane = bpy.context.object
    plane.name = "Showcase_Ground"
    plane.data.materials.append(ground_mat)

    def area(name, offset, power, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = size
        data.color = color
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.location = target + Vector(offset)
        aim(obj, target)

    area("Key · warm daylight", (2.8, -3.6, 3.3), 950, 2.6, (1.0, 0.89, 0.75))
    area("Fill · canopy bounce", (-2.6, -1.2, 2.0), 520, 3.0, (0.72, 0.82, 0.66))
    area("Rim · humid jungle", (0.3, 2.7, 2.8), 760, 2.0, (0.78, 0.88, 0.69))
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Jungle studio")
    scene.world.use_nodes = True
    next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.07, 0.085, 0.06, 1)
    next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 0.28

    cdata = bpy.data.cameras.new("Commando showcase camera")
    camera = bpy.data.objects.new("Commando showcase camera", cdata)
    scene.collection.objects.link(camera)
    scene.camera = camera
    cdata.lens = 55
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.0
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_percentage = 100
    views = {
        "jungle_commando_3q.png": (Vector((2.2, -3.3, 1.25)), (1920, 1080), 128),
        "jungle_commando_front.png": (Vector((0.0, -4.4, 0.8)), (1280, 1600), 48),
        "jungle_commando_back.png": (Vector((0.0, 4.4, 0.85)), (1280, 1600), 48),
        "jungle_commando_side.png": (Vector((4.3, 0.0, 0.82)), (1280, 1600), 48),
        "jungle_commando_gameplay_topdown.png": (Vector((0.0, -14.8, 24.5)), (1920, 1080), 64),
    }
    report = {"status": "PASS", "source": str(opt.source), "engine": "Cycles CPU", "renders": []}
    action = bpy.data.actions.get(opt.action)
    rig = bpy.data.objects.get("Rig")
    if rig and action:
        rig.animation_data_create()
        rig.animation_data.action = action
        frame = int((action.frame_range[0] + action.frame_range[1]) / 2) if opt.frame is None else max(int(action.frame_range[0]), min(int(action.frame_range[1]), opt.frame))
        scene.frame_set(frame)
        report["action"] = action.name
        report["frame"] = frame
    elif opt.action:
        raise RuntimeError(f"Requested action {opt.action!r} is missing")
    for name in opt.views or list(views):
        offset, resolution, samples = views[name]
        output = opt.output_dir / name
        if output.exists():
            raise FileExistsError(output)
        if name == "jungle_commando_gameplay_topdown.png":
            # Match CameraRig's standard-gameplay profile: 45° FOV, 58° elevation, 28m.
            camera.data.lens = 36.0 / (2.0 * math.tan(math.radians(45.0) * 0.5))
            camera.location = target + offset
        else:
            camera.data.lens = 55
            camera.location = target + offset.normalized() * height * 3.2
        aim(camera, target)
        scene.render.resolution_x, scene.render.resolution_y = resolution
        scene.cycles.samples = samples
        scene.render.filepath = str(output)
        start = time.perf_counter()
        bpy.ops.render.render(write_still=True)
        report["renders"].append({"file": str(output), "resolution": list(resolution), "samples": samples, "seconds": round(time.perf_counter() - start, 3)})
        print(f"RENDERED {output} ({resolution[0]}x{resolution[1]}, {samples} CPU samples)")
    report_path = opt.output_dir / "renders.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
