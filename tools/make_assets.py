"""Create original seamless audio and a small Japanese UI font subset.

Sleep-grade ambient for the three worlds is synthesised here, not sampled:
    ambient_0 (ocean): rolling low surf with a gentle shimmer
    ambient_1 (sky):   slow gusts of air with a quiet aeolian hum
    ambient_2 (room):  warm lullaby pads with soft "ponyon" plucks
    chime.wav:         the membrane's gentle "ponyon" (boing-y plop)

Tonal layers use integer-Hz sine tones so the loop seam is sample-perfect;
noise beds sit under amplitude troughs around the seam and get a tiny fade.
"""
from pathlib import Path
import math
import random
import wave
import array
from fontTools.ttLib import TTFont
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"

def make_font():
    text = "".join(p.read_text() for p in (ROOT / "scripts").glob("*.gd"))
    font = TTFont("/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc", fontNumber=0)
    subsetter = subset.Subsetter(options=subset.Options())
    subsetter.populate(text=text + "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ●→←：・ / .+-")
    subsetter.subset(font)
    font.save(ASSETS / "japanese.ttf")
    print("generated Japanese font")

# ---------------------------------------------------------------- audio engine
RATE = 32000
DUR = 24.0
N = int(RATE * DUR)
TAU = math.tau
TARGET = 0.32
rng = random.Random(9031)


def band_noise(lo: float, hi: float) -> array.array:
    """Band-passed noise (one-pole high + low pass) in [-1, 1] roughly."""
    a_hi = 1.0 - math.exp(-TAU * hi / RATE)
    a_lo = 1.0 - math.exp(-TAU * lo / RATE)
    out = array.array("f", [0.0]) * N
    low = 0.0
    y = 0.0
    prev = 0.0
    for i in range(N):
        low += a_hi * (rng.uniform(-1.0, 1.0) - low)
        y = a_lo * (y + low - prev)
        prev = low
        out[i] = y
    return out


def swell_bumps(events, floor: float, amp: float, rise: float, fall: float) -> array.array:
    """Overlapping one-sided 'wave/gust' bumps; a calm floor between them."""
    env = array.array("f", [floor]) * N
    for center, strength in events:
        ci = int(center * RATE)
        for i in range(N):
            dt = abs(i - ci) / RATE
            if dt > 9.0:
                continue
            env[i] += strength * amp * math.exp(-dt * (fall if i > ci else rise))
    return env


def tone(freq: float, phase: float = 0.0) -> list:
    """Steady sine (integer Hz is seamlessly loopable)."""
    return [math.sin(TAU * freq * i / RATE + phase) for i in range(N)]


def seam_quiet(values: list, seconds: float = 0.25):
    """Cos-fade the edges toward the seam so the loop never clicks."""
    steps = int(seconds * RATE)
    for i in range(steps):
        c = 0.5 - 0.5 * math.cos(math.pi * i / steps)  # 0 at seam -> 1 inside
        values[i] *= c
        values[N - 1 - i] *= c
    values[0] = values[N - 1] = 0.0


def mix_swell(noise: array.array, env: array.array, left: list, right: list,
              lx: float, rx: float):
    for i in range(N):
        v = noise[i] * env[i]
        left[i] += v * lx
        right[i] += v * rx


def write_stereo(path: Path, left: list, right: list, target: float = TARGET):
    l = normalize(left, target)
    r = normalize(right, target)
    count = len(l)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        frames = bytearray(2 * 2 * count)
        for i in range(count):
            j = i * 4
            frames[j:j + 2] = l[i].to_bytes(2, "little", signed=True)
            frames[j + 2:j + 4] = r[i].to_bytes(2, "little", signed=True)
        output.writeframes(bytes(frames))


def normalize(samples: list, target: float) -> list:
    peak = max(1e-9, max(abs(s) for s in samples))
    mean = sum(samples) / len(samples)
    scale = target / peak
    out = []
    for s in samples:
        v = max(-1.0, min(1.0, (s - mean) * scale))
        out.append(int(v * 32767))
    return out


# ---------------------------------------------------------------- ocean: surf
def make_ocean():
    left = [0.0] * N
    right = [0.0] * N
    wash = band_noise(240, 950)
    spray = band_noise(2600, 6000)
    wash_env = swell_bumps(
        [(1.8, 0.9), (4.7, 1.0), (7.9, 0.75), (11.2, 1.1), (14.6, 0.9),
         (17.9, 0.8), (21.0, 0.95)], 0.05, 0.7, 1.4, 0.5)
    spray_env = swell_bumps(
        [(2.9, 0.5), (6.6, 0.6), (10.1, 0.45), (12.6, 0.55), (16.4, 0.5),
         (20.3, 0.4)], 0.012, 0.65, 1.8, 0.7)
    mix_swell(wash, wash_env, left, right, 1.0, 0.92)
    mix_swell(spray, spray_env, left, right, 0.9, 1.0)
    sub = tone(55, 0.4)
    breathe = [(0.6 + 0.4 * math.sin(TAU * 2.0 * i / N)) for i in range(N)]
    for i in range(N):
        v = sub[i] * breathe[i] * 0.02
        left[i] += v
        right[i] += v * 0.96
    seam_quiet(left)
    seam_quiet(right)
    return left, right


# ---------------------------------------------------------------- sky: wind
def make_wind():
    left = [0.0] * N
    right = [0.0] * N
    gust = band_noise(380, 1700)
    air = band_noise(2800, 6500)
    gust_env = swell_bumps(
        [(2.0, 0.85), (5.4, 1.0), (8.6, 0.7), (11.8, 1.05), (15.2, 0.9),
         (18.9, 0.7), (21.7, 0.55)], 0.035, 0.72, 1.0, 0.45)
    air_env = swell_bumps(
        [(0.9, 0.35), (6.2, 0.3), (10.8, 0.42), (16.1, 0.33), (22.3, 0.3)],
        0.012, 0.5, 1.3, 0.6)
    mix_swell(gust, gust_env, left, right, 1.0, 0.93)
    mix_swell(air, air_env, left, right, 0.7, 1.0)
    # Quiet aeolian hum D4 / F4 / A4, integer Hz, swelling slowly.
    a = tone(294)
    b = tone(349, 0.5)
    c = tone(440, 2.0)
    for i in range(N):
        sw = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(TAU * i / N + 1.1))
        v = (a[i] + b[i] + c[i]) * 0.004 * sw
        left[i] += v
        right[i] += v * 0.96
    seam_quiet(left)
    seam_quiet(right)
    return left, right


# ---------------------------------------------------------------- balloon room
def pluck(buf: list, freq: float, at: float, amp: float):
    """Soft 'ponyon': a marimba tone with a pitch drop and little bounce."""
    start = int(at * RATE)
    step = TAU * freq / RATE
    phase = 0.0
    for j in range(int(2.6 * RATE)):
        i = start + j
        if i >= N:
            break
        tt = j / RATE
        env = (1.0 - math.exp(-tt * 140.0)) * math.exp(-tt / 0.95)
        pitch = 1.0 + 0.045 * math.exp(-tt / 0.16)
        pitch += 0.012 * math.sin(TAU * 3.1 * tt) * math.exp(-tt / 0.9)
        phase += step * pitch
        wob = 1.0 + 0.05 * math.exp(-tt / 0.12) * math.sin(TAU * 5.0 * tt)
        s = math.sin(phase) * wob + 0.22 * math.sin(phase * 2.0) * math.exp(-tt / 0.4)
        buf[i] += s * env * amp


def pad_chord(buf: list, freqs, at: float, amp: float, seed: float):
    """Warm chord that swells to zero at its own edges."""
    start = int(at * RATE)
    length = int(6.0 * RATE)
    for j in range(length):
        i = start + j
        if i >= N:
            break
        u = j / length
        env = (math.sin(math.pi * u)) ** 1.6
        s = 0.0
        for k, f in enumerate(freqs):
            s += math.sin(TAU * f * i / RATE + seed + k * 0.8)
        buf[i] += s * env * amp


def make_room():
    left = [0.0] * N
    right = [0.0] * N
    bars = [
        (0.0, [262, 330, 392, 294], 0.0),     # C(add9)
        (6.0, [220, 262, 330, 392], 1.2),     # Am7
        (12.0, [175, 220, 262, 392], 2.1),    # F(add9)
        (18.0, [196, 247, 294, 392], 3.0),    # G(add9) -> resolves to C
    ]
    for at, freqs, seed in bars:
        pad_chord(left, freqs, at, 0.03, seed)
        pad_chord(right, freqs, at, 0.029, seed + 0.4)
    scale = [262, 294, 330, 392, 440, 523, 587, 659, 784, 880, 1047]
    idx = 3
    t = 1.1
    while t < 17.4:
        idx = max(0, min(len(scale) - 1, idx + rng.choice([-1, -2, -1, 0, 1, 1, 2])))
        freq = scale[idx]
        amp = 0.085 if freq < 600 else 0.07
        pluck(left, freq, t, amp)
        pluck(right, freq, t + 0.004, amp * 1.0)
        t += rng.uniform(2.1, 3.8)
    seam_quiet(left)
    seam_quiet(right)
    return left, right


# ---------------------------------------------------------------- ぽにょん SFX
def make_ponyon(path: Path):
    n = int(RATE * 1.1)
    L = [0.0] * n
    R = [0.0] * n
    # warm noise 'pop' burst
    pop = array.array("f", [0.0]) * n
    a_hi = 1.0 - math.exp(-TAU * 1800.0 / RATE)
    low = 0.0
    for i in range(n):
        low += a_hi * (rng.uniform(-1.0, 1.0) - low)
        pop[i] = low
    freq = 560.0
    phase = 0.0
    step = TAU * freq / RATE
    for j in range(n):
        tt = j / RATE
        env = (1.0 - math.exp(-tt * 320.0)) * math.exp(-tt / 0.62)
        fade_out = min(1.0, (1.1 - tt) / 0.22)
        env *= max(0.0, fade_out)
        pitch = 1.0 - 0.18 * (1.0 - math.exp(-tt / 0.10))
        pitch += 0.05 * math.sin(TAU * 4.5 * tt) * math.exp(-tt / 0.55)
        phase += step * pitch
        wave = math.sin(phase) + 0.2 * math.sin(phase * 2.7) * math.exp(-tt / 0.2)
        voice = wave * env * 0.5
        blur = pop[j] * math.exp(-tt * 55.0) * 0.9
        L[j] = voice + blur
        R[j] = voice * 0.94 + blur * 0.9
    write_stereo(path, L, R, target=0.55)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Update the UI font without replacing recorded audio.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--font-only", action="store_true", help="Regenerate only the Japanese font (default)")
    mode.add_argument("--procedural-audio", action="store_true", help="Replace ALL ambient recordings with synthesized audio")
    args = parser.parse_args()
    make_font()
    if not args.procedural_audio:
        return
    sets = [
        ("ambient_0.wav", make_ocean()),
        ("ambient_1.wav", make_wind()),
        ("ambient_2.wav", make_room()),
    ]
    for name, (l, r) in sets:
        write_stereo(ASSETS / name, l, r)
        print("generated", name)
    make_ponyon(ASSETS / "chime.wav")
    print("generated chime.wav (ponyon)")
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
    print("Original audio and Japanese font generated")


if __name__ == "__main__":
    main()
