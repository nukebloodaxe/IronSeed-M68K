#!/usr/bin/env python3
"""bandfit.py - choose raster bands (up to 4 x 16 STE colours) for a screen whose content changes:
the statistics come from per-line colour histograms summed over every composite the screen can
show (training images + extra weights), and some palette indices can be given slots of their own
("own groups": colour-cycled or flickering indices whose colours change at run time; a group of n
indices on k slots maps index j of the group to slot j*k//n, and each slot's rep index is the
group member in the middle of its share, so vid_set256 gives it a representative colour).

  fit(hist, pal, own=[(y0, y1, [indices], k), ...], nb=4, fixed=None) -> Design

hist: float array [200, 256], weighted pixel counts per line and palette index.
A band that has any line in [y0, y1) of an own group reserves k slots for it."""
import numpy as np
import cpr2st as c


class Design:
    def __init__(self, splits, table, luts, reps, err):
        self.splits, self.table, self.luts, self.reps, self.err = splits, table, luts, reps, err

    def line_band(self):
        lb = np.zeros(200, int)
        for b, s in enumerate(self.splits): lb[s:] = b
        return lb

    def slots(self, img):
        lb = self.line_band()
        return np.array([self.luts[lb[y]][img[y]] for y in range(200)], np.uint8)

    def isp_header(self, magic=b'ISP2', w=320, h=200):
        """'ISP2' w h, BANDS, 4 LUTs, 64 reps (the layout pic_load / pal_load read)"""
        b = bytearray(magic) + int(w).to_bytes(2, 'big') + int(h).to_bytes(2, 'big')
        b += len(self.table).to_bytes(2, 'big')
        for i in range(4):
            line, cols = self.table[i] if i < len(self.table) else (0, [0] * 16)
            b += line.to_bytes(2, 'big') + b''.join(int(x).to_bytes(2, 'big') for x in cols)
        for i in range(4):
            b += bytes(self.luts[i] if i < len(self.luts) else np.zeros(256, np.uint8))
        b += bytes(self.reps)
        return b

    def rgb(self, img, pal_now=None):
        """preview: slot colours; own slots take pal_now at their rep index (run-time colours)"""
        lb = self.line_band()
        out = np.zeros((200, 320, 3), np.uint8)
        for y in range(200):
            b = lb[y]
            cols = []
            for sl, w in enumerate(self.table[b][1]):
                v = [(((w >> sh) & 7) << 1 | ((w >> sh) & 15) >> 3) * 17 for sh in (8, 4, 0)]
                cols.append(v)
            cols = np.array(cols, np.uint8)
            if pal_now is not None:
                for sl in self.own_slots.get(b, []):
                    r = self.reps[b * 16 + sl]
                    cols[sl] = np.round(np.round(pal_now[r] * 15 / 63) * 17)
            out[y] = cols[self.luts[b][img[y]]]
        return out


def _band(hist_rows, pal, owns, want_err=True, iters=12):
    """one band: returns (err, cent(16,3) 0..15, lut(256), reps(16), own_slots)"""
    cnt = hist_rows.sum(0).astype(float)
    own_idx = set()
    nown = 0
    for _, _, idx, k in owns:
        own_idx |= set(idx); nown += k
    cnt2 = cnt.copy()
    for i in own_idx: cnt2[i] = 0
    idx = np.nonzero(cnt2)[0]
    free = 16 - nown
    if len(idx):
        cent = c.quantise(pal[idx], cnt2[idx], free, reserved=((0, 0, 0),), iters=iters)
    else:
        cent = np.zeros((free, 3), int)
    lut = c.band_lut(pal, cent)
    p = pal.astype(float) * 15 / 63
    err = (((p[idx] - cent[lut[idx]]) ** 2).sum(1) * cnt2[idx]).sum() if len(idx) else 0.0
    cent = np.vstack([cent, np.zeros((nown, 3), int)])
    reps = list(range(16))
    # reps of the free slots: the most used index mapping to the slot (else nearest)
    for sl in range(free):
        m = np.nonzero(lut[:256] == sl)[0]
        m = [i for i in m if i not in own_idx] or list(m)
        if not m: reps[sl] = 0; continue
        reps[sl] = int(max(m, key=lambda i: (cnt2[i], -((p[i] - cent[sl]) ** 2).sum())))
    own_slots = []
    s0 = free
    for _, _, gidx, k in owns:
        n = len(gidx)
        for j, i in enumerate(gidx):
            lut[i] = s0 + j * k // n
        for s in range(k):
            members = [gidx[j] for j in range(n) if j * k // n == s]
            reps[s0 + s] = members[len(members) // 2]
            cent[s0 + s] = np.clip(np.round(pal[reps[s0 + s]] * 15 / 63), 0, 15)
            own_slots.append(s0 + s)
        s0 += k
    return err, cent, lut.astype(np.uint8), reps, own_slots


def _owns_for(owns, a, b):
    return [o for o in owns if o[0] < b and o[1] > a]


def fit(hist, pal, own=(), nb=4, splits=None, step=2, lo=0, hi=200):
    own = list(own)
    if splits is None:
        cache = {}
        def e(a, b):
            if (a, b) not in cache:
                cache[(a, b)] = _band(hist[a:b], pal, _owns_for(own, a, b), iters=4)[0]
            return cache[(a, b)]
        splits = [0]
        while len(splits) < nb:
            bounds = splits + [200]
            best = None
            for bi in range(len(splits)):
                a, b = bounds[bi], bounds[bi + 1]
                for s in range(max(a + 2, lo), min(b - 1, hi), step):
                    gain = e(a, b) - e(a, s) - e(s, b)
                    if best is None or gain > best[0]: best = (gain, s)
            if best is None or best[0] <= 0: break
            splits = sorted(splits + [best[1]])
    bounds = list(splits) + [200]
    table, luts, reps, total = [], [], [], 0.0
    own_slots = {}
    for b in range(len(splits)):
        y0, y1 = bounds[b], bounds[b + 1]
        err, cent, lut, rp, os_ = _band(hist[y0:y1], pal, _owns_for(own, y0, y1))
        total += err
        table.append((y0, [c.to_ste_word(x) for x in cent]))
        luts.append(lut); reps += rp; own_slots[b] = os_
    reps += [0] * (64 - len(reps))
    d = Design(list(splits), table, luts, reps, total)
    d.own_slots = own_slots
    return d


def hist_of(imgs, weights=None):
    h = np.zeros((200, 256))
    for k, im in enumerate(imgs):
        w = 1.0 if weights is None else weights[k]
        for y in range(200):
            h[y] += np.bincount(im[y], minlength=256) * w
    return h
