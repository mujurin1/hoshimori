"""生成物の数値検証(汎用部は lib/audio/verify.py と同じ + 末尾にほしもり固有の期待値): クリップ/DC/NaN/長さ/ラウドネス/スペクトル/ループ継ぎ目

作品固有の期待値は呼び出し側から渡す:
  check_sfx(sfx_dir, spec)      spec = {名前: (ピーク dBFS, 最小秒, 最大秒)}
  check_music(mus_dir, expect)  expect = {名前: (BPM, 小節数)}
"""
import os
import re
import subprocess
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import welch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synth import SR, db, momentary_max, lufs  # noqa

BANDS = [(20, 150), (150, 500), (500, 2000), (2000, 5000), (5000, 20000)]


def spectrum(x):
    f, p = welch(x, SR, nperseg=min(4096, len(x)))
    tot = np.sum(p) + 1e-20
    shares = [100 * np.sum(p[(f >= a) & (f < b)]) / tot for a, b in BANDS]
    cen = np.sum(f * p) / tot
    # 3-5kHz のピーク密度が 500-8k の中央値よりどれだけ突出しているか
    # 耳に刺さる帯域 3-5kHz のエネルギー比 [%]
    hot = 100 * np.sum(p[(f >= 3000) & (f < 5000)]) / tot
    return shares, cen, hot


def ffmpeg_ebur(path):
    r = subprocess.run(['ffmpeg', '-nostats', '-i', path, '-af', 'ebur128=peak=true', '-f', 'null', '-'],
                       capture_output=True, text=True)
    s = r.stderr[r.stderr.rfind('Summary'):]
    I = float(re.search(r'I:\s+(-?[\d.]+) LUFS', s).group(1))
    tp = float(re.search(r'Peak:\s+(-?[\d.]+) dBFS', s).group(1))
    lra = float(re.search(r'LRA:\s+(-?[\d.]+) LU', s).group(1))
    return I, tp, lra


def decode(path):
    r = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                       capture_output=True, check=True)
    return np.frombuffer(r.stdout, np.float32).reshape(-1, 2).T.astype(float)


def check_sfx(sfx_dir, spec):
    print('== SFX ==')
    print(f'{"name":15s} {"len":>6s} {"range":>11s} {"peak":>6s} {"DC":>8s} {"Mmax":>6s} '
          f'{"<150":>5s} {"-500":>5s} {"-2k":>5s} {"-5k":>5s} {">5k":>5s} {"cent":>6s} {"3-5k":>5s} {"edge":>6s}')
    bad = 0
    for name, (_, lo, hi) in spec.items():
        sr, q = wavfile.read(os.path.join(sfx_dir, name + '.wav'))
        assert sr == SR and q.dtype == np.int16 and q.ndim == 1
        x = q / 32768.0
        L = len(x) / SR
        peak = db(np.max(np.abs(x)))
        dc = np.mean(x)
        sh, cen, hot = spectrum(x)
        edge = max(abs(x[0]), abs(x[-1]))
        flags = []
        if not (lo - 1e-3 <= L <= hi + 1e-3):
            flags.append('LEN')
        if peak > -1.0:
            flags.append('CLIP')
        if abs(dc) > 1e-3 or np.isnan(x).any():
            flags.append('DC/NaN')
        if edge > 1e-3:
            flags.append('EDGE')
        bad += bool(flags)
        print(f'{name:15s} {L:6.3f} {lo:5.2f}-{hi:4.2f} {peak:6.1f} {dc:8.1e} {momentary_max(x):6.1f} '
              + ' '.join(f'{s:5.1f}' for s in sh) + f' {cen:6.0f} {hot:5.1f} {edge:6.4f} {" ".join(flags)}')
    return bad


def check_music(mus_dir, expect):
    print('== MUSIC ==')
    bad = 0
    for name, (bpm, bars) in expect.items():
        path = os.path.join(mus_dir, name + '.ogg')
        x = decode(path)
        n_exp = int(round(bars * 4 * 60 / bpm * SR))
        I, tp, lra = ffmpeg_ebur(path)
        peak = db(np.max(np.abs(x)))
        dc = np.abs(np.mean(x, axis=1)).max()
        d = np.abs(np.diff(x, axis=1))
        seam = np.abs(x[:, 0] - x[:, -1]).max()
        p999 = np.percentile(d, 99.9)
        # 継ぎ目前後 50ms の RMS 比(音量の段差)
        w = int(0.05 * SR)
        r_end = np.sqrt(np.mean(x[:, -w:] ** 2))
        r_beg = np.sqrt(np.mean(x[:, :w] ** 2))
        sh, cen, hot = spectrum(x.mean(axis=0))
        flags = []
        if x.shape[1] != n_exp:
            flags.append(f'LEN({x.shape[1]}!={n_exp})')
        if peak > -1.0 or tp > -1.0:
            flags.append('CLIP')
        if dc > 1e-3 or np.isnan(x).any():
            flags.append('DC/NaN')
        if seam > p999:
            flags.append('SEAM')
        if not (-18.5 <= I <= -15.5):
            flags.append('LUFS')
        bad += bool(flags)
        print(f'{name:6s} {bpm}BPM {bars}bars {x.shape[1] / SR:7.3f}s (expect {n_exp / SR:.3f}) '
              f'I={I:.1f}LUFS LRA={lra:.1f} TP={tp:.1f}dBTP peak={peak:.2f} DC={dc:.1e}')
        print(f'       seam step={seam:.4f} (median diff {np.median(d):.4f}, p99.9 {p999:.4f}, max {d.max():.4f}) '
              f'RMS end/begin {db(r_end):.1f}/{db(r_beg):.1f} dB')
        print('       bands%: ' + ' '.join(f'{s:5.1f}' for s in sh) + f'  centroid {cen:.0f}Hz  3-5k {hot:.1f}%  '
              + ' '.join(flags))
    return bad


# ---------------------------------------------------------------- ほしもり固有
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SFX_DIR = os.path.join(ROOT, 'game', 'audio', 'sfx')
MUS_DIR = os.path.join(ROOT, 'game', 'audio', 'music')
EXPECT = {'title': (76, 16), 'game': (128, 56), 'boss': (160, 48)}

if __name__ == '__main__':
    from sfx import SFX  # noqa
    spec = {n: (v[1], v[2], v[3]) for n, v in SFX.items()}
    b = check_sfx(SFX_DIR, spec) + check_music(MUS_DIR, EXPECT)
    print('ALL OK' if b == 0 else f'{b} file(s) flagged')
