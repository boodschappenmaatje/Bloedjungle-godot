#!/usr/bin/env python3
"""Export one iPhone USDZ review copy per approved plant species.

Run inside Blender 4.5+ from the repository root:
  blender --background --factory-startup --python \
    bron/jungle_foliage_depth/export_usdz_previews.py -- \
    --source bron/jungle_foliage_depth/jungle_foliage_depth.blend \
    --output-dir previews/usdz/jungle_depth_foliage/v1

The source .blend is opened read-only. Each export temporarily hides all mesh
nodes except the requested species' LOD0 and uses the project's USDZ helper.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
SPECIES = {
    "rosette": "HQ_rosette_LOD0",
    "arch_fern": "HQ_arch_fern_LOD0",
    "red_bloom": "HQ_red_bloom_LOD0",
}


def args_from_command_line() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Approved Blender .blend source")
    parser.add_argument("--output-dir", required=True, help="New destination directory")
    parser.add_argument("--version", default="v1", help="Preview version path")
    parser.add_argument("--max-texture-size", type=int, choices=(512, 1024), default=1024)
    return parser.parse_args(raw)


def load_usdz_helper():
    helper_path = ROOT / "tools/usdz_preview/export_usdz.py"
    spec = importlib.util.spec_from_file_location("bloedjungle_usdz_export", helper_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load the approved USDZ helper: {helper_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    args = args_from_command_line()
    source = Path(args.source).expanduser().resolve(strict=True)
    output_dir = Path(args.output_dir).expanduser().resolve() / args.version
    if source.suffix.lower() != ".blend":
        raise ValueError("USDZ foliage previews must use the approved .blend source")
    output_dir.mkdir(parents=True, exist_ok=True)
    helper = load_usdz_helper()

    for species, target_name in SPECIES.items():
        helper.load_source(source)
        helper.resolve_texture_paths()
        target = bpy.data.objects.get(target_name)
        if target is None or target.type != "MESH":
            raise RuntimeError(f"Approved LOD0 source mesh is missing: {target_name}")
        # Blender's USD exporter may serialize viewport-hidden meshes and lose
        # their visibility on Quick Look import. Remove non-target nodes from
        # this in-memory review copy so each USDZ contains exactly one LOD0.
        for obj in list(bpy.context.scene.objects):
            if obj.type == "MESH" and obj != target:
                bpy.data.objects.remove(obj, do_unlink=True)
        inventory = helper.scene_inventory()
        if inventory["mesh_objects"] != 1 or inventory["material_images"] != 3:
            raise RuntimeError(f"Unexpected {species} source inventory: {inventory}")

        output = output_dir / f"jungle_{species}_iphone.usdz"
        report_path = output.with_suffix(".json")
        if output.exists() or report_path.exists():
            raise FileExistsError(f"Refusing to replace existing preview or report: {output}")
        with tempfile.TemporaryDirectory(prefix=f".{species}.", dir=output_dir) as temp_dir:
            temporary = Path(temp_dir) / output.name
            helper.export_preview(temporary, args.max_texture_size, False)
            files = helper.inspect_usdz(temporary, inventory["material_images"])
            os.replace(temporary, output)

        # Blender's USD reader verifies that the layer resolves back to one
        # visible mesh and its packaged image textures before the file is kept.
        bpy.ops.wm.read_factory_settings(use_empty=True)
        import_result = bpy.ops.wm.usd_import(filepath=str(output))
        imported_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.visible_get()]
        imported_images = {
            node.image
            for obj in imported_meshes
            for material in obj.data.materials if material and material.use_nodes and material.node_tree
            for node in material.node_tree.nodes if node.type == "TEX_IMAGE" and node.image
        }
        if "FINISHED" not in import_result or len(imported_meshes) != 1 or len(imported_images) < 1:
            raise RuntimeError(f"Blender USD re-import failed for {species}: {len(imported_meshes)} visible mesh(es), {len(imported_images)} texture(s)")

        receipt = {
            "species": species,
            "source": str(source.relative_to(ROOT)),
            "source_sha256": helper.sha256(source),
            "output": str(output.relative_to(ROOT)),
            "output_bytes": output.stat().st_size,
            "output_sha256": helper.sha256(output),
            "blender_version": bpy.app.version_string,
            "mesh_objects": inventory["mesh_objects"],
            "materials": inventory["materials"],
            "material_images": inventory["material_images"],
            "texture_max_px": args.max_texture_size,
            "package_status": "PASS",
            "blender_usd_import_validation": "PASS — one visible LOD0 mesh and packaged PBR textures resolved",
            "apple_arkit_validation": "NOT_RUN — Apple USD tools are unavailable in this Linux environment",
            "quicklook_validation": "NOT_RUN — no macOS Quick Look or physical iPhone was available",
            "packaged_files": files,
        }
        report_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
