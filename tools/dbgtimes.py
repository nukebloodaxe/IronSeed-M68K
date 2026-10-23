#!/usr/bin/env python3
"""dbgtimes.py DBG.BIN : the PMARK entries of a DBG.BIN ring (game/pmac.i, PROFILE builds) as
tag, time in ms, and the time since the previous entry with the tag before it (pairs like 1/2)."""
import struct, sys
d = open(sys.argv[1], 'rb').read()
n = struct.unpack('>I', d[:4])[0]
N = (len(d) - 4) // 4
ring = struct.unpack('>%dI' % N, d[4:4 + 4 * N])
idx = range(max(0, n - N), n)
last = {}
for i in idx:
    v = ring[i % N]; tag, t = v >> 24, v & 0xffffff
    extra = f"  {t - last[tag - 1]} ms after tag {tag - 1}" if tag - 1 in last else ""
    print(f"tag {tag:3} at {t:8} ms{extra}")
    last[tag] = t
