#!/usr/bin/env python3
"""screen_cmp.py LINUX_DUMP ST_DUMP [x1 y1 x2 y2] : the 'screen' blocks of two state dumps
(Linux screen[] and MAIN.PRG's chunky shadow) index by index: the differing rows with their x
range and the first values on both sides."""
import struct, sys
import numpy as np


def blocks(fn):
    d = open(fn, 'rb').read(); p = 0; out = {}
    while p + 28 <= len(d):
        n = d[p + 1:p + 1 + d[p]].decode('latin1')
        raw = d[p + 24:p + 28]
        sz = struct.unpack('<I', raw)[0]
        if sz > len(d) - p - 28:
            sz = struct.unpack('>I', raw)[0]
        out[n] = d[p + 28:p + 28 + sz]; p += 28 + sz
    return out


a = np.frombuffer(blocks(sys.argv[1])['screen'], np.uint8).reshape(200, 320)
b = np.frombuffer(blocks(sys.argv[2])['screen'], np.uint8).reshape(200, 320)
x1, y1, x2, y2 = map(int, sys.argv[3:7]) if len(sys.argv) > 3 else (0, 0, 319, 199)
n = 0
for y in range(y1, y2 + 1):
    xs = np.nonzero(a[y, x1:x2 + 1] != b[y, x1:x2 + 1])[0] + x1
    if len(xs):
        n += len(xs)
        print('row %d: x %d-%d (%d px) linux %s st %s' % (y, xs[0], xs[-1], len(xs), list(map(int, a[y, xs[:8]])), list(map(int, b[y, xs[:8]]))))
print('%d pixels differ' % n)
