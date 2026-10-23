#!/usr/bin/env python3
"""raw2png.py shot_X.raw out.png [scale] : a Linux oracle screenshot (64000 indices + 256 RGB
palette, 6-bit) as a PNG."""
import sys
import numpy as np
from PIL import Image
d = open(sys.argv[1], 'rb').read()
idx = np.frombuffer(d[:64000], np.uint8).reshape(200, 320)
pal = np.frombuffer(d[64000:64000 + 768], np.uint8).reshape(256, 3).astype(np.uint16)
pal = (pal * 255 // 63).clip(0, 255).astype(np.uint8)
im = Image.fromarray(pal[idx])
s = int(sys.argv[3]) if len(sys.argv) > 3 else 2
im.resize((320 * s, 200 * s), Image.NEAREST).save(sys.argv[2])
