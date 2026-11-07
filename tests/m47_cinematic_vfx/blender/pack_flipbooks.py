"""Pack Cycles RGBA volume frames into Godot sprite sheets with soft cloud edges."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parents[1]
GRID = 4
SIZE = 192
y, x = np.mgrid[0:SIZE, 0:SIZE]
for kind in ("smoke", "dust"):
    atlas = Image.new("RGBA", (GRID * SIZE, GRID * SIZE))
    for frame in range(16):
        source = np.asarray(Image.open(OUT / "flipbooks" / kind / f"{frame:02d}.png").convert("RGBA"), dtype=np.float32).copy()
        cloud = np.zeros((SIZE, SIZE), dtype=np.float32)
        for lobe in range(8):
            phase = lobe * 2.39996 + frame * 0.07
            distance = 19 + (lobe % 3) * 12
            cx = 96 + np.cos(phase) * distance + (frame - 7) * 0.55
            cy = 99 + np.sin(phase) * distance - frame * 0.45
            rx = 24 + (lobe * 13 % 16)
            ry = 22 + (lobe * 17 % 21)
            cloud = np.maximum(cloud, np.exp(-(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2) * 0.65))
        cloud = np.clip((cloud - 0.11) * 1.25, 0, 1)
        source[:, :, 3] = np.clip(source[:, :, 3] * cloud * (2.1 if kind == "smoke" else 1.8), 0, 235)
        image = Image.fromarray(source.astype("uint8"), "RGBA")
        image = image.filter(ImageFilter.GaussianBlur(0.45))
        atlas.paste(image, ((frame % GRID) * SIZE, (frame // GRID) * SIZE))
    atlas.save(OUT / f"{kind}_atlas.png")
    print(kind, "atlas", atlas.size, "alpha range", atlas.getchannel("A").getextrema())
