"""Build side-by-side 2.1/2.2 review PNGs from the matching camera renders."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT / 'previews/airfield_hq/v21_review'
NEW = ROOT / 'previews/airfield_hq/v22_review'
SHOTS = ('01_hangar_exterior', '02_hangar_interior_doors_open',
         '03_control_tower', '04_runway_approach')

try:
    font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 25)
except OSError:
    font = ImageFont.load_default()

for name in SHOTS:
    left = Image.open(OLD / f'v21_{name}.png').convert('RGB')
    right = Image.open(NEW / f'v22_{name}.png').convert('RGB')
    assert left.width * right.height == right.width * left.height, name
    if left.size != right.size:
        left = left.resize(right.size, Image.Resampling.LANCZOS)
    canvas = Image.new('RGB', (left.width * 2, left.height + 48), '#20242a')
    canvas.paste(left, (0, 48))
    canvas.paste(right, (left.width, 48))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 9), 'Airfield HQ 2.1', font=font, fill='white')
    draw.text((left.width + 24, 9), 'Airfield HQ 2.2', font=font, fill='white')
    target = NEW / f'compare_{name}.png'
    canvas.save(target, optimize=True)
    print(target.relative_to(ROOT))
