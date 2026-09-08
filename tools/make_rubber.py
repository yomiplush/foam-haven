"""Adapt Huminaatio's CC0 Balloon rubbing recording into a soft friction loop.

Source: https://freesound.org/people/Huminaatio/sounds/266979/
Public HQ preview: https://cdn.freesound.org/previews/266/266979_1325505-hq.mp3
Place it at .build-tools/sound-src/balloon-rubbing-266979.mp3 first.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000
SOURCE = ROOT / ".build-tools/sound-src/balloon-rubbing-266979.mp3"


def main():
    raw = subprocess.run([
        "ffmpeg", "-v", "error", "-i", str(SOURCE), "-ac", "1", "-ar", str(RATE),
        "-af", "highpass=f=100,lowpass=f=2600", "-f", "f32le", "-"
    ], capture_output=True, check=True).stdout
    audio = np.frombuffer(raw, dtype=np.float32).copy()
    clip = audio[int(1.5 * RATE):int(8.0 * RATE)]
    # Suppress sharp handling knocks while retaining the recorded friction texture.
    threshold = max(float(np.sqrt(np.mean(clip ** 2))) * 3, 1e-5)
    clip = np.tanh(clip / threshold) * threshold
    overlap = int(0.4 * RATE)
    phase = np.linspace(0, np.pi / 2, overlap, endpoint=False)
    seam = clip[-overlap:] * np.cos(phase) + clip[:overlap] * np.sin(phase)
    loop = np.concatenate((clip[overlap:-overlap], seam))
    loop -= loop.mean()
    loop *= 0.30 / max(float(np.abs(loop).max()), 1e-8)
    loop[0] = loop[-1] = (loop[0] + loop[-1]) / 2
    output = ROOT / "assets/rubber_rub.wav"
    with wave.open(str(output), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes((loop * 32767).astype("<i2").tobytes())
    record = {
        "title": "Balloon rubbing", "author": "Huminaatio", "license": "CC0-1.0",
        "source_url": "https://freesound.org/people/Huminaatio/sounds/266979/",
        "download_url": "https://cdn.freesound.org/previews/266/266979_1325505-hq.mp3",
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "source_excerpt_seconds": [1.5, 8.0], "overlap_seconds": 0.4,
        "processing": "Mono 32 kHz; 100 Hz high-pass; 2.6 kHz low-pass; soft limiting; equal-power seam; peak 0.30",
        "output": "assets/rubber_rub.wav", "output_seconds": len(loop) / RATE,
    }
    (ROOT / "licenses/rubber-rubbing.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"rubber_rub.wav: {len(loop) / RATE:.2f}s, CC0 recording, seamless endpoints")


if __name__ == "__main__":
    main()
