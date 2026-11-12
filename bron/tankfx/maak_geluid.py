#!/usr/bin/env python3
"""Tankschot: zelf gesynthetiseerd kanongeluid (geen opname, dus vrij van licentie). Vaste seed, alleen numpy.
Lagen: scherpe klap (crack), diepe dreun met dalende toon (body), uitgeblazen gas, drie echo's die in de jungle wegsterven
en het slotstuk dat dichtklikt. Uitvoer: assets/wapenfx/geluid/tankschot.wav (mono, 32 kHz, 16 bit, ~3 s).
Gebruik: python3 bron/tankfx/maak_geluid.py"""
import os, wave
import numpy as np

SR = 32000
UIT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "wapenfx", "geluid")
rng = np.random.default_rng(1943)


def lp(x, fc):
    a = 1.0 - np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x); s = 0.0
    for i, v in enumerate(x):
        s += a * (v - s); y[i] = s
    return y


def hp(x, fc):
    return x - lp(x, fc)


def zet(basis, x, t0, g=1.0):
    i = int(SR * t0); j = min(len(basis), i + len(x))
    if i < len(basis):
        basis[i:j] += x[: j - i] * g


T = 3.4
n = int(SR * T)
out = np.zeros(n)
t = np.arange(int(SR * 2.0)) / SR
# klap: korte, heldere ruisburst
crack = hp(rng.uniform(-1, 1, int(SR * 0.12)), 900) * np.exp(-np.arange(int(SR * 0.12)) / SR / 0.012)
# dreun: sinus die van 85 naar 32 Hz zakt, plus een zware harmonische
f = 32 + 55 * np.exp(-t / 0.18)
body = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)) * np.exp(-t / 0.42)
# gas: laag gefilterde ruis die langer blijft
gas = lp(rng.uniform(-1, 1, len(t)), 650) * np.exp(-t / 0.55)
dry = np.zeros(int(SR * 2.0))
dry[: len(crack)] += crack * 0.9
dry += body * 1.1 + gas * 1.3
zet(out, dry, 0.0)
# echo's tegen de jungle: steeds doffer en zachter
for dt, g, fc in ((0.27, 0.42, 1800), (0.58, 0.28, 1100), (0.95, 0.17, 700)):
    echo = lp(dry[: int(SR * 1.6)], fc)
    zet(out, echo, dt, g)
# staart: dof gerommel
rumble = lp(rng.uniform(-1, 1, int(SR * 2.4)), 220) * np.exp(-np.arange(int(SR * 2.4)) / SR / 0.9)
zet(out, rumble, 0.1, 0.9)
# slotstuk: twee metalen kliks
klik = hp(rng.uniform(-1, 1, int(SR * 0.05)), 1500) * np.exp(-np.arange(int(SR * 0.05)) / SR / 0.008)
zet(out, klik, 1.05, 0.22); zet(out, klik, 1.17, 0.3)
out = np.tanh(out * 0.9)
out /= np.max(np.abs(out)) / 0.92
fade = np.minimum(1.0, (n - np.arange(n)) / (SR * 0.25))
out *= fade
os.makedirs(UIT, exist_ok=True)
pad = os.path.join(UIT, "tankschot.wav")
with wave.open(pad, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((out * 32767).astype("<i2").tobytes())
print(pad, os.path.getsize(pad) // 1024, "KB")
