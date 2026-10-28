#!/usr/bin/env python3
"""Build a focused, editable Blender source for the player's woodland outfit.

The full VQ2 source is read without modification. Unrelated looks are removed only
from the new output copy; the rig and all source actions remain available.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


KEEP = {"Lijf_Uniform", "Hoofdband", "Koppel", "Laarzen"}


def args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args(raw)


def linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def uniform_tint() -> tuple[float, float, float]:
    rgb = [int("4b5a2c"[i : i + 2], 16) / 255.0 for i in (0, 2, 4)]
    mx = max(*rgb, 0.001)
    lum = 0.3 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]
    k = 0.42 * min(max(mx / 0.35, 0.45), 1.0)
    tinted = [(lum / mx + (v / mx - lum / mx) * 0.85) * k for v in rgb]
    return tuple(linear(v) for v in tinted)


def multiply_base_color(material: bpy.types.Material, color: tuple[float, float, float]) -> None:
    if not material.use_nodes or not material.node_tree:
        return
    tree = material.node_tree
    principled = next((node for node in tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
    if principled is None:
        return
    base = principled.inputs.get("Base Color")
    if base is None:
        return
    upstream = next((link.from_socket for link in list(base.links)), None)
    if upstream is not None:
        multiply = tree.nodes.new("ShaderNodeMixRGB")
        multiply.name = "Bloedjungle outfit tint"
        multiply.blend_type = "MULTIPLY"
        multiply.inputs[0].default_value = 1.0
        multiply.inputs[2].default_value = (*color, 1.0)
        tree.links.new(upstream, multiply.inputs[1])
        tree.links.new(multiply.outputs[0], base)
    else:
        base.default_value = (*color, 1.0)


def build(source: Path, output: Path) -> dict:
    source = source.expanduser().resolve(strict=True)
    output = output.expanduser().resolve()
    if source == output:
        raise ValueError("Output cannot overwrite the source blend")
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite {output}")

    bpy.ops.wm.open_mainfile(filepath=str(source))
    missing = KEEP - {obj.name for obj in bpy.context.scene.objects}
    if missing:
        raise RuntimeError(f"Source is missing required player parts: {sorted(missing)}")
    rig = bpy.data.objects.get("Rig")
    if rig is None or rig.type != "ARMATURE" or len(rig.data.bones) != 53:
        raise RuntimeError("Expected the existing 53-bone VQ2 DEF rig")

    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.name not in KEEP:
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type not in {"MESH", "ARMATURE", "EMPTY"} and obj.name != "Scene":
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in list(bpy.context.scene.objects):
        if obj.type == "EMPTY" and obj.name == "Scene":
            bpy.data.objects.remove(obj, do_unlink=True)

    palette = uniform_tint()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for material in obj.data.materials:
            if material is None:
                continue
            if material.name == "Uniform_Kleding":
                multiply_base_color(material, palette)
            elif material.name == "Hoofdband":
                # Keep the project's existing jungle red headband, not an actor-specific sculpt.
                multiply_base_color(material, tuple(linear(v / 255.0) for v in (192, 20, 15)))

    walk = bpy.data.actions.get("lopen")
    if walk is None:
        raise RuntimeError("Source has no existing 'lopen' animation")
    rig.animation_data_create()
    rig.animation_data.action = walk
    start, end = (int(round(v)) for v in walk.frame_range)
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = start, end
    scene.render.fps = 30
    scene.frame_set(start)

    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    return {
        "status": "PASS",
        "source": str(source),
        "output": str(output),
        "mesh_objects": [obj.name for obj in meshes],
        "triangles": sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes),
        "rig_bones": len(rig.data.bones),
        "active_animation": walk.name,
        "animation_frames": [start, end],
        "animation_actions_preserved": sorted(action.name for action in bpy.data.actions),
        "materials": sorted({material.name for obj in meshes for material in obj.data.materials if material}),
    }


if __name__ == "__main__":
    result = build(**vars(args()))
    print(json.dumps(result, indent=2))
