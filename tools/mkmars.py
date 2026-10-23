#!/usr/bin/env python3
"""mkmars.py DATA_DIR OUT.DAT - the Mars scene (intro.pas showmars + upscroll + titles).

The original shows cloud.cpr (in world.cpr's palette), then upscroll() slides the top 99
rows of world.cpr up from the bottom (5 ms per row) until they fill rows 101-199; then
'Mars' / '3784 A.D.' are printed in colours 29/30, which ramp from black to red.

STE: band 0 = the cloud + text: slot 0 black, slots 1-4 cloud shades, slot 14 = colour 29,
slot 15 = colour 30 (both animated); bands 1-3 = the world image, split at rows chosen
within its 99 rows; during the scroll the program moves those split lines with the image.

MARS.DAT, big-endian:
  'MRS1', band table (count.w, 4 x (first line.w, 16 colours.w)) for the final position
         (world at row 101), 4 x 256 LUTs, 4 x 16 reps (vid_set256),
  world split offsets: 3 words (rows within the image where bands 1-3 start: 0, s1, s2),
  cloud planar 32000 bytes (the whole screen, band 0 slots),
  world planar 99 x 160 bytes (bands 1-3 slots),
  world palette 768 bytes.
"""
import os, struct, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c

data, out = sys.argv[1:3]
_, _, world, pal, _ = c.read_cpr(os.path.join(data, 'world.cpr'))
_, _, cloud, _, _ = c.read_cpr(os.path.join(data, 'cloud.cpr'), pal)
top = world[:99]
# band 0: cloud shades (4) + black + the two text colours (ramped red, own slots)
cidx, ccnt = np.unique(cloud[cloud > 0], return_counts=True)
shades = c.quantise(pal[cidx], ccnt.astype(float), 5, reserved=((0, 0, 0),))
b0 = list(shades) + [np.zeros(3, int)] * (14 - len(shades)) + [np.zeros(3, int), np.zeros(3, int)]
lut0 = np.zeros(256, np.uint8)
p4 = pal.astype(float) * 15 / 63
for i in range(256):
    d = [((p4[i] - np.array(b0[s], float)) ** 2).sum() for s in range(len(shades))]
    lut0[i] = int(np.argmin(d))
lut0[29], lut0[30] = 14, 15
reps0 = []
for s in range(16):
    m = [i for i in cidx if lut0[i] == s]
    reps0.append(int(m[np.argmax([ccnt[list(cidx).index(i)] for i in m])]) if m else 0)
reps0[14], reps0[15] = 29, 30
# bands 1-3: world rows 0..98
sp = c.choose_splits(top, pal, 3, step=4)
wb = sp + [99]
tables, luts, reps = [(0, [c.to_ste_word(x) for x in b0])], [lut0], [reps0]
wslots = np.zeros_like(top)
for k in range(3):
    y0, y1 = wb[k], wb[k + 1]
    cnt = np.bincount(top[y0:y1].ravel(), minlength=256).astype(float)
    idx = np.nonzero(cnt)[0]
    cent = c.quantise(pal[idx], cnt[idx], 16, reserved=((0, 0, 0),))
    lut = c.band_lut(pal, cent)
    wslots[y0:y1] = lut[top[y0:y1]]
    tables.append((101 + y0, [c.to_ste_word(x) for x in cent]))
    luts.append(lut)
    rr = []
    for s in range(16):
        m = np.nonzero(lut == s)[0]
        rr.append(int(m[np.argmax(cnt[m])]) if len(m) and cnt[m].max() > 0 else 0)
    reps.append(rr)
cslots = lut0[cloud]
_, cpl = c.planar(cslots)
_, wpl = c.planar(np.vstack([wslots, np.zeros((101, 320), np.uint8)]))
b = bytearray(b'MRS1') + struct.pack('>H', 4)
for line, cols in tables: b += struct.pack('>H16H', line, *cols)
for l in luts: b += bytes(l)
b += bytes(sum(reps, []))
b += struct.pack('>3H', *sp)
b += cpl + wpl[:99 * 160] + pal.astype(np.uint8).tobytes()
open(out, 'wb').write(b)
print('MARS: world splits %s, %d bytes' % (sp, len(b)))
