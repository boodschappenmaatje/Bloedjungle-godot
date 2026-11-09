#!/usr/bin/env python3
"""NON-PRODUCTION diagnostic: isolate candidate M2HB triangles from the approved tower GLB.

Example:
 python3 bron/m2hb_toren/split_weapon_probe.py --source assets/vijand_m2_toren.glb \
   --output /tmp/bloedjungle-m2-separated-PREVIEW.glb \
   --yaw-preview /tmp/bloedjungle-m2-yaw45-PREVIEW.glb \
   --debug-mask /tmp/bloedjungle-m2-mask-PREVIEW.glb

Requires numpy, trimesh, Pillow. DO NOT replace the approved production GLB
with these outputs. In particular, the black protective shield and lower pintle
need further visual isolation before the gun can be reliably articulated.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals


def run(source: Path, output: Path, yaw_preview: Path | None, debug_mask: Path | None) -> None:
    if not source.is_file():
        raise FileNotFoundError(source)
    targets = [p for p in (output, yaw_preview, debug_mask) if p is not None]
    if len({str(p.resolve()) for p in targets}) != len(targets):
        raise ValueError("Each output path must be distinct")
    for p in targets:
        if p.resolve() == source.resolve():
            raise ValueError("Refusing to overwrite the approved GLB")
        if p.exists():
            raise FileExistsError(p)
        p.parent.mkdir(parents=True, exist_ok=True)

    mesh = trimesh.load(str(source), force="mesh", process=False)
    if mesh.is_empty or len(mesh.faces) < 1000:
        raise ValueError("Unexpectedly small or empty input")
    if not isinstance(mesh.visual, TextureVisuals) or mesh.visual.uv is None:
        raise ValueError("No UVs found. Preserve the approved texture; aborting.")

    centers = mesh.vertices[mesh.faces].mean(axis=1)
    x, y, z = centers.T
    # Based on the original 6m-high, Y-up Meshy model. This is a FIRST
    # DIAGNOSTIC SELECTION, not a fully verified production gun mesh.
    receiver = ((y > 5.35) & (x < 1.0) & (np.abs(z) < 0.65)) | (
        (y > 5.0) & (x > -0.9) & (x < 0.85) & (np.abs(z) < 0.58)
    )
    barrel = (x < -0.8) & (y > 5.5) & (np.abs(z - (0.15 - 0.28 * x)) < 0.25)
    selected = receiver | barrel
    if selected.sum() < 100 or (~selected).sum() < 100:
        raise ValueError("Model coordinates do not match the expected tower")
    print(f"Source triangles={len(mesh.faces)}, MG candidate={selected.sum()}")

    def make(mask: np.ndarray, material: object) -> trimesh.Trimesh:
        faces = mesh.faces[mask]
        used, mapped = np.unique(faces, return_inverse=True)
        return trimesh.Trimesh(
            vertices=mesh.vertices[used],
            faces=mapped.reshape(-1, 3),
            vertex_normals=mesh.vertex_normals[used],
            visual=TextureVisuals(uv=mesh.visual.uv[used], material=material),
            process=False,
        )

    static = make(~selected, mesh.visual.material)
    moving = make(selected, mesh.visual.material)
    pivot = np.array([0.0, 5.2, 0.0])
    moving.apply_translation(-pivot)
    scene = trimesh.Scene()
    scene.add_geometry(static, node_name="TowerStatic", geom_name="TowerStatic")
    scene.add_geometry(
        moving, node_name="MG_Yaw", geom_name="MG_Artwork",
        transform=trimesh.transformations.translation_matrix(pivot)
    )
    scene.export(str(output), file_type="glb")
    restored = trimesh.load(str(output), force="scene", process=False)
    assert sum(len(g.faces) for g in restored.geometry.values()) == len(mesh.faces)
    assert np.max(np.abs(restored.bounds - mesh.bounds)) < 0.002
    print("PASS: every source triangle present; rest bounds differ < 2mm")

    if debug_mask:
        red = PBRMaterial(
            baseColorFactor=[230, 35, 30, 255],
            roughnessFactor=0.8, metallicFactor=0.0, doubleSided=True
        )
        scene_debug = trimesh.Scene()
        scene_debug.add_geometry(make(~selected, mesh.visual.material), node_name="TowerStatic")
        scene_debug.add_geometry(make(selected, red), node_name="MG_MASK")
        scene_debug.export(str(debug_mask), file_type="glb")

    if yaw_preview:
        rotated = trimesh.load(str(output), force="scene", process=False)
        node = next(n for n in rotated.graph.nodes_geometry if "MG_Yaw" in n)
        _, geometry = rotated.graph.get(node)
        rotation = trimesh.transformations.rotation_matrix(np.radians(45), [0, 1, 0])
        transform = trimesh.transformations.translation_matrix(pivot) @ rotation
        rotated.graph.update(frame_to=node, matrix=transform, geometry=geometry)
        rotated.export(str(yaw_preview), file_type="glb")

    print("WARNING: visual separation is incomplete. Preview only; DO NOT DEPLOY.")


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--source", type=Path, required=True)
    cli.add_argument("--output", type=Path, required=True)
    cli.add_argument("--yaw-preview", type=Path)
    cli.add_argument("--debug-mask", type=Path)
    args = cli.parse_args()
    run(args.source, args.output, args.yaw_preview, args.debug_mask)
