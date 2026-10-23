#!/usr/bin/env python3
"""convdump.py DATA_DIR NNNN - the keywords of conversation CONVNNNN (DOS files) with their
event, run event, response code and the length of the answer (lines of 56 glyphs) - to pick
subjects for test sessions."""
import struct, sys
G = {}
for o in range(32, 35): G[o - 31] = chr(o)
for o in range(39, 64): G[o - 35] = chr(o)
for o in range(65, 91): G[o - 36] = chr(o)
for o in range(97, 123): G[o - 40] = chr(o)
dec = lambda b: ''.join(G.get(x, '#%d' % x) for x in b)
d, n = sys.argv[1], sys.argv[2]
ind = open('%s/conv%s.ind' % (d, n), 'rb').read()
dta = open('%s/conv%s.dta' % (d, n), 'rb').read()
R = {}
for k in range(0, len(dta), 258):
    ix = struct.unpack('<h', dta[k:k + 2])[0]
    R.setdefault(ix, []).append(dta[k + 3:k + 3 + dta[k + 2]])
for k in range(0, len(ind), 84):
    ev, re_, rc, ix = struct.unpack('<4h', ind[k:k + 8])
    kw = ind[k + 9:k + 9 + ind[k + 8]]
    rs = R.get(ix, [])
    ln = sum(len(r) for r in rs)
    print('%5d %5d rc%d ix%3d n%d len%4d  %s' % (ev, re_, rc, ix, len(rs), ln, dec(kw).replace(' ', '|')))
