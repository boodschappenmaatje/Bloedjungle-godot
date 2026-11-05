#!/usr/bin/env python3
"""Non-destructive M2HB artwork articulation from Dennis' approved, optimized GLB.

Requires numpy, trimesh and Pillow.  Output is a CANDIDATE, never the game GLB.
The original shape, UVs and texture remain intact in rest pose. The specific
spatial selection has been visually inspected ONLY on a 162806-triangle GLB;
inspect --debug-mask on the separate production 60k GLB before publishing.

python3 bron/m2hb_toren/build_articulated_m2.py \
  --source assets/vijand_m2_toren.glb \
  --output /tmp/m2-articulated-CANDIDATE.glb \
  --debug-mask /tmp/m2-selection.glb \
  --yaw-preview /tmp/m2-yaw45.glb
"""
import argparse
from pathlib import Path
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals

YAW = np.array([0.0, 5.20, 0.12])
PITCH = np.array([-0.30, 5.47, 0.22])
MUZZLE = np.array([-2.25, 5.75, 0.83])


def part(mesh, mask, material):
    faces = mesh.faces[mask]
    used, inverse = np.unique(faces, return_inverse=True)
    return trimesh.Trimesh(
        vertices=mesh.vertices[used],
        faces=inverse.reshape(-1, 3),
        vertex_normals=mesh.vertex_normals[used],
        visual=TextureVisuals(uv=mesh.visual.uv[used], material=material),
        process=False)


def build(source, output, debug_mask, yaw_preview):
    source = Path(source)
    outputs = [Path(p) for p in [output, debug_mask, yaw_preview] if p is not None]
    if not source.is_file():
        raise FileNotFoundError(source)
    if len(set(map(lambda p: str(p.resolve()), outputs))) != len(outputs):
        raise ValueError("Output paths must be different")
    for path in outputs:
        if path.exists() or path.resolve() == source.resolve():
            raise FileExistsError("Refusing to overwrite approved source or output: " + str(path))
        path.parent.mkdir(parents=True, exist_ok=True)

    scene_src = trimesh.load(source, force="scene", process=False)
    if len(scene_src.geometry) != 1 or "MG_Yaw" in scene_src.graph.nodes:
        raise ValueError("Expected the original single-mesh optimized tower")
    # The Blender GLB carries a node transform. `force="mesh"` bakes that
    # transform and turns the approved Y-up tower into Z-up coordinates.
    # Split the original accessor geometry so the output glTF remains Y-up.
    mesh = next(iter(scene_src.geometry.values())).copy()
    if not isinstance(mesh.visual, TextureVisuals) or mesh.visual.uv is None:
        raise ValueError("Missing original UVs")
    if not 5.7 <= np.ptp(mesh.bounds, axis=0)[1] <= 6.3:
        raise ValueError("Unexpected source height, must be Y-up and approximately 6 m")
    x, y, z = mesh.vertices[mesh.faces].mean(axis=1).T

    # Only the approved M2 geometry: no boxes, new designs, or replacement weapon.
    shield = (y > 5.02) & (z > -0.64) & (z < 1.05) & (np.abs(x - (-0.20 + 0.16*z)) < 0.24)
    receiver = (y > 5.18) & (x > -0.38) & (x < 1.02) & (z > -0.7) & (z < 0.62)
    barrel = (y > 5.32) & (x < -0.18) & (x > -2.27) & (np.abs(z - (0.29 - 0.26*x)) < 0.22)
    mount = (y > 4.82) & (y < 5.40) & (x > -0.55) & (x < 0.52) & (z > -0.52) & (z < 0.60)
    yaw = shield | mount
    pitch = (receiver | barrel) & ~yaw
    fixed = ~(yaw | pitch)
    if min(fixed.sum(), yaw.sum(), pitch.sum()) < 100:
        raise ValueError("Source selection failed")
    assert np.all(fixed.astype(int) + yaw.astype(int) + pitch.astype(int) == 1)

    root = trimesh.Scene()
    root.add_geometry(part(mesh, fixed, mesh.visual.material),
                      node_name="TowerStatic", geom_name="TowerStatic")
    root.graph.update(frame_from="world", frame_to="MG_Yaw",
                      matrix=trimesh.transformations.translation_matrix(YAW))
    yaw_geo = part(mesh, yaw, mesh.visual.material)
    yaw_geo.apply_translation(-YAW)
    root.add_geometry(yaw_geo, parent_node_name="MG_Yaw",
                      node_name="MG_ShieldMount", geom_name="MG_ShieldMount")
    root.graph.update(frame_from="MG_Yaw", frame_to="MG_Pitch",
                      matrix=trimesh.transformations.translation_matrix(PITCH-YAW))
    root.graph.update(frame_from="MG_Pitch", frame_to="MG_Recoil", matrix=np.eye(4))
    pitch_geo = part(mesh, pitch, mesh.visual.material)
    pitch_geo.apply_translation(-PITCH)
    root.add_geometry(pitch_geo, parent_node_name="MG_Recoil",
                      node_name="MG_BarrelReceiver", geom_name="MG_BarrelReceiver")
    root.graph.update(frame_from="MG_Recoil", frame_to="Muzzle",
                      matrix=trimesh.transformations.translation_matrix(MUZZLE-PITCH))
    root.export(str(output), file_type="glb")

    checked = trimesh.load(output, force="scene", process=False)
    face_count = sum(len(g.faces) for g in checked.geometry.values())
    if face_count != len(mesh.faces):
        raise AssertionError("Triangle loss")
    if np.max(np.abs(checked.bounds - mesh.bounds)) >= 0.002:
        raise AssertionError("Rest-pose geometry drift")
    names = set(checked.graph.nodes)
    if not {"MG_Yaw", "MG_Pitch", "MG_Recoil", "Muzzle"} <= names:
        raise AssertionError("Missing pivot nodes")
    parents = checked.graph.transforms.parents
    if parents.get("MG_Pitch") != "MG_Yaw" or parents.get("MG_Recoil") != "MG_Pitch":
        raise AssertionError("Broken pivot hierarchy")

    if debug_mask:
        dbg = trimesh.Scene()
        dbg.add_geometry(part(mesh, fixed, mesh.visual.material), node_name="TowerStatic")
        for name, mask, rgb in [
            ("MG_Yaw_Selection", yaw, [20, 110, 245, 255]),
            ("MG_Pitch_Selection", pitch, [245, 70, 20, 255]),
        ]:
            col = PBRMaterial(baseColorFactor=rgb, roughnessFactor=0.7, doubleSided=True)
            dbg.add_geometry(part(mesh, mask, col), node_name=name)
        dbg.export(str(debug_mask), file_type="glb")

    if yaw_preview:
        moved = trimesh.load(output, force="scene", process=False)
        transform = trimesh.transformations.translation_matrix(YAW)
        transform = transform @ trimesh.transformations.rotation_matrix(np.pi/4, [0, 1, 0])
        moved.graph.update(frame_from="world", frame_to="MG_Yaw", matrix=transform)
        moved.export(str(yaw_preview), file_type="glb")

    print("PASS: %d triangles, unchanged rest bounds (<2 mm), nested moving pivots" % face_count)
    print("fixed=%d yaw/shield=%d pitch/gun=%d" % (fixed.sum(), yaw.sum(), pitch.sum()))
    print("PREVIEW ONLY: verify the mask on the 60k GLB and compare multiple rotations.")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--debug-mask")
    p.add_argument("--yaw-preview")
    a = p.parse_args()
    build(a.source, a.output, a.debug_mask, a.yaw_preview)
