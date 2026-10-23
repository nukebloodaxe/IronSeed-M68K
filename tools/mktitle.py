#!/usr/bin/env python3
"""mktitle.py DATA_DIR OUT.DAT [--png preview.png] - assets for the title screen (intro.pas mainloop).

The original scrolls cloud.cpr as one 64000-byte ring (s3[a] = cloud[a-k]) and draws every
non-zero pixel of intro5.cpr in the linear range [7210, 7210+51453) over it, every frame.

STE version: the cloud's 12 colours are reduced to 4 shades in slots 1-4, the same in every
band, so a scrolling star keeps its colour across splits; slot 0 is black. The logo gets
slots 5-15 of each of 4 bands. Per 16-pixel group the logo is full (never redrawn),
empty (copy cloud) or partial (merge with a mask).

TITLE.DAT, big-endian:
  'TTL1'
  bands: count.w, 4 x (first line.w, 16 STE colours.w)        138 bytes
  4 x 256 LUT bytes (intro5 palette index -> slot, per band)  for the menu box colour etc.
  cloud planar, 32000 bytes (slots 1-4 / 0)
  logo planar, 32000 bytes (logo slots where the logo is drawn, else 0)
  nruns.w, runs of empty groups: (byte offset.w, groups.w)
  nparts.w, partial groups: (byte offset.w, keep mask.l (= ~logo mask, both words), plane01.l, plane23.l)
"""
import argparse, os, struct, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c

LOGO_FROM, LOGO_LEN = 7210, 51453


def kmeans1(vals, weights, k):
    """weighted 1-D k-means on brightness -> cluster label per value"""
    cent = np.quantile(np.repeat(vals, np.maximum(1, (weights / weights.min()).astype(int))), np.linspace(0.1, 0.9, k))
    for _ in range(30):
        lab = np.abs(vals[:, None] - cent[None, :]).argmin(1)
        for i in range(k):
            if (lab == i).any(): cent[i] = np.average(vals[lab == i], weights=weights[lab == i])
    return lab


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('data'); ap.add_argument('out'); ap.add_argument('--png')
    a = ap.parse_args()
    _, _, logo, pal, _ = c.read_cpr(os.path.join(a.data, 'intro5.cpr'))
    _, _, cloud, _, _ = c.read_cpr(os.path.join(a.data, 'cloud.cpr'), pal)
    p4 = pal.astype(float) * 15 / 63
    # --- cloud: 4 shades (slots 1-4)
    cidx, ccnt = np.unique(cloud[cloud > 0], return_counts=True)
    bright = p4[cidx].mean(1)
    lab = kmeans1(bright, ccnt.astype(float), 4)
    order = np.argsort([bright[lab == i].mean() if (lab == i).any() else 99 for i in range(4)])
    rank = {old: new for new, old in enumerate(order)}
    shades = []
    for new in range(4):
        old = order[new]; m = lab == old
        shades.append(np.clip(np.round(np.average(p4[cidx[m]], axis=0, weights=ccnt[m])), 0, 15).astype(int) if m.any() else np.array([0, 0, 0]))
    cloud_lut = np.zeros(256, np.uint8)
    for i, ci in enumerate(cidx): cloud_lut[ci] = 1 + rank[lab[i]]
    cslots = cloud_lut[cloud]
    # --- logo mask
    lin = np.zeros(64000, bool); lin[LOGO_FROM:LOGO_FROM + LOGO_LEN] = True
    mask = ((logo.ravel() != 0) & lin).reshape(200, 320)
    reserved = [np.array([0, 0, 0])] + shades
    # bands: split by logo colours only (reuse cpr2st's greedy search on the masked logo)
    li = logo.copy(); li[~mask] = 0
    splits = c.choose_splits(li, pal, 4)
    bounds = splits + [200]
    table, luts = [], []
    lslots = np.zeros((200, 320), np.uint8)
    for b in range(len(splits)):
        y0, y1 = bounds[b], bounds[b + 1]
        sub = logo[y0:y1][mask[y0:y1]]
        cnt = np.bincount(sub, minlength=256).astype(float) if sub.size else np.zeros(256)
        idx = np.nonzero(cnt)[0]
        cent = c.quantise(pal[idx], cnt[idx], 16, reserved=reserved) if len(idx) else np.array(reserved + [np.zeros(3, int)] * 11)
        lut = c.band_lut(pal, cent)
        lslots[y0:y1] = np.where(mask[y0:y1], lut[logo[y0:y1]], 0)
        table.append((y0, [c.to_ste_word(x) for x in cent]))
        luts.append(lut)
    # --- planar data and group classification
    _, cloud_pl = c.planar(cslots)
    _, logo_pl = c.planar(lslots)
    mw = mask.reshape(200, 20, 16)
    bits = (mw * (1 << (15 - np.arange(16)))).sum(2).astype(np.uint16).ravel()  # mask word per group (linear)
    lp = np.frombuffer(logo_pl, '>u2').reshape(4000, 4)
    runs, parts = [], []
    g = 0
    while g < 4000:
        if bits[g] == 0:
            s = g
            while g < 4000 and bits[g] == 0: g += 1
            runs.append((s * 8, g - s))
        else:
            if bits[g] != 0xFFFF:
                keep = (~int(bits[g])) & 0xFFFF
                parts.append((g * 8, (keep << 16) | keep, (int(lp[g, 0]) << 16) | int(lp[g, 1]), (int(lp[g, 2]) << 16) | int(lp[g, 3])))
            g += 1
    out = bytearray(b'TTL1') + struct.pack('>H', len(table))
    for i in range(4):
        line, cols = table[i] if i < len(table) else (0, [0] * 16)
        out += struct.pack('>H16H', line, *cols)
    for i in range(4): out += bytes(luts[i] if i < len(luts) else luts[-1])
    out += cloud_pl + logo_pl
    out += struct.pack('>H', len(runs)) + b''.join(struct.pack('>HH', o, n) for o, n in runs)
    out += struct.pack('>H', len(parts)) + b''.join(struct.pack('>HIII', *p) for p in parts)
    open(a.out, 'wb').write(out)
    full = int((bits == 0xFFFF).sum())
    print('TITLE: bands at %s, cloud shades %s, %d empty runs (%d groups), %d partial, %d full groups, %d bytes' % (
        splits, [tuple(x) for x in shades], len(runs), sum(n for _, n in runs), len(parts), full, len(out)))
    if a.png:  # preview of frame k=0
        from PIL import Image
        slots = np.where(mask, lslots, cslots)
        c.preview(a.png, slots, table, 200)


if __name__ == '__main__':
    main()
