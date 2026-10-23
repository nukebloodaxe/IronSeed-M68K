#!/usr/bin/env python3
"""check_p1.py LAYOUT.json STDIR : the 1994 probes session tests/st/p1.main (run by
tests/st/run_st.sh p1) - every category scanned (planet notes), one anomaly fetched by a probe:
the planet's cache lost exactly one item and the hold gained that item. Prints PASS/FAIL."""
import glob, json, struct, sys

L = json.load(open(sys.argv[1]))
ship = {f['name']: f['off_st'] for f in L['types']['data:shiptype']['fields']}
pt = L['types']['data:planettype']
pf = {f['name']: f['off_st'] for f in pt['fields']}


def blocks(fn):
    d = open(fn, 'rb').read(); p = 0; b = {}
    while p + 28 <= len(d):
        n = d[p+1:p+1+d[p]].decode('latin1'); p += 24
        sz = struct.unpack('>i', d[p:p+4])[0]; b[n] = d[p+4:p+4+sz]; p += 4 + sz
    return b


def state(fn):
    b = blocks(fn)
    s = b['ship']
    c = struct.unpack('>250h', s[ship['cargo']:ship['cargo']+500])
    n = struct.unpack('>250h', s[ship['numcargo']:ship['numcargo']+500])
    hold = {}
    for a, k in zip(c, n):
        if k: hold[a] = hold.get(a, 0) + k
    cp = struct.unpack('>h', b['curplan'])[0]
    o = (cp - 1) * pt['size_st']
    cache = [x for x in struct.unpack('>7h', b['tempplan'][o+pf['cache']:o+pf['cache']+14]) if x]
    return hold, cache


dumps = sorted(glob.glob(sys.argv[2] + '/D0*.BIN'))
st = [state(f) for f in dumps]
first = next((i for i, (h, c) in enumerate(st) if c), None)   # anomalies created
if first is None:
    print('FAIL probes94: no anomalies were created'); sys.exit(1)
h0, c0 = st[first]; h1, c1 = st[-1]
gone = sorted({x for x in c0 if c0.count(x) > c1.count(x)})
gained = {k: h1.get(k, 0) - h0.get(k, 0) for k in set(h0) | set(h1) if h1.get(k, 0) != h0.get(k, 0)}
if len(c1) == len(c0) - 1 and len(gone) == 1 and gained == {gone[0]: 1}:
    print('PASS probes94 (anomaly %d fetched by a probe: off the planet, into the hold)' % gone[0])
else:
    print('FAIL probes94: cache %s -> %s, hold change %s' % (c0, c1, gained)); sys.exit(1)
