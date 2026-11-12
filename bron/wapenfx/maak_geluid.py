#!/usr/bin/env python3
"""Wapeneffecten AAA: gelaagde schotgeluiden, zelf gesynthetiseerd (geen externe opnames, dus vrij van licentie).

Elk schot bestaat uit lagen: scherpe knal (crack), lage dreun (body), uitgeblazen gas (blast), mechaniek en een staart
die in de jungle naklinkt (slapback + galm). Vaste seeds, alleen numpy. Uitvoer in assets/wapenfx/geluid/ (mono, 32 kHz, 16 bit).
  shotgun_schot.wav   knal + pompklak op 0,38 s + staart (0,95 s)
  pistool_staart.wav  alleen de staart van de M1911 (de knal zelf is de bestaande opname m1911_report.wav)
  huls_tink.wav       messing/kunststof hulsje dat de grond raakt
  tik_treffer.wav     korte bevestigingstik voor een treffer
Gebruik: python3 bron/wapenfx/maak_geluid.py
"""
import os
import wave
import numpy as np

SR = 32000
UIT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "wapenfx", "geluid")


def laag(n):
    return np.zeros(int(SR * n))


def lp(x, fc):
    """Eenpolig laagdoorlaatfilter."""
    a = 1.0 - np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s += a * (v - s)
        y[i] = s
    return y


def hp(x, fc):
    return x - lp(x, fc)


def env(n, attack, decay):
    t = np.arange(int(SR * n)) / SR
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)


def ruis(n, rng):
    return rng.uniform(-1, 1, int(SR * n))


def plaats(basis, x, t0):
    i = int(SR * t0)
    j = min(len(basis), i + len(x))
    basis[i:j] += x[: j - i]


def galm(x, rng, lengte=0.8, dichtheid=34, zwaarte=0.5):
    """Goedkope jungle-galm: een wolk dalende echo's met laaggefilterde ruis."""
    ir = np.zeros(int(SR * lengte))
    t = np.arange(len(ir)) / SR
    for _ in range(dichtheid):
        k = int(rng.uniform(0.012, lengte * 0.9) * SR)
        ir[k] += rng.uniform(-1, 1) * np.exp(-t[k] / (lengte * 0.33))
    ir += lp(rng.uniform(-1, 1, len(ir)), 1800) * np.exp(-t / (lengte * 0.28)) * 0.35
    ir[0] = 0
    out = np.convolve(x, ir)[: len(x)]
    return out * zwaarte


def echt(naam, van=0.0, tot=None):
    """Laadt een echte opname uit opnames/ (mono, naar 32 kHz), bijgesneden."""
    pad = os.path.join(os.path.dirname(__file__), "opnames", naam)
    with wave.open(pad) as w:
        ch, sr = w.getnchannels(), w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
    x = x.reshape(-1, ch).mean(axis=1)
    x = x[int(sr * van): int(sr * tot) if tot else None]
    n = int(len(x) * SR / sr)
    x = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)
    return x / max(1e-6, np.max(np.abs(x)))


def opslaan(naam, x, piek=0.89):
    x = np.tanh(x * 1.1)
    x = x / max(1e-6, np.max(np.abs(x))) * piek
    pad = os.path.join(UIT, naam)
    with wave.open(pad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(naam, f"{len(x) / SR:.2f}s", os.path.getsize(pad) // 1024, "KB")


def shotgun():
    rng = np.random.default_rng(1897)
    s = laag(0.95)
    # 1. crack: heel korte breedbandruis
    crack = hp(ruis(0.02, rng), 1500) * env(0.02, 0.0004, 0.004) * 2.4
    plaats(s, crack, 0.0)
    # 2. blast: uitgeblazen gas, laag gefilterde ruis die dichtgaat
    bl = ruis(0.5, rng)
    blast = lp(bl, 2600) * env(0.5, 0.001, 0.09)
    blast = 0.55 * blast + 0.9 * lp(bl, 700) * env(0.5, 0.002, 0.14)
    plaats(s, blast * 2.2, 0.0)
    # 3. body: dreun met dalende toon
    t = np.arange(int(SR * 0.45)) / SR
    f = 150 * np.exp(-t * 7) + 38
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(0.45, 0.002, 0.11) * 1.8
    plaats(s, body, 0.0)
    # 4. pompklak: twee metalen tikken (naar achter, naar voren)
    for t0, f0, zw in ((0.36, 1650, 1.0), (0.47, 2300, 1.2)):
        tt = np.arange(int(SR * 0.09)) / SR
        klak = (np.sin(2 * np.pi * f0 * tt) * 0.5 + np.sin(2 * np.pi * f0 * 1.52 * tt) * 0.3) * np.exp(-tt / 0.012)
        klak += hp(ruis(0.09, rng), 2500) * np.exp(-tt / 0.006) * 0.8
        plaats(s, klak * 0.55 * zw, t0)
    # 4b. echte opname (CC0, zie opnames/BRON.md) als hoofdlaag; de eigen lagen geven er diepte aan
    echt_schot = echt("shotty.wav", 0.12, 0.7)
    s *= 0.45
    plaats(s, echt_schot * 2.6, 0.0)
    # 5. staart: jungle-galm over het begin
    kop = s[: int(SR * 0.4)].copy()
    staart = np.zeros_like(s)
    staart[: len(kop)] = galm(kop, rng, 0.9, 40, 0.9)
    s = s + lp(staart, 3200) * 1.0
    opslaan("shotgun_schot.wav", s)


def pistool_staart():
    rng = np.random.default_rng(1911)
    s = laag(0.9)
    # de knal zelf is de bestaande opname; hier alleen de naklank: korte slapback na 70 ms, daarna galm
    impuls = hp(ruis(0.03, rng), 900) * env(0.03, 0.001, 0.007) * 1.6
    ruim = laag(0.9)
    plaats(ruim, impuls, 0.0)
    st = galm(ruim, rng, 0.85, 46, 1.3)
    plaats(s, impuls * 0.35, 0.07)
    s += lp(st, 3600)
    opslaan("pistool_staart.wav", s, 0.55)


def pistool_diep():
    """Echte opname van een pistool, laag gefilterd: de zwaarte onder de bestaande m1911-knal."""
    rng = np.random.default_rng(52)
    x = echt("cz.wav", 0.27, 0.9)
    laag_deel = lp(x, 900)
    s = laag(0.9)
    plaats(s, laag_deel * 0.9, 0.0)
    s += lp(galm(s.copy(), rng, 0.85, 46, 1.1), 3200)
    opslaan("pistool_staart.wav", s, 0.62)


def kogelsuis():
    """Korte zwiep van een kogel die langs je oor gaat."""
    rng = np.random.default_rng(88)
    s = laag(0.22)
    tt = np.arange(len(s)) / SR
    ruw = hp(ruis(0.22, rng), 1800)
    boog = np.exp(-((tt - 0.09) / 0.045) ** 2)
    s += ruw * boog * 0.8
    s += np.sin(2 * np.pi * np.cumsum(5200 - 3200 * tt / 0.22) / SR) * boog * 0.2
    opslaan("kogelsuis.wav", s, 0.55)


def tink():
    rng = np.random.default_rng(7)
    s = laag(0.16)
    tt = np.arange(len(s)) / SR
    for f0, a in ((3150, 1.0), (4710, 0.55), (6980, 0.3)):
        s += np.sin(2 * np.pi * f0 * tt) * np.exp(-tt / 0.028) * a * 0.5
    s += hp(ruis(0.16, rng), 4000) * np.exp(-tt / 0.003) * 0.7
    opslaan("huls_tink.wav", s, 0.6)


def tik():
    rng = np.random.default_rng(3)
    s = laag(0.07)
    tt = np.arange(len(s)) / SR
    s += np.sin(2 * np.pi * 1850 * tt) * np.exp(-tt / 0.009)
    s += hp(ruis(0.07, rng), 2500) * np.exp(-tt / 0.003) * 0.6
    opslaan("tik_treffer.wav", s, 0.6)


if __name__ == "__main__":
    os.makedirs(UIT, exist_ok=True)
    shotgun()
    pistool_diep()
    kogelsuis()
    tink()
    tik()
