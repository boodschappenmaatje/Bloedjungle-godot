"""Create transparent blue-white optical flare cards for the Godot test scene."""
from pathlib import Path
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1]
size = 256
axis = np.linspace(-1, 1, size, dtype=np.float32)
x, y = np.meshgrid(axis, axis)
radius = np.sqrt(x*x + y*y)
core = np.exp(-radius**2 / 0.011)
halo = np.exp(-radius**2 / 0.19) * 0.34
rays = np.zeros_like(radius)
for angle in np.arange(0, np.pi, np.pi / 6):
    along = np.abs(x * np.cos(angle) + y * np.sin(angle))
    across = np.abs(-x * np.sin(angle) + y * np.cos(angle))
    spike = np.exp(-across**2 / (0.00025 + 0.0015*along)) * np.exp(-along*4.4)
    rays = np.maximum(rays, spike)
alpha = np.clip(core*1.3 + rays*0.9 + halo, 0, 1)
white_mix = np.clip(core*1.6 + rays*0.45, 0, 1)
rgba = np.zeros((size, size, 4), dtype=np.uint8)
rgba[:, :, 0] = (55 + 200*white_mix).astype(np.uint8)
rgba[:, :, 1] = (160 + 95*white_mix).astype(np.uint8)
rgba[:, :, 2] = 255
rgba[:, :, 3] = (alpha * 255).astype(np.uint8)
Image.fromarray(rgba, "RGBA").save(OUT / "blue_white_flare.png")
print("flare alpha range", int(rgba[:, :, 3].min()), int(rgba[:, :, 3].max()))
