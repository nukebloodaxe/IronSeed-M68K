#!/usr/bin/env python3
"""looks.py [--png OUTDIR] [SESSION ...] - how close the ST's colours are to the original's, per
script shot: the ST shot (build/st_shots/SESSION/NAME.SCR, kept by tests/check_main.sh: planar
screen + band colours) shown as the STE shows it, against the Linux shot (build/oracle_SESSION/
shot_NAME.raw, 6-bit palette). Prints per shot the mean colour error (RGB distance, 0-255 scale),
the share of pixels off by more than 48 and the worst band; sorted worst first. --png writes
Linux | ST | error (bright = far) side by side for the 12 worst shots."""
import glob, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from stscreen import planar_to_slots
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
args = sys.argv[1:]
png = None
if args[:1] == ['--png']: png = args[1]; args = args[2:]
sessions = args or sorted(os.path.basename(d) for d in glob.glob(R + '/build/st_shots/*'))
def st_rgb(d):
    slots = planar_to_slots(d[:32000])
    b = d[32000:]
    n = struct.unpack('>H', b[:2])[0]
    pal = np.zeros((200, 16, 3), np.int32); band = np.zeros(200, int)
    for k in range(n):
        e = b[2 + 34 * k:2 + 34 * (k + 1)]
        y0 = struct.unpack('>H', e[:2])[0]
        band[y0:] = k
        for s in range(16):
            w = struct.unpack('>H', e[2 + 2 * s:4 + 2 * s])[0]
            for c, sh in enumerate((8, 4, 0)):
                v = (w >> sh) & 15
                pal[y0:, s, c] = (((v & 7) << 1) | (v >> 3)) * 17
    return pal[np.arange(200)[:, None], slots], band
rows = []
for S in sessions:
    for f in sorted(glob.glob(R + '/build/st_shots/%s/*.SCR' % S)):
        name = os.path.basename(f)[:-4]
        raw = R + '/build/oracle_%s/shot_%s.raw' % (S, name)
        if not os.path.exists(raw): continue
        st, band = st_rgb(open(f, 'rb').read())
        d = open(raw, 'rb').read()
        idx = np.frombuffer(d[:64000], np.uint8).reshape(200, 320)
        lp = np.frombuffer(d[64000:64768], np.uint8).reshape(256, 3).astype(np.int32) * 255 // 63
        li = lp[idx]
        err = np.sqrt(((st - li) ** 2).sum(axis=2))
        far = (err > 48).mean()
        bands = [(err[band == k].mean() if (band == k).any() else 0) for k in range(band.max() + 1)]
        wb = int(np.argmax(bands))
        rows.append((err.mean(), far, S, name, wb, bands[wb], li, st, err))
rows.sort(key=lambda r: -r[0])
print('%-5s %-8s %6s %6s  worst band' % ('sess', 'shot', 'mean', '>48'))
for m, far, S, name, wb, bm, *_ in rows:
    print('%-5s %-8s %6.1f %5.1f%%  band %d (mean %.1f)' % (S, name, m, 100 * far, wb, bm))
if png:
    from PIL import Image
    os.makedirs(png, exist_ok=True)
    for m, far, S, name, wb, bm, li, st, err in rows[:12]:
        e = np.clip(err * 2, 0, 255).astype(np.uint8)
        img = np.concatenate([li.astype(np.uint8), st.astype(np.uint8), np.stack([e] * 3, axis=2)], axis=1)
        Image.fromarray(img).resize((960 * 2, 400), Image.NEAREST).save('%s/%s_%s.png' % (png, S, name))
