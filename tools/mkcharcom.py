#!/usr/bin/env python3
"""mkcharcom.py DATA_DIR OUT.ISP - the charcom scene (intro.pas readyencode, powerupencodes,
charcomstuff, fadecharcom).

The original draws TV static into a 69x70 box at (126, 40) (index random(16)+128 on even
rows, +144 on odd rows) and flickers it by palette: one phase gives colours 128-143 random
greys (colors[random(22)]) and 144-159 black, the other phase the reverse (random(16)).
Six 2-pixel bars grow in red (64 + round(b*31/36)) and six status lights change (pixels
48-63 -> +32); text in colour 191 shaded -2 per row.

STE: the static is drawn instead of palette-flickered: NFRAMES pre-rendered frames of the
box (rows 40-109, x 112-207 = 6 plane groups = 48 bytes per row, picture pixels around the
box baked in), half of each phase, each with its own random index colours, using the grey
slots of the picture's bands. Bands are chosen on the final screen (bars, lights, text).

File: the ISP2 picture, then charcom's palette (768), then frames.w + frames (3360 bytes
each, even phase first: frame k has phase k & 1), then the lights: per bar 0-5,
count.w + count x (x.w, y.w, colour.w).
"""
import os, struct, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c

NFRAMES = 16
data, out = sys.argv[1:3]
_, _, pic, pal, _ = c.read_cpr(os.path.join(data, 'charcom.cpr'))
rng = np.random.default_rng(1994)

final = pic.copy()
part = 31 / 36
for a in range(6):
    for b in range(37):
        for dy in (48, 49):
            final[(a % 3) * 30 + dy, (a // 3) * 258 + b + 13] = round(b * part) + 64
lights = []
for a in range(6):
    L = []
    for y in range((a % 3) * 30 + 37, (a % 3) * 30 + 43):
        for x in range((a // 3) * 138 + 89, (a // 3) * 138 + 94):
            if final[y, x] // 16 == 3:
                final[y, x] += 32
                L.append((x, y, int(final[y, x])))
    lights.append(L)

# static: fixed random index per pixel, as readyencode
sidx = np.zeros((70, 69), int)
for i in range(70):
    sidx[i] = rng.integers(0, 16, 69) + 128 + (i % 2) * 16

extra = np.zeros((200, 256))          # text and static colours, for the band statistics
for y in range(154, 190):
    for t in range(191, 180, -2): extra[y, t] += 3
for y in range(40, 110):
    for g in range(22): extra[y, g] += 69 * 0.5 / 22

splits = c.choose_splits(final, pal, 4)
bounds = splits + [200]
table, luts = [], []
for b in range(4):
    y0, y1 = bounds[b], bounds[b + 1]
    cnt = np.bincount(final[y0:y1].ravel(), minlength=256).astype(float) + extra[y0:y1].sum(0)
    idx = np.nonzero(cnt)[0]
    cent = c.quantise(pal[idx], cnt[idx], 16, reserved=((0, 0, 0),))
    luts.append(c.band_lut(pal, cent))
    table.append((y0, [c.to_ste_word(x) for x in cent]))
line_band = np.zeros(200, int)
for b, (y0, _) in enumerate(table): line_band[y0:] = b
def slots_of(img):
    return np.array([luts[line_band[y]][img[y]] for y in range(200)], np.uint8)
W, pdata = c.planar(slots_of(pic))
reps = c.compute_reps(final, pal, table, luts)

frames = bytearray()
for k in range(NFRAMES):
    col = np.zeros(256, int)           # colour index each static index shows in this frame
    if k & 1 == 0: col[128:144] = rng.integers(0, 22, 16)
    else: col[144:160] = rng.integers(0, 16, 16)
    scr = pic.copy()
    scr[40:110, 126:195] = col[sidx]
    sl = slots_of(scr)
    _, pd = c.planar(sl)
    for y in range(40, 110):
        frames += pd[y * 160 + 56:y * 160 + 104]

c.write_isp(out, W, 200, table, luts, pdata, reps)
b = bytearray(pal.astype(np.uint8).tobytes())
b += struct.pack('>H', NFRAMES) + frames
for L in lights:
    b += struct.pack('>H', len(L))
    for x, y, v in L: b += struct.pack('>3H', x, y, v)
open(out, 'ab').write(b)
print('%s: bands %s, %d light pixels' % (out, splits, sum(len(L) for L in lights)))
