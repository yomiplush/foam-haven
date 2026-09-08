"""Deterministic, original soft effects. Does not touch ambient recordings."""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000


def render(name: str, duration: float, pitch: float, drop: float, decay: float):
    samples = []
    phase = 0.0
    for i in range(round(RATE * duration)):
        t = i / RATE
        # Rounded attack and release, with no noise burst or high metallic partials.
        attack = 1.0 - math.exp(-t / 0.018)
        release = min(1.0, max(0.0, (duration - t) / 0.12))
        release = 0.5 - 0.5 * math.cos(math.pi * release)
        envelope = attack * math.exp(-t / decay) * release
        frequency = pitch * (1.0 + drop * math.exp(-t / 0.10))
        phase += math.tau * frequency / RATE
        value = math.sin(phase) + 0.13 * math.sin(2 * phase) * math.exp(-t / 0.08)
        samples.append(value * envelope)
    peak = max(abs(value) for value in samples)
    pcm = [round(value / peak * 0.30 * 32767) for value in samples]
    pcm[0] = pcm[-1] = 0
    path = ROOT / "assets" / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    print(f"{name}: {duration:.2f}s, peak -10.46 dBFS, silent endpoints")


if __name__ == "__main__":
    render("touch_soft.wav", 0.55, 220, 0.22, 0.16)
    render("bubble_soft.wav", 0.70, 330, 0.18, 0.22)
    render("confirm_soft.wav", 0.28, 440, 0.0, 0.08)
