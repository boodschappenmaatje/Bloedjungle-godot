"""Dieselgeneratorlus voor Bloedjungle: assets/geluid/generator.wav (mono, 22050 Hz, 16 bit, 2 s, naadloze lus).
Alles uit numpy, geen externe bron: een slaande dieselmotor (15 ontstekingen per seconde, ruwe lage slag), een alternatorbrom
van 100 Hz met boventonen, en ruis uit de ventilator. Het spectrum wordt met FFT-fasen opgebouwd, dus de lus is perfect periodiek.
Gebruik: python3 maak_generator_geluid.py ../../assets/geluid/generator.wav"""
import sys, wave
import numpy as np

SR, DUUR = 22050, 2.0
N = int(SR * DUUR)
rng = np.random.default_rng(7)
t = np.arange(N) / SR


def periodieke_ruis(lo, hi, helling=0.0):
    """Ruis met vlak (of aflopend) spectrum tussen lo en hi Hz; precies periodiek over DUUR seconden."""
    f = np.fft.rfftfreq(N, 1 / SR)
    amp = ((f >= lo) & (f <= hi)).astype(float) * np.power(np.maximum(f, 1.0) / 100.0, helling)
    spec = amp * np.exp(1j * rng.uniform(0, 2 * np.pi, f.size))
    x = np.fft.irfft(spec, N)
    return x / np.max(np.abs(x))


slag = np.zeros(N)
pulsen = int(15 * DUUR)
laag = periodieke_ruis(25, 300, -1.0)
for i in range(pulsen):
    s = int(i * N / pulsen)
    lengte = int(SR / 15 * 0.8)
    k = np.arange(lengte) / SR
    env = np.exp(-k * 38.0) * (1.0 + 0.25 * rng.uniform(-1, 1))
    puls = env * (np.sin(2 * np.pi * (58 + 18 * np.exp(-k * 25)) * k) * 0.9 + 0.55 * laag[(s + np.arange(lengte)) % N])
    slag[(s + np.arange(lengte)) % N] += puls
brom = sum(np.sin(2 * np.pi * 100 * h * t + h) / h ** 1.3 for h in range(1, 7))
brom /= np.max(np.abs(brom))
ruis = periodieke_ruis(600, 5000, -0.6)
mix = 0.75 * slag / np.max(np.abs(slag)) + 0.22 * brom + 0.09 * ruis * (0.7 + 0.3 * np.sin(2 * np.pi * 15 * t))
mix *= 0.9 / np.max(np.abs(mix))
out = sys.argv[1] if len(sys.argv) > 1 else "generator.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32000).astype("<i2").tobytes())
print("geschreven", out, "%.1f s" % DUUR)
