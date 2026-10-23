#!/usr/bin/env python3
"""check_cred.py CRED.SCR CREDITS.ISL linux_credits.raw - the ST credits screen against the
Linux one (indices mapped through the ST LUT), on the lines both versions share:
rows 0-74 and 85-94 (the ST adds a port credit at row 75 and a version suffix at row 105)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import numpy as np
from stscreen import planar_to_slots
scr, isl, raw = sys.argv[1:4]
st = planar_to_slots(open(scr, 'rb').read()[:32000])
lut = np.frombuffer(open(isl, 'rb').read()[146:146 + 256], np.uint8)
lin = lut[np.frombuffer(open(raw, 'rb').read()[:64000], np.uint8).reshape(200, 320)]
rows = list(range(0, 75)) + list(range(85, 95))
bad = int((st[rows] != lin[rows]).sum())
print('credits: %d pixels differ from the Linux screen on the shared lines' % bad)
sys.exit(1 if bad else 0)
