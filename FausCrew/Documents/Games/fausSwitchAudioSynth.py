"""Faus Switch audio: a cute looping chiptune-ish track, two flip "bloops" and a portal "vwoop".
Pure Python, writes 16-bit mono WAV files into the directory given as argv[1]."""
import math, random, struct, sys, wave, os

OUT = sys.argv[1]
RATE = 32000
random.seed(7)

def write(name, samples, rate=RATE):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.89 / peak
    with wave.open(os.path.join(OUT, name), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate)
        f.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * gain)) * 32767)) for s in samples))

def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12)

# ---------------------------------------------------------------- music
BPM = 116
EIGHTH = 60 / BPM / 2
BARS = 16
LOOP = int(round(BARS * 8 * EIGHTH * RATE / 64)) * 64
mix = [0.0] * LOOP

def add(start_s, voice):
    """voice: list of samples; wraps around the loop so the seam is continuous."""
    i0 = int(round(start_s * RATE))
    for k, v in enumerate(voice):
        mix[(i0 + k) % LOOP] += v

def env(n, attack, release, total):
    a = max(1, int(attack * RATE)); r = max(1, int(release * RATE))
    out = []
    for i in range(n):
        if i < a: e = i / a
        else: e = 1.0
        rem = n - i
        if rem < r: e *= rem / r
        out.append(e)
    return out

def lead(midi, dur):
    f = hz(midi); n = int((dur + 0.06) * RATE); out = []; lp = 0.0
    for i in range(n):
        t = i / RATE
        vib = 1 + 0.004 * math.sin(2 * math.pi * 5.5 * t) * min(1, t / 0.15)
        ph = (f * vib * t) % 1.0
        tri = 4 * abs(ph - 0.5) - 1
        pulse = 1.0 if ph < 0.25 else -1.0
        x = 0.68 * tri + 0.32 * pulse
        lp += 0.28 * (x - lp)                      # soft one-pole low-pass
        decay = 0.55 + 0.45 * math.exp(-t * 5)     # plucky, then sustain
        rel = 1.0 if t < dur else max(0.0, 1 - (t - dur) / 0.06)
        att = min(1, t / 0.008)
        out.append(lp * decay * rel * att * 0.30)
    return out

def bell(midi, dur, level):
    f = hz(midi); n = int((dur + 0.35) * RATE); out = []
    for i in range(n):
        t = i / RATE
        e = math.exp(-t * 7.5) * min(1, t / 0.003)
        x = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 4 * t) * math.exp(-t * 22)
        out.append(x * e * level)
    return out

def bass(midi, dur):
    f = hz(midi); n = int((dur + 0.03) * RATE); out = []
    for i in range(n):
        t = i / RATE
        ph = (f * t) % 1.0
        tri = 4 * abs(ph - 0.5) - 1
        e = math.exp(-t * 3.2) * min(1, t / 0.005) * (1.0 if t < dur else max(0, 1 - (t - dur) / 0.03))
        out.append((tri + 0.25 * math.sin(2 * math.pi * f * 2 * t)) * e * 0.34)
    return out

def kick():
    n = int(0.18 * RATE); out = []; ph = 0.0
    for i in range(n):
        t = i / RATE
        f = 48 + 90 * math.exp(-t * 30)
        ph += 2 * math.pi * f / RATE
        out.append(math.sin(ph) * math.exp(-t * 16) * 0.55)
    return out

def hat(level):
    n = int(0.045 * RATE); out = []; prev = 0.0
    for i in range(n):
        t = i / RATE
        w = random.uniform(-1, 1)
        hp = w - prev; prev = w                    # crude high-pass
        out.append(hp * math.exp(-t * 90) * level)
    return out

def clap():
    n = int(0.12 * RATE); out = []; prev = 0.0
    for i in range(n):
        t = i / RATE
        w = random.uniform(-1, 1); hp = w - 0.6 * prev; prev = w
        tone = math.sin(2 * math.pi * 330 * t) * math.exp(-t * 40)
        out.append((hp * 0.6 + tone * 0.5) * math.exp(-t * 28) * 0.16)
    return out

# F major. Chords: bass root, triad for the arpeggio.
CH = {
    'F': (41, [65, 69, 72]), 'Dm': (38, [62, 65, 69]), 'Bb': (46, [62, 65, 70]),
    'C': (36, [60, 64, 67]), 'Am': (45, [60, 64, 69]), 'Gm': (43, [62, 67, 70]),
}
PROG = ['F', 'Dm', 'Bb', 'C', 'F', 'Am', 'Bb', 'C', 'Gm', 'C', 'Am', 'Dm', 'Bb', 'C', 'F', 'C']
F4, G4, A4, Bb4, C5, D5, E5, F5, G5, A5, C6 = 65, 67, 69, 70, 72, 74, 76, 77, 79, 81, 84
MELODY = [  # per bar: (start eighth, length in eighths, midi)
    [(0, 1, C5), (1, 1, A4), (2, 1, C5), (3, 2, F5), (5, 1, E5), (6, 1, D5), (7, 1, C5)],
    [(0, 2, D5), (2, 1, A4), (3, 1, D5), (4, 2, F5), (6, 2, E5)],
    [(0, 1, D5), (1, 1, C5), (2, 1, Bb4), (3, 2, D5), (5, 1, F5), (6, 2, D5)],
    [(0, 2, C5), (2, 1, E5), (3, 3, G5)],
    [(0, 1, A5), (1, 1, G5), (2, 1, F5), (3, 1, C5), (4, 2, F5), (6, 2, A5)],
    [(0, 1, G5), (1, 1, E5), (2, 2, C5), (4, 1, E5), (5, 1, G5), (6, 2, A5)],
    [(0, 2, F5), (2, 1, D5), (3, 1, Bb4), (4, 1, D5), (5, 1, F5), (6, 1, G5), (7, 1, F5)],
    [(0, 3, E5), (3, 1, G5), (4, 4, C5)],
    [(0, 2, Bb4), (2, 2, D5), (4, 2, G5), (6, 2, F5)],
    [(0, 2, E5), (2, 2, C5), (4, 2, G4), (6, 2, C5)],
    [(0, 1, A4), (1, 1, C5), (2, 2, E5), (4, 2, A5), (6, 2, G5)],
    [(0, 2, F5), (2, 2, D5), (4, 2, A4), (6, 2, D5)],
    [(0, 1, D5), (1, 1, F5), (2, 2, A5), (4, 1, G5), (5, 1, F5), (6, 2, D5)],
    [(0, 1, E5), (1, 1, G5), (2, 2, C6), (4, 2, G5), (6, 2, E5)],
    [(0, 3, F5), (3, 1, C5), (4, 1, A4), (5, 1, C5), (6, 2, F5)],
    [(0, 2, G5), (2, 2, E5), (4, 3, C5)],
]

for bar, name in enumerate(PROG):
    root, triad = CH[name]
    t0 = bar * 8 * EIGHTH
    calm = 8 <= bar < 12
    for start, length, midi in MELODY[bar]:
        add(t0 + start * EIGHTH, lead(midi, length * EIGHTH * 0.92))
    for step, idx in enumerate([0, 1, 2, 1, 0, 1, 2, 1]):
        add(t0 + step * EIGHTH, bell(triad[idx], EIGHTH, 0.085 if step % 2 else 0.11))
    add(t0, bell(triad[2] + 12, EIGHTH, 0.05))                 # sparkle on the downbeat
    for step, midi, length in [(0, root, 1.4), (3, root + 12, 0.8), (4, root + 7, 1.4), (6, root + 12, 0.8)]:
        add(t0 + step * EIGHTH, bass(midi, length * EIGHTH))
    for step in ([0] if calm else [0, 4]):
        add(t0 + step * EIGHTH, kick())
    if not calm:
        for step in (2, 6):
            add(t0 + step * EIGHTH, clap())
    for step in (1, 3, 5, 7):
        add(t0 + step * EIGHTH, hat(0.05 if calm else 0.07))

# gentle bus compression-ish soft clip
peak = max(abs(s) for s in mix)
music = [math.tanh(1.4 * s / peak) / math.tanh(1.4) for s in mix]
write('music.wav', music)

# ---------------------------------------------------------------- flip bloops
def bloop(f_start, f_end, sparkle):
    n = int(0.24 * RATE); out = []; ph = 0.0; ph2 = 0.0
    for i in range(n):
        t = i / RATE
        glide = min(1, t / 0.085)
        g = glide * glide * (3 - 2 * glide)                # smoothstep pitch glide
        f = f_start * (f_end / f_start) ** g
        ph += 2 * math.pi * f / RATE
        ph2 += 2 * math.pi * sparkle / RATE
        body = math.sin(ph) + 0.18 * math.sin(2 * ph)
        e = min(1, t / 0.004) * math.exp(-t * 15)
        twinkle = math.sin(ph2) * math.exp(-max(0, t - 0.05) * 30) * (1 if t > 0.05 else 0) * 0.28
        out.append((body * e + twinkle) * 0.8)
    return out

write('flip_up.wav', bloop(560, 1120, 2240))        # toward the ceiling: rising
write('flip_down.wav', bloop(980, 520, 1560))       # toward the floor: falling

# ---------------------------------------------------------------- portal vwoop
def vwoop():
    # A wobbling tone that swirls down while a soft shimmer rises: being pulled through
    # and thrown back. Short and quieter than a crash, so it reads as a setback.
    n = int(0.36 * RATE); out = []; ph = 0.0; ph2 = 0.0; prev = 0.0; lp = 0.0
    for i in range(n):
        t = i / RATE
        k = t / 0.36
        wobble = 1 + 0.06 * math.sin(2 * math.pi * 17 * t)
        f = (1250 * (300 / 1250) ** (k ** 0.8)) * wobble          # swirl down
        f2 = 620 * (1900 / 620) ** k                               # shimmer up
        ph += 2 * math.pi * f / RATE
        ph2 += 2 * math.pi * f2 / RATE
        body = math.sin(ph) + 0.22 * math.sin(3 * ph)
        shimmer = math.sin(ph2) * 0.22 * math.sin(math.pi * k)
        w = random.uniform(-1, 1); hp = w - prev; prev = w
        lp += 0.18 * (hp - lp)
        whoosh = lp * 0.5 * math.sin(math.pi * min(1, k * 1.6))
        e = min(1, t / 0.012) * (1 - k) ** 1.6
        out.append((body * 0.75 + shimmer + whoosh) * e)
    return out

write('portal.wav', vwoop())
print('loop seconds', LOOP / RATE)
