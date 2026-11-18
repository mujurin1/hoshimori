"""ほしもり 音声合成 共通ライブラリ (numpy/scipy のみ)。

オシレータ / エンベロープ / フィルタ / リバーブ / 楽器 / ドラム / ラウドネス処理。
BGM 用の処理はすべて「循環(wrap-around)」で行い、ループの継ぎ目が出ないようにする。
"""
import numpy as np
from scipy import signal
from scipy.ndimage import minimum_filter1d, uniform_filter1d
import pyloudnorm

SR = 44100
TAU = 2 * np.pi


# ---------------------------------------------------------------- 基本
def ns(sec):
    return int(round(sec * SR))


def tvec(n):
    return np.arange(n) / SR


def midi_hz(m):
    return 440.0 * 2 ** ((np.asarray(m, float) - 69) / 12)


_PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def nm(name):
    """'F#5' -> MIDI 番号"""
    pc = _PC[name[0]]
    i = 1
    while i < len(name) and name[i] in '#b':
        pc += 1 if name[i] == '#' else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + pc


def db(x):
    return 20 * np.log10(np.maximum(x, 1e-12))


def undb(d):
    return 10 ** (d / 20)


# ---------------------------------------------------------------- オシレータ
def phase(freq, n):
    """周波数(スカラ or 配列) -> 累積位相 [cycles], dt"""
    f = np.broadcast_to(np.asarray(freq, float), (n,)).astype(float)
    ph = np.empty(n)
    ph[0] = 0.0
    np.cumsum(f[:-1], out=ph[1:])
    ph /= SR
    return ph, f / SR


def _blep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    y[m] = 2 * x - x * x - 1
    m = t > 1 - dt
    x = (t[m] - 1) / dt[m]
    y[m] = x * x + 2 * x + 1
    return y


def sine(ph):
    return np.sin(TAU * ph)


def tri(ph):
    return 4 * np.abs(np.mod(ph + 0.25, 1.0) - 0.5) - 1


def saw(ph, dt):
    t = np.mod(ph, 1.0)
    return 2 * t - 1 - _blep(t, dt)


def pulse(ph, dt, duty=0.5):
    return 0.5 * (saw(ph, dt) - saw(ph + duty, dt))


# ---------------------------------------------------------------- エンベロープ
def env_ar(n, att=0.002, tau=0.1):
    """線形アタック + 指数減衰"""
    t = tvec(n)
    a = np.clip(t / max(att, 1e-5), 0, 1)
    return a * np.exp(-np.maximum(t - att, 0) / tau)


def env_adsr(n, gate, att=0.01, dec=0.1, sus=0.7, rel=0.1):
    """gate 秒で鍵盤を離す ADSR。n は release 込みの長さ"""
    t = tvec(n)
    e = np.where(t < att, t / max(att, 1e-5),
                 sus + (1 - sus) * np.exp(-(t - att) / max(dec, 1e-5)))
    g = np.interp(gate, t, e) if n > 0 else 0
    rel_part = g * np.exp(-(t - gate) / max(rel, 1e-5) * 3)
    return np.where(t < gate, e, rel_part)


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = ns(fin), ns(fout)
    if a > 0:
        x[..., :a] *= np.linspace(0, 1, a) ** 2
    if b > 0:
        x[..., -b:] *= np.linspace(1, 0, b) ** 2
    return x


# ---------------------------------------------------------------- フィルタ
def _sos(kind, fc, order=2):
    if kind == 'band':
        return signal.butter(order, [fc[0], fc[1]], 'bandpass', fs=SR, output='sos')
    fc = min(fc, SR * 0.49)
    return signal.butter(order, fc, kind, fs=SR, output='sos')


def lp(x, fc, order=2):
    return signal.sosfilt(_sos('low', fc, order), x, axis=-1)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos('high', fc, order), x, axis=-1)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos('band', (lo, hi), order), x, axis=-1)


def circ_filter(x, kind, fc, order=2, pad_sec=3.0):
    """ループ素材用: 周期境界でフィルタ(前後を wrap パディング)"""
    sos = _sos(kind, fc, order)
    p = min(ns(pad_sec), x.shape[-1])
    xp = np.concatenate([x[..., -p:], x, x[..., :p]], axis=-1)
    y = signal.sosfilt(sos, xp, axis=-1)
    return y[..., p:p + x.shape[-1]]


def tv_filter(x, fc, kind='low', q=0.707, hop=16):
    """時変 biquad (RBJ)。fc は配列可。効果音用(短い素材向け)"""
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, float), (n,))
    q = np.broadcast_to(np.asarray(q, float), (n,))
    y = np.zeros(n)
    z1 = z2 = 0.0
    for s in range(0, n, hop):
        w0 = TAU * min(fc[s], SR * 0.45) / SR
        c, sn = np.cos(w0), np.sin(w0)
        al = sn / (2 * q[s])
        if kind == 'low':
            b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
        elif kind == 'high':
            b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
        else:  # band (0dB peak)
            b0, b1, b2 = al, 0.0, -al
        a0, a1, a2 = 1 + al, -2 * c, 1 - al
        b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
        e = min(s + hop, n)
        for i in range(s, e):
            xi = x[i]
            yi = b0 * xi + z1
            z1 = b1 * xi - a1 * yi + z2
            z2 = b2 * xi - a2 * yi
            y[i] = yi
    return y


# ---------------------------------------------------------------- ノイズ
def white(n, rng):
    return rng.standard_normal(n)


def pink(n, rng):
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1]
    y = np.fft.irfft(X / np.sqrt(f), n)
    return y / (np.std(y) + 1e-12)


# ---------------------------------------------------------------- リバーブ
def make_ir(sec=2.5, rt60=2.0, predelay=0.02, bright=7000, dark=2200, seed=7, stereo=True):
    rng = np.random.default_rng(seed)
    n = ns(sec)
    t = tvec(n)
    chans = []
    for _ in range(2 if stereo else 1):
        w = rng.standard_normal(n)
        b, d = lp(w, bright), lp(w, dark)
        mix = np.exp(-t / (rt60 * 0.2))
        ir = (b * mix + d * (1 - mix)) * 10 ** (-3 * t / rt60)
        ir *= np.clip(t / 0.012, 0, 1)  # 拡散のビルドアップ
        ir = np.concatenate([np.zeros(ns(predelay)), ir])
        chans.append(ir / np.sqrt(np.sum(ir ** 2)))
    return np.array(chans) if stereo else chans[0]


def circ_convolve(x, ir):
    """x: (2,N) ループ, ir: (2,M) -> 循環畳み込み(尾が先頭に回り込む)"""
    N = x.shape[-1]
    out = np.zeros_like(x)
    for ch in range(x.shape[0]):
        h = ir[ch % ir.shape[0]]
        if len(h) > N:
            h = h[:N]
        out[ch] = np.fft.irfft(np.fft.rfft(x[ch]) * np.fft.rfft(h, N), N)
    return out


def circ_delay(x, delay_sec, fb=0.35, taps=6, pingpong=True, lp_hz=3500):
    """循環フィードバックディレイ(ロール + 減衰)"""
    d = ns(delay_sec)
    out = np.zeros_like(x)
    for k in range(1, taps + 1):
        g = fb ** (k - 1)
        sh = np.roll(x, d * k, axis=-1)
        if pingpong and k % 2 == 1:
            sh = sh[::-1]
        out += g * sh
    return circ_filter(out, 'low', lp_hz)


# ---------------------------------------------------------------- パン / ラウドネス
def pan2(x, pan=0.0):
    th = (pan + 1) * np.pi / 4
    return np.array([x * np.cos(th), x * np.sin(th)])


_meter = pyloudnorm.Meter(SR)


def lufs(x):
    """x: (2,N) or (N,)"""
    d = x.T if x.ndim == 2 else x
    return _meter.integrated_loudness(d)


def kweight(x):
    y = x
    for f in _meter._filters.values():
        y = f.apply_filter(y)
    return y


def momentary_max(x):
    """400ms 窓の最大モーメンタリラウドネス(短い効果音の聴感比較用)"""
    x = np.concatenate([np.zeros(ns(0.2)), x, np.zeros(ns(0.4))])
    k = kweight(x)
    ms = uniform_filter1d(k ** 2, ns(0.4))
    return -0.691 + 10 * np.log10(np.max(ms) + 1e-20)


def circ_limiter(x, ceiling_db=-1.5, hold=0.010):
    """ループ用の先読みリミッタ(循環)。出力サンプルピークは必ず ceiling 以下"""
    c = undb(ceiling_db)
    peak = np.max(np.abs(x), axis=0)
    need = np.minimum(1.0, c / np.maximum(peak, 1e-9))
    w = 2 * ns(hold) + 1
    g = minimum_filter1d(need, w, mode='wrap')
    g = uniform_filter1d(g, w, mode='wrap')
    return x * g


# ---------------------------------------------------------------- 楽器
def music_box(f, vel=1.0, dur=2.5):
    n = ns(dur)
    t = tvec(n)
    k = (max(f, 200) / 500) ** 0.35
    parts = [(1.0, 1.0, 1.6), (2.0, 0.22, 0.8), (3.98, 0.12, 0.35), (5.43, 0.08, 0.2), (8.1, 0.03, 0.08)]
    y = np.zeros(n)
    for r, a, d in parts:
        fr = f * r
        if fr > 11000:
            continue
        y += a * np.sin(TAU * fr * t + r) * np.exp(-t / (d / k))
    y *= np.clip(t / 0.0015, 0, 1)
    return fade(y * vel * 0.5, 0, 0.05)


def fm_bell(f, vel=1.0, dur=1.6, ratio=3.5, index=2.0, decay=0.9, idecay=0.25):
    n = ns(dur)
    t = tvec(n)
    I = index * np.exp(-t / idecay)
    y = np.sin(TAU * f * t + I * np.sin(TAU * f * ratio * t))
    y *= np.clip(t / 0.002, 0, 1) * np.exp(-t / decay)
    return fade(y * vel * 0.5, 0, 0.05)


def pad_voice(freqs, dur, rng, att=0.5, rel=0.9, cutoff=1600, detune=0.08, nsaw=3):
    """和音パッド(ステレオ)。dur は鍵盤を押している長さ"""
    n = ns(dur + rel * 1.5)
    out = np.zeros((2, n))
    for ch in range(2):
        y = np.zeros(n)
        for f in freqs:
            for k in range(nsaw):
                cents = (k - (nsaw - 1) / 2) * detune * 100 / max(nsaw - 1, 1) * 2 + rng.uniform(-3, 3)
                ff = f * 2 ** (cents / 1200)
                ph, dt = phase(ff, n)
                y += saw(ph + rng.uniform(), dt)
        y = lp(y, cutoff, 2)
        out[ch] = y
    e = env_adsr(n, dur, att, 0.5, 0.9, rel)
    return out * e * (0.12 / np.sqrt(len(freqs) * nsaw))


def chip_lead(f, gate, vel=1.0, duty=0.25, cutoff=3200, vib=0.12, tri_mix=0.5, rel=0.08):
    n = ns(gate + rel * 2)
    t = tvec(n)
    vib_env = np.clip((t - 0.18) / 0.25, 0, 1)
    fr = f * 2 ** (vib * vib_env * np.sin(TAU * 5.5 * t) / 12)
    ph, dt = phase(fr, n)
    y = (1 - tri_mix) * pulse(ph, dt, duty) + tri_mix * tri(ph)
    y = lp(y, cutoff, 2)
    return y * env_adsr(n, gate, 0.006, 0.12, 0.75, rel) * vel * 0.5


def saw_lead(f, gate, vel=1.0, cutoff=2600, vib=0.15, rel=0.08, rng=None):
    n = ns(gate + rel * 2)
    t = tvec(n)
    vib_env = np.clip((t - 0.15) / 0.2, 0, 1)
    fr = f * 2 ** (vib * vib_env * np.sin(TAU * 6.0 * t) / 12)
    y = np.zeros(n)
    for c in (-7, 0, 7):
        ph, dt = phase(fr * 2 ** (c / 1200), n)
        y += saw(ph + (rng.uniform() if rng is not None else 0), dt)
    ph, dt = phase(fr * 0.5, n)
    y += 0.6 * pulse(ph, dt, 0.5)
    y = lp(y, cutoff, 2)
    return y * env_adsr(n, gate, 0.005, 0.15, 0.8, rel) * vel * 0.22


def pluck(f, vel=1.0, dur=0.35, bright=4500, dark=900, ftau=0.06, tau=0.18, duty=0.5):
    n = ns(dur)
    t = tvec(n)
    ph, dt = phase(f, n)
    y = 0.6 * saw(ph, dt) + 0.4 * pulse(ph, dt, duty)
    m = np.exp(-t / ftau)
    y = lp(y, bright) * m + lp(y, dark) * (1 - m)
    y *= env_ar(n, 0.002, tau)
    return fade(y * vel * 0.4, 0, 0.02)


def bass_soft(f, gate, vel=1.0, rel=0.04, cutoff=700):
    n = ns(gate + rel * 2)
    ph, dt = phase(f, n)
    y = 0.6 * tri(ph) + 0.5 * sine(ph) + 0.25 * saw(ph, dt)
    y = lp(y, cutoff, 2)
    return y * env_adsr(n, gate, 0.004, 0.15, 0.8, rel) * vel * 0.6


def bass_grit(f, gate, vel=1.0, rel=0.03, cutoff=1100):
    n = ns(gate + rel * 2)
    t = tvec(n)
    ph, dt = phase(f, n)
    y = saw(ph, dt) + 0.5 * pulse(ph * 0.5, dt * 0.5, 0.5) + 0.6 * sine(ph)
    m = np.exp(-t / 0.07)
    y = lp(y, cutoff) * m + lp(y, cutoff * 0.35) * (1 - m)
    return y * env_adsr(n, gate, 0.003, 0.1, 0.7, rel) * vel * 0.5


# ---------------------------------------------------------------- ドラム
def kick(vel=1.0, rng=None, f0=150, f1=48, tau=0.32):
    n = ns(0.45)
    t = tvec(n)
    f = f1 + (f0 - f1) * np.exp(-t / 0.028)
    ph, _ = phase(f, n)
    y = np.sin(TAU * ph) * env_ar(n, 0.001, tau) * np.exp(-t / 0.5)
    cl = lp(rng.standard_normal(n), 2500) * env_ar(n, 0.0005, 0.003) * 0.3
    return fade((y + cl) * vel * 0.9, 0, 0.03)


def snare(vel=1.0, rng=None, tone=190, tau=0.11, lp_hz=5500):
    n = ns(0.3)
    t = tvec(n)
    nz = bp(rng.standard_normal(n), 900, lp_hz) * env_ar(n, 0.001, tau)
    ph, _ = phase(tone * (1 + 0.3 * np.exp(-t / 0.01)), n)
    tn = np.sin(TAU * ph) * env_ar(n, 0.001, 0.05)
    return fade((0.55 * nz + 0.6 * tn) * vel * 0.7, 0, 0.02)


def clap(vel=1.0, rng=None):
    n = ns(0.3)
    y = np.zeros(n)
    for k, off in enumerate((0, 0.009, 0.019)):
        s = ns(off)
        m = n - s
        y[s:] += rng.standard_normal(m) * env_ar(m, 0.0005, 0.006 if k < 2 else 0.09)
    y = bp(y, 900, 4200)
    return fade(y * vel * 0.6, 0, 0.02)


def hat(vel=1.0, rng=None, open_=False):
    n = ns(0.35 if open_ else 0.08)
    y = rng.standard_normal(n)
    y = lp(hp(y, 7000, 2), 13000)
    y *= env_ar(n, 0.0008, 0.12 if open_ else 0.018)
    return fade(y * vel * 0.35, 0, 0.01)


def shaker(vel=1.0, rng=None):
    n = ns(0.09)
    y = bp(rng.standard_normal(n), 5000, 11000)
    t = tvec(n)
    y *= np.clip(t / 0.012, 0, 1) * np.exp(-t / 0.025)
    return fade(y * vel * 0.3, 0, 0.01)


def cymbal(vel=1.0, rng=None, dur=2.0):
    n = ns(dur)
    y = lp(hp(rng.standard_normal(n), 3500, 2), 11000)
    # 金属感: 高域リング変調
    t = tvec(n)
    y = y * (0.7 + 0.3 * np.sin(TAU * 5400 * t))
    y *= env_ar(n, 0.002, dur * 0.3)
    return fade(y * vel * 0.25, 0, 0.1)


def tom(f=110, vel=1.0, rng=None):
    n = ns(0.4)
    t = tvec(n)
    ph, _ = phase(f * (1 + 0.5 * np.exp(-t / 0.04)), n)
    y = np.sin(TAU * ph) * env_ar(n, 0.001, 0.15)
    y += 0.1 * lp(rng.standard_normal(n), 2000) * env_ar(n, 0.001, 0.02)
    return fade(y * vel * 0.7, 0, 0.02)


def riser(dur, rng, f0=800, f1=7000):
    """ノイズのライザー(展開の前振り)"""
    n = ns(dur)
    t = tvec(n)
    fc = f0 * (f1 / f0) ** (t / dur)
    y = np.zeros(n)
    w = rng.standard_normal(n)
    # 時変BPの代わりに複数帯域をクロスフェード(高速)
    bands = np.geomspace(f0, f1, 7)
    for i, b in enumerate(bands):
        comp = bp(w, b / 1.4, min(b * 1.4, SR * 0.45))
        wgt = np.exp(-0.5 * (np.log(fc / b) / 0.35) ** 2)
        y += comp * wgt
    y *= (t / dur) ** 2
    return fade(y * 0.25, 0.01, 0.01)
