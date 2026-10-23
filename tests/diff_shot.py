#!/usr/bin/env python3
"""diff_shot.py ORACLE_DIR ST_DIR NAME MODE.ISP OUT.png [x1 y1 x2 y2] - side by side: Linux through the
ST LUTs | ST | difference mask (x3 zoom of the rectangle, default whole screen)."""
import os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import numpy as np
from PIL import Image
from stscreen import planar_to_slots, read_isp
from isp2png import ste_rgb
odir, sdir, name, isp, out = sys.argv[1:6]
x1, y1, x2, y2 = map(int, sys.argv[6:10]) if len(sys.argv) > 6 else (0, 0, 319, 199)
bands, luts, _ = read_isp(isp)
s = open(os.path.join(sdir, name + '.SCR'), 'rb').read()
st = planar_to_slots(s[:32000])
lin = np.frombuffer(open(os.path.join(odir, 'shot_%s.raw' % name), 'rb').read()[:64000], np.uint8).reshape(200, 320)
lb = np.zeros(200, int)
for k, (y, _) in enumerate(bands): lb[y:] = k
ref = np.array([luts[lb[y]][lin[y]] for y in range(200)], np.uint8)
pal = np.zeros((200, 16, 3), np.uint8)
for y0, cols in bands: pal[y0:] = [ste_rgb(c) for c in cols]
rgb = lambda sl: pal[np.arange(200)[:, None], sl]
a, b = rgb(ref), rgb(st)
d = np.zeros_like(a); d[ref != st] = (255, 0, 0)
crop = lambda im: im[y1:y2 + 1, x1:x2 + 1]
row = np.concatenate([crop(a), np.full((y2 - y1 + 1, 4, 3), 128, np.uint8), crop(b), np.full((y2 - y1 + 1, 4, 3), 128, np.uint8), crop(d)], 1)
z = 3 if (x2 - x1) < 200 else 2
Image.fromarray(row).resize((row.shape[1] * z, row.shape[0] * z), Image.NEAREST).save(out)
for y in range(y1, y2 + 1):
    xs = np.nonzero(ref[y, x1:x2 + 1] != st[y, x1:x2 + 1])[0]
    if len(xs): print('row %d: x %d-%d (%d px); linux idx %s' % (y, xs[0] + x1, xs[-1] + x1, len(xs), list(lin[y, xs[:6] + x1])))
