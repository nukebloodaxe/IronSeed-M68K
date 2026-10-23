#!/usr/bin/env python3
"""check_title.py TITLE.DAT SHOT.SCR... - a title-screen shot (no menu box) must be exactly the
cloud ring shifted by some k (found from the logo-free top lines) with the logo over it.
Caught the compose block-copy bug (one group in six left stale: 'squares in the stars')."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
from stscreen import planar_to_slots
d = open(sys.argv[1], 'rb').read()
o = 4 + 2 + 4 * 34 + 1024
cloud = planar_to_slots(d[o:o + 32000]).ravel()
logo = planar_to_slots(d[o + 32000:o + 64000]).ravel()
ok = True
for fn in sys.argv[2:]:
    scr = planar_to_slots(open(fn, 'rb').read()[:32000]).ravel()
    seg = scr[:7000]
    best = (1 << 30, 0)
    for k in range(64000):
        e = int((cloud[(np.arange(7000) - k) % 64000] != seg).sum())
        if e < best[0]: best = (e, k)
        if e == 0: break
    k = best[1]
    exp = np.where(logo > 0, logo, cloud[(np.arange(64000) - k) % 64000])
    bad = int((exp != scr).sum())
    print('%s: k=%d, %d pixels differ' % (os.path.basename(fn), k, bad))
    ok &= bad == 0
sys.exit(0 if ok else 1)
