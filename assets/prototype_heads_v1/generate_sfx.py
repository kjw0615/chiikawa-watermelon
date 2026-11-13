"""Reproducible original prototype sounds. Python standard library only."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).parent / 'sfx'
OUT.mkdir(parents=True, exist_ok=True)


def write(name, samples):
    peak = max(abs(x) for x in samples) or 1
    gain = min(1, 0.7 / peak)
    data = b''.join(struct.pack('<h', round(max(-1, min(1, x * gain)) * 32767)) for x in samples)
    with wave.open(str(OUT / name), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(data)


def pop(duration, start, end, level):
    rng = random.Random(42)
    result = []
    phase = 0
    for i in range(round(duration * RATE)):
        t = i / RATE
        phase += 2 * math.pi * (end + (start - end) * math.exp(-t * 28)) / RATE
        env = min(1, t / 0.003) * math.exp(-t * 27) * min(1, (duration - t) / 0.015)
        result.append(level * env * (math.sin(phase) + 0.08 * rng.uniform(-1, 1)))
    return result


def chime(notes, spacing, duration):
    result = [0.0] * round(duration * RATE)
    for j, freq in enumerate(notes):
        offset = round(j * spacing * RATE)
        for i in range(len(result) - offset):
            t = i / RATE
            env = min(1, t / 0.004) * math.exp(-t * 10) * min(1, (duration - (i + offset) / RATE) / 0.025)
            result[i + offset] += 0.34 * env * (math.sin(2 * math.pi * freq * t) + 0.2 * math.sin(2 * math.pi * freq * 2 * t))
    return result


write('contact_soft.wav', pop(0.14, 650, 240, 0.48))
write('land_squash.wav', pop(0.26, 270, 85, 0.65))
write('merge_pop.wav', chime([523.25, 659.25, 783.99], 0.05, 0.52))
write('merge_chain.wav', chime([783.99, 987.77, 1174.66, 1567.98], 0.055, 0.68))
for p in sorted(OUT.glob('*.wav')):
    with wave.open(str(p), 'rb') as f:
        raw = f.readframes(f.getnframes())
        values = struct.unpack('<' + 'h' * (len(raw) // 2), raw)
        print(p.name, f.getframerate(), 'Hz', f.getnchannels(), 'channel', f.getsampwidth() * 8, 'bit', round(f.getnframes() / f.getframerate(), 3), 'sec', 'peak', max(abs(v) for v in values))
