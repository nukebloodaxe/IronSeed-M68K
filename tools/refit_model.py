#!/usr/bin/env python3
"""refit_model.py SHOT.raw LINE0 LINE1 [Y1 Y2 X1 X2] - the run-time band fit of game/refit.s (Phase 6j)
modelled on a Linux shot (build/oracle_mN/shot_X.raw): weighted farthest-point picks + k-means on
the band's colours, reps snapped to used indices, the LUT by nearest shown colour; prints the reps
and the mean colour error of the band (and of the rectangle). render() writes Linux | refit."""
import numpy as np, sys
def ste(c6):  # 6-bit -> STE 4-bit level -> displayed 8-bit (as looks.py)
    v = np.round(c6 * 15 / 63).astype(int)
    return v * 17
def fit(idx, pal6, lines, w_extra=None, k=16, sq=False, iters=6):
    reg = idx[lines[0]:lines[1]]
    cnt = np.bincount(reg.ravel(), minlength=256).astype(float)
    if w_extra is not None: cnt += w_extra
    used = np.nonzero(cnt)[0]
    w = np.sqrt(cnt[used]) if sq else cnt[used]
    col = pal6[used].astype(float)
    # init: black + farthest-point weighted
    cents = [np.zeros(3)]
    for _ in range(k - 1):
        d = np.min([((col - c) ** 2).sum(1) for c in cents], axis=0)
        cents.append(col[np.argmax(w * d)])
    cents = np.array(cents)
    for _ in range(iters):
        a = np.argmin(((col[:, None, :] - cents[None]) ** 2).sum(2), 1)
        for j in range(1, k):
            m = a == j
            if m.any(): cents[j] = (col[m] * w[m, None]).sum(0) / w[m].sum()
    reps = [0]
    for j in range(1, k):
        reps.append(used[np.argmin(((col - cents[j]) ** 2).sum(1))])
    reps = np.array(reps)
    slot_rgb = ste(pal6[reps])
    allc = ste(pal6)
    lut = np.argmin(((allc[:, None, :] - slot_rgb[None]) ** 2).sum(2), 1)
    return reps, slot_rgb, lut
def score(idx, pal6, lines, slot_rgb, lut, rect=None):
    reg = idx[lines[0]:lines[1]]
    lin = pal6[reg].astype(int) * 255 // 63
    st = slot_rgb[lut[reg]]
    err = np.sqrt(((lin - st) ** 2).sum(2))
    r = err.mean()
    if rect:
        y1, y2, x1, x2 = rect
        r2 = err[y1 - lines[0]:y2 - lines[0], x1:x2].mean()
        return r, r2
    return r, None
if __name__ == '__main__':
    f, l0, l1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    rect = tuple(map(int, sys.argv[4:8])) if len(sys.argv) > 4 else None
    d = open(f, 'rb').read()
    idx = np.frombuffer(d[:64000], np.uint8).reshape(200, 320)
    pal6 = np.frombuffer(d[64000:64768], np.uint8).reshape(256, 3).astype(int)
    for sq in (False, True):
        reps, srgb, lut = fit(idx, pal6, (l0, l1), sq=sq)
        print('sqrt' if sq else 'lin ', 'reps', list(reps), 'err band %.1f rect %s' % score(idx, pal6, (l0, l1), srgb, lut, rect))

def render(f, bands_lines, out, sq=False):
    from PIL import Image
    d = open(f, 'rb').read()
    idx = np.frombuffer(d[:64000], np.uint8).reshape(200, 320)
    pal6 = np.frombuffer(d[64000:64768], np.uint8).reshape(256, 3).astype(int)
    lin = (pal6[idx] * 255 // 63).astype(np.uint8)
    st = lin.copy()
    for (l0, l1) in bands_lines:
        reps, srgb, lut = fit(idx, pal6, (l0, l1), sq=sq)
        st[l0:l1] = srgb[lut[idx[l0:l1]]]
    img = np.concatenate([lin, st], 1)
    Image.fromarray(img).resize((1280, 400), Image.NEAREST).save(out)
