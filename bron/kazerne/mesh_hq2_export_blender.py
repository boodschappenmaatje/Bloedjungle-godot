"""Kazerne HQ2: reproduceerbare Blender 4.5-kandidaatbouw.
Gebruik:
  blender -b --python bron/kazerne/mesh_hq2_export_blender.py -- \
    --src /pad/kazerne_hq2_source_high.glb --out /pad/uitvoer
Dit script bouwt TESTKANDIDATEN, niet een visueel goedgekeurd mobiele asset.
"""
import argparse
import json
import sys
from pathlib import Path

import bpy


def triangles(obj):
    return sum(max(0, len(p.vertices) - 2) for p in obj.data.polygons)


def create_candidate(source, outdir, level, target):
    # Decimeer een kopie zodat het gebruikersgoedgekeurde Meshy-model intact blijft.
    obj = source.copy()
    obj.data = source.data.copy()
    bpy.context.collection.objects.link(obj)
    obj.name = "Kazerne_HQ2_LOD%d_CANDIDATE" % level
    original_count = triangles(obj)
    ratio = min(1.0, target / max(1, original_count))
    dec = obj.modifiers.new("Meshy_HQ2_Decimate_Review_Required", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.ratio = ratio
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=dec.name)
    count = triangles(obj)
    dims = [round(float(v), 3) for v in obj.dimensions]
    # Numerieke check voorkomt een verkeerd formaat, maar vervangt geen visuele controle.
    if abs(dims[0] - 6.4) > 0.08 or abs(dims[1] - 4.8) > 0.08 or abs(dims[2] - 3.5) > 0.08:
        raise RuntimeError("Kazerne-afmetingen afwijkend in LOD%d: %r" % (level, dims))
    bpy.ops.export_scene.gltf(
        filepath=str(outdir / ("kazerne_hq2_lod%d_CANDIDATE.glb" % level)),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    obj.hide_render = True
    obj.hide_set(True)
    return {"lod": level, "triangles": count, "dimensions_blender_xyz_m": dims,
            "quality_gate": "NOT APPROVED - inspect roof, walls, UV seams, normal map and gameplay camera"}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", type=Path, required=True, help="High source GLB")
    parser.add_argument("--out", type=Path, required=True)
    cfg = parser.parse_args(args)
    cfg.out.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(cfg.src.resolve()))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("High-poly bron bevat geen mesh")
    # HQ2-export heeft momenteel precies een mesh. Niet stilzwijgend meerdere meshes weggooien.
    if len(meshes) != 1:
        raise RuntimeError("Verwacht 1 mesh, kreeg %d: combineer bewust in Blender" % len(meshes))
    source = meshes[0]
    source.name = "Kazerne_HQ2_Meshy_Original_Keep"
    bpy.context.view_layer.objects.active = source
    source.hide_render = True
    dims = [round(float(v), 3) for v in source.dimensions]
    if any(abs(a - b) > 0.08 for a, b in zip(dims, [6.4, 4.8, 3.5])):
        raise RuntimeError("Verwacht Blender XYZ 6.4 x 4.8 x 3.5 m, kreeg %r" % dims)
    bpy.ops.wm.save_as_mainfile(filepath=str(cfg.out / "kazerne_hq2_SOURCE.blend"))
    report = {"source_triangles": triangles(source), "source_dimensions_blender_xyz_m": dims,
              "blender_version": bpy.app.version_string, "source_file": str(cfg.src),
              "warning": "LOD normals need a proper high-to-low bake and user visual approval"}
    for lod, target in [(0, 80000), (1, 25000), (2, 8000)]:
        report["lod%d" % lod] = create_candidate(source, cfg.out, lod, target)
    (cfg.out / "lod_build_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("KAZERNE_HQ2_BUILD_CANDIDATES", json.dumps(report))


if __name__ == "__main__":
    main()
