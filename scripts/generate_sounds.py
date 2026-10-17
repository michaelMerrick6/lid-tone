#!/usr/bin/env python3
"""Original, deterministic modal/noise Foley. No samples or third-party assets."""
import math
from pathlib import Path
import random
import struct
import wave

RATE = 44100
DEST = Path(__file__).resolve().parents[1] / "Sources/LidTone/Resources/Sounds"


def render(name, duration, modes, impacts, creak=False, air=False):
    rng = random.Random(name)
    samples = []
    low = 0.0
    for index in range(round(duration * RATE)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        low += 0.14 * (noise - low)
        value = 0.0
        for start, gain, decay in impacts:
            u = t - start
            if u >= 0:
                attack = min(u * 2500, 1)
                value += gain * attack * math.exp(-decay * u) * (low * 0.8 + noise * math.exp(-170 * u) * 0.3)
                for frequency, strength, damping in modes:
                    value += gain * strength * attack * math.exp(-damping * u) * math.sin(2 * math.pi * frequency * u)
        if creak and t < 0.29:
            envelope = math.sin(math.pi * t / 0.29) ** 2
            phase = 2 * math.pi * (410 * t + 90 * t * t + 0.6 * math.sin(2 * math.pi * 19 * t))
            value += envelope * 0.065 * (math.sin(phase) + 0.35 * math.sin(2.01 * phase))
        if air and t < 0.31:
            value += 0.42 * low * math.sin(math.pi * t / 0.31) ** 1.5
            value += 0.045 * math.sin(2 * math.pi * (800 * t - 600 * t * t)) * math.sin(math.pi * t / 0.31)
        # Raised-cosine end fade avoids a hard cut; normalize below with headroom.
        fade = min(t / 0.003, 1) * min((duration - t) / 0.045, 1)
        samples.append(value * max(0, fade))
    scale = 0.78 / max(abs(x) for x in samples)
    with wave.open(str(DEST / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(struct.pack("<h", round(x * scale * 32767)) for x in samples))


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    wood = [(82, .42, 17), (143, .27, 22), (227, .15, 28), (371, .08, 37)]
    render("wooden-door", .78, wood, [(.27, .9, 32), (.315, .3, 75)], creak=True)
    render("soft-latch", .35, [(760, .13, 65), (1480, .08, 95)], [(.02, .36, 135), (.065, .25, 95)])
    render("book-close", .55, [(120, .28, 24), (250, .15, 38)], [(.07, .45, 20), (.14, .65, 45)])
    render("sci-fi-hatch", .82, [(61, .36, 13), (177, .16, 25), (640, .08, 40)], [(.29, .7, 28), (.37, .25, 55)], air=True)
    print("Generated four original mono 44.1 kHz PCM sounds.")
