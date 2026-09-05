"""Generate royalty-free alarm sounds for WakeQR (no external deps).

Outputs (all mono 16-bit 44.1kHz WAV, ~28s so they stay under the 30s
notification-sound limit and loop seamlessly in-app):
  WakeQR/Resources/alarm_classic.wav - alternating two-tone beep bursts
  WakeQR/Resources/alarm_siren.wav   - continuous rising/falling siren sweep
  WakeQR/Resources/alarm_bell.wav    - repeated bell strikes
  WakeQR/Resources/alarm_digital.wav - fast high-pitched digital pips
  WakeQR/Resources/alarm_urgent.wav  - relentless two-tone emergency alternation
  WakeQR/Resources/alarm_buzzer.wav  - harsh low buzzer, hardest to sleep through
  WakeQR/Resources/alarm_chime.wav   - ascending arpeggio, gentlest of the set
  WakeQR/Resources/silence.wav       - 10s near-silent keep-alive tone

To add your own tone (e.g. a recording of your own voice), skip this script:
drop a mono WAV under 30s into WakeQR/Resources/ and add its base name to
AppModel.sounds. A voice you recognise is far harder to sleep through than
anything synthesised here.
"""
import math
import os
import struct
import wave

RATE = 44100
TOTAL = 28.0
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "WakeQR", "Resources")


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        w.writeframes(frames)


def beep_pattern(freqs, beep_len, gap_len, burst, burst_gap, amp=0.95):
    samples = []
    t = 0.0
    burst_i = 0
    while t < TOTAL:
        f = freqs[burst_i % len(freqs)]
        for _ in range(burst):
            n = int(beep_len * RATE)
            for i in range(n):
                x = 2 * math.pi * f * i / RATE
                s = math.sin(x) + 0.5 * math.sin(3 * x)
                s = max(-1.0, min(1.0, s * 1.6))
                env = min(1.0, i / (0.004 * RATE), (n - i) / (0.004 * RATE))
                samples.append(amp * s * env)
            samples.extend([0.0] * int(gap_len * RATE))
            t += beep_len + gap_len
            if t >= TOTAL:
                break
        samples.extend([0.0] * int(burst_gap * RATE))
        t += burst_gap
        burst_i += 1
    return samples


def classic():
    return beep_pattern([1568.0, 2093.0], 0.12, 0.06, 8, 0.35)


def digital():
    return beep_pattern([3200.0, 4000.0], 0.06, 0.03, 14, 0.22)


def siren():
    """Continuous sweep 700..1500 Hz, phase-accurate so there are no clicks."""
    samples = []
    phase = 0.0
    n = int(TOTAL * RATE)
    for i in range(n):
        t = i / RATE
        f = 1100.0 + 400.0 * math.sin(2 * math.pi * 0.6 * t)
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase) + 0.4 * math.sin(2 * phase)
        s = max(-1.0, min(1.0, s * 1.3))
        edge = min(1.0, i / (0.01 * RATE), (n - i) / (0.01 * RATE))
        samples.append(0.9 * s * edge)
    return samples


def bell():
    """A bright bell strike every 1.1s: inharmonic partials with exponential decay."""
    samples = [0.0] * int(TOTAL * RATE)
    strike_period = 1.1
    partials = [(880.0, 1.0), (2200.0, 0.6), (3960.0, 0.35)]
    strike_len = int(1.0 * RATE)
    t0 = 0.0
    while t0 < TOTAL - 0.2:
        start = int(t0 * RATE)
        for i in range(min(strike_len, len(samples) - start)):
            t = i / RATE
            s = sum(a * math.exp(-4.0 * t) * math.sin(2 * math.pi * f * t) for f, a in partials)
            samples[start + i] += 0.85 * s
        t0 += strike_period
    return [max(-1.0, min(1.0, s)) for s in samples]


def urgent():
    """Two tones alternating with almost no gap - no lull to drift back off in."""
    samples = []
    t = 0.0
    i_tone = 0
    while t < TOTAL:
        f = (880.0, 1318.0)[i_tone % 2]
        n = int(0.18 * RATE)
        for i in range(n):
            x = 2 * math.pi * f * i / RATE
            s = math.sin(x) + 0.6 * math.sin(2 * x) + 0.3 * math.sin(3 * x)
            s = max(-1.0, min(1.0, s * 1.5))
            env = min(1.0, i / (0.005 * RATE), (n - i) / (0.005 * RATE))
            samples.append(0.95 * s * env)
        samples.extend([0.0] * int(0.02 * RATE))
        t += 0.2
        i_tone += 1
    return samples


def buzzer():
    """Harsh low square-ish buzz, pulsed. Deliberately unpleasant."""
    samples = []
    n = int(TOTAL * RATE)
    for i in range(n):
        t = i / RATE
        base = math.sin(2 * math.pi * 210.0 * t)
        s = 1.0 if base >= 0 else -1.0            # square wave
        s += 0.4 * (1.0 if math.sin(2 * math.pi * 420.0 * t) >= 0 else -1.0)
        gate = 1.0 if (t % 0.7) < 0.45 else 0.0   # on/off pulsing
        edge = min(1.0, i / (0.01 * RATE), (n - i) / (0.01 * RATE))
        samples.append(0.55 * max(-1.0, min(1.0, s)) * gate * edge)
    return samples


def chime():
    """Ascending five-note arpeggio with bell decay - the gentle option."""
    samples = [0.0] * int(TOTAL * RATE)
    notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]
    step = 0.32
    note_len = int(1.4 * RATE)
    t0 = 0.0
    k = 0
    while t0 < TOTAL - 0.3:
        f = notes[k % len(notes)]
        start = int(t0 * RATE)
        for i in range(min(note_len, len(samples) - start)):
            t = i / RATE
            s = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2 * t)
            samples[start + i] += 0.5 * s * math.exp(-2.6 * t)
        t0 += step
        k += 1
        if k % len(notes) == 0:
            t0 += 0.9   # breathe between runs
    return [max(-1.0, min(1.0, s)) for s in samples]


def silence_samples():
    n = 10 * RATE
    return [0.0004 * math.sin(2 * math.pi * 100.0 * i / RATE) for i in range(n)]


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUT_DIR, "alarm_classic.wav"), classic())
    write_wav(os.path.join(OUT_DIR, "alarm_siren.wav"), siren())
    write_wav(os.path.join(OUT_DIR, "alarm_bell.wav"), bell())
    write_wav(os.path.join(OUT_DIR, "alarm_digital.wav"), digital())
    write_wav(os.path.join(OUT_DIR, "alarm_urgent.wav"), urgent())
    write_wav(os.path.join(OUT_DIR, "alarm_buzzer.wav"), buzzer())
    write_wav(os.path.join(OUT_DIR, "alarm_chime.wav"), chime())
    write_wav(os.path.join(OUT_DIR, "silence.wav"), silence_samples())
    print("wrote alarm_classic/siren/bell/digital/urgent/buzzer/chime + silence")
