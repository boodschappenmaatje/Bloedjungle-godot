"""Make detail crops and an honest VFX 2.1 / VFX 4.0 / target-criteria board.

The target supplied in chat is a multi-panel collage without a local source
file, so the third column is explicitly a criteria card, not a fake image.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "screenshots"
OLD = ROOT / "tests/m47_vfx/screenshots"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size):
    return ImageFont.truetype(FONT, size)


def crop_detail(name, file, cx, cy):
    image = Image.open(OUT / file).convert("RGB")
    w, h = 480, 300
    left = max(0, min(image.width - w, cx - w // 2))
    top = max(0, min(image.height - h, cy - h // 2))
    detail = image.crop((left, top, left + w, top + h)).resize((1152, 720), Image.Resampling.LANCZOS)
    detail.save(OUT / f"detail_{name}.png")


for name, file, cx, cy in [
    ("core", "cinematic_049.png", 456, 384),
    ("muzzle", "cinematic_098.png", 520, 384),
    ("projectile", "cinematic_109.png", 655, 350),
    ("impact", "cinematic_130.png", 810, 325),
    ("debris", "cinematic_148.png", 805, 365),
    ("permanent_breach", "cinematic_244.png", 810, 364),
]:
    crop_detail(name, file, cx, cy)

board = Image.new("RGB", (1920, 810), (8, 19, 26))
draw = ImageDraw.Draw(board)
heading = font(20)
body = font(17)
draw.text((18, 11), "M-47 VFX 2.1  →  CINEMATIC VFX 4.0  |  vergelijkingscamera (-0.4, 5.6, 7.2), FOV 47°", font=heading, fill=(205, 230, 236))
headers = ["VOOR  ·  PR #239", "NA  ·  cinematic 4.0", "DOELBEELD  ·  kwaliteitslat"]
for index, title in enumerate(headers):
    x = index * 640
    draw.rectangle((x + 2, 46, x + 637, 78), fill=(15, 46, 61))
    draw.text((x + 18, 53), title, font=body, fill=(113, 221, 244))

images = [
    (OLD / "after_vfx21_projectile.png", 0, 79),
    (OLD / "after_vfx21_impact.png", 0, 439),
    (OUT / "cinematic_109.png", 640, 79),
    (OUT / "cinematic_130.png", 640, 439),
]
for path, x, y in images:
    image = Image.open(path).convert("RGB").resize((640, 360), Image.Resampling.LANCZOS)
    board.paste(image, (x, y))

draw.rectangle((1282, 80, 1918, 798), fill=(11, 29, 39), outline=(37, 131, 155), width=2)
criteria = [
    "De oorspronkelijke referentie is een",
    "collage met meerdere camerakaders.",
    "Er is geen lokaal afbeeldingsbestand",
    "voor een pixelvergelijking.",
    "",
    "Gewenste kenmerken:",
    "• Heldere blauw-witte sterflits",
    "• Duidelijk draaiende kern",
    "• Gesegmenteerd energieprojectiel",
    "• Elektrische draden en rookspiraal",
    "• Lichtgevende zeshoekige schokgolf",
    "• Volumineus stof en echte brokstukken",
    "• Onregelmatige permanente doorgang",
    "",
    "De twee beeldkolommen gebruiken wel",
    "exact dezelfde Godot-camera en FOV.",
]
for i, line in enumerate(criteria):
    draw.text((1302, 103 + i * 34), line, font=body, fill=(190, 218, 221))
board.save(OUT / "comparison_v21_v40_target_notes.png")
print("created six detail crops and comparison board")
