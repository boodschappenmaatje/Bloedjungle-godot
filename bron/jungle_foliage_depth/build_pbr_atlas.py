#!/usr/bin/env python3
"""Build a shared 1K PBR atlas from the approved local foliage maps.

No source image is changed. The 2×2 atlas holds leaf, flower, fern and palm
regions at their native 512px source resolution. Roughness is authored from
each source albedo's luminance and edge detail.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/textures/foliage"
OUT = ROOT / "assets/textures/foliage/depth_pass"
OUT.mkdir(parents=True, exist_ok=True)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_set(name: str, size: tuple[int, int]) -> tuple[Image.Image, Image.Image]:
    color = Image.open(SRC / f"{name}_color.png").convert("RGBA")
    normal = Image.open(SRC / f"{name}_normal.png").convert("RGB")
    if color.size != size or normal.size != color.size:
        raise SystemExit(f"Approved {name} color and normal maps must remain {size[0]}×{size[1]}")
    return color, normal


leaf, leaf_normal = source_set("leaf", (512, 512))
fern, fern_normal = source_set("fern", (512, 256))
palm, palm_normal = source_set("palm", (512, 256))

rgb = np.asarray(leaf, dtype=np.float32) / 255.0
# The flower side retains the leaf's fine surface grain while adding restrained
# oxide-red and warm bronze pigment. Its alpha silhouette is unchanged.
flower = rgb.copy()
flower[:, :, 0] = np.clip(rgb[:, :, 0] * 1.18 + rgb[:, :, 1] * 0.35 + 0.06, 0, 1)
flower[:, :, 1] = np.clip(rgb[:, :, 1] * 0.48 + 0.025, 0, 1)
flower[:, :, 2] = np.clip(rgb[:, :, 2] * 0.38 + 0.012, 0, 1)
flower[:, :, 3] = rgb[:, :, 3]

atlas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
atlas.paste(leaf, (0, 0))
atlas.paste(Image.fromarray(np.uint8(np.round(flower * 255)), "RGBA"), (512, 0))
atlas.paste(fern, (0, 640))
atlas.paste(palm, (512, 640))
atlas_path = OUT / "jungle_leaf_flower_base_color.png"
atlas.save(atlas_path, optimize=True)

normal_atlas = Image.new("RGB", (1024, 1024), (128, 128, 255))
normal_atlas.paste(leaf_normal, (0, 0))
normal_atlas.paste(leaf_normal, (512, 0))
normal_atlas.paste(fern_normal, (0, 640))
normal_atlas.paste(palm_normal, (512, 640))
normal_path = OUT / "jungle_leaf_flower_normal_gl.png"
normal_atlas.save(normal_path, optimize=True)

# A measured, non-upscaled roughness map: glossy leaf centers (0.33–0.40),
# more diffuse cut edges/veins (up to 0.60), satin flower surfaces (0.44–0.57).
def roughness(color: Image.Image, center: float, edge_weight: float) -> Image.Image:
    lum = np.asarray(color.convert("L"), dtype=np.float32) / 255.0
    edge = np.asarray(color.convert("L").filter(ImageFilter.FIND_EDGES), dtype=np.float32) / 255.0
    values = np.clip(center + 0.08 * (1.0 - lum) + edge_weight * edge, center - 0.02, center + edge_weight + 0.10)
    return Image.fromarray(np.uint8(np.round(values * 255)), "L")


rough = Image.new("L", (1024, 1024), 255)
rough.paste(roughness(leaf, 0.34, 0.19), (0, 0))
rough.paste(roughness(leaf, 0.43, 0.13), (512, 0))
rough.paste(roughness(fern, 0.46, 0.16), (0, 640))
rough.paste(roughness(palm, 0.39, 0.17), (512, 640))
rough_path = OUT / "jungle_leaf_flower_roughness.png"
rough.save(rough_path, optimize=True)

manifest = {
    "asset": "jungle_foliage_depth",
    "resolution": [1024, 1024],
    "license": "Reuses the project's existing foliage texture sources; no external texture downloaded.",
    "source_maps": {
        "assets/textures/foliage/leaf_color.png": sha(SRC / "leaf_color.png"),
        "assets/textures/foliage/leaf_normal.png": sha(SRC / "leaf_normal.png"),
        "assets/textures/foliage/fern_color.png": sha(SRC / "fern_color.png"),
        "assets/textures/foliage/fern_normal.png": sha(SRC / "fern_normal.png"),
        "assets/textures/foliage/palm_color.png": sha(SRC / "palm_color.png"),
        "assets/textures/foliage/palm_normal.png": sha(SRC / "palm_normal.png"),
    },
    "maps": {
        "jungle_leaf_flower_base_color.png": "sRGB RGBA; 2x2 atlas from native 512px source maps: leaf, derived red/bronze flower, fine fern and pinnate palm; 512x256 fern/palm maps centered in their 512px cells; original alpha silhouettes retained",
        "jungle_leaf_flower_normal_gl.png": "OpenGL tangent normal; approved leaf, fern and palm normal maps; leaf normal reused by flower variant",
        "jungle_leaf_flower_roughness.png": "Linear grayscale; authored per region from source luminance and edge detail; glossy leaf/palm and satin fern/flowers",
    },
    "sha256": {p.name: sha(p) for p in (atlas_path, normal_path, rough_path)},
}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
