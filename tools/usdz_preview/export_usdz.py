#!/usr/bin/env python3
"""Export a Blender .blend or GLB asset as an iPhone Quick Look USDZ preview.

Run with Blender 4.5+:
  blender --background --factory-startup --python tools/usdz_preview/export_usdz.py -- \
    --source asset.blend --output preview.usdz [--report preview.json]

The source file is read/imported in memory only; it is never saved or changed.
Existing outputs are protected unless --overwrite is passed explicitly.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
import uuid
import zipfile
from pathlib import Path

import bpy


TEXTURE_SUFFIXES = {".png", ".jpg", ".jpeg", ".exr", ".avif", ".tif", ".tiff"}
USD_SUFFIXES = {".usd", ".usda", ".usdc"}


def parse_args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Existing Blender .blend or game .glb")
    parser.add_argument("--output", required=True, help="New .usdz destination")
    parser.add_argument("--report", help="Optional JSON receipt destination")
    parser.add_argument("--max-texture-size", type=int, choices=(512, 1024, 2048, 4096), default=2048)
    parser.add_argument("--require-animation", action="store_true", help="Fail if no active scene/NLA animation is found")
    parser.add_argument("--action", help="Select this Blender action before exporting a review animation")
    parser.add_argument("--overwrite", action="store_true", help="Allow replacing output and receipt files")
    return parser.parse_args(raw)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_source(source: Path) -> None:
    suffix = source.suffix.lower()
    if suffix == ".blend":
        bpy.ops.wm.open_mainfile(filepath=str(source))
    elif suffix == ".glb":
        bpy.ops.wm.read_factory_settings(use_empty=True)
        result = bpy.ops.import_scene.gltf(filepath=str(source))
        if "FINISHED" not in result:
            raise RuntimeError(f"Blender could not import GLB: {result}")
    else:
        raise ValueError("Source must be a .blend or .glb file")


def scene_inventory() -> dict:
    scene = bpy.context.scene
    meshes = [obj for obj in scene.objects if obj.type == "MESH" and obj.visible_get()]
    materials = {mat for obj in meshes for mat in obj.data.materials if mat is not None}
    images = {
        node.image
        for material in materials
        if material.use_nodes and material.node_tree
        for node in material.node_tree.nodes
        if node.type == "TEX_IMAGE" and node.image is not None
    }
    actions = set()
    active_animation = False
    for obj in scene.objects:
        animation_data = obj.animation_data
        if animation_data is None:
            continue
        if animation_data.action is not None:
            actions.add(animation_data.action.name)
            active_animation = True
        for track in animation_data.nla_tracks:
            if track.mute:
                continue
            for strip in track.strips:
                if strip.mute or strip.action is None:
                    continue
                actions.add(strip.action.name)
                active_animation = True

    return {
        "mesh_objects": len(meshes),
        "materials": len(materials),
        "material_images": len(images),
        "animation_actions": sorted(actions),
        "scene_animation_active": active_animation,
        "frame_start": scene.frame_start,
        "frame_end": scene.frame_end,
        "fps": scene.render.fps / scene.render.fps_base,
    }


def convert_static_curves_to_meshes() -> int:
    """AR Quick Look doesn't accept USD BasisCurves; bake static curves in memory."""
    curves = [obj for obj in bpy.context.scene.objects if obj.type in {"CURVE", "FONT"} and obj.visible_get()]
    for obj in curves:
        animation_data = obj.animation_data
        if animation_data and (animation_data.action or any(not track.mute for track in animation_data.nla_tracks)):
            raise RuntimeError(
                f"Animated curve {obj.name!r} cannot be converted safely; author it as animated mesh/GLB geometry first"
            )
    for obj in curves:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        result = bpy.ops.object.convert(target="MESH")
        if "FINISHED" not in result:
            raise RuntimeError(f"Could not convert static curve {obj.name!r} to a Quick Look mesh")
    bpy.ops.object.select_all(action="DESELECT")
    return len(curves)


def export_preview(output: Path, max_texture_size: int, animation: bool) -> None:
    size_name = str(max_texture_size)
    result = bpy.ops.wm.usd_export(
        filepath=str(output),
        selected_objects_only=False,
        visible_objects_only=True,
        export_animation=animation,
        export_textures=True,
        export_textures_mode="NEW",
        overwrite_textures=False,
        export_materials=True,
        generate_preview_surface=True,
        export_lights=False,
        export_cameras=False,
        export_volumes=False,
        usdz_downscale_size=size_name,
        convert_scene_units="METERS",
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        convert_orientation=True,
        relative_paths=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"Blender USD export did not finish: {result}")


def resolve_texture_paths() -> int:
    """Resolve source-relative image paths before exporting into a temp folder.

    Blender's USDZ packager otherwise resolves `//` image paths against the
    temporary USD output directory, which can omit newly generated pipeline
    maps even though they exist beside the source .blend.
    """
    resolved = 0
    for image in bpy.data.images:
        if image.source != "FILE" or not image.filepath:
            continue
        try:
            source_path = Path(bpy.path.abspath(image.filepath)).expanduser().resolve(strict=True)
        except (OSError, RuntimeError):
            continue
        if source_path.is_file():
            if image.packed_file:
                image.unpack(method="USE_ORIGINAL")
            image.filepath = str(source_path)
            image.reload()
            resolved += 1
    return resolved


def select_action(name: str | None) -> None:
    if not name:
        return
    action = bpy.data.actions.get(name)
    rig = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if action is None or rig is None:
        raise RuntimeError(f"Could not select review action {name!r}: action or armature is missing")
    rig.animation_data_create()
    rig.animation_data.action = action
    first, last = (int(round(v)) for v in action.frame_range)
    bpy.context.scene.frame_start = first
    bpy.context.scene.frame_end = last
    bpy.context.scene.frame_set((first + last) // 2)


def inspect_usdz(path: Path, expected_textures: int) -> list[str]:
    if not zipfile.is_zipfile(path):
        raise RuntimeError("Blender output is not a valid USDZ zip archive")
    with zipfile.ZipFile(path) as archive:
        names = [name for name in archive.namelist() if not name.endswith("/")]
    if not any(Path(name).suffix.lower() in USD_SUFFIXES for name in names):
        raise RuntimeError("USDZ package contains no USD layer")
    texture_count = sum(Path(name).suffix.lower() in TEXTURE_SUFFIXES for name in names)
    if texture_count < expected_textures:
        raise RuntimeError(
            f"USDZ contains {texture_count} texture files but the scene uses {expected_textures}; "
            "refusing to report a complete material preview"
        )
    return names


def main() -> None:
    args = parse_args()
    source = Path(args.source).expanduser().resolve(strict=True)
    output = Path(args.output).expanduser().resolve()
    report_path = Path(args.report).expanduser().resolve() if args.report else None
    if output.suffix.lower() != ".usdz":
        raise ValueError("Output filename must end in .usdz")
    if output == source:
        raise ValueError("Output cannot overwrite the source")
    if report_path and report_path in {source, output}:
        raise ValueError("The JSON report must use a different path from the source and USDZ")
    if output.exists() and not args.overwrite:
        raise FileExistsError(f"Refusing to overwrite existing preview: {output}")
    if report_path and report_path.exists() and not args.overwrite:
        raise FileExistsError(f"Refusing to overwrite existing report: {report_path}")

    load_source(source)
    select_action(args.action)
    converted_curves = convert_static_curves_to_meshes()
    inventory = scene_inventory()
    if not inventory["mesh_objects"]:
        raise RuntimeError("No visible mesh objects were found in the source scene")
    if args.require_animation and not inventory["scene_animation_active"]:
        raise RuntimeError("No active Action/NLA animation was found for the requested preview")
    resolved_texture_paths = resolve_texture_paths()

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary_dir = Path(tempfile.mkdtemp(prefix=f".{output.stem}.{uuid.uuid4().hex}.", dir=output.parent))
    temporary = temporary_dir / output.name
    try:
        export_preview(temporary, args.max_texture_size, inventory["scene_animation_active"])
        package_files = inspect_usdz(temporary, inventory["material_images"])
        if output.exists() and not args.overwrite:
            raise FileExistsError(f"Preview appeared during export; refusing to replace: {output}")
        os.replace(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)
        temporary_dir.rmdir()

    receipt = {
        "package_status": "PASS",
        "apple_arkit_validation": "NOT_RUN_BY_EXPORTER",
        "source": str(source),
        "source_sha256": sha256(source),
        "output": str(output),
        "output_bytes": output.stat().st_size,
        "output_sha256": sha256(output),
        "blender_version": bpy.app.version_string,
        "preview_texture_max_px": args.max_texture_size,
        "source_texture_paths_resolved": resolved_texture_paths,
        "animation_exported": inventory["scene_animation_active"],
        "static_curves_converted_to_meshes": converted_curves,
        **inventory,
        "packaged_files": package_files,
    }
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        if report_path.exists() and not args.overwrite:
            raise FileExistsError(f"Refusing to overwrite existing report: {report_path}")
        report_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
