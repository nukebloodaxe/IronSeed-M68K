#!/usr/bin/env python3
"""eggeval.py ORACLE_ROOT DESIGN.ISP... : EGGN designs on the egg shots (Linux frames through the
design: slot colour = its rep's colour on the STE grid; egg 2's shots with ms_dither's spec 0-2/1-63
modelled exactly as vid_dith). Blurred and raw mean error per design."""
import sys, struct, numpy as np
R = sys.argv[1]
SHOTS = [('m44', n, n.startswith('G')) for n in ('G1', 'G2', 'G3')] + [('m44', 'H1', False), ('m44', 'H2', False), ('m45', 'K1', False), ('m45', 'K2', False)]
def blur(x):
    y = x.copy(); y[:, 1:-1] = (x[:, :-2] + 2 * x[:, 1:-1] + x[:, 2:]) / 4
    z = y.copy(); z[1:-1] = (y[:-2] + 2 * y[1:-1] + y[2:]) / 4; return z
def lev(c6): return np.round(c6 * 15 / 63).astype(int) * 17
def dith(A, reps, pal6, lo, hi):
    B = A.copy(); cs = lev(pal6[reps]); use = np.array([lo <= r <= hi for r in reps])
    c255 = (pal6 * 255 + 31) // 63
    for i in range(lo, hi + 1):
        a = A[i]
        if not use[a]: continue
        t = c255[i]; ca = cs[a]; ea = ((t - ca) ** 2).sum()
        if ea <= 196: continue
        best, bs = None, a
        for s in range(16):
            if s == a or not use[s]: continue
            s1 = ((ca + cs[s] - 2 * t) ** 2).sum()
            if s1 > ea: continue
            cost = 5 * s1 + 2 * ((ca - cs[s]) ** 2).sum()
            if best is None or cost < best: best, bs = cost, s
        B[i] = bs
    return B
for fn in sys.argv[2:]:
    d = open(fn, 'rb').read(); tab = d[8:146]; n = struct.unpack('>H', tab[:2])[0]
    lines = [struct.unpack('>H', tab[2 + 34 * k:4 + 34 * k])[0] for k in range(n)]
    luts = [np.frombuffer(d[146 + i * 256:146 + (i + 1) * 256], np.uint8) for i in range(4)]
    reps = np.frombuffer(d[1170:1234], np.uint8).reshape(4, 16)
    lb = np.zeros(200, int)
    for k, y in enumerate(lines): lb[y:] = k
    eb, er, ep = [], [], []
    for S, N, isg in SHOTS:
        import os
        raw = open(next(p for p in ('%s/build/oracle_%s/shot_%s.raw' % (r, S, N) for r in R.split(',')) if os.path.exists(p)), 'rb').read()
        idx = np.frombuffer(raw[:64000], np.uint8).reshape(200, 320)
        pal6 = np.frombuffer(raw[64000:64768], np.uint8).reshape(256, 3).astype(int)
        true = pal6[idx] * 255 / 63; img = np.zeros_like(true)
        par = (np.add.outer(np.arange(200), np.arange(320)) & 1).astype(bool)
        for k in range(n):
            r = lb == k; cs = lev(pal6[reps[k]]); A = luts[k]
            B = dith(A, reps[k], pal6, 1, 63) if (isg and k <= 2) else A
            m0 = r[:, None] & ~par; m1 = r[:, None] & par
            img[m0] = cs[A[idx[m0]]]; img[m1] = cs[B[idx[m1]]]
        import os as _o
        if _o.environ.get('PNGDIR'):
            from PIL import Image
            _o.makedirs(_o.environ['PNGDIR'], exist_ok=True)
            tag = fn.split('/')[-2]
            Image.fromarray(img.astype(np.uint8)).save('%s/%s_%s_%s.png' % (_o.environ['PNGDIR'], S, N, tag))
            Image.fromarray(true.astype(np.uint8)).save('%s/%s_%s_linux.png' % (_o.environ['PNGDIR'], S, N))
        tb = np.stack([blur(true[..., c]) for c in range(3)], -1); ib = np.stack([blur(img[..., c]) for c in range(3)], -1)
        e = np.sqrt(((ib - tb) ** 2).sum(-1))
        if _o.environ.get('NONOISE'):
            keep = ~((idx >= 200) & (idx < 232)); keep[1:-1] &= keep[:-2] & keep[2:]; keep[:, 1:-1] &= keep[:, :-2] & keep[:, 2:]
            eb.append(e[keep].mean())
        else: eb.append(e.mean()); er.append(np.sqrt(((img - true) ** 2).sum(-1)).mean())
        if isg: ep.append(np.concatenate([e[69:139, 50:120].ravel(), e[69:139, 201:271].ravel()]).mean())
    print('%-34s splits %-18s blurred %.2f raw %.2f  portraits %.2f  (G %s / others %s)' % (fn.split('/')[-2] + '/' + fn.split('/')[-1], lines, np.mean(eb), np.mean(er), np.mean(ep),
          ' '.join('%.1f' % x for x in eb[:3]), ' '.join('%.1f' % x for x in eb[3:])))
