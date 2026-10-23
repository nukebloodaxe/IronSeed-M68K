#!/usr/bin/env python3
"""mkalien.py DATA_DIR OUTDIR - the ship1 / alien-screen part of the intro (intro.pas 1585-1615:
ship1 + orders text, shrinkalienscreen, fadeinalienscreen, alienscreenwait).

SHRINK.DAT: ship1 as ISP2 (bands chosen over ship1, its text and all 24 shrink frames),
  ship1's palette (768), frames.w, then per frame (shrinkalienscreen a = 1..24):
  y0.w, rows.w, offset.w (byte offset of the first 16-pixel group in a line), longs.w
  (per row), rows x longs planar data - the frame's rectangle, cell-aligned, from the
  screen as it is after that frame (scale_img of ship1's (10,0,200,106) over the previous
  frames; the host does the scaling, the ST copies).
ALIENS.DAT: alien.cpr with the final frame's box (rows 142-176, x 234-305) pasted, as ISP2
  (bands over the picture, the moving dots and the circles), alien's palette (768),
  2 x 8 dot entries (x.w, y.w, colour.w, xor colour.w) - dot 1 then dot 2, positions
  0..7 - then 3 circles (j = 3, 2, 1): colour.w, count.w, count x (dx.b, dy.b).
"""
import os, struct, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c
import introgfx as G

data, outdir = sys.argv[1:3]
_, _, ship, spal, _ = c.read_cpr(os.path.join(data, 'ship1.cpr'))
_, _, alien, apal, _ = c.read_cpr(os.path.join(data, 'alien.cpr'))
ORDERS = [(125, 'Orders: Approach and Destroy.'), (135, 'Jamming all Emissions.'), (145, 'Targeting...'),
          (155, 'Locked and Loading...'), (165, 'Closing for Fire...')]

scr = ship.copy()
for y, s in ORDERS: G.printxy(scr, data, 50, y, s, 255)
t = scr.copy()
screens, rects = [scr.copy()], []
for a in range(1, 25):
    partx = 306 - 234 / 25 * a
    party = 177 - 142 / 25 * a
    starty = 171 - round(party)
    startx = 305 - round(partx)
    G.scale_img(10, 0, 200, 106, startx, starty, round(partx), round(party), t, scr)
    screens.append(scr.copy())
    rects.append((startx, starty, round(partx), round(party)))
table, luts, lb = G.bands(np.stack(screens), spal)
W, pdata = c.planar(G.slots(ship, luts, lb))
reps = c.compute_reps(screens[0], spal, table, luts)
c.write_isp(os.path.join(outdir, 'SHRINK.DAT'), W, 200, table, luts, pdata, reps)
out = bytearray(spal.astype(np.uint8).tobytes()) + struct.pack('>H', len(rects))
total = 0
for k, (x0, y0, w, h) in enumerate(rects):
    _, pd = c.planar(G.slots(screens[k + 1], luts, lb))
    g0, g1 = x0 // 16, (x0 + w - 1) // 16
    n = (g1 - g0 + 1) * 8
    out += struct.pack('>4H', y0, h, g0 * 8, n // 4)
    for y in range(y0, y0 + h):
        out += pd[y * 160 + g0 * 8:y * 160 + g0 * 8 + n]
    total += h * n
open(os.path.join(outdir, 'SHRINK.DAT'), 'ab').write(out)
print('SHRINK.DAT: bands %s, frames %d bytes' % ([b[0] for b in table], total))

# alien screen
comp = alien.copy()
comp[142:177, 234:306] = scr[142:177, 234:306]
x1, y1, x2, y2 = 183, 131, 62, 148
dots = [[], []]
for j in range(8):
    dots[0].append((x1 - j, y1 + j))
    dots[1].append((x2, y2 + j))
final = comp.copy()
extra = np.zeros((200, 256))
for d in dots:
    for x, y in d: extra[y, comp[y, x] ^ 31] += 40
circ = []
for j in (3, 2, 1):
    col = 175 - j * 2
    pts = G.circle_points(j * 3 + 1)
    circ.append((col, pts))
    for cx, cy in ((176, 138), (62, 155)):
        for dx, dy in pts: final[cy + dy, cx + dx] = col
table, luts, lb = G.bands(np.stack([final, comp]), apal, extra)
W, pdata = c.planar(G.slots(comp, luts, lb))
reps = c.compute_reps(final, apal, table, luts)
c.write_isp(os.path.join(outdir, 'ALIENS.DAT'), W, 200, table, luts, pdata, reps)
out = bytearray(apal.astype(np.uint8).tobytes())
for d in dots:
    for x, y in d: out += struct.pack('>4H', x, y, int(comp[y, x]), int(comp[y, x]) ^ 31)
for col, pts in circ:
    out += struct.pack('>2H', col, len(pts))
    for dx, dy in pts: out += struct.pack('>2b', dx, dy)
    if len(pts) & 1: pass
open(os.path.join(outdir, 'ALIENS.DAT'), 'ab').write(out)
print('ALIENS.DAT: bands %s' % [b[0] for b in table])
