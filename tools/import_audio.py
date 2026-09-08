"""Bake real (open-licensed) recordings into seamless, evenly-loud ambient loops.

Sources live in .build-tools/sound-src (excluded from the export) so the
resulting .wav files in assets/ are the only thing shipped. Licenses are
documented in README (素材と参照).

  assets/ambient_0.wav  <- Ocean Waves on a Tropical Beach (CC0), Commons
  assets/ambient_1.wav  <- procedural wind (kept; re-leveled to match)
  assets/ambient_2.wav  <- Lullaby wound up clock "Schlafe mein Prinzchen" (PD)

Every loop is closed with an equal-power crossfade so the forward-loop seam
(edit/loop_mode=2) does not click, then RMS-matched to a common level.
"""
from pathlib import Path
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / ".build-tools" / "sound-src"
ASSETS = ROOT / "assets"
RATE = 32000
RMS_TARGET_DB = -18.0
SEAM_FADE = 2.5  # seconds of crossfade used to close each loop


def load_stereo(path: Path) -> np.ndarray:
    """Decode any audio to float32 stereo at RATE, shape (n, 2)."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "2",
         "-ar", str(RATE), "-f", "f32le", "-"],
        capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32)
    return x.copy().reshape(-1, 2)


def close_loop(x: np.ndarray, sr: int = RATE, fade: float = SEAM_FADE):
    """Equal-power crossfade of tail onto head so the loop seam is smooth."""
    f = int(fade * sr)
    n = len(x)
    w = np.linspace(0.0, 1.0, f, endpoint=False)[:, None]
    head = x[:f].copy()
    tail = x[n - f:].copy()
    x[:f] = tail * w + head * (1.0 - w)
    x[n - f:] = x[n - f:] * (1.0 - w) + head * w
    # Ease the very last millisecond into the first sample so the forward
    # loop re-entry is no larger than an ordinary sample step.
    r = int(0.012 * sr)
    t = np.linspace(0.0, 1.0, r, endpoint=False)[:, None]
    x[n - r:] = x[n - r] * (1.0 - t) + x[0] * t
    x[0] = x[-1] = 0.5 * (x[0] + x[-1])
    return x


def rms_level(x: np.ndarray) -> float:
    return 20.0 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)


def write_wav(path: Path, x: np.ndarray):
    gain = 10.0 ** ((RMS_TARGET_DB - rms_level(x)) / 20.0)
    y = x * gain
    peak = np.abs(y).max()
    if peak > 0.85:
        y *= 0.85 / peak
    y = np.clip(y, -1.0, 1.0)
    pcm = (y * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def main():
    # ocean: steady open-sea surf, take a solid 46 s slice
    ocean = load_stereo(SRC / "ocean_tropical.ogg")
    slice_len = 46 * RATE
    ocean = ocean[10 * RATE:10 * RATE + slice_len]
    close_loop(ocean)
    write_wav(ASSETS / "ambient_0.wav", ocean)
    print("ambient_0.wav <- ocean CC0", ocean.shape)

    # wind: existing procedural loop, re-leveled to the same loudness
    wind = load_stereo(ASSETS / "ambient_1.wav")
    write_wav(ASSETS / "ambient_1.wav", wind)
    print("ambient_1.wav <- procedural wind (leveled)")

    # room: music-box lullaby, full piece, seam closed
    box = load_stereo(SRC / "lullaby_clock.ogg")
    close_loop(box, fade=3.0)
    write_wav(ASSETS / "ambient_2.wav", box)
    print("ambient_2.wav <- music box PD", box.shape)

    for i in range(3):
        (ASSETS / f"ambient_{i}.wav.import").write_text(f'''[remap]
importer="wav"
type="AudioStreamWAV"
path="res://.godot/imported/ambient_{i}.wav-placeholder.sample"
[deps]
source_file="res://assets/ambient_{i}.wav"
dest_files=["res://.godot/imported/ambient_{i}.wav-placeholder.sample"]
[params]
force/8_bit=false
force/mono=false
force/max_rate=false
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
''')


if __name__ == "__main__":
    main()
