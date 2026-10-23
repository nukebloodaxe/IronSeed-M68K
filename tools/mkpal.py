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
a = ap.parse_args()
if a.cpr:
    pal = c.read_cpr(a.pal)[3]
else:
    pal = np.frombuffer(open(a.pal, 'rb').read()[:768], np.uint8).reshape(256, 3).astype(np.int32)
use = []
for part in a.use.split(','):
    lo, _, hi = part.partition('-'); use += list(range(int(lo), int(hi or lo) + 1))
use = np.array(sorted(set(use)))
cent = c.quantise(pal[use], np.ones(len(use)), 16, reserved=((0, 0, 0),))
lut = c.band_lut(pal, cent)
table = [(0, [c.to_ste_word(x) for x in cent])]
b = bytearray(b'ISP1') + bytes(4)
b += bytes([0, 1])
for i in range(4):
    line, cols = table[i] if i < len(table) else (0, [0] * 16)
    b += line.to_bytes(2, 'big') + b''.join(x.to_bytes(2, 'big') for x in cols)
b += bytes(lut) * 4
open(a.out, 'wb').write(b)
print('%s: %d colours used -> %d slots' % (os.path.basename(a.out), len(use), len({tuple(x) for x in cent})))
