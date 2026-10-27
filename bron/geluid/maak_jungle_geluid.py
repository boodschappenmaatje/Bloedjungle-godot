#!/usr/bin/env python3
"""Maakt de jungle-geluiden voor scripts/jungle_geluid.gd, helemaal uit code (geen opnames).

    python3 bron/geluid/maak_jungle_geluid.py [--voorbeeld map]

Schrijft naar assets/geluid/jungle/:
  achter_dag.wav, achter_nacht.wav, achter_water.wav   lussen (achtergrond) die naadloos herhalen
  roep_<soort>_<n>.wav                                 losse roepen die het spel tussen de bomen afspeelt
Met --voorbeeld komen er ook twee mixen van 30 s bij (dag en nacht) om te beluisteren.

Echte opnames later: zet een .ogg of .wav met dezelfde naam-begin (bijv. roep_fluit_4.ogg of achter_dag.ogg)
in assets/geluid/jungle/; jungle_geluid.gd pakt alles op wat met die namen begint.
Alleen numpy nodig. Vaste zaadjes: elke run geeft dezelfde bestanden.
"""
import math
import os
import sys
import wave

import numpy as np

R = 24000
HIER = os.path.dirname(os.path.abspath(__file__))
UIT = os.path.normpath(os.path.join(HIER, "..", "..", "assets", "geluid", "jungle"))


# ------------------------------------------------------------------ bouwstenen

def tijd(sec):
    return np.arange(int(sec * R)) / R


def biquad_bp(x, f, q):
    """Banddoorlaat (RBJ), 0 dB in de top."""
    w = 2 * math.pi * f / R
    al = math.sin(w) / (2 * q)
    b0, b2 = al, -al
    a0, a1, a2 = 1 + al, -2 * math.cos(w), 1 - al
    return _iir(x, b0 / a0, 0.0, b2 / a0, a1 / a0, a2 / a0)


def biquad_lp(x, f, q=0.707):
    w = 2 * math.pi * f / R
    al = math.sin(w) / (2 * q)
    c = math.cos(w)
    a0 = 1 + al
    return _iir(x, (1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0, -2 * c / a0, (1 - al) / a0)


def _iir(x, b0, b1, b2, a1, a2):
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    xs = x.tolist()
    ys = [0.0] * len(xs)
    for i, v in enumerate(xs):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        ys[i] = o
    y[:] = ys
    return y


def ruis(rng, n):
    return rng.uniform(-1, 1, n)


def fase(freq):
    """Faselijn voor een toon waarvan de hoogte verloopt (freq is een array in Hz)."""
    return np.cumsum(2 * math.pi * freq / R)


def hann(n):
    return 0.5 - 0.5 * np.cos(2 * math.pi * np.arange(n) / max(1, n - 1))


def omhulsel(n, aan=0.01, uit=0.08):
    e = np.ones(n)
    a = min(n, int(aan * R))
    u = min(n - a, int(uit * R))
    if a:
        e[:a] = np.linspace(0, 1, a) ** 1.5
    if u:
        e[n - u:] = np.linspace(1, 0, u) ** 2
    return e


def galm(x, rng, lengte=0.7, nat=0.28):
    """Bosgalm: korte, donkere nagalm (ruis-impuls die uitsterft), zodat roepen tussen de bomen klinken."""
    n = int(lengte * R)
    imp = ruis(rng, n) * np.exp(-np.arange(n) / (0.16 * R))
    imp = biquad_lp(imp, 2600)
    imp /= np.sqrt(np.sum(imp ** 2)) + 1e-9
    m = len(x) + n
    k = 1 << (m - 1).bit_length()
    nat_sig = np.fft.irfft(np.fft.rfft(x, k) * np.fft.rfft(imp, k), k)[:m]
    droog = np.concatenate([x, np.zeros(n)])
    return droog * (1 - nat) + nat_sig * nat * 2.2


def lus(sig, overloop):
    """Maakt een naadloze lus: het laatste stuk (overloop samples) vloeit over in het begin."""
    n = len(sig) - overloop
    uit = sig[:n].copy()
    k = np.linspace(0, 1, overloop)
    uit[:overloop] = sig[n:] * np.sqrt(1 - k) + sig[:overloop] * np.sqrt(k)
    return uit


def normaal(sig, top):
    m = np.max(np.abs(sig)) + 1e-9
    return sig * (top / m)


def schrijf(naam, sig):
    os.makedirs(UIT, exist_ok=True)
    pad = os.path.join(UIT, naam + ".wav")
    _wav(pad, sig)
    return pad


def _wav(pad, sig):
    data = np.clip(np.round(sig * 32767), -32768, 32767).astype("<i2")
    with wave.open(pad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(R)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ achtergronden (lussen)

def achter_dag():
    rng = np.random.default_rng(101)
    L, F = 10.0, 0.6
    t = tijd(L + F)
    n = len(t)
    # cicaden: twee koren die aan- en afzwellen (perioden passen precies in de lus)
    c1 = biquad_bp(ruis(rng, n), 4300, 7) * (0.5 + 0.5 * np.sin(2 * math.pi * 95 * t)) ** 3
    c1 *= 0.25 + 0.75 * (0.5 - 0.5 * np.cos(2 * math.pi * t / L)) ** 1.6
    c2 = biquad_bp(ruis(rng, n), 3550, 9) * (0.5 + 0.5 * np.sin(2 * math.pi * 140 * t + 1)) ** 4
    c2 *= 0.2 + 0.8 * (0.5 - 0.5 * np.cos(2 * math.pi * t / (L / 2) + 2.0)) ** 2
    # fijn gezoem van kleine insecten
    zoem = np.sin(fase(6100 + 40 * np.sin(2 * math.pi * 0.7 * t))) * (0.6 + 0.4 * np.sin(2 * math.pi * 31 * t)) * 0.05
    # bladgeruis in de wind
    blad = biquad_lp(ruis(rng, n), 900) * (0.6 + 0.4 * np.sin(2 * math.pi * 3 * t / L)) * 0.5
    sig = c1 * 1.0 + c2 * 0.7 + zoem + blad
    return normaal(lus(sig, int(F * R)), 0.55)


def _krekel(t, rng, f, periode, pulsen, amp, start):
    out = np.zeros_like(t)
    pl, gap = int(0.018 * R), int(0.013 * R)
    toon = np.sin(2 * math.pi * f * np.arange(pl) / R) * hann(pl)
    p = start
    while p < len(t):
        for k in range(pulsen):
            a = int(p * R) + k * (pl + gap)
            if a + pl < len(t):
                out[a:a + pl] += toon * amp
        p += periode
    return out


def _kwaak(f0, snelheid, duur, rng):
    t = tijd(duur)
    puls = (0.5 + 0.5 * np.sin(2 * math.pi * snelheid * t)) ** 6
    s = sum(np.sin(2 * math.pi * h * f0 * t + rng.uniform(0, 6)) / h for h in range(1, 7))
    return s * puls * omhulsel(len(t), 0.02, 0.06)


def achter_nacht():
    rng = np.random.default_rng(202)
    L, F = 10.0, 0.6
    t = tijd(L + F)
    sig = np.zeros_like(t)
    # krekels: elk een eigen toonhoogte en tempo (aantal tjirpjes per lus is heel, dus de lus klopt)
    for k in range(7):
        per = L / rng.integers(12, 23)
        sig += _krekel(t, rng, rng.uniform(3800, 5100), per, int(rng.integers(2, 5)), rng.uniform(0.15, 0.42), rng.uniform(0, per))
    # sabelsprinkhaan: ki-ki-ki elke 1,25 s
    ki = np.sin(2 * math.pi * 2750 * t) * (0.5 + 0.5 * np.sin(2 * math.pi * 18 * t)) ** 2
    poort = ((t % 1.25) < 0.17).astype(float)
    sig += biquad_lp(ki * poort, 4000) * 0.16
    # kikkers in de verte
    for k in range(8):
        a = int(rng.uniform(0, L) * R)
        kw = _kwaak(rng.uniform(150, 290), rng.uniform(32, 60), rng.uniform(0.16, 0.3), rng) * rng.uniform(0.18, 0.34)
        e = min(len(sig), a + len(kw))
        sig[a:e] += kw[:e - a]
    # boomkikkertjes: korte hoge 'kwiek'
    for k in range(6):
        a = int(rng.uniform(0, L) * R)
        n = int(0.07 * R)
        f = np.linspace(1500, 2100, n)
        kw = np.sin(fase(f)) * hann(n) * 0.2
        sig[a:a + n] += kw[:len(sig[a:a + n])]
    sig += biquad_lp(ruis(rng, len(t)), 280) * 0.25
    return normaal(lus(sig, int(F * R)), 0.55)


def achter_water():
    rng = np.random.default_rng(303)
    L, F = 8.0, 0.6
    t = tijd(L + F)
    n = len(t)
    stroom = biquad_lp(ruis(rng, n), 1400) * 0.55 + biquad_bp(ruis(rng, n), 520, 0.9) * 0.45
    stroom *= 0.8 + 0.2 * np.sin(2 * math.pi * 2 * t / L)
    # klotsende belletjes
    for k in range(55):
        a = int(rng.uniform(0, L) * R)
        m = int(rng.uniform(0.02, 0.05) * R)
        f = np.linspace(rng.uniform(450, 800), rng.uniform(900, 1700), m)
        b = np.sin(fase(f)) * np.exp(-np.arange(m) / (0.3 * m)) * rng.uniform(0.05, 0.16)
        stroom[a:a + m] += b[:len(stroom[a:a + m])]
    return normaal(lus(stroom, int(F * R)), 0.5)


# ------------------------------------------------------------------ losse roepen

def _noot(f0, f1, duur, rng, harm=0.22, vib=0.0, adem=0.04):
    n = int(duur * R)
    t = np.arange(n) / R
    k = np.linspace(0, 1, n)
    f = f0 + (f1 - f0) * (k ** 0.8) + vib * np.sin(2 * math.pi * 28 * t)
    ph = fase(f)
    s = np.sin(ph) + harm * np.sin(2 * ph + 0.3)
    s += adem * 3 * biquad_bp(ruis(rng, n), (f0 + f1) / 2, 4)   # adem: ruis rond de toon, niet overal
    return s * omhulsel(n, 0.012, duur * 0.45)


def _rij(stukken, gat):
    uit = []
    for i, s in enumerate(stukken):
        uit.append(s)
        g = gat[i] if isinstance(gat, list) else gat
        uit.append(np.zeros(int(g * R)))
    return np.concatenate(uit)


def roep_fluit(rng):
    """Tropische fluiter: 2 tot 4 heldere glijtonen."""
    hoog = rng.uniform(2100, 3000)
    stukken = []
    for i in range(int(rng.integers(2, 5))):
        f0 = hoog * rng.uniform(0.85, 1.1)
        stukken.append(_noot(f0, f0 * rng.uniform(0.62, 0.85), rng.uniform(0.11, 0.26), rng, vib=rng.uniform(0, 25)))
    return _rij(stukken, list(rng.uniform(0.05, 0.14, len(stukken))))


def roep_triller(rng):
    """Snelle triller die langzaam zakt."""
    f = rng.uniform(3000, 3700)
    aantal = int(rng.integers(12, 22))
    stukken = []
    for i in range(aantal):
        ff = f * (1 - 0.18 * i / aantal)
        stukken.append(_noot(ff * 1.06, ff * 0.94, 0.035, rng, harm=0.1, adem=0.02) * (0.6 + 0.4 * math.sin(math.pi * i / aantal)))
    return _rij(stukken, 0.018)


def roep_krijs(rng, kort=False):
    """Papegaai/ara: rauwe krijs (toon met snelle frequentiemodulatie, afgekapt)."""
    stukken = []
    for i in range(1 if kort else int(rng.integers(1, 3))):
        d = rng.uniform(0.22, 0.38) * (0.7 if kort else 1)
        n = int(d * R)
        t = np.arange(n) / R
        dr = rng.uniform(900, 1300) * (1 + 0.25 * np.sin(math.pi * t / d))
        ph = fase(dr) + 6.0 * np.sin(2 * math.pi * rng.uniform(60, 95) * t)
        s = np.tanh(2.8 * (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * ruis(rng, n)))
        s = biquad_bp(s, rng.uniform(1600, 2300), 1.3) * 2.5 + s * 0.25
        stukken.append(s * omhulsel(n, 0.015, d * 0.4))
    return _rij(stukken, rng.uniform(0.08, 0.2))


def roep_koer(rng):
    """Duif: zacht koeren, 2 of 3 lage tonen."""
    f = rng.uniform(430, 560)
    stukken = [_noot(f * 1.04, f * 0.93, rng.uniform(0.28, 0.4), rng, harm=0.35, adem=0.015) for _ in range(int(rng.integers(2, 4)))]
    stukken[-1] = _noot(f * 1.02, f * 0.82, 0.55, rng, harm=0.35, adem=0.015)
    return _rij(stukken, rng.uniform(0.18, 0.3))


def roep_brulaap(rng):
    """Brulaap in de verte: diep aanzwellend gebrul."""
    stukken = []
    for i in range(int(rng.integers(2, 4))):
        d = rng.uniform(0.9, 1.6)
        n = int(d * R)
        t = np.arange(n) / R
        f0 = rng.uniform(85, 120) * (1 + 0.15 * np.sin(math.pi * t / d))
        zaag = 2 * ((np.cumsum(f0 / R)) % 1.0) - 1
        s = biquad_bp(zaag, 420, 2.2) * 2 + biquad_bp(ruis(rng, n), 520, 1.8) * 0.9
        env = np.sin(math.pi * np.linspace(0, 1, n)) ** 1.2 * (0.8 + 0.2 * np.sin(2 * math.pi * 6 * t))
        stukken.append(np.tanh(s * 1.6) * env)
    return _rij(stukken, rng.uniform(0.15, 0.35))


def roep_uil(rng):
    """Uil: hoe-hoe ... hoeoeoe."""
    f = rng.uniform(340, 420)
    stukken = [_noot(f, f * 0.97, 0.18, rng, harm=0.15, adem=0.03), _noot(f, f * 0.97, 0.18, rng, harm=0.15, adem=0.03),
               _noot(f * 1.02, f * 0.9, 0.7, rng, harm=0.15, vib=3, adem=0.03)]
    return _rij(stukken, [0.12, 0.35, 0.0])


def roep_nachtzwaluw(rng):
    """Nachtzwaluw: drie snelle stijgende fluitjes ('wip-poer-wil')."""
    f = rng.uniform(1300, 1600)
    stukken = [_noot(f * 1.3, f * 1.55, 0.09, rng), _noot(f * 0.95, f * 1.0, 0.12, rng), _noot(f * 1.05, f * 1.75, 0.2, rng)]
    return _rij(stukken, [0.05, 0.04, 0.0])


ROEPEN = {"fluit": roep_fluit, "triller": roep_triller, "krijs": roep_krijs, "koer": roep_koer,
          "brulaap": roep_brulaap, "uil": roep_uil, "nachtzwaluw": roep_nachtzwaluw}
VARIANTEN = 3


def maak_roepen():
    uit = {}
    for i, (soort, fn) in enumerate(ROEPEN.items()):
        for v in range(1, VARIANTEN + 1):
            rng = np.random.default_rng(1000 + 37 * i + v)
            s = galm(fn(rng), rng, lengte=1.1 if soort == "brulaap" else 0.7, nat=0.4 if soort == "brulaap" else 0.28)
            s = biquad_lp(s, 3200) if soort == "brulaap" else s
            uit[f"roep_{soort}_{v}"] = normaal(s, 0.8)
    return uit


# ------------------------------------------------------------------ voorbeeldmix

def voorbeeld(achter, roepen, soorten, sec, rng, water=None):
    n = int(sec * R)
    reps = n // len(achter) + 1
    mix = np.tile(achter, reps)[:n] * 0.55
    if water is not None:
        mix += np.tile(water, n // len(water) + 1)[:n] * 0.25
    p = 1.0
    while p < sec - 2:
        s = roepen[f"roep_{rng.choice(soorten)}_{rng.integers(1, VARIANTEN + 1)}"] * rng.uniform(0.25, 0.6)
        a = int(p * R)
        e = min(n, a + len(s))
        mix[a:e] += s[:e - a]
        p += rng.uniform(2.5, 6.5)
    return normaal(mix, 0.8)


def main():
    stukken = {"achter_dag": achter_dag(), "achter_nacht": achter_nacht(), "achter_water": achter_water()}
    stukken.update(maak_roepen())
    for naam, sig in stukken.items():
        schrijf(naam, sig)
        print(f"{naam}.wav  {len(sig) / R:.2f} s")
    if "--voorbeeld" in sys.argv:
        map_ = sys.argv[sys.argv.index("--voorbeeld") + 1]
        os.makedirs(map_, exist_ok=True)
        rng = np.random.default_rng(7)
        _wav(os.path.join(map_, "voorbeeld_dag.wav"), voorbeeld(stukken["achter_dag"], stukken, ["fluit", "triller", "krijs", "koer", "fluit", "brulaap"], 30, rng))
        _wav(os.path.join(map_, "voorbeeld_nacht.wav"), voorbeeld(stukken["achter_nacht"], stukken, ["uil", "nachtzwaluw", "nachtzwaluw"], 30, rng))
        _wav(os.path.join(map_, "voorbeeld_rivier_dag.wav"), voorbeeld(stukken["achter_dag"], stukken, ["fluit", "koer"], 20, rng, stukken["achter_water"]))
        print("voorbeelden in", map_)


if __name__ == "__main__":
    main()
