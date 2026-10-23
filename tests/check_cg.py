#!/usr/bin/env python3
"""check_cg.py ORACLE_DIR ST_DIR CGMODES.DAT NAME... - CREWGEN screens: each ST shot (NAME.SCR) against
the Linux shot (shot_NAME.raw): the Linux indices go through the ST's LUTs of the mode the ST was in
(found from the band table in the .SCR), and the slots are compared. Prints differing pixels
per shot (the dialog's version string is excluded: the ST says 'STE 0.3')."""
import os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import numpy as np
from stscreen import planar_to_slots
odir, sdir, cgm = sys.argv[1:4]
d = open(cgm, 'rb').read()
MODE = 8 + 2 + 136 + 1024 + 64 + 32000 + 64
modes = []
for m in range(struct.unpack('>H', d[4:6])[0]):
    h = d[6 + m * MODE:6 + (m + 1) * MODE]
    luts = [np.frombuffer(h[146 + i * 256:146 + (i + 1) * 256], np.uint8) for i in range(4)]
    modes.append((h[8:146], luts))
bad_total = 0
for name in sys.argv[4:]:
    s = open(os.path.join(sdir, name + '.SCR'), 'rb').read()
    st = planar_to_slots(s[:32000])
    tab = s[32000:32000 + 138]
    lin = np.frombuffer(open(os.path.join(odir, 'shot_%s.raw' % name), 'rb').read()[:64000], np.uint8).reshape(200, 320)
    # the mode: same split lines (colours of own slots change at run time)
    lines = lambda t: [struct.unpack('>H', t[2 + 34 * k:4 + 34 * k])[0] for k in range(struct.unpack('>H', t[:2])[0])]
    mi = next(i for i, (t, _) in enumerate(modes) if lines(t) == lines(tab) and t[:2] == tab[:2])
    t, luts = modes[mi]
    lb = np.zeros(200, int)
    for k, y in enumerate(lines(t)): lb[y:] = k
    ref = np.array([luts[lb[y]][lin[y]] for y in range(200)], np.uint8)
    mask = np.ones((200, 320), bool)
    mask[132:139, 85:190] = False
    if mi == 2: mask &= (lin < 128) | (lin > 159)   # SAVE: the frozen graph is re-mapped at run time
    diff = (ref != st) & mask
    n = int(diff.sum()); bad_total += n
    ys, xs = np.nonzero(diff)
    print('%-5s mode %d: %5d pixels differ%s' % (name, mi, n, (' (rows %d-%d, x %d-%d)' % (ys.min(), ys.max(), xs.min(), xs.max())) if n else ''))
sys.exit(1 if bad_total else 0)
