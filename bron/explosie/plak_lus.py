"""Maakt van N + OVERLAP beelden een naadloze lus van N beelden (het einde vloeit over in het begin) en plakt ze tot één vel.
Gebruik:  python plak_lus.py <beeldmap> <voorvoegsel> <uitbestand.png> <cols> <rows> <px> <N>"""
import sys, glob
from PIL import Image
src, pre, dst, cols, rows, px, N = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), int(sys.argv[7])
files = sorted(glob.glob("%s/%s_*.png" % (src, pre)))
ims = [Image.open(f).convert("RGBA") for f in files]
O = len(ims) - N
assert O > 0 and cols * rows >= N
out = []
for i in range(N):
    if i < O:
        a = (i + 1) / (O + 1)  # begin van de lus: meer van het begin, minder van de staart
        out.append(Image.blend(ims[N + i], ims[i], a))
    else:
        out.append(ims[i])
sheet = Image.new("RGBA", (cols * px, rows * px), (0, 0, 0, 0))
for i, im in enumerate(out):
    r, g, b, a = im.split()
    z = Image.new("L", r.size, 0)
    pm = Image.merge("RGBA", (Image.composite(r, z, a), Image.composite(g, z, a), Image.composite(b, z, a), a)).resize((px, px), Image.LANCZOS)
    sheet.paste(pm, ((i % cols) * px, (i // cols) * px))
sheet.save(dst, optimize=True)
print(N, "beelden ->", dst, sheet.size)
