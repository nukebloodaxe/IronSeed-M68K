#!/usr/bin/env python3
"""check_here.py LAYOUT.json STDIR : tests/st/here.main (run by tests/st/run_st.sh here) - a
travel to the orbit the ship is in changes nothing (curplan, orbiting, the planet's visits, the
stardate's day), a travel elsewhere does. Prints PASS/FAIL."""
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
    cp = struct.unpack('>h', b['curplan'])[0]
    orb = struct.unpack('>h', s[ship['orbiting']:ship['orbiting']+2])[0]
    sd = struct.unpack('>3h', s[ship['stardate']:ship['stardate']+6])
    o = (cp - 1) * (len(b['tempplan']) // 1000)
    t = b['tempplan']
    vis = struct.unpack('>h', t[o+pf['visits']:o+pf['visits']+2])[0] if cp > 0 else None
    return dict(curplan=cp, orbiting=orb, stardate=sd, visits=vis)


d = sorted(glob.glob(sys.argv[2] + '/D0*.BIN'))
st = [state(f) for f in d if state(f)['curplan'] > 0]
for h in st:
    print(h)
home, star = st[0], st[-1]
ok = len(st) >= 4 and star['orbiting'] == 0 and star['curplan'] != home['curplan']
# every dump in orbit of home (before and after Alt-4) and every dump at the star (before and
# after the second Alt-0) shows the same state: no travel time, no visit counted
for h in st:
    ref = home if h['curplan'] == home['curplan'] else star
    if h != ref:
        print('FAIL: travelled again', h); ok = False
if [h['curplan'] for h in st].count(home['curplan']) < 2 or [h['curplan'] for h in st].count(star['curplan']) < 2:
    ok = False
print('PASS here' if ok else 'FAIL here')
sys.exit(0 if ok else 1)
