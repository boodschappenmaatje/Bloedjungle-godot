"""Make one same-framing strip: supplied target, original 5.1, refined 5.2."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parents[1]
REFERENCE = OUT.parent / "m47_photoreal_vfx5/reference/M47_VFX_2_1_TARGET.jpg"
RENDER_51 = OUT / "renders/M47_Impact_Hero_Cycles.png"
RENDER_52 = OUT / "renders/M47_Impact_Hero_Cycles_5_2.png"
OUTPUT = OUT / "renders/impact_5_1_5_2_vs_target.png"

sheet = Image.open(REFERENCE).convert("RGB")
target = sheet.crop((0, 335, 612, 575))

def crop_render(path):
    image = Image.open(path).convert("RGB")
    crop_h = round(image.width / (612 / 240))
    center_y = image.height // 2
    return image.crop((0, center_y - crop_h // 2, image.width, center_y + crop_h // 2))

panel_w, panel_h, heading_h = 800, 314, 56
panels = [target, crop_render(RENDER_51), crop_render(RENDER_52)]
panels = [im.resize((panel_w, panel_h), Image.Resampling.LANCZOS) for im in panels]
board = Image.new("RGB", (panel_w * 3, panel_h + heading_h + 12), (6, 14, 22))
draw = ImageDraw.Draw(board)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except OSError:
    font = ImageFont.load_default()
labels = ("DOELBEELD — IMPACTPANEEL 4", "BLENDER CYCLES — HERO STILL 5.1", "BLENDER CYCLES — HERO STILL 5.2")
for i, (label, panel) in enumerate(zip(labels, panels)):
    x = i * panel_w
    draw.text((x + 18, 16), label, fill=(180, 226, 246), font=font)
    board.paste(panel, (x, heading_h))
board.save(OUTPUT, quality=96)
print(f"saved {OUTPUT} — target, 5.1, 5.2 same impact crop")
