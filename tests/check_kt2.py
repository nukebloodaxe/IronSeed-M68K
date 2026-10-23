#!/usr/bin/env python3
"""check_kt2.py ISP SCREEN.BIN FONT.I - compare kt2's screen with the reference model."""
import sys, os; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import numpy as np
from stscreen import Model, planar_to_slots, load_font
isp, scrbin, fonti = sys.argv[1:4]
m = Model(isp); font = load_font(fonti)[0]
m.printxy(20, 30, "IRON SEED on the STE: 64 colours!", 31, 255, font)
m.printxy(20, 40, "Text on a background (bkcolor 0)", 63, 0, font)
m.printxy(13, 100, "Crossing the band split at line 104?", 47, 255, font)
m.bar(200, 20, 250, 60, 44)
m.rect(190, 15, 260, 65, 63)
m.line(30, 60, 170, 150, 31)
m.pset(5, 5, 63); m.pset(318, 197, 63)
got = planar_to_slots(open(scrbin, 'rb').read())
bad = np.argwhere(got != m.img)
print('pixels differing from the reference:', len(bad))
for y, x in bad[:15]: print('  x=%d y=%d got %d want %d' % (x, y, got[y, x], m.img[y, x]))
sys.exit(1 if len(bad) else 0)
