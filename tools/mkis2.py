#!/usr/bin/env python3
"""mkis2.py DATA_DIR OUT.DAT - the is2 scene (intro.pas getbackgroundforis2, is2wait, blast).

main3.cpr with its colour 255 replaced by cloud.cpr (colours as main3's palette), the small
planet (radius 400, c2 1.30, inverted land, ecl 50; drawn on the ST by planet.s, set 2)
and four bars lit by fadearea(+32), which is2wait puts back column by column (-32).

IS2.DAT: ISP2 of the lit state (bands chosen over the picture, the unlit bars, the text in
colour 26 and the planet at every rotation), main3's palette (768), then rows 35-105 of
the unlit state (71 x 160 bytes planar) for the ST to copy columns from.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c
import introgfx as G
import planetref as P

data, out = sys.argv[1:3]
_, _, main3, pal, _ = c.read_cpr(os.path.join(data, 'main3.cpr'))
_, _, cloud, _, _ = c.read_cpr(os.path.join(data, 'cloud.cpr'), pal)
base = np.where(main3 == 255, cloud, main3)
lit = base.copy()
for x1, y1, x2, y2 in ((186, 35, 290, 45), (186, 55, 200, 65), (186, 75, 233, 85), (186, 95, 279, 105)):
    r = lit[y1:y2 + 1, x1:x2 + 1]
    r[r > 0] += 32
F = P.colour_table(50, 33, [48, 49, 50, 51, 128, 129])
land = P.load_land(os.path.join(data, 'plan1.dta'))
inv = [[255 - v for v in col] for col in land]
geo = P.geometry(400, 1.30)
frames = []
for cc in range(0, 120, 4):
    pl = [[None] * 121 for _ in range(121)]
    P.render(pl, inv, cc, 50, geo, F)
    fr = lit.copy()
    for oy in range(1, 121):
        for ox in range(1, 121):
            if pl[oy][ox] is not None: fr[oy + 12, ox + 27] = pl[oy][ox]
    frames.append(fr)
extra = np.zeros((200, 256))
for y in range(160, 190):
    for t in range(26, 15, -2): extra[y, t] += 4
table, luts, lb = G.bands(np.stack([frames[0]] + frames[1:] + [base]), pal, extra)
W, pdata = c.planar(G.slots(lit, luts, lb))
reps = c.compute_reps(frames[0], pal, table, luts)
c.write_isp(out, W, 200, table, luts, pdata, reps)
_, pb = c.planar(G.slots(base, luts, lb))
open(out, 'ab').write(pal.astype(np.uint8).tobytes() + pb[35 * 160:106 * 160])
print('%s: bands %s' % (out, [b[0] for b in table]))
