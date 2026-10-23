#!/usr/bin/env python3
"""stscreen.py - helpers for STE low-res screens in tests: planar <-> slot images, ISP files,
and reference implementations of the kernel's drawing (printxy, bar, rectangle, line, pset)."""
import struct
import numpy as np


def planar_to_slots(b):
    a = np.frombuffer(b[:32000], '>u2').reshape(200, 20, 4)
    out = np.zeros((200, 320), np.uint8)
    for p in range(4):
        bits = (a[:, :, p][:, :, None] >> (15 - np.arange(16))) & 1
        out |= (bits.reshape(200, 320) << p).astype(np.uint8)
    return out


def read_isp(fn):
    d = open(fn, 'rb').read()
    assert d[:4] == b'ISP1'
    w, h = struct.unpack('>HH', d[4:8])
    n = struct.unpack('>H', d[8:10])[0]
    bands = []
    for i in range(4):
        line, *cols = struct.unpack_from('>H16H', d, 10 + i * 34)
        if i < n: bands.append((line, cols))
    luts = [np.frombuffer(d[146 + i * 256:146 + (i + 1) * 256], np.uint8) for i in range(4)]
    slots = planar_to_slots(d[146 + 1024:]) if (w, h) == (320, 200) else None
    return bands, luts, slots


class Model:
    """chunky-colour drawing onto a slot image, mapped per line like the kernel"""
    def __init__(self, isp):
        self.bands, self.luts, self.img = read_isp(isp)
        self.img = self.img.copy()
        self.line_band = np.zeros(200, int)
        for i, (line, _) in enumerate(self.bands): self.line_band[line:] = i

    def pset(self, x, y, c):
        self.img[y, x] = self.luts[self.line_band[y]][c & 255]

    def span(self, x1, y, x2, c):
        if x2 < x1: x1, x2 = x2, x1
        self.img[y, x1:x2 + 1] = self.luts[self.line_band[y]][c & 255]

    def bar(self, x1, y1, x2, y2, c):
        for y in range(min(y1, y2), max(y1, y2) + 1): self.span(x1, y, x2, c)

    def rect(self, x1, y1, x2, y2, c):
        self.span(x1, y2, x2, c); self.span(x1, y1, x2, c)
        for y in range(y1, y2 + 1): self.pset(x1, y, c); self.pset(x2, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, sx = abs(x1 - x0), (1 if x1 >= x0 else -1)
        dy, sy = -abs(y1 - y0), (1 if y1 >= y0 else -1)
        err = dx + dy
        while True:
            self.pset(x0, y0, c)
            if x0 == x1 and y0 == y1: break
            e2 = 2 * err
            if e2 >= dy: err += dy; x0 += sx
            if e2 <= dx: err += dx; y0 += sy

    def printxy(self, x1, y1, s, tcolor, bkcolor, font):
        """data.pas printxy, font = list of 82 (b0,b1,b2) for the selected font"""
        x1 += 4
        for ch in s:
            o = ord(ch)
            if 'a' <= ch <= 'z': letter = o - 40
            elif 'A' <= ch <= 'Z': letter = o - 36
            elif ' ' <= ch <= '"': letter = o - 31
            elif "'" <= ch <= '?': letter = o - 35
            elif ch == '%': letter = 55
            else: letter = 1
            g = font[letter - 1]
            t = tcolor
            for row in range(6):
                bits = (g[row // 2] >> (4 if row % 2 == 0 else 0)) & 15
                y = y1 + 1 + row
                for k in range(4):
                    x = x1 + 1 + k
                    if bits & (8 >> k): self.pset(x, y, t)
                    elif bkcolor < 255: self.pset(x, y, bkcolor)
                t -= 2
            x1 += 5
            if bkcolor < 255:
                for i in range(1, 7): self.pset(x1, y1 + i, bkcolor)


def load_font(font_i):
    nums = [int(x) for line in open(font_i) if line.strip().startswith('dc.b') for x in line.split()[1].split(',')]
    return [[tuple(nums[(f * 82 + g) * 3:(f * 82 + g) * 3 + 3]) for g in range(82)] for f in range(3)]
