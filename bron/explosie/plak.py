"""Zet de losse beelden vuur_000.png ... tot één vel (cols x rows) en verkleint ze (dat dempt ook de ruis).
Gebruik:  python plak.py <beeldmap> <voorvoegsel> <uitbestand.png> <cols> <rows> <px>"""
import sys, glob
from PIL import Image
src, pre, dst, cols, rows, px = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
files = sorted(glob.glob("%s/%s_*.png" % (src, pre)))[: cols * rows]
sheet = Image.new("RGBA", (cols * px, rows * px), (0, 0, 0, 0))
for i, f in enumerate(files):
    im = Image.open(f).convert("RGBA")
    # eerst in premultiplied ruimte verkleinen, zodat transparante randen niet donker uitlopen
    r, g, b, a = im.split()
    pm = Image.merge("RGBA", (Image.composite(r, Image.new("L", r.size, 0), a), Image.composite(g, Image.new("L", g.size, 0), a), Image.composite(b, Image.new("L", b.size, 0), a), a))
    pm = pm.resize((px, px), Image.LANCZOS)
    sheet.paste(pm, ((i % cols) * px, (i // cols) * px))
sheet.save(dst, optimize=True)
print(len(files), "beelden ->", dst, sheet.size)
