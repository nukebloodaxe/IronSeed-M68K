#!/usr/bin/env python3
"""mktidy.py DATA_DIR TIDY.png OUT.png - the title logo (intro5.cpr) with David's tidy-up
from Ironseed-py (Graphics_Assets/intro5.png, 2020 "Tidied IronSeed Logo"): missing edge
pixels filled in, stray black (index 112) pixels made transparent.

The tidy PNG is RGBA. Every opaque pixel whose colour differs from intro5.cpr is mapped to
the intro5 palette entry with exactly that colour (all of them exist); fully transparent
pixels become index 0 (the title draws index 0 as see-through). Half-transparent edge pixels
keep their original index. Output: a palettised PNG (intro5's palette) that mktitle.py
reads with --logo, so the shipped data needs no Python project at build time."""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c

data, tidy, out = sys.argv[1:4]
_, _, logo, pal, _ = c.read_cpr(os.path.join(data, 'intro5.cpr'))
t = np.array(Image.open(tidy).convert('RGBA')).astype(int)
idx = logo.copy()
opaque = t[..., 3] == 255
changed = opaque & (np.abs(t[..., :3] - pal[logo] * 4).max(2) > 4)
n_fill = 0
for y, x in zip(*np.nonzero(changed)):
    d = np.abs(pal * 4 - t[y, x, :3]).sum(1)
    i = int(d.argmin())
    if d[i] > 6: sys.exit('no palette entry for %s at %d,%d' % (t[y, x, :3], x, y))
    idx[y, x] = i; n_fill += 1
clear = (t[..., 3] == 0) & (logo > 0)
idx[clear] = 0
im = Image.fromarray(idx.astype(np.uint8), 'P')
im.putpalette((pal * 4).astype(np.uint8).ravel().tolist())
im.save(out)
print('intro5 tidy: %d pixels filled/recoloured, %d made transparent' % (n_fill, int(clear.sum())))
