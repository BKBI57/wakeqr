"""Generate royalty-free alarm sounds for WakeQR (no external deps).

Outputs (all mono 16-bit 44.1kHz WAV, ~28s so they stay under the 30s
notification-sound limit and loop seamlessly in-app):
  WakeQR/Resources/alarm_classic.wav - alternating two-tone beep bursts
  WakeQR/Resources/alarm_siren.wav   - continuous rising/falling siren sweep
  WakeQR/Resources/alarm_bell.wav    - repeated bell strikes
  WakeQR/Resources/alarm_digital.wav - fast high-pitched digital pips
  WakeQR/Resources/silence.wav       - 10s near-silent keep-alive tone
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


def silence_samples():
    n = 10 * RATE
    return [0.0004 * math.sin(2 * math.pi * 100.0 * i / RATE) for i in range(n)]


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUT_DIR, "alarm_classic.wav"), classic())
    write_wav(os.path.join(OUT_DIR, "alarm_siren.wav"), siren())
    write_wav(os.path.join(OUT_DIR, "alarm_bell.wav"), bell())
    write_wav(os.path.join(OUT_DIR, "alarm_digital.wav"), digital())
    write_wav(os.path.join(OUT_DIR, "silence.wav"), silence_samples())
    print("wrote alarm_classic/siren/bell/digital + silence")
