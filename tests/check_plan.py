#!/usr/bin/env python3
"""check_plan.py C_DIR DATA_DIR - compare ktplan's screens with tools/planetref.py."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import numpy as np
import planetref as P
from stscreen import read_isp, planar_to_slots
cdir, data = sys.argv[1:3]
F = P.colour_table(50, 33, [48, 49, 50, 51, 128, 129])
land = P.load_land(os.path.join(data, 'plan1.dta'))
inv = [[255 - v for v in col] for col in land]
cases = [('PLN1.ISP', land, P.geometry(3025, 1.09), 1, 180), ('PLN1.ISP', land, P.geometry(3025, 1.09), 100, 250),
         ('PLN1.ISP', land, P.geometry(3025, 1.09), 200, 120), ('PLN2.ISP', inv, P.geometry(2000, 1.16), 50, 105)]
bad = 0
prev = None
for n, (isp, lnd, geo, c, ecl) in enumerate(cases):
    bands, luts, slots = read_isp(os.path.join(cdir, 'DATA', isp))
    if isp != prev: ref = slots.copy(); prev = isp   # frames accumulate on the same screen
    lb = np.zeros(200, int)
    for b, (y0, _) in enumerate(bands): lb[y0:] = b
    pl = [[None] * 121 for _ in range(121)]
    P.render(pl, lnd, c, ecl, geo, F)
    for oy in range(1, 121):
        for ox in range(1, 121):
            if pl[oy][ox] is not None:
                y, x = oy + 12, ox + 27
                ref[y, x] = luts[lb[y]][pl[oy][ox]]
    got = planar_to_slots(open(os.path.join(cdir, 'PLAN%d.BIN' % n), 'rb').read())
    d = int((got != ref).sum()); bad += d
    print('frame %d (c=%d, ecl=%d): %d pixels differ' % (n, c, ecl, d))
t = int.from_bytes(open(os.path.join(cdir, 'PLANT.BIN'), 'rb').read(), 'big')
print('20 frames (geometry 0) in %d ticks = %.0f ms per frame (no music)' % (t, t * 5 / 20))
sys.exit(1 if bad else 0)
