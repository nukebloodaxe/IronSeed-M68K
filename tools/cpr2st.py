#!/usr/bin/env python3
"""cpr2st.py - Iron Seed .cpr pictures -> STE planar pictures with 64 colours.

  cpr2st.py [options] IN.cpr OUT.ISP [--png preview.png]
  cpr2st.py --batch SRC_DIR OUT_DIR [--pngdir DIR] [--pal main.pal]

.cpr (data.pas uncompressfile): header {word 'RM'=19794, byte version 4, word width,
word height, byte flags, byte headersize} little-endian packed; if flags&1, a 768-byte
VGA palette (6-bit) follows the header; then RLE pixels: 255,count,value or a literal.

Output .ISP (all big-endian):
  'ISP1'  w.w  h.w                          (w multiple of 16 after padding)
  BANDS table for vid_set_bands: count.w, then 4 x (first_line.w, 16 x STE colour.w)
  4 x 256-byte LUTs: original palette index -> 4-bit slot, one per band
  planar data: h lines x (w/16) groups x 4 plane words
Each band is quantised separately (k-means in RGB, snapped to the STE 4-bit grid).
Split lines are chosen automatically unless --splits is given.
"""
import argparse, math, os, struct, sys
import numpy as np

SIG = 19794


def read_cpr(fn, default_pal=None):
    d = open(fn, 'rb').read()
    sig, ver, w, h, flags, hs = struct.unpack_from('<HBHHBB', d, 0)
    if sig != SIG or ver != 4:
        raise ValueError('%s: not a version-4 .cpr' % fn)
    pos = hs
    pal = None
    if flags & 1:
        pal = np.frombuffer(d[hs:hs + 768], np.uint8).reshape(256, 3).astype(np.int32)
        pos = hs + 768
    n = w * h
    out = np.zeros(n, np.uint8)
    j = 0
    while j < n and pos < len(d):
        b = d[pos]
        if b == 255:
            cnt, val = d[pos + 1], d[pos + 2]
            cnt = min(cnt, n - j)
            out[j:j + cnt] = val; j += cnt; pos += 3
        else:
            out[j] = b; j += 1; pos += 1
    if pal is None:
        pal = default_pal
    return w, h, out.reshape(h, w), pal, bool(flags & 1)


def ste_nib(v4):  # 0..15 -> STE nibble
    return ((v4 & 1) << 3) | (v4 >> 1)


def to_ste_word(c4):
    r, g, b = (int(x) for x in c4)
    return (ste_nib(r) << 8) | (ste_nib(g) << 4) | ste_nib(b)


def quantise(cols, weights, k=16, reserved=(), iters=12):
    """cols: (n,3) 6-bit RGB of distinct palette entries, weights: pixel counts.
    Returns (k,3) colours on the 4-bit grid (0..15). reserved: list of 4-bit colours kept fixed first."""
    cols = cols.astype(np.float64) * 15.0 / 63.0  # work on the 0..15 scale
    res = [np.array(r, float) for r in reserved]
    free = k - len(res)
    uniq = np.unique(np.round(cols), axis=0)
    if len(uniq) + len(res) <= k:
        cent = np.vstack(res + [uniq]) if res else uniq
    else:
        # median cut init on the free slots
        boxes = [np.arange(len(cols))]
        while len(boxes) < free:
            best = max(range(len(boxes)), key=lambda i: (weights[boxes[i]].sum() * np.ptp(cols[boxes[i]], axis=0).max()) if len(boxes[i]) > 1 else -1)
            idx = boxes[best]
            if len(idx) < 2: break
            ch = np.argmax(np.ptp(cols[idx], axis=0))
            order = idx[np.argsort(cols[idx, ch])]
            cw = np.cumsum(weights[order]); cut = np.searchsorted(cw, cw[-1] / 2) + 1
            cut = min(max(cut, 1), len(order) - 1)
            boxes[best:best + 1] = [order[:cut], order[cut:]]
        cent = np.array([np.average(cols[b], axis=0, weights=weights[b] + 1e-9) for b in boxes])
        for _ in range(iters):
            allc = np.vstack(res + [cent]) if res else cent
            dist = ((cols[:, None, :] - allc[None, :, :]) ** 2).sum(2)
            lab = dist.argmin(1)
            for i in range(len(cent)):
                m = lab == i + len(res)
                if m.any(): cent[i] = np.average(cols[m], axis=0, weights=weights[m] + 1e-9)
        cent = np.vstack(res + [cent]) if res else cent
    cent = np.clip(np.round(cent), 0, 15).astype(int)
    # dedupe, pad to k
    out = []
    for c in cent:
        if not any((c == o).all() for o in out): out.append(c)
    while len(out) < k: out.append(np.array([0, 0, 0]))
    return np.array(out[:k])


def band_lut(pal6, cent4):
    p = pal6.astype(float) * 15.0 / 63.0
    d = ((p[:, None, :] - cent4[None, :, :].astype(float)) ** 2).sum(2)
    return d.argmin(1).astype(np.uint8)


def band_error(img, pal6, lines, k=16):
    sub = img[lines[0]:lines[1]].ravel()
    cnt = np.bincount(sub, minlength=256).astype(float)
    idx = np.nonzero(cnt)[0]
    cent = quantise(pal6[idx], cnt[idx], k, iters=4)
    lut = band_lut(pal6, cent)
    p = pal6.astype(float) * 15.0 / 63.0
    err = ((p[idx] - cent[lut[idx]]) ** 2).sum(1)
    return (err * cnt[idx]).sum(), cent, lut


def choose_splits(img, pal6, nb=4, step=8):
    """greedy: repeatedly split the band whose best split reduces error most"""
    h = img.shape[0]
    bands = [(0, h)]
    errs = {(0, h): band_error(img, pal6, (0, h))[0]}
    while len(bands) < nb:
        best = None
        for bi, (a, b) in enumerate(bands):
            for s in range(a + step, b - step + 1, step):
                e1 = errs.setdefault((a, s), band_error(img, pal6, (a, s))[0])
                e2 = errs.setdefault((s, b), band_error(img, pal6, (s, b))[0])
                gain = errs[(a, b)] - e1 - e2
                if best is None or gain > best[0]: best = (gain, bi, s)
        if best is None: break
        _, bi, s = best
        a, b = bands[bi]
        bands[bi:bi + 1] = [(a, s), (s, b)]
    return [a for a, _ in bands]


def convert(img, pal6, splits, reserved=((0, 0, 0),)):
    """reserved: 4-bit colours placed first in every band. Slot 0 = black by default,
    because colour 0 is also the border colour beside and below the picture."""
    h, w = img.shape
    bounds = splits + [h]
    table, luts, slot_img = [], [], np.zeros_like(img)
    total_err = 0.0
    for i in range(len(splits)):
        a, b = bounds[i], bounds[i + 1]
        sub = img[a:b].ravel()
        cnt = np.bincount(sub, minlength=256).astype(float)
        idx = np.nonzero(cnt)[0]
        cent = quantise(pal6[idx], cnt[idx], 16, reserved=reserved)
        lut = band_lut(pal6, cent)
        slot_img[a:b] = lut[img[a:b]]
        table.append((a, [to_ste_word(c) for c in cent]))
        luts.append(lut)
        p = pal6.astype(float) * 15.0 / 63.0
        total_err += (((p[idx] - cent[lut[idx]]) ** 2).sum(1) * cnt[idx]).sum()
    return table, luts, slot_img, total_err / img.size


def planar(slot_img):
    h, w = slot_img.shape
    W = (w + 15) // 16 * 16
    s = np.zeros((h, W), np.uint8); s[:, :w] = slot_img
    g = s.reshape(h, W // 16, 16)
    out = np.zeros((h, W // 16, 4), np.uint16)
    for p in range(4):
        bits = ((g >> p) & 1).astype(np.uint16)
        out[:, :, p] = (bits * (1 << (15 - np.arange(16)))).sum(2)
    return W, out.astype('>u2').tobytes()


def write_isp(fn, W, h, table, luts, pdata):
    b = bytearray(b'ISP1') + struct.pack('>HH', W, h)
    b += struct.pack('>H', len(table))
    for i in range(4):
        line, cols = table[i] if i < len(table) else (0, [0] * 16)
        b += struct.pack('>H16H', line, *cols)
    for i in range(4):
        b += bytes(luts[i] if i < len(luts) else np.zeros(256, np.uint8))
    b += pdata
    open(fn, 'wb').write(b)


def preview(fn, slot_img, table, h):
    from PIL import Image
    rgb = np.zeros(slot_img.shape + (3,), np.uint8)
    bounds = [t[0] for t in table] + [h]
    for i, (line, cols) in enumerate(table):
        dec = []
        for c in cols:
            v = []
            for sh in (8, 4, 0):
                n = (c >> sh) & 15; v.append((((n & 7) << 1) | (n >> 3)) * 17)
            dec.append(v)
        dec = np.array(dec, np.uint8)
        rgb[bounds[i]:bounds[i + 1]] = dec[slot_img[bounds[i]:bounds[i + 1]]]
    Image.fromarray(rgb).save(fn)


def original_png(fn, img, pal6):
    from PIL import Image
    p = (pal6 * 255 // 63).astype(np.uint8)
    Image.fromarray(p[img]).save(fn)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('inp'); ap.add_argument('out')
    ap.add_argument('--png'); ap.add_argument('--orig')
    ap.add_argument('--splits', help='comma list of band start lines, e.g. 0,50,100,150')
    ap.add_argument('--bands', type=int, default=4)
    ap.add_argument('--pal', help='default palette for .cpr files without one (main.pal)')
    ap.add_argument('--batch', action='store_true', help='inp/out are directories')
    ap.add_argument('--pngdir')
    a = ap.parse_args()
    defpal = np.frombuffer(open(a.pal, 'rb').read()[:768], np.uint8).reshape(256, 3).astype(np.int32) if a.pal else None
    jobs = []
    if a.batch:
        os.makedirs(a.out, exist_ok=True)
        if a.pngdir: os.makedirs(a.pngdir, exist_ok=True)
        for f in sorted(os.listdir(a.inp)):
            if f.lower().endswith('.cpr'):
                base = os.path.splitext(f)[0].upper()[:8]
                jobs.append((os.path.join(a.inp, f), os.path.join(a.out, base + '.ISP'),
                             os.path.join(a.pngdir, base + '.png') if a.pngdir else None, None))
    else:
        jobs.append((a.inp, a.out, a.png, a.orig))
    for inp, out, png, orig in jobs:
        try:
            w, h, img, pal6, haspal = read_cpr(inp, defpal)
        except ValueError as e:
            print('skip', e); continue
        if pal6 is None:
            print('skip %s: no palette (pass --pal)' % inp); continue
        if a.splits: splits = [int(x) for x in a.splits.split(',')]
        elif h >= 16 * a.bands: splits = choose_splits(img, pal6, a.bands)
        else: splits = [0]
        table, luts, slot_img, err = convert(img, pal6, splits)
        W, pdata = planar(slot_img)
        write_isp(out, W, h, table, luts, pdata)
        ncol = len(np.unique(img))
        print('%-12s %3dx%3d %3d colours%s  bands at %-16s mean sq err %.3f  -> %s (%d bytes)' % (
            os.path.basename(inp), w, h, ncol, '' if haspal else ' (default pal)',
            ','.join(map(str, splits)), err, os.path.basename(out), os.path.getsize(out)))
        if png:
            preview(png, slot_img, table, h)
        if orig:
            original_png(orig, img, pal6)


if __name__ == '__main__':
    main()
