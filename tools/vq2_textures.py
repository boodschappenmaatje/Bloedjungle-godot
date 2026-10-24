#!/usr/bin/env python3
"""Derive native 1024px VQ2 PBR sets from the repository's licensed CC0 photographs.

No enlargement, downloads or paid generation. All inputs remain untouched.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/textures"
OUT = BASE / "vq2"
SETS = {
    "painted_timber": ("buildings/weathered_wood", (0.25, 0.31, 0.18), 0.0),
    "timber": ("buildings/weathered_wood", (0.34, 0.28, 0.19), 0.0),
    "roof": ("buildings/corrugated_iron", (0.34, 0.38, 0.32), 0.58),
    "concrete": ("buildings/concrete", (0.35, 0.35, 0.31), 0.0),
    "canvas": ("buildings/jute", (0.53, 0.48, 0.33), 0.0),
    "olive": ("buildings/army_green_paint", (0.37, 0.42, 0.26), 0.15),
    "steel": ("buildings/metal", (0.34, 0.36, 0.33), 0.80),
}


def build():
    provenance = {"license": "CC0-1.0", "resolution": [1024, 1024],
                  "method": "Native-resolution photographic PBR derivation; seeded directional rain/mud and edge-wear masks, no upscaling.",
                  "inputs_license_manifest": "assets/licenses/downloaded_assets.json", "sets": {}}
    rng = np.random.default_rng(5320)
    yy, xx = np.mgrid[0:1024, 0:1024] / 1023
    for name, (source, tint, metal) in SETS.items():
        dst = OUT / name
        dst.mkdir(parents=True, exist_ok=True)
        original = BASE / source
        color_img = Image.open(original / "base_color.jpg").convert("RGB")
        assert color_img.size == (1024, 1024), (source, color_img.size)
        rgb = np.asarray(color_img, dtype=np.float32) / 255
        lum = rgb @ np.array([.2126, .7152, .0722])
        lum = np.clip(lum / max(float(lum.mean()), .01), .3, 1.8)
        col = np.array(tint)[None, None, :] * (lum[..., None] * .55 + .45)
        rough = np.asarray(Image.open(original / "roughness.jpg").convert("L"), dtype=np.float32) / 255
        metallic = np.full_like(rough, metal)
        if name in ("painted_timber", "timber"):
            # Photo grain is retained under a thin, faded coat; exposed fibers remain brown.
            wear = np.clip((.82 - lum) * 1.4, 0, .45)
            if name == "painted_timber":
                col = col * (1 - wear[..., None]) + np.array([.30, .24, .16]) * wear[..., None]
            rain = np.zeros(1024)
            for _ in range(24):
                at = rng.integers(0, 1024)
                rain += np.exp(-((np.arange(1024)-at)/rng.uniform(2, 8))**2) * rng.uniform(.02, .10)
            stain = rain[None, :] * (1 - yy)**2 + .16 * np.exp(-yy * 13)
            col *= 1 - stain[..., None]
            rough = np.clip(rough * .35 + .60, .62, .97)
        elif name == "roof":
            # Controlled oxidation at sheet joints, rather than uniform rust everywhere.
            seam = np.exp(-(xx/.022)**2) + np.exp(-((1-xx)/.022)**2)
            rust = np.clip(seam * (.25 + .60 * yy) + np.clip(.65-lum, 0, .15), 0, .8)
            col = col * (1-rust[..., None]) + np.array([.29, .17, .09]) * rust[..., None]
            metallic *= 1-rust
            rough = np.clip(.50 + rough * .22 + rust * .25, .45, .95)
        elif name == "olive":
            edge = np.exp(-np.minimum(xx, 1-xx)/.009)
            chips = edge * np.clip((lum-.75)*2, 0, 1)
            col = col*(1-chips[..., None]) + np.array([.33, .30, .22])*chips[..., None]
            rough = np.clip(.48 + rough*.30, .45, .87)
            metallic = .06 + .55*chips
        elif name == "concrete":
            col *= 1 - (.14 * np.exp(-yy*10))[..., None]
            rough = np.clip(.68 + rough*.24, .7, .98)
        elif name == "canvas":
            rough[:] = .94
        color = Image.fromarray(np.uint8(np.clip(col, 0, 1)*255))
        color.save(dst / "albedo.jpg", quality=94, subsampling=0)
        # The source normal map retains its native photographic relief and OpenGL convention.
        Image.open(original / "normal_gl.jpg").convert("RGB").save(dst / "normal.jpg", quality=96, subsampling=0)
        orm = np.stack((np.ones_like(rough), rough, metallic), axis=-1)
        Image.fromarray(np.uint8(np.clip(orm, 0, 1)*255)).save(dst / "orm.png", optimize=True)
        provenance["sets"][name] = {
            "source_directory": str(original.relative_to(ROOT)),
            "source_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in original.glob("*.jpg")},
            "output_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in dst.iterdir() if p.suffix in (".jpg", ".png")},
        }
    (OUT / "provenance.json").write_text(json.dumps(provenance, indent=2)+"\n")
    print("VQ2: 7 photographic PBR sets, native 1024px; provenance.json written")


if __name__ == "__main__":
    build()
