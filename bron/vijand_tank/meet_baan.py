"""Meet de baan van de rupsband aan Dennis' Meshy-tank en schrijft baan.json: de buitenkant van de band als gesloten veelhoek (bronmaat, x/z).
De buitenste rand van de band (|y| 0,39 tot 0,415) bevat alleen schakels. Rond een met de hand afgelezen hartlijn (SCHETS) wordt per stukje baan
de buitenste afstand van de schakels gemeten; de mediaan daarvan is de halve schakeldikte, en de hartlijn plus die dikte is de baan (op gelijke afstand bemonsterd).
Gebruik: python3 meet_baan.py <bron.glb> [controleplaatje.png]"""
import sys, json, struct
import numpy as np
from pathlib import Path

# hartlijn van de schakels (x, z), afgelezen van de zijaanzichten; volgorde: bovenkant van voor naar achter, om het spanwiel, onderkant terug, om het aandrijfwiel
SCHETS = [(-0.316, -0.212), (-0.26, -0.226), (-0.10, -0.238), (0.15, -0.242), (0.45, -0.240), (0.60, -0.230), (0.68, -0.212), (0.735, -0.208),
          (0.785, -0.228), (0.816, -0.270), (0.822, -0.315), (0.800, -0.360), (0.750, -0.398), (0.690, -0.428), (0.620, -0.450), (0.40, -0.455),
          (0.0, -0.455), (-0.30, -0.455), (-0.364, -0.448), (-0.436, -0.416), (-0.495, -0.362), (-0.528, -0.300), (-0.520, -0.240),
          (-0.480, -0.195), (-0.428, -0.180), (-0.375, -0.192)]
BRON = Path(sys.argv[1])
f = open(BRON, "rb"); f.read(12)
n, _t = struct.unpack("<II", f.read(8)); j = json.loads(f.read(n))
f.read(8); basis = f.tell()
a = j["accessors"][j["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
bv = j["bufferViews"][a["bufferView"]]
f.seek(basis + bv.get("byteOffset", 0) + a.get("byteOffset", 0))
P = np.frombuffer(f.read(a["count"] * 12), np.float32).reshape(-1, 3)
x, y, z = P[:, 0], -P[:, 2], P[:, 1]          # Blender-assen na glTF-import: X = lengte (voor = -X), Y = breedte, Z = omhoog
m = (np.abs(y) > 0.39) & (np.abs(y) < 0.415) & (z < -0.15)
pp = np.stack([x[m], z[m]], 1).astype(np.float64)


def bemonster(pts, k):
    pts = np.asarray(pts, np.float64)
    d = np.hypot(*np.diff(np.vstack([pts, pts[:1]]), axis=0).T)
    cum = np.concatenate([[0], np.cumsum(d)])
    t = np.linspace(0, cum[-1], k, endpoint=False)
    return np.stack([np.interp(t, cum, np.append(pts[:, i], pts[0, i])) for i in range(2)], 1), cum[-1]


def glad(v, w):
    kern = np.ones(w) / w
    return np.convolve(np.concatenate([v[-w:], v, v[:w]]), kern, mode="same")[w:-w]


M = 480
hart, L0 = bemonster(SCHETS, M)
for _ in range(3):                                      # de schets zelf afronden
    hart = np.stack([glad(hart[:, 0], 9), glad(hart[:, 1], 9)], 1)
tang = np.roll(hart, -1, 0) - np.roll(hart, 1, 0)
tang /= np.linalg.norm(tang, axis=1)[:, None]
nor = np.stack([-tang[:, 1], tang[:, 0]], 1)            # naar buiten (de schets loopt met de klok mee gezien vanaf -Y: bovenkant naar +x)
if np.sum((hart - hart.mean(0)) * nor) < 0:
    nor = -nor
af = np.full(M, np.nan)
dichtst = np.empty(len(pp), np.int32); uit_n = np.empty(len(pp))
for s in range(0, len(pp), 20000):
    q = pp[s:s + 20000]
    d2 = ((q[:, None, :] - hart[None, :, :]) ** 2).sum(-1)
    i = d2.argmin(1); dichtst[s:s + 20000] = i
    uit_n[s:s + 20000] = ((q - hart[i]) * nor[i]).sum(1)
ok = np.abs(uit_n) < 0.03
for i in range(M):
    v = uit_n[ok & (dichtst == i)]
    if len(v) > 10:
        af[i] = np.percentile(v, 97)
idx = np.arange(M); g = ~np.isnan(af)
af = np.interp(idx, idx[g], af[g], period=M)
DIK = float(np.median(af))                                # de schakels zijn overal even dik; spatborden vlak boven de band storen de meting plaatselijk
af = np.full(M, DIK)
buiten = hart + nor * af[:, None]
K = 160
baan, L = bemonster(buiten, K)
uit = Path(__file__).resolve().parent / "baan.json"
uit.write_text(json.dumps({"lengte": round(float(L), 5), "punten": [[round(float(p), 5), round(float(q), 5)] for p, q in baan]}))
print("baan: %d punten, lengte %.4f (bronmaat), x %.3f..%.3f, z %.3f..%.3f, afstand hart->buiten %.4f..%.4f" % (
    K, L, baan[:, 0].min(), baan[:, 0].max(), baan[:, 1].min(), baan[:, 1].max(), af.min(), af.max()))
if len(sys.argv) > 2:
    from PIL import Image, ImageDraw
    S = 1250; x0, z1 = -0.58, -0.14
    H, _, _ = np.histogram2d(pp[:, 1], pp[:, 0], bins=(int(0.36 * S), int(1.44 * S)), range=((-0.50, -0.14), (x0, x0 + 1.44)))
    im = Image.fromarray(255 - np.clip(H * 60, 0, 255).astype(np.uint8)[::-1]).convert("RGB")
    dr = ImageDraw.Draw(im)
    pix = [((p - x0) * S, (z1 - q) * S) for p, q in baan]
    dr.line(pix + pix[:1], fill=(255, 0, 0), width=2)
    pix = [((p - x0) * S, (z1 - q) * S) for p, q in hart]
    dr.line(pix + pix[:1], fill=(0, 160, 0), width=1)
    im.save(sys.argv[2])
