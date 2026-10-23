#!/usr/bin/env python3
"""dumpship.py LAYOUT.json DUMP.bin [field ...] : print ship fields of an oracle/ST state dump
(default: hull, battery, shield, shieldlevel, accelmax, damages). Linux dumps are little-endian
with DOS offsets, ST dumps big-endian with ST offsets (taken from the block size)."""
import json, struct, sys
L = json.load(open(sys.argv[1]))
ship = L['types']['data:shiptype']
d = open(sys.argv[2], 'rb').read()
p = 0; blocks = {}
while p + 28 <= len(d):
    n = d[p+1:p+1+d[p]].decode('latin1'); p += 24
    sz = struct.unpack('<i', d[p:p+4])[0]
    be = sz < 0 or sz > len(d)
    if be: sz = struct.unpack('>i', d[p:p+4])[0]
    blocks[n] = (d[p+4:p+4+sz], be); p += 4 + sz
data, be = blocks['ship']
st = len(data) == ship['size_st'] and ship['size_st'] != ship['size_dos'] or be
want = sys.argv[3:] or ['hullintegrity', 'hullmax', 'battery', 'shield', 'shieldlevel', 'accelmax', 'damages']
fmt = {'s16': 'h', 'u16': 'H', 's32': 'i', 'u32': 'I', 'u8': 'B', 's8': 'b', 'bool': 'B'}
for f in ship['fields']:
    if f['name'] not in want: continue
    off = f['off_st' if st else 'off_dos']
    if f['kind'] == 'base':
        print(f['name'], struct.unpack(('>' if st else '<') + fmt.get(f['type'], 'h'), data[off:off+f['size_st' if st else 'size_dos']])[0])
    else:
        print(f['name'], list(data[off:off+f['size_dos']]))
