"""Optional cinematic bloom/color pass over archived raw Godot frames.

The source PNGs and raw video remain unchanged and are the engine evidence.
"""
from pathlib import Path
import sys
import numpy as np
from PIL import Image, ImageChops, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "frames"
DEST = ROOT / "graded_frames"
DEST.mkdir(exist_ok=True)
files = sorted(SOURCE.glob("frame_*.png"))
if "--single" in sys.argv:
    files = [SOURCE / "frame_0130.png"]
if not files:
    raise SystemExit("No Godot frames found")

width, height = 1280, 720
yy, xx = np.mgrid[0:height, 0:width]
radial = np.sqrt(((xx - width/2)/(width/2))**2 + ((yy-height/2)/(height/2))**2)
vignette = np.clip(1.06 - 0.23 * radial**1.6, 0.72, 1.0).astype(np.float32)

for file in files:
    raw = Image.open(file).convert("RGB")
    base = ImageEnhance.Contrast(raw).enhance(1.11)
    base = ImageEnhance.Color(base).enhance(1.08)
    arr = np.asarray(base, dtype=np.float32).copy()
    arr *= vignette[:, :, None]
    base = Image.fromarray(np.clip(arr, 0, 255).astype("uint8"), "RGB")
    highlights = base.point(lambda x: max(0, min(255, int((x - 175) * 2.9))))
    bloom = highlights.filter(ImageFilter.GaussianBlur(15))
    bloom = ImageEnhance.Brightness(bloom).enhance(1.3)
    graded = ImageChops.screen(base, bloom)
    graded.save(DEST / file.name)
print("graded", len(files), "frames in", DEST)
