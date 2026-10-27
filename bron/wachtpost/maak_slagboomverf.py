"""Rood-wit afgesleten verf voor de slagboomarm (Bloedjungle VQ2): albedo, OpenGL-normal en ORM, 1024x512.
U loopt 1 m langs de arm (0,5 m rood + 0,5 m wit), V is dwars. Eigen ruis (numpy), geen externe bron: geen licentie nodig.
Gebruik: python3 maak_slagboomverf.py [uitmap]  ->  slagboomverf_{albedo.jpg,normal.jpg,orm.png}"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / "uit"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1024, 512
rng = np.random.default_rng(11)


def noise(scale, seed):
    r = np.random.default_rng(seed)
    n = r.random((H // scale + 2, W // scale + 2))
    img = Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0


def fbm(seed):
    return 0.5 * noise(64, seed) + 0.3 * noise(16, seed + 1) + 0.2 * noise(4, seed + 2)


u = np.linspace(0, 1, W, endpoint=False)[None, :].repeat(H, 0)
v = np.linspace(0, 1, H, endpoint=False)[:, None].repeat(W, 1)
band = (u % 1.0) < 0.5
red = np.array([0.58, 0.08, 0.06])
white = np.array([0.64, 0.63, 0.56])
paint = np.where(band[..., None], red, white)
# vuil en regenstrepen (langs V), vlekken
dirt = fbm(20)
paint *= (0.82 + 0.3 * dirt)[..., None]
drip = np.asarray(Image.fromarray((np.random.default_rng(3).random((1, W // 3 + 2)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255.0
paint *= (1.0 - 0.18 * np.clip((drip - 0.55) * 3, 0, 1) * (0.4 + 0.6 * v))[..., None]
# afgesleten verf: staal komt door op de randen (V dicht bij 0 en 1) en op losse plekken
edge = np.minimum(v, 1 - v) * 2
chip = (fbm(40) > 0.80 - 0.26 * (1 - np.clip(edge * 4, 0, 1))).astype(np.float32)
steel = np.array([0.22, 0.23, 0.22]) * (0.7 + 0.5 * noise(2, 9))[..., None]
alb = paint * (1 - chip[..., None]) + steel * chip[..., None]
# roestrand rond de afgesleten plekken
rust = np.clip(np.asarray(Image.fromarray((chip * 255).astype(np.uint8)).resize((W // 2, H // 2)).filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(3)).resize((W, H)), np.float32) / 255.0 - chip, 0, 1)
alb = alb * (1 - 0.5 * rust[..., None]) + np.array([0.33, 0.17, 0.08]) * 0.5 * rust[..., None]
Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(OUT / "slagboomverf_albedo.jpg", quality=92)
# normal: verf licht, ruwe plekken waar de verf weg is
h = 0.6 * fbm(30) + 0.4 * chip * -1 + 0.1 * noise(2, 17)
gy, gx = np.gradient(h)
n = np.stack([-gx * 6, gy * 6, np.ones_like(h)], -1)
n /= np.linalg.norm(n, axis=-1, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(OUT / "slagboomverf_normal.jpg", quality=92)
# ORM: R = occlusion, G = roughness, B = metallic (alleen waar het staal bloot ligt)
rough = np.where(chip > 0, 0.55, 0.72) + 0.1 * fbm(50)
orm = np.stack([np.full_like(h, 0.95), np.clip(rough, 0, 1), chip * 0.8], -1)
Image.fromarray((orm * 255).astype(np.uint8)).save(OUT / "slagboomverf_orm.png")
print("slagboomverf klaar", OUT)
