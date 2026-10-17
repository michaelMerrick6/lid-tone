#!/usr/bin/env python3
"""Prepare credited CC0 recordings. Requires NumPy for development only.

Input directory: decoded wood.wav, saber-real.wav, and the extracted
Button Accordion HN SFZ+WAV-20240329 sound bank. See docs/AUDIO_CREDITS.md.
"""
import sys
import wave
from pathlib import Path
import numpy as np

RATE = 48000
SOURCE = Path(sys.argv[1])
DEST = Path(__file__).resolve().parents[1] / 'Sources/LidTone/Resources/Audio'
DEST.mkdir(parents=True, exist_ok=True)


def read(path):
    with wave.open(str(path)) as w:
        assert w.getsampwidth() == 2
        signal = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').reshape(-1, w.getnchannels()).mean(axis=1) / 32768
        return signal, w.getframerate()


def save(name, signal):
    signal = signal - signal.mean()
    signal = signal * (0.86 / max(abs(signal)))
    # Avoid leading/trailing clicks; the renderer also overlaps the loop seam.
    fade = min(480, len(signal)//8)
    signal[:fade] *= np.linspace(0, 1, fade)
    signal[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(str(DEST / (name+'.wav')), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(np.round(signal*32767).astype('<i2').tobytes())
    print(name, f'{len(signal)/RATE:.2f}s')


def resample(signal, rate):
    return np.interp(np.arange(round(len(signal)*RATE/rate))*rate/RATE, np.arange(len(signal)), signal)


wood, sr = read(SOURCE/'wood.wav')
# Preserve long irregular creaks, omitting one near-silent gap in the source.
wood = np.concatenate([wood[round(.15*sr):round(6.8*sr)], wood[round(8.0*sr):round(16.7*sr)]])
save('wood-creaks', resample(wood, sr))
saber, sr = read(SOURCE/'saber-real.wav')
save('saber-hum', resample(saber[round(32*sr):round(38*sr)], sr))
save('saber-swings', resample(saber[round(42*sr):round(51.8*sr)], sr))

bank = SOURCE/'Button Accordion HN SFZ+WAV-20240329'
notes = {'C5':(72926,86200,-28), 'E5':(65908,83784,-30), 'G5':(78733,97217,-29),
         'G4':(66543,93290,-30), 'B4':(76136,91082,-19), 'D5':(73008,86264,-26)}


def reed(note, semitones=0):
    signal, sr = read(bank/f'Button Accordion HN {note}.wav')
    start, end, cents = notes[note]
    loop = signal[start:end+1]
    # Overlap the sustain seam once, then repeat phase-continuously.
    overlap = 100
    loop = np.concatenate([loop[overlap:-overlap], loop[-overlap:]*np.linspace(1,0,overlap) + loop[:overlap]*np.linspace(0,1,overlap)])
    phase = np.arange(RATE*6)*sr/RATE*2**((semitones+cents/100)/12)
    return np.interp(phase % len(loop), np.arange(len(loop)+1), np.r_[loop,loop[0]])


save('accordion-open', reed('C5') + .8*reed('E5') + .7*reed('G5') + .35*reed('C5',-12))
save('accordion-close', reed('G4') + .8*reed('B4') + .7*reed('D5') + .35*reed('G4',-12))
