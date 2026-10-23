#!/usr/bin/env python3
"""mkplanets.py DATA_DIR OUTDIR - assets for the intro's planet scenes (intro.pas makeplanet).

PLANET.DAT (big-endian):
  'PLN2'
  F: 30 x 256 bytes, game colour for (lighting alt 0..29, land height 0..255)
     (water 50, waterindex 33, spcindex 48,49,50,51,128,129 - the same in all three scenes)
  land: 120 rows x 360 words, row i = land[1..240][i] then land[1..120][i] again (no wrap test),
        each stored as height*4 (a byte offset into the renderer's long tables)
  3 geometry sets, (radius 3025, c2 1.09), (2000, 1.16) and (400, 1.30, is2), each:
     r2.w, x.w, nrows.w, then per row: ofsy.w (= i-5), m.w, count.w, count index*2 bytes (+pad)
PLN1.ISP / PLN2.ISP / PLN3.ISP: the backgrounds (cloud, battle1, cloud) as ISP2 pictures with
bands chosen for the background + planet colours over a whole turn + the bigprintxy text.
PLN2.PAL: battle1's own palette (768 bytes, 0..63), as loadscreen_data sets it.
"""
import os, re, struct, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c
import planetref as P

data, outdir = sys.argv[1:3]
SPC = [48, 49, 50, 51, 128, 129]
F = P.colour_table(50, 33, SPC)
land = P.load_land(os.path.join(data, 'plan1.dta'))
inv = [[255 - v for v in col] for col in land]
geoA = P.geometry(3025, 1.09)
geoB = P.geometry(2000, 1.16)
geoC = P.geometry(400, 1.30)

out = bytearray(b'PLN2')
for row in F: out += bytes(row)
for i in range(1, 121):
    out += struct.pack('>360H', *[4 * land[j2][i] for j2 in list(range(1, 241)) + list(range(1, 121))])
for r2, x, rows in (geoA, geoB, geoC):
    out += struct.pack('>3H', r2, x, len(rows))
    for i, m, idx in rows:
        out += struct.pack('>3H', i - 5, m, len(idx)) + bytes(2 * v for v in idx)
        if len(idx) & 1: out += b'\0'
open(os.path.join(outdir, 'PLANET.DAT'), 'wb').write(out)

# bigfont text, as bigprintxy draws it (for the band statistics)
src = open(os.path.join(os.path.dirname(data.rstrip('/')), 'intro.pas'), encoding='latin-1').read()
m = re.search(r'bigfont:\s*array\[1\.\.82\] of bigfonttype\s*=\s*\((.*?)\);', src, re.S)
bf = [int(v) for v in re.findall(r'\d+', m.group(1))]
def letter(ch):
    o = ord(ch)
    if 'a' <= ch <= 'z': return o - 40
    if 'A' <= ch <= 'Z': return o - 36
    if ' ' <= ch <= '"': return o - 31
    if "'" <= ch <= '?': return o - 35
    if ch == '%': return 55
    return 1
def bigprint(img, x1, y1, s, tcolor):
    for ch in s:
        g = bf[(letter(ch) - 1) * 8:(letter(ch) - 1) * 8 + 8]
        t = tcolor
        for r in range(8):
            for b in range(8):
                if g[r] & (128 >> b): img[y1 + 1 + r, x1 + 1 + b] = t
            t -= 1
        x1 += 8

TEXT1 = [(159, 'Escaping the iron fist of a fanatic'), (167, 'theocracy, the members of the Ironseed'),
         (175, 'Movement launch into space and are set'), (183, 'adrift after suffering a computer'), (191, 'malfunction.')]
TEXT2 = [(175, 'As captain, you awaken along with the'), (183, 'crew some thousand years later and are'),
         (191, 'confronted by an alien horde...')]
TEXT3 = [(159, 'They threaten to devour all life in'), (167, 'their path...your only hope of defeating'),
         (175, 'the Scavengers is to reunite the Kendar,'), (183, 'an ancient alliance among the free'), (191, 'worlds.')]

def scene(bgname, palname, lnd, geo, ecls, text, outname):
    w, h, bg, pal, haspal = c.read_cpr(os.path.join(data, bgname + '.cpr'),
        np.frombuffer(open(os.path.join(data, 'main.pal'), 'rb').read()[:768], np.uint8).reshape(256, 3).astype(np.int32))
    if palname == 'main':
        pal = np.frombuffer(open(os.path.join(data, 'main.pal'), 'rb').read()[:768], np.uint8).reshape(256, 3).astype(np.int32)
    img = bg.copy()
    for y, s in text: bigprint(img, 0, y, s, 22)
    hist_img = []          # planet frames over a turn, for statistics
    for k, cc in enumerate(range(0, 240, 6)):
        pl = [[None] * 121 for _ in range(121)]
        P.render(pl, lnd, cc, ecls[k % len(ecls)], geo, F)
        fr = img.copy()
        for oy in range(1, 121):
            for ox in range(1, 121):
                if pl[oy][ox] is not None: fr[oy + 12, ox + 27] = pl[oy][ox]
        hist_img.append(fr)
    stack = np.stack(hist_img)
    splits = c.choose_splits(stack[0], pal, 4)
    bounds = splits + [200]
    table, luts = [], []
    for b in range(len(splits)):
        y0, y1 = bounds[b], bounds[b + 1]
        cnt = np.bincount(stack[:, y0:y1].ravel(), minlength=256).astype(float)
        idx = np.nonzero(cnt)[0]
        cent = c.quantise(pal[idx], cnt[idx], 16, reserved=((0, 0, 0),))
        lut = c.band_lut(pal, cent)
        table.append((y0, [c.to_ste_word(x) for x in cent])); luts.append(lut)
    line_band = np.zeros(200, int)
    for b, (y0, _) in enumerate(table): line_band[y0:] = b
    slots = np.array([luts[line_band[y]][bg[y]] for y in range(200)], np.uint8)
    W, pdata = c.planar(slots)
    c.write_isp(os.path.join(outdir, outname), W, 200, table, luts, pdata, c.compute_reps(stack[0], pal, table, luts))
    if palname == 'own':       # loadscreen_data sets colors to the picture's palette
        open(os.path.join(outdir, outname[:-4] + '.PAL'), 'wb').write(pal.astype(np.uint8).tobytes())
    print('%s: bands %s' % (outname, splits))

scene('cloud', 'main', land, geoA, [180, 200, 230, 260, 300], TEXT1, 'PLN1.ISP')
scene('battle1', 'own', inv, geoB, [105], TEXT2, 'PLN2.ISP')
scene('cloud', 'main', inv, geoA, [190], TEXT3, 'PLN3.ISP')
print('PLANET.DAT: %d bytes' % len(out))
