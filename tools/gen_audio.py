#!/usr/bin/env python3
"""Generates the few sounds the Brackeys pack does not contain (warning, zombie,
fall, win) plus the synthesized "oo loser" voice line. Everything else is Brackeys.
The sounds here are synthesized and are NOT from any asset pack. The 'oo loser' line is synthesized with ffmpeg's flite text-to-speech.
Run:  python3 tools/gen_audio.py   (needs numpy; ffmpeg optional for the voice line)
"""
import numpy as np, wave, os, subprocess, sys
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)

def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * gain
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())

def t(d): return np.arange(int(SR * d)) / SR
def midi(n): return 440.0 * 2 ** ((n - 69) / 12)
def square(f, d, duty=0.5):
    tt = t(d); return np.where((tt * f) % 1.0 < duty, 1.0, -1.0)
def tri(f, d):
    tt = t(d); return 2 * np.abs(2 * ((tt * f) % 1.0) - 1) - 1
def noise(d): return np.random.RandomState(7).uniform(-1, 1, int(SR * d))
def env(x, a=0.005, r=0.08, decay=0.0):
    n = len(x); e = np.ones(n)
    ai = max(1, int(a * SR)); e[:ai] = np.linspace(0, 1, ai)
    ri = max(1, min(n, int(r * SR))); e[-ri:] *= np.linspace(1, 0, ri)
    if decay: e *= np.exp(-np.arange(n) / SR * decay)
    return x * e
def sweep(f0, f1, d, kind="square"):
    tt = t(d); f = np.linspace(f0, f1, len(tt)); ph = np.cumsum(f) / SR
    if kind == "square": return np.where(ph % 1.0 < 0.5, 1.0, -1.0)
    return np.sin(2 * np.pi * ph)

# ---------------- SFX (only the ones Brackeys does not provide) ----------------
# jump / coin / hurt / explosion / power_up / tap and the music come from the Brackeys pack.
save("warning.wav", np.concatenate([env(square(440, 0.14), r=0.05), np.zeros(int(SR*0.06)), env(square(330, 0.2), r=0.08)]))
save("zombie.wav", env(sweep(110, 55, 1.2), a=0.05, r=0.4) * 0.6 + 0.5 * env(noise(1.2), a=0.1, r=0.5, decay=2))
save("win.wav", np.concatenate([env(square(midi(m), 0.14), r=0.05) for m in (72, 76, 79, 84)] + [env(square(midi(88), 0.5), r=0.3, decay=3)]))
save("fall.wav", env(sweep(700, 100, 0.6, "sine"), r=0.3))

# ---------------- Voice line (TTS fallback) ----------------
voice_ok = False
tmp = os.path.join(OUT, "_loser_raw.wav")
try:
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i",
                        "flite=text='oo loser':voice=slt", "-ar", str(SR), "-ac", "1", tmp], capture_output=True)
    if r.returncode == 0 and os.path.exists(tmp):
        with wave.open(tmp) as w: raw = np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768.0
        save("loser.wav", raw, gain=0.95); voice_ok = True
        os.remove(tmp)
except FileNotFoundError:
    pass
if not voice_ok:
    # Honest fallback: a "sad trombone" jingle (NOT speech).
    save("loser.wav", np.concatenate([env(sweep(f, f * 0.96, 0.3), r=0.1) for f in (233, 220, 208)] + [env(sweep(196, 150, 0.8), r=0.4)]))
print("voice line via TTS:", voice_ok)

print("audio written to", os.path.abspath(OUT))
