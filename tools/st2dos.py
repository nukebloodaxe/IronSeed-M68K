#!/usr/bin/env python3
"""st2dos.py build/layout.json IN_DIR OUT_DIR - a saved game written by the ST port (68000
layout) back to the DOS/Linux layout, so the Linux build can load it and files can be compared
byte for byte. Handles SAVEGAME.DIR and a SAVEn folder's files."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from convdata import convert_file

TYPES = {'SHIP.DTA': 'data:shiptype', 'SYSTEMS.DTA': 'data:systemarray', 'EVENTS.DTA': 'data:eventarray',
         'LOGS.DTA': 'data:logarray', 'PENDING.DTA': 'data:logpendingarray', 'PLANETS.DTA': 'data:planarray',
         'CONTACTS.DTA': 'data:alientype', 'SAVEGAME.DIR': 'saveload:namearray'}
T = json.load(open(sys.argv[1]))['types']
src, dst = sys.argv[2:4]
os.makedirs(dst, exist_ok=True)
for fn in sorted(os.listdir(src)):
    t = TYPES.get(fn.upper())
    if not t: continue
    out, n = convert_file(T[t], open(os.path.join(src, fn), 'rb').read(), rev=True)
    open(os.path.join(dst, fn.upper()), 'wb').write(out)
    print('%-13s %3d record(s) -> %6d bytes' % (fn, n, len(out)))
