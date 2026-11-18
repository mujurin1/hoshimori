"""ほしもり 効果音生成 -> game/audio/sfx/*.wav (44.1kHz/16bit/mono)

音程のあるものは D major ペンタトニック (D E F# A B) 基準で BGM と調を揃える。
"""
import os
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import fftconvolve

from synth import *  # noqa

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'game', 'audio', 'sfx')
rng = np.random.default_rng(2026)

PENTA = ['D', 'E', 'F#', 'A', 'B']


def penta(oct_lo, oct_hi):
    return [nm(f'{p}{o}') for o in range(oct_lo, oct_hi + 1) for p in PENTA]


def place(buf, t, sig, gain=1.0):
    i = ns(t)
    m = min(len(sig), len(buf) - i)
    if m > 0:
        buf[i:i + m] += sig[:m] * gain


def room(x, wet=0.25, sec=1.2, rt=0.9, seed=1):
    ir = make_ir(sec, rt, 0.012, 7000, 2500, seed=seed, stereo=False)
    y = fftconvolve(x, ir)[:len(x)]
    return x + wet * y


def tail(x, sec):
    return np.concatenate([x, np.zeros(ns(sec))])


def sine_sweep(f, n):
    ph, _ = phase(f, n)
    return np.sin(TAU * ph)


# ------------------------------------------------------------------ 高頻度
def shoot():
    n = ns(0.13)
    t = tvec(n)
    f = 880 + 1200 * np.exp(-t / 0.022)  # A5 に落ちる「ピュ」
    ph, dt = phase(f, n)
    y = sine(ph) + 0.25 * tri(ph * 2)
    y *= env_ar(n, 0.003, 0.035)
    return lp(y, 3500)


def hit():
    n = ns(0.085)
    t = tvec(n)
    nz = lp(white(n, rng), 2200) * env_ar(n, 0.001, 0.018)
    th = sine_sweep(320 * (1 + 0.6 * np.exp(-t / 0.008)), n) * env_ar(n, 0.001, 0.03)
    return 0.7 * nz + th


def enemy_die():
    n = ns(0.22)
    t = tvec(n)
    f = 587.3 * (1 + 1.4 * np.exp(-t / 0.012))  # D5 へ落ちるポップ
    y = sine_sweep(f, n) * env_ar(n, 0.001, 0.055)
    y += 0.35 * sine_sweep(f * 2, n) * env_ar(n, 0.001, 0.02)
    y += 0.5 * sine_sweep(150 * (1 + np.exp(-t / 0.01)), n) * env_ar(n, 0.001, 0.03)
    y += 0.3 * lp(white(n, rng), 3000) * env_ar(n, 0.0005, 0.006)
    # 小さなきらめき (A6)
    sp = np.zeros(n)
    place(sp, 0.025, np.sin(TAU * 1760 * tvec(ns(0.15))) * env_ar(ns(0.15), 0.001, 0.035))
    return y + 0.18 * sp


def gem():
    n = ns(0.17)
    t = tvec(n)
    f = 1760.0  # A6 (D major の5度)。エンジン側でピッチ変更
    y = np.sin(TAU * f * t + 0.6 * np.exp(-t / 0.03) * np.sin(TAU * f * 2 * t))
    y += 0.2 * np.sin(TAU * f * 2 * t) * np.exp(-t / 0.025)
    y *= env_ar(n, 0.001, 0.06)
    return y


def moon_hit():
    n = ns(0.1)
    t = tvec(n)
    y = np.sin(TAU * 880 * t) * env_ar(n, 0.0005, 0.026)
    y += 0.35 * np.sin(TAU * 880 * 2.32 * t) * env_ar(n, 0.0005, 0.008)
    y += 0.5 * np.sin(TAU * 220 * t) * env_ar(n, 0.0005, 0.012)
    y += 0.25 * bp(white(n, rng), 1500, 5000) * env_ar(n, 0.0002, 0.002)
    return y


# ------------------------------------------------------------------ UI
def hover():
    n = ns(0.055)
    t = tvec(n)
    y = np.sin(TAU * 1174.7 * t) * env_ar(n, 0.001, 0.012)  # D6
    y += 0.15 * np.sin(TAU * 2349.3 * t) * env_ar(n, 0.001, 0.005)
    return y


def select():
    x = np.zeros(ns(0.22))
    for k, m in enumerate(('A5', 'D6')):
        n = ns(0.16)
        t = tvec(n)
        f = midi_hz(nm(m))
        ph, _ = phase(f, n)
        s = (tri(ph) * 0.6 + sine(ph)) * env_ar(n, 0.002, 0.05 if k == 0 else 0.06)
        place(x, k * 0.055, s, 0.8 if k == 0 else 1.0)
    return lp(x, 5000)


# ------------------------------------------------------------------ プレイヤー
def hurt():
    n = ns(0.32)
    t = tvec(n)
    th = sine_sweep(55 + 110 * np.exp(-t / 0.04), n) * env_ar(n, 0.001, 0.12)
    # 短2度の不協和 (G3 / G#3) を歪ませる
    d = np.zeros(n)
    for f in (196.0, 207.7, 311.1):
        ph, dt = phase(f * (1 - 0.08 * t / 0.32), n)
        d += pulse(ph, dt, 0.4)
    d = lp(np.tanh(d * 1.5), 1600) * env_ar(n, 0.002, 0.09)
    nz = lp(white(n, rng), 1500) * env_ar(n, 0.001, 0.03)
    return 0.6 * th + 0.9 * d + 0.4 * nz


def dash():
    n = ns(0.3)
    t = tvec(n)
    fc = 500 * (2800 / 500) ** np.clip(t / 0.13, 0, 1) * (1 - 0.4 * np.clip((t - 0.13) / 0.17, 0, 1))
    y = tv_filter(white(n, rng), fc, 'band', 1.3)
    a = np.clip(t / 0.05, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 0.05, 0) / 0.07)
    return y * a


def heal():
    x = np.zeros(ns(0.65))
    for k, m in enumerate(('D5', 'F#5', 'A5', 'D6')):
        n = ns(0.5)
        f = midi_hz(nm(m))
        ph, _ = phase(f, n)
        ph2, _ = phase(f * 1.004, n)
        s = (tri(ph) + 0.6 * sine(ph2) + 0.2 * sine(ph * 2)) * env_ar(n, 0.02, 0.18)
        place(x, k * 0.07, s, 0.7 + 0.1 * k)
    # 暖かい上昇グライド
    n = len(x)
    t = tvec(n)
    g = sine_sweep(293.7 * 2 ** (t / 0.5), n) * np.sin(np.pi * np.clip(t / 0.55, 0, 1)) ** 2
    x += 0.35 * g
    return room(lp(x, 4000), 0.2, seed=4)


def pickup_special():
    x = np.zeros(ns(0.8))
    notes = ['D6', 'E6', 'F#6', 'A6', 'B6', 'D7']
    for k, m in enumerate(notes):
        place(x, k * 0.045, fm_bell(midi_hz(nm(m)), 0.7, 0.5, 2.0, 1.0, 0.12, 0.05))
    # シマー: 和音 (D/A) をトレモロで
    n = len(x)
    t = tvec(n)
    sh = sum(np.sin(TAU * midi_hz(nm(m)) * t) for m in ('D6', 'F#6', 'A6'))
    sh *= (0.6 + 0.4 * np.sin(TAU * 14 * t)) * np.clip((t - 0.2) / 0.05, 0, 1) * np.exp(-np.maximum(t - 0.25, 0) / 0.12)
    sh *= (t > 0.2)
    x += 0.12 * sh
    x += 0.1 * hp(white(n, rng), 8000) * np.exp(-t / 0.15) * np.clip(t / 0.01, 0, 1)
    return room(x, 0.3, seed=6)


def levelup():
    x = np.zeros(ns(1.25))
    seq = ['D5', 'F#5', 'A5', 'D6', 'F#6', 'A6']
    for k, m in enumerate(seq):
        f = midi_hz(nm(m))
        place(x, k * 0.065, fm_bell(f, 0.8, 0.9, 3.0, 1.2, 0.35 if k < 5 else 0.5, 0.08))
        ph, _ = phase(f, ns(0.3))
        place(x, k * 0.065, tri(ph) * env_ar(ns(0.3), 0.003, 0.08), 0.25)
    # 最後に D メジャーの和音を鳴らす
    for m in ('D5', 'A5', 'D6', 'F#6'):
        place(x, 0.42, fm_bell(midi_hz(nm(m)), 0.35, 0.8, 2.0, 0.8, 0.35, 0.1))
    # きらめき
    pool = penta(6, 7)
    for k in range(10):
        place(x, 0.35 + k * 0.05 + rng.uniform(0, 0.02),
              fm_bell(midi_hz(rng.choice(pool)), rng.uniform(0.15, 0.3), 0.4, 2.0, 0.8, 0.12, 0.05))
    return room(x, 0.25, seed=2)


# ------------------------------------------------------------------ 攻撃 / スキル
def shockwave():
    n = ns(0.62)
    t = tvec(n)
    f = 42 + 90 * np.exp(-t / 0.12)
    ph, dt = phase(f, n)
    body = 0.8 * np.sin(TAU * ph) + 0.4 * saw(ph, dt)
    fc = 180 + 1100 * np.exp(-t / 0.08)
    body = tv_filter(body, fc, 'low', 2.0)
    nz = tv_filter(white(n, rng), 300 + 1500 * np.exp(-t / 0.1), 'low', 0.8) * 0.4
    a = np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.18)
    return (body + nz) * a


def lightning():
    n = ns(0.36)
    t = tvec(n)
    # パチパチ: まばらなインパルス列 * ノイズ
    imp = (rng.random(n) < 0.004 * np.exp(-t / 0.12) + 0.001).astype(float) * rng.uniform(0.3, 1, n)
    k = np.exp(-tvec(ns(0.004)) / 0.0008)
    crack = np.convolve(imp, k)[:n] * white(n, rng)
    crack = lp(hp(crack, 1200), 7000)
    zap = lp(white(n, rng), 6000) * env_ar(n, 0.0005, 0.02)
    th = sine_sweep(60 + 120 * np.exp(-t / 0.02), n) * env_ar(n, 0.001, 0.08)
    # 3〜5kHz を少し抑える
    y = 1.6 * crack + 0.8 * zap + 0.25 * th
    y = y - 0.4 * bp(y, 3000, 5000)
    return np.tanh(2.0 * y / np.max(np.abs(y))) * np.exp(-t / 0.2)


def explosion():
    n = ns(0.85)
    t = tvec(n)
    nz = tv_filter(white(n, rng), 150 + 3500 * np.exp(-t / 0.07), 'low', 0.9)
    nz *= env_ar(n, 0.002, 0.22)
    boom = sine_sweep(32 + 70 * np.exp(-t / 0.06), n) * env_ar(n, 0.002, 0.28)
    rumble = lp(white(n, rng), 120) * env_ar(n, 0.02, 0.3) * 3
    y = np.tanh(1.6 * (1.3 * nz + 1.0 * boom + 0.6 * rumble))
    return y * np.clip(1 - (t - 0.7) / 0.15, 0, 1)


def comet():
    n = ns(0.55)
    t = tvec(n)
    fc = 5500 * (900 / 5500) ** (t / 0.55)
    sw = tv_filter(white(n, rng), fc, 'band', 3.0)
    sw *= np.clip(t / 0.06, 0, 1) * np.exp(-np.maximum(t - 0.06, 0) / 0.18)
    gl = np.zeros(n)
    pool = penta(5, 7)[::-1][:10]
    for k, m in enumerate(pool):
        place(gl, 0.02 + k * 0.03, fm_bell(midi_hz(m), 0.5, 0.25, 2.0, 0.6, 0.08, 0.04))
    y = 1.4 * sw + 0.6 * gl
    y = y - 0.6 * bp(y, 3000, 5000)
    y = room(y, 0.25, seed=8)
    return y * np.clip(1 - (t - 0.45) / 0.1, 0, 1)


def enemy_shoot():
    n = ns(0.2)
    t = tvec(n)
    f = 110 + 90 * np.exp(-t / 0.03)
    ph, dt = phase(f, n)
    y = lp(pulse(ph, dt, 0.5) + 0.5 * sine(ph), 900) * env_ar(n, 0.003, 0.06)
    y += 0.6 * lp(white(n, rng), 700) * env_ar(n, 0.002, 0.035)
    return y


# ------------------------------------------------------------------ 敵 / ボス
def spawn_elite():
    n = ns(0.8)
    t = tvec(n)
    y = np.zeros(n)
    for f in (73.4, 77.8, 110.0):  # D2, Eb2, A2 (半音でぶつける)
        ph, dt = phase(f * (1 - 0.06 * t / 0.8), n)
        y += saw(ph + rng.uniform(), dt)
    wob = 250 + 450 * (0.5 + 0.5 * np.sin(TAU * 7 * t - np.pi / 2)) * np.exp(-t / 0.5)
    y = tv_filter(y, wob, 'low', 3.0)
    y += 2.0 * lp(white(n, rng), 140)
    a = np.clip(t / 0.08, 0, 1) * np.exp(-np.maximum(t - 0.25, 0) / 0.2)
    return np.tanh(y * 0.8) * a


def boss_warn():
    n = ns(1.85)
    t = tvec(n)
    y = np.zeros(n)
    for k, st in enumerate((0.0, 0.8)):
        m = ns(0.75)
        tt = tvec(m)
        h = np.zeros(m)
        for f in (73.4, 103.8, 146.8):  # D2, G#2(三全音), D3
            fr = f * (1 - 0.03 * k) * 2 ** (0.1 * np.sin(TAU * 5 * tt) * np.clip(tt / 0.3, 0, 1) / 12)
            ph, dt = phase(fr, m)
            h += saw(ph + rng.uniform(), dt)
        fc = 250 + 1100 * np.clip(tt / 0.15, 0, 1) * np.exp(-np.maximum(tt - 0.15, 0) / 0.5)
        h = tv_filter(h, fc, 'low', 1.5)
        h *= np.clip(tt / 0.04, 0, 1) * np.clip((0.75 - tt) / 0.12, 0, 1)
        place(y, st, h)
    y += 1.5 * lp(white(n, rng), 100) * np.clip(t / 0.3, 0, 1)
    y = np.tanh(0.6 * y)
    return room(y, 0.2, seed=3) * np.clip((1.85 - t) / 0.2, 0, 1)


def boss_die():
    x = np.zeros(ns(2.4))
    t = tvec(len(x))
    n = ns(1.5)
    tt = tvec(n)
    nz = tv_filter(white(n, rng), 120 + 4000 * np.exp(-tt / 0.12), 'low', 0.8) * env_ar(n, 0.002, 0.4)
    boom = sine_sweep(28 + 80 * np.exp(-tt / 0.08), n) * env_ar(n, 0.002, 0.5)
    rumble = lp(white(n, rng), 110) * env_ar(n, 0.03, 0.5) * 3
    place(x, 0, np.tanh(1.5 * (0.8 * nz + boom + 0.7 * rumble)))
    place(x, 0.12, explosion() * 0.6)
    # 降ってくるきらめき (D ペンタを下降)
    pool = penta(5, 7)[::-1]
    for k in range(22):
        st = 0.35 + k * 0.075 + rng.uniform(0, 0.03)
        m = pool[min(k // 2 + rng.integers(0, 2), len(pool) - 1)]
        place(x, st, fm_bell(midi_hz(m), 0.75 * (1 - k / 30), 0.5, 3.0, 1.0, 0.18, 0.06))
    x = room(x, 0.3, 1.8, 1.4, seed=5)
    return x * np.clip((2.4 - t) / 0.3, 0, 1)


# ------------------------------------------------------------------ ジングル
def gameover():
    x = np.zeros(ns(3.2))
    t = tvec(len(x))
    mel_ = [('A5', 0.0), ('F5', 0.32), ('E5', 0.64), ('C#5', 0.96), ('D5', 1.4)]
    for m, st in mel_:
        place(x, st, music_box(midi_hz(nm(m)), 0.9, 1.8))
        place(x, st, fm_bell(midi_hz(nm(m) - 12), 0.25, 1.2, 1.0, 0.5, 0.6))
    # 下の和音 Dm (Bb -> A -> Dm)
    for chord, st, d in ((('Bb3', 'D4', 'F4'), 0.0, 0.62), (('A3', 'C#4', 'E4'), 0.64, 0.7),
                         (('D3', 'F3', 'A3', 'D4'), 1.4, 1.2)):
        p = pad_voice(midi_hz([nm(c) for c in chord]), d, rng, att=0.08, rel=0.6, cutoff=1200)[0]
        place(x, st, p * 3)
    x = room(x, 0.35, 2.0, 1.6, seed=7)
    return x * np.clip((3.2 - t) / 0.5, 0, 1)


def brass(f, gate, vel=1.0):
    n = ns(gate + 0.25)
    t = tvec(n)
    y = np.zeros(n)
    for c in (-6, 0, 6):
        ph, dt = phase(f * 2 ** (c / 1200), n)
        y += saw(ph + rng.uniform(), dt)
    fc = 600 + 2200 * np.clip(t / 0.05, 0, 1) * (0.6 + 0.4 * np.exp(-t / 0.2))
    y = tv_filter(y, fc, 'low', 0.9, hop=64)
    return y * env_adsr(n, gate, 0.02, 0.2, 0.75, 0.15) * vel * 0.3


def victory():
    x = np.zeros(ns(5.2))
    t = tvec(len(x))
    b = 0.15  # 16分 (100 BPM)
    mel_ = [('A4', 0, 1), ('A4', 1, 1), ('A4', 2, 1), ('D5', 3, 5), ('F#5', 8, 2), ('E5', 10, 2),
            ('F#5', 12, 2), ('A5', 14, 6), ('G5', 20, 2), ('A5', 22, 2), ('B5', 24, 2), ('D6', 26, 10)]
    for m, st, d in mel_:
        place(x, st * b, brass(midi_hz(nm(m)), d * b * 0.9, 1.0))
        place(x, st * b, fm_bell(midi_hz(nm(m) + 12), 0.25, 0.8, 3.0, 1.0, 0.3, 0.08))
    chords = [(('D4', 'F#4', 'A4'), 3, 5), (('G3', 'B3', 'D4'), 8, 6), (('A3', 'C#4', 'E4'), 14, 6),
              (('G3', 'B3', 'D4'), 20, 6), (('D4', 'F#4', 'A4', 'D5'), 26, 12)]
    for ch, st, d in chords:
        for m in ch:
            place(x, st * b, brass(midi_hz(nm(m)), d * b * 0.95, 0.45))
        place(x, st * b, bass_soft(midi_hz(nm(ch[0]) - 12), d * b * 0.9, 0.8, cutoff=500))
    for st in (3, 8, 14, 20, 26):
        place(x, st * b, kick(0.8, rng, 110, 50, 0.25))
        place(x, st * b, tom(98, 0.6, rng), 0.3)
    place(x, 26 * b, cymbal(0.7, rng, 2.5))
    # 朝日のきらめき
    pool = penta(6, 7)
    for k in range(18):
        place(x, 26 * b + k * 0.07 + rng.uniform(0, 0.03),
              fm_bell(midi_hz(rng.choice(pool)), rng.uniform(0.15, 0.3), 0.6, 2.0, 0.8, 0.2, 0.06))
    x = room(x, 0.3, 2.0, 1.5, seed=11)
    return x * np.clip((5.2 - t) / 0.8, 0, 1)


# ------------------------------------------------------------------ 出力
# name: (関数, ピーク目標 dBFS, 長さ下限, 上限)
SFX = {
    'shoot': (shoot, -9.0, 0.10, 0.15),
    'hit': (hit, -9.0, 0.06, 0.10),
    'enemy_die': (enemy_die, -7.0, 0.15, 0.25),
    'gem': (gem, -9.0, 0.10, 0.18),
    'moon_hit': (moon_hit, -8.0, 0.08, 0.12),
    'levelup': (levelup, -3.0, 0.9, 1.3),
    'select': (select, -5.0, 0.15, 0.25),
    'hover': (hover, -9.0, 0.04, 0.07),
    'hurt': (hurt, -3.0, 0.25, 0.35),
    'dash': (dash, -6.0, 0.25, 0.35),
    'shockwave': (shockwave, -3.0, 0.5, 0.7),
    'lightning': (lightning, -4.0, 0.25, 0.4),
    'explosion': (explosion, -4.0, 0.6, 0.9),
    'comet': (comet, -5.0, 0.4, 0.6),
    'heal': (heal, -4.0, 0.5, 0.7),
    'pickup_special': (pickup_special, -5.0, 0.5, 0.8),
    'spawn_elite': (spawn_elite, -6.0, 0.6, 0.9),
    'boss_warn': (boss_warn, -4.0, 1.5, 2.0),
    'boss_die': (boss_die, -3.0, 2.0, 2.5),
    'enemy_shoot': (enemy_shoot, -6.0, 0.15, 0.25),
    'gameover': (gameover, -3.0, 2.5, 3.5),
    'victory': (victory, -3.0, 4.0, 6.0),
}


def finish(x, peak_db, lo, hi):
    x = np.nan_to_num(np.asarray(x, float))
    x = x - np.mean(x)
    a = np.abs(x)
    pk = a.max()
    on = np.nonzero(a > pk * undb(-50))[0]
    s, e = on[0], on[-1] + 1
    s = max(0, s - ns(0.001))
    x = x[s:e]
    if len(x) > ns(hi):
        x = x[:ns(hi)]
    if len(x) < ns(lo):
        x = np.concatenate([x, np.zeros(ns(lo) - len(x))])
    x = fade(x, 0.0015, min(0.012, len(x) / SR * 0.15))
    x = x - np.mean(x) * np.hanning(len(x)) / np.mean(np.hanning(len(x)))  # DC除去(端は0のまま)
    x = x * undb(peak_db) / np.max(np.abs(x))
    return x


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        fn, pk, lo, hi = SFX[name]
        x = finish(fn(), pk, lo, hi)
        q = np.round(x * 32767).astype(np.int16)
        wavfile.write(os.path.join(OUT, name + '.wav'), SR, q)
        print(f'{name:15s} {len(x) / SR:5.3f}s peak {db(np.max(np.abs(x))):6.2f} dBFS  '
              f'M-max {momentary_max(x):6.1f} LUFS')


if __name__ == '__main__':
    main(sys.argv[1:] or list(SFX))
