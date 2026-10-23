#!/usr/bin/env python3
"""mkc7.py DATA_DIR OUT.ISP - the Channel 7 logo scene (intro.pas c7logo).

The original fills the screen with TV static (index random(16)+200 on even rows, +216 on
odd rows) and flickers it by rewriting palette entries 200-231 every frame, while the
channel7.cpr logo is revealed 178 pixels at a time in the order j += 159 (mod 38000),
x = j mod 300 + 20, y = j div 300 + 30.

STE: every band has slot 0 = black, slots 1-3 = even-row static (reps 200-202), slots 4-6 =
odd-row static (reps 216-218), slots 7-15 = the logo (quantised per band on the pixels the
reveal actually shows). The planar picture is the static. Appended: the logo as raw
chunky indices (64000 bytes) for the reveal, and channel7's 768-byte palette.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c

data, out = sys.argv[1:3]
_, _, logo, pal, _ = c.read_cpr(os.path.join(data, 'channel7.cpr'))
shown = np.zeros((200, 320), bool)
for j in range(38000):
    shown[j // 300 + 30, j % 300 + 20] = True
vis = np.where(shown & (logo > 0), logo, 0)
splits = c.choose_splits(vis, pal, 4)
bounds = splits + [200]
p4 = pal.astype(float) * 15 / 63
table, luts, reps = [], [], []
for b in range(4):
    y0, y1 = bounds[b], bounds[b + 1]
    sub = vis[y0:y1][vis[y0:y1] > 0]
    cnt = np.bincount(sub, minlength=256).astype(float)
    idx = np.nonzero(cnt)[0]
    cent = c.quantise(pal[idx], cnt[idx], 9) if len(idx) else np.zeros((9, 3), int)
    slots_rgb = [np.zeros(3, int)] * 7 + list(cent)          # 0-6 black placeholders (animated), 7-15 logo
    lut = np.zeros(256, np.uint8)
    for i in range(256):
        if 200 <= i <= 215: lut[i] = 1 + (i - 200) % 3
        elif 216 <= i <= 231: lut[i] = 4 + (i - 216) % 3
        else:
            cand = [0] + list(range(7, 16))
            d = [((p4[i] - np.array(slots_rgb[s], float)) ** 2).sum() for s in cand]
            lut[i] = cand[int(np.argmin(d))]
    rp = [0, 200, 201, 202, 216, 217, 218]
    for s in range(7, 16):
        m = np.nonzero(lut[:200] == s)[0]
        rp.append(int(m[np.argmax(cnt[m])]) if len(m) and cnt[m].max() > 0 else (int(m[0]) if len(m) else 0))
    table.append((y0, [0] * 7 + [c.to_ste_word(x) for x in cent]))
    luts.append(lut); reps.append(rp)
rng = np.random.default_rng(7)
static = (rng.integers(0, 16, (200, 320)) + 200 + (np.arange(200)[:, None] % 2) * 16).astype(np.uint8)
line_band = np.zeros(200, int)
for b, (y0, _) in enumerate(table): line_band[y0:] = b
slots = np.array([luts[line_band[y]][static[y]] for y in range(200)], np.uint8)
W, pdata = c.planar(slots)
c.write_isp(out, W, 200, table, luts, pdata, bytes(sum(reps, [])))
with open(out, 'ab') as f:
    f.write(logo.tobytes())
    f.write(pal.astype(np.uint8).tobytes())
print('C7: bands at %s, %d bytes' % (splits, os.path.getsize(out)))
