"""Create a direct visual comparison of the target impact panel and the final still."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parents[1]
REFERENCE = OUT.parent / "m47_photoreal_vfx5/reference/M47_VFX_2_1_TARGET.jpg"
RENDER = OUT / "renders/M47_Impact_Hero_Cycles.png"
OUTPUT = OUT / "renders/impact_vs_target.png"

target_sheet = Image.open(REFERENCE).convert("RGB")
render = Image.open(RENDER).convert("RGB")

# Panel 4 in the supplied 1280x720 storyboard: image area below its caption.
target = target_sheet.crop((0, 335, 612, 575))
# Center the impact on the same wide 2.55:1 aspect as the source panel.
crop_h = round(render.width / (612 / 240))
center_y = render.height // 2
render_crop = render.crop((0, center_y - crop_h // 2, render.width, center_y + crop_h // 2))

panel_w, panel_h = 960, 376
target = target.resize((panel_w, panel_h), Image.Resampling.LANCZOS)
render_crop = render_crop.resize((panel_w, panel_h), Image.Resampling.LANCZOS)
board = Image.new("RGB", (panel_w * 2 + 64, panel_h + 90), (7, 15, 23))
draw = ImageDraw.Draw(board)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
except OSError:
    font = ImageFont.load_default()
draw.text((24, 18), "DOELBEELD — IMPACTPANEEL 4", fill=(180, 226, 246), font=font)
draw.text((panel_w + 48, 18), "BLENDER CYCLES — M-47 IMPACT HERO 5.1", fill=(180, 226, 246), font=font)
board.paste(target, (0, 68))
board.paste(render_crop, (panel_w + 64, 68))
board.save(OUTPUT, quality=95)
print(f"saved {OUTPUT} from {REFERENCE} and {RENDER}")
