#!/usr/bin/env python3
"""Re-export small, recentered Airfield HQ 2.2 module previews for Apple Quick Look.

Run in Blender 4.x or 4.5:
  blender --background --factory-startup --python tools/airfield_hq/create_iphone_quicklook_previews.py -- \
      --source assets/airfield_hq_v22/runtime/Bloedjungle_Airfield_HQ_2_2_LOD1.glb \
      --outdir preview-download

Do not use the entire 900m runway when reviewing building detail in Quick Look:
Apple frames the complete scene bounds, which can make buildings invisible.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import zipfile
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--source", required=True)
    p.add_argument("--outdir", required=True)
    return p.parse_args(argv)


def world_bounds(objects):
    corners = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    return Vector([min(v[i] for v in corners) for i in range(3)]), Vector([max(v[i] for v in corners) for i in range(3)])


def load_and_crop(source, kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    names = [o.name for o in bpy.data.objects if o.type == "MESH"]
    print("SOURCE_MESHES=" + json.dumps(names))
    keep = []
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        name = o.name.casefold()
        if kind == "hangar":
            match = ("hangar" in name or "sliding door" in name or "hangar service" in name or "workshop" in name)
        else:
            match = ("tower" in name or "wind sock" in name or "windsock" in name)
        if match:
            keep.append(o)

    if not keep:
        raise RuntimeError(f"No meshes for {kind}: {names!r}")
    # Keep only selected module mesh geometry, unparent while preserving world
    # transforms. USDZ preview is intentionally static (the gameplay GLBs retain
    # the five animation clips).
    for o in keep:
        mat = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mat
        if o.animation_data:
            o.animation_data_clear()

    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)

    minimum, maximum = world_bounds(keep)
    extent = maximum - minimum
    if min(extent) <= 0.01 or max(extent) > 250.0:
        raise RuntimeError(f"Unreasonable {kind} model bounds: min={list(minimum)}, max={list(maximum)}, extent={list(extent)}")
    offset = Vector((-(minimum.x + maximum.x) / 2.0, -(minimum.y + maximum.y) / 2.0, -minimum.z))
    for o in keep:
        m = o.matrix_world.copy()
        m.translation += offset
        o.matrix_world = m
    mn, mx = world_bounds(keep)
    return {"meshes": len(keep), "names": [o.name for o in keep], "original_mins_m": list(minimum), "original_maxs_m": list(maximum), "centered_mins_m": list(mn), "centered_maxs_m": list(mx), "dimensions_m": list(extent)}


def export_usdz(path):
    candidate = {
        "filepath": str(path),
        "selected_objects_only": False,
        "visible_objects_only": True,
        "export_animation": False,
        "export_textures": True,
        "export_textures_mode": "NEW",
        "export_materials": True,
        "generate_preview_surface": True,
        "export_lights": False,
        "export_cameras": False,
        "export_volumes": False,
        "usdz_downscale_size": "1024",
        "convert_scene_units": "METERS",
        "export_global_forward_selection": "NEGATIVE_Z",
        "export_global_up_selection": "Y",
        "convert_orientation": True,
        "relative_paths": True,
    }
    known = {p.identifier for p in bpy.ops.wm.usd_export.get_rna_type().properties}
    result = bpy.ops.wm.usd_export(**{k: v for k, v in candidate.items() if k in known})
    if "FINISHED" not in result:
        raise RuntimeError(f"USDZ export failed: {result}")
    if not zipfile.is_zipfile(path):
        raise RuntimeError(f"USDZ isn't a valid zip archive: {path}")
    with zipfile.ZipFile(path) as archive:
        files = archive.namelist()
    if not any(n.endswith((".usdc", ".usd", ".usda")) for n in files):
        raise RuntimeError(f"USDZ lacks a USD layer: {path}")
    if not any(n.endswith((".jpg", ".png")) for n in files):
        raise RuntimeError(f"USDZ lacks textures: {path}")
    return {"bytes": path.stat().st_size, "packaged_files": len(files), "texture_count": sum(n.endswith((".jpg", ".png")) for n in files)}


def main():
    args = parse_args()
    source = Path(args.source).resolve()
    outdir = Path(args.outdir).resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    results = {}
    for kind in ("hangar", "tower"):
        stats = load_and_crop(source, kind)
        output = outdir / f"Bloedjungle_Airfield_HQ_2_2_{kind.capitalize()}_iPhone_FIX.usdz"
        stats.update(export_usdz(output))
        results[kind] = stats
        print(kind.upper() + "_PREVIEW=" + json.dumps(stats))
    (outdir / "iphone_quicklook_preview_report.json").write_text(json.dumps(results, indent=2) + "\n")
    print("IPHONE_QUICKLOOK_BUNDLE_PASS")


if __name__ == "__main__":
    main()
