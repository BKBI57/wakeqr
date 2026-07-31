"""Generate royalty-free alarm sounds for WakeQR (no external deps).

Outputs:
  WakeQR/Resources/alarm.wav   - loud alternating two-tone alarm, ~28s (loopable,
                                 also under the 30s limit for notification sounds)
  WakeQR/Resources/silence.wav - 10s near-silent tone used to keep the app alive
                                 in the background (audio background mode)
"""
import math
import os
import struct
import wave

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "WakeQR", "Resources")


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        w.writeframes(frames)


def alarm_samples():
    """Classic aggressive alarm: fast beeping bursts alternating between two pitches."""
    samples = []
    total_seconds = 28.0
    beep_len = 0.12          # seconds per beep
    gap_len = 0.06           # silence between beeps
    burst = 8                # beeps per burst
    burst_gap = 0.35         # pause between bursts
    freqs = [1568.0, 2093.0] # G6 / C7 - piercing but not pure-sine harsh
    t = 0.0
    burst_i = 0
    while t < total_seconds:
        f = freqs[burst_i % 2]
        for _ in range(burst):
            n = int(beep_len * RATE)
            for i in range(n):
                # square-ish wave (sine + 3rd harmonic, clipped) = loud and cutting
                x = 2 * math.pi * f * i / RATE
                s = math.sin(x) + 0.5 * math.sin(3 * x)
                s = max(-1.0, min(1.0, s * 1.6))
                # short attack/release to avoid clicks
                env = min(1.0, i / (0.004 * RATE), (n - i) / (0.004 * RATE))
                samples.append(0.95 * s * env)
            samples.extend([0.0] * int(gap_len * RATE))
            t += beep_len + gap_len
            if t >= total_seconds:
                break
        samples.extend([0.0] * int(burst_gap * RATE))
        t += burst_gap
        burst_i += 1
    return samples


def silence_samples():
    """Near-silent (but not digitally zero) tone so iOS keeps the audio session alive."""
    n = 10 * RATE
    return [0.0004 * math.sin(2 * math.pi * 100.0 * i / RATE) for i in range(n)]


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUT_DIR, "alarm.wav"), alarm_samples())
    write_wav(os.path.join(OUT_DIR, "silence.wav"), silence_samples())
    print("wrote alarm.wav and silence.wav")
