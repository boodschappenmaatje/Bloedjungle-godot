#!/usr/bin/env python3
"""Photographic terrain maps at their existing 1K storage resolution; sources stay intact.

Pack existing OpenGL normal RGB + true roughness alpha into one linear map per
layer. Existing source-resolution limits are recorded; no further enlargement.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/textures/terrain"
OUT = ROOT / "assets/textures/world_ground"
LAYERS = {
    # Low-frequency colour and the original photo grain remain; suppress crunchy microcontrast.
    "earth": ("dry_earth", (1.02, 1.01, 0.97), 0.72, 0.70, 0.98),
    "gravel": ("gravel_rock", (0.93, 0.98, 1.04), 0.72, 0.72, 0.98),
    "mud": ("mud", (0.92, 0.86, 0.77), 0.82, 0.30, 0.74),
    "grass": ("grass", (0.78, 0.87, 0.77), 0.82, 0.78, 0.98),
    "litter": ("jungle_ground", (0.78, 0.81, 0.70), 0.78, 0.76, 0.98),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    licenses = json.loads((ROOT / "assets/licenses/downloaded_assets.json").read_text())
    report = {"license": "CC0-1.0", "resolution": [1024, 1024],
              "method": "Existing photographic albedo: contrast around image mean and restrained tint. Original normal RGB; original roughness remapped into alpha. No height map claimed; no enlargement in this build.",
              "linear_packed_channels": "RGB = OpenGL normal; A = roughness; import as data, not normal-only compression",
              "layers": {}}
    for name, (source, tint, contrast, rmin, rmax) in LAYERS.items():
        folder = SOURCE / source
        paths = [folder / n for n in ("base_color.jpg", "normal_gl.jpg", "roughness.jpg")]
        assert all(p.is_file() for p in paths)
        assert all(Image.open(p).size == (1024, 1024) for p in paths)
        for p in paths:
            entry = licenses[str(p.relative_to(ROOT))]
            assert entry["license"] == "CC0-1.0"
        rgb = np.asarray(Image.open(paths[0]).convert("RGB"), dtype=np.float32) / 255.0
        mean = rgb.mean(axis=(0, 1), keepdims=True)
        rgb = np.clip((mean + (rgb - mean) * contrast) * np.array(tint), 0, 1)
        albedo = OUT / (name + "_albedo.jpg")
        Image.fromarray(np.uint8(rgb * 255)).save(albedo, quality=94, subsampling=0)
        normal = np.asarray(Image.open(paths[1]).convert("RGB"))
        rough = np.asarray(Image.open(paths[2]).convert("L"), dtype=np.float32) / 255.0
        # Preserve measured source variation. The layer bounds represent dry versus damp surface.
        alpha = np.uint8(np.clip(rmin + rough * (rmax-rmin), 0, 1) * 255)
        packed = OUT / (name + "_normal_roughness.png")
        Image.fromarray(np.dstack((normal, alpha))).save(packed, optimize=True)
        report["layers"][name] = {"source_directory": str(folder.relative_to(ROOT)),
            "source_sha256": {p.name: digest(p) for p in paths},
            "prior_manifest_sha256": {p.name: licenses[str(p.relative_to(ROOT))]["sha256"] for p in paths},
            "source_effective_resolution": {p.name: licenses[str(p.relative_to(ROOT))].get("effective_resolution", "See original source dimensions") for p in paths},
            "source_size_before_prior_repository_conversion": {p.name: licenses[str(p.relative_to(ROOT))].get("source_size", [1024, 1024]) for p in paths},
            "source_urls": {p.name: licenses[str(p.relative_to(ROOT))]["source_url"] for p in paths},
            "albedo_tint": tint, "albedo_contrast": contrast, "roughness_range": [rmin, rmax],
            "outputs_sha256": {p.name: digest(p) for p in (albedo, packed)}}
    (OUT / "provenance.json").write_text(json.dumps(report, indent=2) + "\n")
    print("World ground: five existing photographic layers, 1024px storage; effective source limits recorded, normal/roughness packed")


if __name__ == "__main__":
    build()
