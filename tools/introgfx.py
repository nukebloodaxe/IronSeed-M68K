#!/usr/bin/env python3
"""introgfx.py - intro.pas drawing on chunky 200x320 index arrays (numpy), for the scene
tools: printxy (intro font), bigprintxy, circle (c_utils.c), scale_img (c_utils.c), and a
band converter with extra colour statistics."""
import math, os, re
import numpy as np
import cpr2st as c

_src = None


def _intro_src(data):
    global _src
    if _src is None:
        _src = open(os.path.join(os.path.dirname(data.rstrip('/')), 'intro.pas'), encoding='latin-1').read()
    return _src


def _letter(ch):
    o = ord(ch)
    if 'a' <= ch <= 'z': return o - 40
    if 'A' <= ch <= 'Z': return o - 36
    if ' ' <= ch <= '"': return o - 31
    if "'" <= ch <= '?': return o - 35
    if ch == '%': return 55
    return 1


def printxy(img, data, x1, y1, s, tcolor, bkcolor=255):
    m = re.search(r'font:\s*array\[1\.\.84\] of fonttype\s*=\s*\((.*?)\);', _intro_src(data), re.S)
    f = [int(v) for v in re.findall(r'\d+', m.group(1))]
    x1 += 4
    for ch in s:
        L = _letter(ch)
        g = f[(L - 1) * 3:(L - 1) * 3 + 3]
        t = tcolor
        for row in range(6):
            bits = (g[row // 2] >> (4 if row % 2 == 0 else 0)) & 15
            for k in range(4):
                if bits & (8 >> k): img[y1 + 1 + row, x1 + 1 + k] = t
                elif bkcolor < 255: img[y1 + 1 + row, x1 + 1 + k] = bkcolor
            t -= 2
        x1 += 5


def bigprintxy(img, data, x1, y1, s, tcolor):
    m = re.search(r'bigfont:\s*array\[1\.\.82\] of bigfonttype\s*=\s*\((.*?)\);', _intro_src(data), re.S)
    bf = [int(v) for v in re.findall(r'\d+', m.group(1))]
    for ch in s:
        L = _letter(ch)
        g = bf[(L - 1) * 8:(L - 1) * 8 + 8]
        t = tcolor
        for r in range(8):
            for b in range(8):
                if g[r] & (128 >> b): img[y1 + 1 + r, x1 + 1 + b] = t
            t -= 1
        x1 += 8


def circle_points(r):
    """c_utils.c circle(): the (dx, dy) offsets it draws, in order (E = 0.9, truncation)"""
    E = 0.9
    pts = []
    def put(xx, yy):
        for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            pts.append((sx * xx, math.floor(sy * yy * E)))  # (int16_t)(y +/- yy*E) of a positive value
    xx, yy = 0, r
    put(xx, yy)
    while yy >= 1:
        yy -= 1
        if xx * xx + yy * yy < r * r: xx += 1
        if xx * xx + yy * yy < r * r: yy += 1
        put(xx, yy)
    return pts


def circle(img, x, y, r, col):
    for dx, dy in circle_points(r):
        img[y + dy, x + dx] = col


def scale_img(x0s, y0s, ws, hs, x0d, y0d, wd, hd, s, d):
    kx = ws / wd
    ky = hs / hd
    for yd in range(hd):
        sy = y0s + int(yd * ky)
        xs = (x0s + (np.arange(wd) * kx).astype(int))
        d[y0d + yd, x0d:x0d + wd] = s[sy, xs]


def bands(stack, pal, extra=None, nb=4, reserved=((0, 0, 0),), splits=None):
    """bands for a scene: splits chosen on stack[0], each band quantised on the histogram of
    all images in stack (+ extra[y][index] weights). Returns table, luts, line_band."""
    if splits is None: splits = c.choose_splits(stack[0], pal, nb)
    bounds = splits + [200]
    table, luts = [], []
    for b in range(len(splits)):
        y0, y1 = bounds[b], bounds[b + 1]
        cnt = np.bincount(stack[:, y0:y1].ravel(), minlength=256).astype(float)
        if extra is not None: cnt += extra[y0:y1].sum(0)
        idx = np.nonzero(cnt)[0]
        cent = c.quantise(pal[idx], cnt[idx], 16, reserved=reserved)
        luts.append(c.band_lut(pal, cent))
        table.append((y0, [c.to_ste_word(x) for x in cent]))
    line_band = np.zeros(200, int)
    for b, (y0, _) in enumerate(table): line_band[y0:] = b
    return table, luts, line_band


def slots(img, luts, line_band):
    return np.array([luts[line_band[y]][img[y]] for y in range(200)], np.uint8)
