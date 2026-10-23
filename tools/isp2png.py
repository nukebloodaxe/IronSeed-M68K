#!/usr/bin/env python3
"""isp2png.py PIC.ISP out.png - render a converted picture as the STE shows it (doubled)."""
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from stscreen import read_isp


def ste_rgb(w):
    out = []
    for sh in (8, 4, 0):
        v = (w >> sh) & 15
        out.append((((v & 7) << 1) | (v >> 3)) * 17)
    return out


def render(bands, slots):
    pal = np.zeros((200, 16, 3), np.uint8)
    for y0, cols in bands:
        pal[y0:] = [ste_rgb(c) for c in cols]
    return pal[np.arange(200)[:, None], slots]


if __name__ == '__main__':
    bands, luts, slots = read_isp(sys.argv[1])
    print('bands at', [b[0] for b in bands])
    Image.fromarray(render(bands, slots)).resize((640, 400), Image.NEAREST).save(sys.argv[2])
