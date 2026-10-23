#!/usr/bin/env python3
"""scr2png.py NAME.SCR out.png - render a test-script screenshot (screen + band table,
kernel/scr.s) with its band colours (full fade level), doubled in size."""
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from stscreen import planar_to_slots
d = open(sys.argv[1], 'rb').read()
slots = planar_to_slots(d[:32000])
b = d[32000:]
n = struct.unpack('>H', b[:2])[0]
pal = np.zeros((200, 16, 3), np.uint8)
for k in range(n):
    e = b[2 + 34 * k:2 + 34 * (k + 1)]
    y0 = struct.unpack('>H', e[:2])[0]
    for s in range(16):
        w = struct.unpack('>H', e[2 + 2 * s:4 + 2 * s])[0]
        rgb = []
        for sh in (8, 4, 0):
            v = (w >> sh) & 15
            v = ((v & 7) << 1) | (v >> 3)      # STE: bit 3 is the LSB
            rgb.append(v * 17)
        pal[y0:, s] = rgb
img = pal[np.arange(200)[:, None], slots]
Image.fromarray(img).resize((640, 400), Image.NEAREST).save(sys.argv[2])
