#!/usr/bin/env python3
"""mkpal.py PALFILE OUT.ISL [--use 0,12-22,...] [--cpr file.cpr]
Bands + LUTs only (no picture) for screens drawn at run time, e.g. text on black.
Palette from a 768-byte VGA .pal, or from a .cpr's embedded palette (--cpr).
One band; the 16 slots are the most important colours of --use (default: all 256)
quantised to the STE grid, slot 0 = black. Output: 'ISP1', w=0, h=0, bands, 4 LUTs (all equal)."""
import argparse, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c

ap = argparse.ArgumentParser()
ap.add_argument('pal'); ap.add_argument('out')
ap.add_argument('--use', default='0-255'); ap.add_argument('--cpr', action='store_true')
ap.add_argument('--own', default='', help='indices that get a slot of their own (animated colours)')
a = ap.parse_args()
if a.cpr:
    pal = c.read_cpr(a.pal)[3]
else:
    pal = np.frombuffer(open(a.pal, 'rb').read()[:768], np.uint8).reshape(256, 3).astype(np.int32)
use = []
for part in a.use.split(','):
    lo, _, hi = part.partition('-'); use += list(range(int(lo), int(hi or lo) + 1))
use = np.array(sorted(set(use)))
own = [int(x) for x in a.own.split(',') if x]
rest = np.array([u for u in use if u not in own])
cent = c.quantise(pal[rest], np.ones(len(rest)), 16 - len(own), reserved=((0, 0, 0),))
lut = c.band_lut(pal, cent)
cent = np.vstack([cent, np.zeros((len(own), 3), int)])
for k, o in enumerate(own):
    lut[o] = 16 - len(own) + k
    cent[16 - len(own) + k] = np.clip(np.round(pal[o] * 15 / 63), 0, 15)
table = [(0, [c.to_ste_word(x) for x in cent])]
b = bytearray(b'ISP2') + bytes(4)
b += bytes([0, 1])
for i in range(4):
    line, cols = table[i] if i < len(table) else (0, [0] * 16)
    b += line.to_bytes(2, 'big') + b''.join(x.to_bytes(2, 'big') for x in cols)
b += bytes(lut) * 4
reps = c.compute_reps(None, pal, table, [lut])   # no picture: nearest index per slot
reps = bytearray(reps)
for k, o in enumerate(own): reps[16 - len(own) + k] = o
for sl in range(16):                               # prefer indices from --use
    m = [u for u in use if lut[u] == sl]
    if m and reps[sl] not in m: reps[sl] = m[len(m) // 2]
b += bytes(reps)
open(a.out, 'wb').write(b)
print('%s: %d colours used -> %d slots' % (os.path.basename(a.out), len(use), len({tuple(x) for x in cent})))
