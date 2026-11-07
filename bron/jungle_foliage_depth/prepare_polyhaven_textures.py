#!/usr/bin/env python3
"""Build mobile Godot PBR maps from the approved 2K Poly Haven foliage sources.

The source .blend files and 2K maps remain in polyhaven_source/. Runtime albedo,
OpenGL normal, and roughness are normalized to 1K for the existing MultiMesh
foliage batches; alpha is packed into base color so all three materials use the
same opaque alpha-cutout shader path.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "bron/jungle_foliage_depth/polyhaven_source"
OUT = ROOT / "assets/textures/foliage/polyhaven"
SIZE = (1024, 1024)
ASSETS = {
    "arch_fern": "fern_02",
    "rosette": "anthurium_botany_01",
    "shrub": "shrub_04",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unique(pattern: str, base: Path) -> Path:
    matches = list(base.glob(pattern))
    if len(matches) != 1:
        raise SystemExit(f"Expected one {pattern} in {base}, found {len(matches)}")
    return matches[0]


def build(species: str, asset_id: str) -> dict:
    source_dir = SOURCE / asset_id
    source_textures = source_dir / "textures"
    runtime_sources = source_dir / "runtime_maps"
    diffuse_path = unique("*_diff_2k.jpg", source_textures)
    alpha_path = unique("*_alpha_2k.png", source_textures)
    normal_path = unique("*_nor_gl_2k.jpg", runtime_sources)
    arm_path = unique("*_arm_2k.jpg", runtime_sources)

    diffuse = np.asarray(Image.open(diffuse_path).convert("RGB"), dtype=np.uint8)
    alpha = np.asarray(Image.open(alpha_path).convert("L"), dtype=np.uint8)
    if diffuse.shape[:2] != alpha.shape:
        raise SystemExit(f"Albedo/alpha size mismatch for {asset_id}: {diffuse.shape} vs {alpha.shape}")

    # Color bleeding under transparent texels prevents dark outlines after mipmapping.
    valid = alpha > 8
    if valid.any():
        nearest = distance_transform_edt(~valid, return_distances=False, return_indices=True)
        diffuse = diffuse[nearest[0], nearest[1]]
    rgba = np.dstack((diffuse, alpha))
    base_image = Image.fromarray(rgba, "RGBA").resize(SIZE, Image.Resampling.LANCZOS)

    # Normal maps are vector data. Downsample then renormalize in linear space.
    normal_image = Image.open(normal_path).convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
    normal = np.asarray(normal_image, dtype=np.float32) / 127.5 - 1.0
    normal /= np.maximum(np.linalg.norm(normal, axis=2, keepdims=True), 1e-6)
    normal = np.uint8(np.round(np.clip(normal * 0.5 + 0.5, 0.0, 1.0) * 255.0))
    normal_image = Image.fromarray(normal, "RGB")

    # Poly Haven ARM stores AO in R and roughness in G. Edge-dilate both from
    # the leaf alpha so mip filtering does not draw dark halos at cutout edges.
    arm = np.asarray(Image.open(arm_path).convert("RGB"), dtype=np.uint8)
    rough = arm[:, :, 1]
    ao = arm[:, :, 0]
    if valid.any():
        rough = rough[nearest[0], nearest[1]]
        ao = ao[nearest[0], nearest[1]]
    rough_resized = np.asarray(Image.fromarray(rough, "L").resize(SIZE, Image.Resampling.LANCZOS), dtype=np.uint8)
    ao_resized = np.asarray(Image.fromarray(ao, "L").resize(SIZE, Image.Resampling.LANCZOS), dtype=np.uint8)
    rough_image = Image.fromarray(np.dstack((rough_resized, ao_resized, rough_resized,
                                              np.full(SIZE, 255, dtype=np.uint8))), "RGBA")

    OUT.mkdir(parents=True, exist_ok=True)
    outputs = {
        "base_color": OUT / f"{species}_base_color.png",
        "normal_gl": OUT / f"{species}_normal_gl.png",
        "roughness": OUT / f"{species}_roughness.png",
    }
    for image, path in ((base_image, outputs["base_color"]),
                        (normal_image, outputs["normal_gl"]),
                        (rough_image, outputs["roughness"])):
        image.save(path, optimize=True)

    return {
        "polyhaven_asset_id": asset_id,
        "source_resolution": "2k",
        "runtime_resolution": list(SIZE),
        "source_maps": {
            diffuse_path.name: sha(diffuse_path),
            alpha_path.name: sha(alpha_path),
            normal_path.name: sha(normal_path),
            arm_path.name: sha(arm_path),
        },
        "runtime_maps": {key: {"path": str(path.relative_to(ROOT)), "sha256": sha(path), "bytes": path.stat().st_size}
                         for key, path in outputs.items()},
        "channels": {
            "base_color": "sRGB RGB from diffuse; alpha from Poly Haven alpha mask; transparent RGB edge-dilated before 1K resize",
            "normal_gl": "OpenGL tangent normal from Poly Haven nor_gl; vector-filtered and renormalized after resize",
            "roughness": "Linear roughness from ARM G packed in runtime red; ambient occlusion from ARM R packed in runtime green",
        },
    }


manifest_path = SOURCE / "download_manifest.json"
source_manifest = json.loads(manifest_path.read_text())
manifest = {
    "asset": "Bloedjungle_PolyHaven_Foliage_PBR",
    "license": source_manifest["license"],
    "license_url": source_manifest["license_url"],
    "provider": source_manifest["provider"],
    "api": source_manifest["api"],
    "runtime_texture_policy": "Three 1K PBR sets; one material per plant species; alpha-cutout, no blended foliage transparency.",
    "species": {species: build(species, asset_id) for species, asset_id in ASSETS.items()},
}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
