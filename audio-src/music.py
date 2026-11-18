"""ほしもり BGM 生成: title.ogg / game.ogg / boss.ogg

キー: title = D major, game = D major, boss = D minor (効果音も D major ペンタトニック基準)
すべて小節ぴったりの長さで、リバーブ/ディレイ/音の尾は先頭へ循環ミックスする。
"""
import os
import subprocess
import sys
import numpy as np
from scipy.io import wavfile

from synth import *  # noqa

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'game', 'audio', 'music')
BUILD = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build')
TARGET_LUFS = -17.0
CEIL_DB = -2.0

QUAL = {'': [0, 4, 7], 'm': [0, 3, 7], 'sus4': [0, 5, 7], '7': [0, 4, 7, 10],
        'm7': [0, 3, 7, 10], 'maj7': [0, 4, 7, 11], 'add9': [0, 4, 7, 14]}
D_MAJOR = [2, 4, 6, 7, 9, 11, 1]
D_MINOR_H = [2, 4, 5, 7, 9, 10, 1]  # 和声的短音階


def chord_info(name):
    """'F#m' -> (root pc, 構成音 intervals)"""
    i = 1
    pc = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}[name[0]]
    if len(name) > 1 and name[1] in '#b':
        pc += 1 if name[1] == '#' else -1
        i = 2
    return pc % 12, QUAL[name[i:]]


def voicing(name, low):
    pc, iv = chord_info(name)
    notes = []
    for x in iv:
        p = (pc + x) % 12
        m = low + ((p - low) % 12)
        notes.append(m)
    return sorted(notes)


def root_midi(name, low):
    pc, _ = chord_info(name)
    return low + ((pc - low) % 12)


def mel(s, bar0=0):
    """'A4:2 D5:2 | r:4 -:2' -> [(step, dur, midi)] (step は16分音符単位)"""
    out = []
    pos = bar0 * 16
    for tok in s.replace('|', ' ').split():
        n, d = tok.split(':')
        d = int(d)
        if n == 'r':
            pass
        elif n == '-':
            st, dd, m = out[-1]
            out[-1] = (st, dd + d, m)
        else:
            out.append((pos, d, nm(n)))
        pos += d
    return out, pos - bar0 * 16


def check_len(s, bars):
    _, L = mel(s)
    assert L == bars * 16, f'melody length {L} != {bars * 16}: {s[:40]}'


def harmonize(m, scale, steps=-2):
    """スケール上で steps 度ずらす(-2 = 3度下)"""
    pcs = sorted(set(scale))
    # 一番近いスケール音のインデックス
    oct_, pc = divmod(m, 12)
    allnotes = [o * 12 + p for o in range(oct_ - 2, oct_ + 3) for p in pcs]
    allnotes.sort()
    idx = min(range(len(allnotes)), key=lambda k: abs(allnotes[k] - m))
    return allnotes[idx + steps]


class Song:
    def __init__(self, bpm, bars, seed=0, tail=8.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.step = self.beat / 4
        self.bars = bars
        self.N = ns(bars * 4 * self.beat)
        self.T = self.N + ns(tail)
        self.stems = {}
        self.rng = np.random.default_rng(seed)
        self.kicks = []

    def at(self, bar, step=0.0):
        return (bar * 16 + step) * self.step

    def add(self, stem, t, sig, pan=0.0, gain=1.0):
        if sig.ndim == 1:
            sig = pan2(sig, pan)
        buf = self.stems.setdefault(stem, np.zeros((2, self.T)))
        i = ns(t) % self.N
        m = min(sig.shape[1], self.T - i)
        buf[:, i:i + m] += sig[:, :m] * gain

    def loop(self, stem):
        buf = self.stems[stem]
        out = buf[:, :self.N].copy()
        out[:, :self.T - self.N] += buf[:, self.N:]
        return out

    def hum(self, ms=4):
        return self.rng.uniform(-ms, ms) / 1000

    # ---- 便利関数
    def kick(self, t, vel=1.0, stem='kick', **kw):
        self.add(stem, t, kick(vel, self.rng, **kw))
        self.kicks.append(t)

    def duck_env(self, depth=0.35, tau=0.11):
        imp = np.zeros(self.N)
        for t in self.kicks:
            imp[ns(t) % self.N] += 1
        n = ns(tau * 6)
        tt = tvec(n)
        k = np.where(tt < 0.006, tt / 0.006, np.exp(-(tt - 0.006) / tau))
        e = np.fft.irfft(np.fft.rfft(imp) * np.fft.rfft(k, self.N), self.N)
        return 1 - depth * np.clip(e, 0, 1)

    def melody(self, stem, notes, inst, pan=0.0, gain=1.0, gate=0.92, transpose=0, **kw):
        for st, d, m in notes:
            f = midi_hz(m + transpose)
            vel = (1.0 if st % 4 == 0 else 0.88) * self.rng.uniform(0.92, 1.0)
            sig = inst(f, d * self.step * gate, vel, **kw)
            self.add(stem, st * self.step + self.hum(3), sig, pan, gain)


def mixdown(song, spec, ir, delay_sec=None, delay_fb=0.35, duck=None):
    N = song.N
    dry = np.zeros((2, N))
    rev = np.zeros((2, N))
    dly = np.zeros((2, N))
    print('  stems (RMS dBFS before master):')
    for name, s in spec.items():
        if name not in song.stems:
            continue
        x = song.loop(name) * s.get('gain', 1.0)
        if s.get('duck') and duck is not None:
            x = x * duck
        if s.get('hp'):
            x = circ_filter(x, 'high', s['hp'])
        print(f'    {name:10s} {db(np.sqrt(np.mean(x ** 2))):6.1f}')
        dry += x
        rev += x * s.get('rev', 0.0)
        dly += x * s.get('dly', 0.0)
    out = dry
    if delay_sec:
        d = circ_delay(dly, delay_sec, delay_fb)
        out = out + d
        rev = rev + d * 0.5
    out = out + circ_convolve(rev, ir)
    out = circ_filter(out, 'high', 28)
    return out


def master(x):
    for _ in range(4):
        g = TARGET_LUFS - lufs(x)
        x = x * undb(g)
        x = circ_limiter(x, CEIL_DB)
        if abs(lufs(x) - TARGET_LUFS) < 0.1:
            break
    x -= np.mean(x, axis=1, keepdims=True)
    return x


def export(x, name):
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(BUILD, exist_ok=True)
    wav = os.path.join(BUILD, name + '.wav')
    wavfile.write(wav, SR, x.T.astype(np.float32))
    ogg = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis',
                    '-q:a', '5', ogg], check=True)
    print(f'  -> {ogg}  {x.shape[1] / SR:.3f}s  {lufs(x):.2f} LUFS  peak {db(np.max(np.abs(x))):.2f} dBFS')


# ====================================================================== TITLE
def make_title():
    print('title: D major, 76 BPM, 16 bars')
    s = Song(76, 16, seed=11, tail=10.0)
    rng = s.rng
    chords = ['D', 'Bm', 'G', 'A', 'D', 'F#m', 'G', 'A',
              'G', 'A', 'F#m', 'Bm', 'Em', 'F#m', 'G', 'A']
    mA = ("F#5:8 E5:4 D5:4 | B4:8 D5:4 F#5:4 | G5:6 F#5:2 E5:4 D5:4 | E5:12 r:4 | "
          "F#5:8 A5:4 B5:4 | A5:6 F#5:2 C#5:8 | B4:4 D5:4 G5:4 F#5:4 | E5:16")
    mB = ("D6:8 B5:4 A5:4 | A5:6 B5:2 C#6:4 E5:4 | F#5:8 E5:4 C#5:4 | D5:6 C#5:2 B4:8 | "
          "G5:8 F#5:4 E5:4 | A5:8 F#5:4 C#5:4 | B5:6 A5:2 G5:4 F#5:4 | E5:8 r:4 C#5:2 E5:2")
    check_len(mA, 8)
    check_len(mB, 8)
    notes, _ = mel(mA + ' ' + mB)
    for st, d, m in notes:
        t = st * s.step + s.hum(6)
        v = rng.uniform(0.85, 1.0)
        s.add('lead', t, music_box(midi_hz(m), v, 3.0), 0.05)
        s.add('leadhi', t, fm_bell(midi_hz(m + 12), v, 1.2, ratio=3.0, index=1.2, decay=0.4), 0.2)

    for b, c in enumerate(chords):
        t = s.at(b)
        # パッド
        s.add('pad', t, pad_voice(midi_hz(voicing(c, 54)), 4 * s.beat * 0.98, rng, att=1.0, rel=1.4,
                                  cutoff=1100 if b < 8 else 1500))
        # ベース(全音符 + 3拍目に5度)
        r = root_midi(c, 38)
        s.add('bass', t, bass_soft(midi_hz(r), s.beat * 2.8, 0.9, rel=0.4, cutoff=400))
        s.add('bass', s.at(b, 12), bass_soft(midi_hz(r + 7 if r + 7 < 50 else r - 5), s.beat * 0.9, 0.6,
                                             rel=0.3, cutoff=400))
        # オルゴール分散和音 (8分)
        pc, iv = chord_info(c)
        base = root_midi(c, 50)
        tones = [base, base + 7, base + 12, base + iv[1] + 12, base + 19]
        pat = [0, 1, 2, 3, 4, 3, 2, 1]
        for k, p in enumerate(pat):
            s.add('arp', s.at(b, k * 2) + s.hum(5),
                  music_box(midi_hz(tones[p]), rng.uniform(0.5, 0.75) * (1.0 if k % 2 == 0 else 0.8), 2.0),
                  pan=-0.35 + 0.1 * (k % 3))
        # B セクション: 鼓動のような柔らかいキックとシェイカー
        if b >= 8:
            s.kick(t, 0.45, f0=90, f1=45, tau=0.2)
            s.kick(s.at(b, 8), 0.35, f0=90, f1=45, tau=0.2)
            for k in range(8):
                s.add('shaker', s.at(b, k * 2 + 1) + s.hum(4), shaker(rng.uniform(0.4, 0.7), rng), 0.4)
            # 高めのストリングス的パッド(対旋律の代わりに5度上の持続)
            s.add('pad2', t, pad_voice(midi_hz(voicing(c, 66)), 4 * s.beat * 0.98, rng, att=1.5, rel=1.5,
                                       cutoff=2200, nsaw=2), 0)

    # 星のまたたき: ランダムな高音ベル (D ペンタ)
    penta = [nm(x) for x in ('D6', 'E6', 'F#6', 'A6', 'B6', 'D7')]
    for k in range(40):
        t = rng.uniform(0, s.N / SR)
        s.add('twinkle', t, fm_bell(midi_hz(rng.choice(penta)), rng.uniform(0.15, 0.4), 1.5, 2.0, 0.8, 0.6),
              rng.uniform(-0.8, 0.8))
    # 夜風 (周期的ノイズ)
    w = np.array([pink(s.N, rng), pink(s.N, rng)])
    w = circ_filter(circ_filter(w, 'low', 900), 'high', 150)
    lfo = 0.6 + 0.4 * np.sin(TAU * np.arange(s.N) / s.N * 4)  # ループ内で整数周期
    s.stems['wind'] = np.concatenate([w * lfo, np.zeros((2, s.T - s.N))], axis=1)

    ir = make_ir(4.0, 3.2, 0.03, 6000, 1800, seed=3)
    spec = {
        'lead': dict(gain=1.0, rev=0.35, dly=0.18),
        'leadhi': dict(gain=0.12, rev=0.5, dly=0.3),
        'arp': dict(gain=0.35, rev=0.4),
        'pad': dict(gain=1.4, rev=0.4),
        'pad2': dict(gain=0.5, rev=0.5),
        'bass': dict(gain=1.4, rev=0.1),
        'kick': dict(gain=0.6, rev=0.1),
        'shaker': dict(gain=1.2, rev=0.2),
        'twinkle': dict(gain=0.35, rev=0.7),
        'wind': dict(gain=0.025, rev=0.0),
    }
    x = mixdown(s, spec, ir, delay_sec=s.beat * 0.75, delay_fb=0.3)
    export(master(x), 'title')


# ====================================================================== GAME
def make_game():
    print('game: D major, 128 BPM, 56 bars (A16 B16 C8 A16)')
    s = Song(128, 56, seed=22)
    rng = s.rng
    A = ['D', 'A', 'Bm', 'G'] * 4
    B = ['G', 'A', 'F#m', 'Bm'] * 3 + ['Em', 'G', 'A', 'A']
    C = ['Bm', 'G', 'D', 'A'] * 2
    chords = A + B + C + A
    sec = ['A'] * 16 + ['B'] * 16 + ['C'] * 8 + ['A2'] * 16

    P1 = ("A4:2 D5:2 E5:2 F#5:4 E5:2 D5:2 E5:2 | E5:4 C#5:2 A4:6 r:4 | "
          "B4:2 D5:2 F#5:2 A5:4 F#5:2 E5:2 D5:2 | E5:6 D5:2 B4:4 r:4")
    P2 = ("A4:2 D5:2 E5:2 F#5:4 A5:2 B5:2 A5:2 | E5:4 F#5:2 E5:6 C#5:4 | "
          "D5:2 F#5:2 B5:4 A5:2 F#5:2 E5:2 D5:2 | D5:10 r:6")
    P3 = P2.replace('D5:10 r:6', 'D5:6 E5:2 F#5:4 A5:4')
    P4 = P2.replace('D5:10 r:6', 'D5:8 r:8')
    MB1 = "B5:6 A5:2 G5:4 F#5:4 | E5:6 F#5:2 A5:8 | F#5:6 E5:2 C#5:4 A4:4 | B4:12 D5:2 E5:2"
    MB2 = "B5:6 A5:2 G5:4 F#5:2 G5:2 | A5:6 B5:2 C#6:4 E5:4 | F#5:2 A5:2 C#6:4 B5:2 A5:2 F#5:4 | B5:12 r:4"
    MB3 = "G5:4 F#5:4 E5:4 B4:4 | D5:4 E5:4 G5:4 B5:4 | A5:8 E5:4 C#5:4 | E5:8 r:8"
    MC = "D6:16 | B5:16 | A5:16 | C#6:16 | D6:8 F#6:8 | D6:8 B5:8 | A5:16 | E5:8 C#5:8"
    for p, n in ((P1, 4), (P2, 4), (P3, 4), (MB1, 4), (MB2, 4), (MB3, 4), (MC, 8)):
        check_len(p, n)

    secA, _ = mel(' '.join([P1, P2, P1, P3]), 0)
    secB, _ = mel(' '.join([MB1, MB2, MB1, MB3]), 16)
    secC, _ = mel(MC, 32)
    secA2, _ = mel(' '.join([P1, P2, P1, P4]), 40)

    s.melody('lead', secA + secB, chip_lead, pan=0.0, gain=1.0, duty=0.25, cutoff=3000)
    s.melody('lead', secA2, chip_lead, pan=0.0, gain=1.0, duty=0.25, cutoff=3300)
    # A2 は3度下ハモ + 1オクターブ上のベル
    harm = [(st, d, harmonize(m, D_MAJOR, -2)) for st, d, m in secA2]
    s.melody('harm', harm, chip_lead, pan=-0.3, gain=0.45, duty=0.5, cutoff=2200, tri_mix=0.7)
    for st, d, m in secA2 + secB:
        s.add('bell', st * s.step, fm_bell(midi_hz(m + 12), 0.5, 0.8, 3.0, 1.0, 0.25, 0.1), 0.3)
    for st, d, m in secC:
        s.add('bell', st * s.step, fm_bell(midi_hz(m), 0.8, 3.0, 3.5, 1.5, 1.1, 0.3), 0.15, 1.6)

    for b, c in enumerate(chords):
        sc = sec[b]
        t0 = s.at(b)
        pc, iv = chord_info(c)
        # パッド
        s.add('pad', t0, pad_voice(midi_hz(voicing(c, 55)), 4 * s.beat * 0.97, rng, att=0.08 if sc != 'C' else 0.6,
                                   rel=0.5, cutoff=1300 if sc != 'C' else 1000))
        # ベース
        r = root_midi(c, 38)
        if sc in ('A', 'A2'):
            pat = [(0, 3, 0), (3, 3, 0), (6, 2, 12), (8, 3, 0), (11, 3, 0), (14, 2, 12)]
        elif sc == 'B':
            pat = [(k * 2, 2, 12 if k % 2 else 0) for k in range(8)]
        else:
            pat = [(0, 14, 0)] if b < 38 else [(k * 2, 2, 0) for k in range(8)]
        for st, d, o in pat:
            s.add('bass', s.at(b, st), bass_soft(midi_hz(r + o), d * s.step * 0.85, 0.95 if st % 4 == 0 else 0.8))
        # 裏拍のコードスタブ
        if sc != 'C':
            vo = voicing(c, 62)
            for st in (2, 6, 10, 14):
                sig = sum(pluck(midi_hz(m), 0.5, 0.3, 3000, 700, 0.04, 0.09) for m in vo)
                s.add('stab', s.at(b, st) + s.hum(2), sig, 0.25)
        # アルペジオ(B, C)
        if sc in ('B', 'C'):
            base = root_midi(c, 62)
            tones = [base, base + iv[1], base + 7, base + 12]
            pat16 = [0, 1, 2, 3, 2, 1, 2, 3] * 2
            for k in range(16 if sc == 'C' else 8):
                st = k if sc == 'C' else k * 2
                m = tones[pat16[k]] + (12 if sc == 'B' else 0)
                s.add('arp', s.at(b, st), music_box(midi_hz(m), 0.6 if st % 4 == 0 else 0.45, 1.0),
                      -0.5 + (k % 4) * 0.3)
        # ---- ドラム
        if sc in ('A', 'A2'):
            for st in (0, 8) + ((11,) if b % 2 else (6, 11) if b % 4 == 2 else ()):
                s.kick(s.at(b, st), 1.0 if st in (0, 8) else 0.75)
            for st in (4, 12):
                s.add('snare', s.at(b, st), snare(0.9, rng), 0.0)
                s.add('clap', s.at(b, st) + 0.003, clap(0.6, rng), 0.0)
            for k in range(8):
                st = k * 2
                s.add('hat', s.at(b, st) + s.hum(3), hat(0.55 if k % 2 else 0.3, rng), 0.3)
            if b % 2 == 1:
                s.add('hat', s.at(b, 14), hat(0.5, rng, open_=True), 0.3)
            if sc == 'A2':
                for k in range(16):
                    s.add('shaker', s.at(b, k), shaker(0.7 if k % 2 else 0.4, rng), -0.35)
            if b in (15, 55):  # フィル
                for st, f in ((12, 196), (13, 165), (14, 131), (15, 110)):
                    s.add('tom', s.at(b, st), tom(f, 0.8, rng), (st - 13.5) * 0.3)
        elif sc == 'B':
            for st in (0, 4, 8, 12):
                s.kick(s.at(b, st), 1.0)
            for st in (4, 12):
                s.add('clap', s.at(b, st), clap(0.9, rng), 0.0)
                s.add('snare', s.at(b, st), snare(0.5, rng), 0.0)
            for st in (2, 6, 10, 14):
                s.add('hat', s.at(b, st), hat(0.7, rng, open_=(b % 4 == 3 and st == 14)), 0.3)
            for k in range(16):
                s.add('shaker', s.at(b, k) + s.hum(2), shaker(0.65 if k % 2 else 0.35, rng), -0.35)
            if b == 31:
                for st, f in ((8, 220), (10, 196), (12, 165), (13, 147), (14, 131), (15, 110)):
                    s.add('tom', s.at(b, st), tom(f, 0.8, rng), (st - 12) * 0.2)
        else:  # C ブレイクダウン
            if b < 38:
                s.kick(t0, 0.8)
                if b % 2:
                    s.kick(s.at(b, 10), 0.5)
                for k in range(8):
                    s.add('hat', s.at(b, k * 2 + 1), hat(0.35, rng), 0.3)
            else:  # ビルドアップ
                hits = range(0, 16, 2) if b == 38 else range(16)
                for st in hits:
                    v = 0.25 + 0.6 * ((b - 38) * 16 + st) / 32
                    s.add('snare', s.at(b, st), snare(v, rng, lp_hz=4500), 0.0)
                for st in (0, 4, 8, 12):
                    s.kick(s.at(b, st), 0.8)
        if b in (0, 16, 40):
            s.add('crash', t0, cymbal(0.8, rng, 2.2), -0.2)
    s.add('fx', s.at(38), riser(4 * 4 * s.beat * 2 / 4, rng), 0.0)  # 2小節のライザー

    ir = make_ir(2.6, 1.8, 0.02, 6500, 2000, seed=5)
    duck = s.duck_env(0.3, 0.1)
    spec = {
        'lead': dict(gain=0.95, rev=0.18, dly=0.14),
        'harm': dict(gain=1.26, rev=0.2, dly=0.1),
        'bell': dict(gain=0.22, rev=0.35, dly=0.2),
        'pad': dict(gain=0.9, rev=0.25, duck=True),
        'stab': dict(gain=0.94, rev=0.15, duck=True),
        'arp': dict(gain=0.3, rev=0.3, dly=0.15, duck=True),
        'bass': dict(gain=1.6, duck=True),
        'kick': dict(gain=0.47, rev=0.03),
        'snare': dict(gain=0.88, rev=0.15),
        'clap': dict(gain=0.84, rev=0.2),
        'hat': dict(gain=0.95, rev=0.05),
        'shaker': dict(gain=0.8, rev=0.05),
        'tom': dict(gain=0.8, rev=0.2),
        'crash': dict(gain=1.0, rev=0.2),
        'fx': dict(gain=0.75, rev=0.3),
    }
    x = mixdown(s, spec, ir, delay_sec=s.beat * 0.75, delay_fb=0.3, duck=duck)
    export(master(x), 'game')


# ====================================================================== BOSS
def make_boss():
    print('boss: D minor, 160 BPM, 48 bars (A16 B16 C8 D8)')
    s = Song(160, 48, seed=33)
    rng = s.rng
    A = ['Dm', 'Bb', 'C', 'A'] * 4
    B = ['Gm', 'Dm', 'Bb', 'A', 'Gm', 'Dm', 'Eb', 'A'] * 2
    C = ['Bb', 'C', 'Dm', 'Dm', 'Bb', 'C', 'A', 'A']
    D = ['Dm', 'Dm', 'Bb', 'C'] * 2
    chords = A + B + C + D
    sec = ['A'] * 16 + ['B'] * 16 + ['C'] * 8 + ['D'] * 8

    MA = ("D5:3 D5:3 F5:2 A5:4 G5:2 F5:2 | F5:3 E5:3 D5:2 Bb4:6 r:2 | C5:2 E5:2 G5:2 C6:6 Bb5:2 A5:2 | "
          "A5:8 G5:2 F5:2 E5:2 C#5:2 | D5:3 D5:3 F5:2 A5:4 C6:2 A5:2 | D6:6 C6:2 Bb5:4 F5:4 | "
          "G5:3 A5:3 Bb5:2 C6:4 E5:4 | A5:12 r:4")
    MB = ("G5:8 Bb5:4 D6:4 | A5:8 F5:4 D5:4 | Bb5:6 A5:2 F5:4 D5:4 | E5:8 C#5:4 E5:4 | "
          "G5:8 Bb5:4 D6:4 | F6:8 E6:4 D6:4 | Eb6:6 D6:2 Bb5:4 G5:4 | A5:4 C#6:4 E6:8")
    check_len(MA, 8)
    check_len(MB, 8)
    a1, _ = mel(MA, 0)
    a2, _ = mel(MA, 8)
    b1, _ = mel(MB, 16)
    b2, _ = mel(MB, 24)
    s.melody('lead', a1 + a2 + b1 + b2, saw_lead, gain=1.0, rng=rng, cutoff=2600)
    s.melody('lead2', a2 + b2, chip_lead, pan=0.25, gain=0.5, transpose=-12, duty=0.5, cutoff=2000)

    riff = [0, 0, 12, 0, 10, 0, 7, 0, 0, 0, 12, 0, 15, 12, 10, 7]
    for b, c in enumerate(chords):
        sc = sec[b]
        t0 = s.at(b)
        pc, iv = chord_info(c)
        r = root_midi(c, 38)
        # パッド(暗めのストリングス)
        s.add('pad', t0, pad_voice(midi_hz(voicing(c, 53)), 4 * s.beat * 0.97, rng,
                                   att=0.05 if sc != 'C' else 0.5, rel=0.4, cutoff=1400))
        # ベース
        if sc == 'C':
            for st in (0, 8):
                s.add('bass', s.at(b, st), bass_grit(midi_hz(r), 7 * s.step, 0.9, cutoff=700))
        elif sc == 'D':
            for k in range(16):
                iv2 = riff[k]
                if iv[1] == 4:  # 長三和音(Bb, C)ではキー内に収める
                    iv2 = {15: 16, 10: 9}.get(iv2, iv2)
                s.add('bass', s.at(b, k), bass_grit(midi_hz(r + (12 if iv2 == 12 else 0)),
                                                    s.step * 0.75, 1.0 if k % 4 == 0 else 0.8))
                s.add('riff', s.at(b, k), pluck(midi_hz(r + 24 + iv2), 0.9 if k % 4 == 0 else 0.7, 0.25,
                                                3500, 800, 0.05, 0.12, 0.3), 0.1)
        else:
            for k in range(8):
                o = 12 if k % 2 else 0
                s.add('bass', s.at(b, k * 2), bass_grit(midi_hz(r + o), s.step * 1.6, 1.0 if k % 2 == 0 else 0.85))
        # 16分アルペジオ
        if sc in ('A', 'C'):
            base = root_midi(c, 62)
            tones = [base, base + iv[1], base + 7, base + 12, base + 12 + iv[1]]
            pat = [0, 1, 2, 3, 4, 3, 2, 1] * 2
            for k in range(16):
                s.add('arp', s.at(b, k), pluck(midi_hz(tones[pat[k]]), 0.55 if k % 4 == 0 else 0.4, 0.2,
                                               3000, 900, 0.03, 0.07, 0.25), -0.4 + 0.8 * (k % 2))
        # B: ブラス風スタブ (付点リズム)
        if sc == 'B':
            vo = voicing(c, 60)
            for st, d in ((0, 3), (3, 3), (6, 2), (10, 2), (12, 4)):
                sig = sum(saw_lead(midi_hz(m), d * s.step * 0.7, 0.7, cutoff=1800, vib=0, rng=rng) for m in vo)
                s.add('stab', s.at(b, st), sig, -0.2)
        # ---- ドラム
        if sc in ('A', 'B'):
            for st in (0, 4, 8, 12):
                s.kick(s.at(b, st), 1.0)
            if sc == 'B' and b % 2:
                s.kick(s.at(b, 14), 0.7)
            for st in (4, 12):
                s.add('snare', s.at(b, st), snare(1.0, rng, tone=210), 0.0)
            for k in range(16):
                v = 0.6 if k % 4 == 2 else 0.3 if k % 2 == 0 else 0.4
                s.add('hat', s.at(b, k) + s.hum(2), hat(v, rng, open_=(k % 4 == 2 and sc == 'B')), 0.3)
            if b % 8 == 7:
                for st, f in ((12, 180), (13, 150), (14, 120), (15, 95)):
                    s.add('tom', s.at(b, st), tom(f, 0.9, rng), (st - 13.5) * 0.3)
        elif sc == 'C':
            if b < 38:  # ハーフタイム
                s.kick(t0, 0.9)
                s.add('snare', s.at(b, 8), snare(0.9, rng, tone=200), 0.0)
                if b % 2:
                    s.kick(s.at(b, 14), 0.6)
                for k in range(4):
                    s.add('hat', s.at(b, k * 4 + 2), hat(0.5, rng), 0.3)
            else:  # ビルドアップ (b=38,39)
                for st in range(0, 16, 1 if b == 39 else 2):
                    v = 0.3 + 0.6 * ((b - 38) * 16 + st) / 32
                    s.add('snare', s.at(b, st), snare(v, rng, tone=200), 0.0)
                for st in (0, 4, 8, 12):
                    s.kick(s.at(b, st), 0.9)
        else:  # D: ギャロップ
            for st in (0, 3, 6, 8, 11, 14):
                s.kick(s.at(b, st), 1.0 if st in (0, 8) else 0.8)
            for st in (4, 12):
                s.add('snare', s.at(b, st), snare(1.0, rng, tone=210), 0.0)
            for k in range(8):
                s.add('hat', s.at(b, k * 2 + 1), hat(0.6, rng, open_=True), 0.3)
            if b == 47:
                for st, f in ((8, 200), (10, 170), (12, 140), (14, 110)):
                    s.add('tom', s.at(b, st), tom(f, 0.9, rng), (st - 11) * 0.2)
        if b in (0, 16, 32, 40):
            s.add('crash', t0, cymbal(1.0, rng, 2.0), 0.2)
    s.add('fx', s.at(38), riser(2 * 4 * s.beat, rng, 600, 6000), 0.0)

    ir = make_ir(2.0, 1.4, 0.015, 6000, 2000, seed=9)
    duck = s.duck_env(0.3, 0.08)
    spec = {
        'lead': dict(gain=0.9, rev=0.18, dly=0.12),
        'lead2': dict(gain=1.0, rev=0.15),
        'pad': dict(gain=0.7, rev=0.25, duck=True),
        'stab': dict(gain=0.4, rev=0.2, duck=True),
        'arp': dict(gain=1.2, rev=0.2, dly=0.1, duck=True),
        'riff': dict(gain=0.9, rev=0.15, duck=True),
        'bass': dict(gain=0.75, duck=True),
        'kick': dict(gain=0.4, rev=0.03),
        'snare': dict(gain=0.85, rev=0.18),
        'hat': dict(gain=0.57, rev=0.05),
        'tom': dict(gain=0.55, rev=0.2),
        'crash': dict(gain=1.0, rev=0.2),
        'fx': dict(gain=0.75, rev=0.3),
    }
    x = mixdown(s, spec, ir, delay_sec=s.beat * 0.75, delay_fb=0.3, duck=duck)
    export(master(x), 'boss')


if __name__ == '__main__':
    which = sys.argv[1:] or ['title', 'game', 'boss']
    for w in which:
        {'title': make_title, 'game': make_game, 'boss': make_boss}[w]()
