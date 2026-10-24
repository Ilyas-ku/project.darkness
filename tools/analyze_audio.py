#!/usr/bin/env python3
"""Objective check of recorded game audio (Godot Movie Maker .avi -> PCM).
Prints a timeline of loudness (RMS dBFS) and stereo balance per window and counts
transient onsets (footsteps, impacts) above the ambience floor.

usage: python3 tools/analyze_audio.py movie.avi [window_s=0.25]
"""
import subprocess
import sys
import wave

import numpy as np


def load(path):
    wav = path.rsplit(".", 1)[0] + "_audio.wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-vn", "-acodec", "pcm_s16le", wav], check=True)
    with wave.open(wav) as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
    return sr, data.reshape(-1, ch)


def main():
    path = sys.argv[1]
    win = float(sys.argv[2]) if len(sys.argv) > 2 else 0.25
    sr, x = load(path)
    n = int(win * sr)
    hop = int(0.01 * sr)
    # onset detection on 10 ms frames: energy jump over the running median floor
    frames = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)])
    floor = np.median(frames)
    onsets = []
    for i in range(3, len(frames)):
        if frames[i] > max(4 * floor, 0.004) and frames[i] > 2.0 * frames[i - 3:i].max():
            if not onsets or i - onsets[-1] > 8:
                onsets.append(i)
    print(f"file={path} duration={len(x) / sr:.1f}s floor_rms={20 * np.log10(floor + 1e-9):.1f} dBFS onsets={len(onsets)}")
    print(" t(s)   rms(dBFS)  L/R balance  onsets")
    for k in range(0, len(x), n):
        seg = x[k:k + n]
        if len(seg) < n // 2:
            break
        rms = np.sqrt(np.mean(seg ** 2))
        l, r = np.sqrt(np.mean(seg[:, 0] ** 2)), np.sqrt(np.mean(seg[:, 1] ** 2))
        bal = (r - l) / (r + l + 1e-9)
        cnt = sum(1 for o in onsets if k <= o * hop < k + n)
        print(f"{k / sr:5.2f}  {20 * np.log10(rms + 1e-9):8.1f}   {bal:+.2f} {'R' if bal > 0.15 else ('L' if bal < -0.15 else 'C')}   {'|' * cnt}")


if __name__ == "__main__":
    main()
