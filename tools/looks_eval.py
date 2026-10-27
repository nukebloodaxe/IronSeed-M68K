#!/usr/bin/env python3
"""looks_eval.py MODE DESIGN.ISP [DESIGN2.ISP ...] - score band designs offline on the Linux shots
that the ST showed in MODE (tests/check_main.sh's per-session /tmp/main_mN.txt name the mode of
every shot; the oracle shots from build/oracle_mN or the regression copies /root/r*/). Each Linux
shot is shown as the STE would through the design: slot = LUT[band][index], colour = the palette
entry of the slot's rep index on the 4-bit grid (vid_set256), and compared with Linux's colours:
mean RGB distance and the share of pixels off by > 48, per design, over all those shots."""
import glob, os, struct, sys
import numpy as np
mode, designs = sys.argv[1], sys.argv[2:]
def load(fn):
    d = open(fn, 'rb').read()
    tab = d[8:146]; n = struct.unpack('>H', tab[:2])[0]
    lines = [struct.unpack('>H', tab[2 + 34 * k:4 + 34 * k])[0] for k in range(n)]
    luts = [np.frombuffer(d[146 + i * 256:146 + (i + 1) * 256], np.uint8) for i in range(4)]
    reps = np.frombuffer(d[146 + 1024:146 + 1088], np.uint8)
    lb = np.zeros(200, int)
    for k, y in enumerate(lines): lb[y:] = k
    return lb, luts, reps
shots = []
for f in sorted(glob.glob('/tmp/main_m*.txt')):
    S = os.path.basename(f)[5:-4]
    for line in open(f):
        p = line.split()
        if len(p) >= 2 and p[1] == mode + '.ISP':
            for root in ['/root/w/ironseed-ste'] + sorted(glob.glob('/root/r*/ironseed-ste')):
                raw = '%s/build/oracle_%s/shot_%s.raw' % (root, S, p[0])
                if os.path.exists(raw): shots.append((S, p[0], raw)); break
print('%d shots in %s' % (len(shots), mode))
for dfn in designs:
    lb, luts, reps = load(dfn)
    errs, fars = [], []
    for S, n, raw in shots:
        d = open(raw, 'rb').read()
        idx = np.frombuffer(d[:64000], np.uint8).reshape(200, 320)
        pal6 = np.frombuffer(d[64000:64768], np.uint8).reshape(256, 3).astype(int)
        li = pal6 * 255 // 63
        q = np.clip(np.round(pal6 * 15 / 63), 0, 15).astype(int) * 17      # 4-bit grid
        st = np.zeros((200, 320, 3), int)
        for y in range(200):
            b = lb[y]
            sl = luts[b][idx[y]]
            st[y] = q[reps[b * 16 + sl]]
        e = np.sqrt(((st - li[idx]) ** 2).sum(2))
        errs.append(e.mean()); fars.append((e > 48).mean())
    print('%-28s mean %.2f  >48 %.2f%%  worst %.1f' % (os.path.basename(dfn), np.mean(errs), 100 * np.mean(fars), max(errs)))
