"""Zet de losse beelden vuur_000.png ... tot één vel (cols x rows) en verkleint ze (dat dempt ook de ruis).
Gebruik:  python plak.py <beeldmap> <voorvoegsel> <uitbestand.png> <cols> <rows> <px>"""
import sys, glob
from PIL import Image
src, pre, dst, cols, rows, px = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
files = sorted(glob.glob("%s/%s_*.png" % (src, pre)))[: cols * rows]
# gezamenlijke inhoud van alle beelden: alles daarbuiten is leeg en kost op een telefoon alleen tekentijd
import numpy as np
union = None
for f in files:
    m = np.array(Image.open(f).convert("RGBA").split()[3]) > 40
    union = m if union is None else (union | m)
# losse puntjes (ruis) tellen niet mee: een rij of kolom telt pas bij minstens 6 beeldpunten
rows_ok = np.where(union.sum(axis=1) >= 6)[0]
cols_ok = np.where(union.sum(axis=0) >= 6)[0]
box = (int(cols_ok[0]), int(rows_ok[0]), int(cols_ok[-1]) + 1, int(rows_ok[-1]) + 1)
W0 = Image.open(files[0]).size[0]
pad = int(W0 * 0.02)
box = (max(0, box[0] - pad), max(0, box[1] - pad), min(W0, box[2] + pad), min(W0, box[3] + pad))
cw = px
ch = round(px * (box[3] - box[1]) / (box[2] - box[0]))
print("uitsnede (fractie van het beeld): x %.3f-%.3f  y(van boven) %.3f-%.3f" % (box[0] / W0, box[2] / W0, box[1] / W0, box[3] / W0))
sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
for i, f in enumerate(files):
    im = Image.open(f).convert("RGBA").crop(box)
    # eerst in premultiplied ruimte verkleinen, zodat transparante randen niet donker uitlopen
    r, g, b, a = im.split()
    pm = Image.merge("RGBA", (Image.composite(r, Image.new("L", r.size, 0), a), Image.composite(g, Image.new("L", g.size, 0), a), Image.composite(b, Image.new("L", b.size, 0), a), a))
    pm = pm.resize((cw, ch), Image.LANCZOS)
    sheet.paste(pm, ((i % cols) * cw, (i // cols) * ch))
sheet.save(dst, optimize=True)
print(len(files), "beelden ->", dst, sheet.size)
