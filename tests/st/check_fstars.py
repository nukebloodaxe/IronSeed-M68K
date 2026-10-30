#!/usr/bin/env python3
"""check_fstars.py CDIR : after tests/st/fstars.main on a LANDDUMP build - the star's landform
(the first LANDn.BIN whose cells are all within the star's 6 steps) against tools/faststar.c's model for the star the dumps show
(tempplan[curplan] at orbit 0), and the same star again from the cache (the last LANDn.BIN)."""
import glob, os, struct, subprocess, sys, tempfile
C = sys.argv[1]
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
exe = os.path.join(tempfile.gettempdir(), 'faststar')
subprocess.check_call(['gcc', '-O2', '-o', exe, os.path.join(R, 'tools/faststar.c')])
stars = set()
for f in sorted(glob.glob(os.path.join(C, 'D0*.BIN'))):
    d = open(f, 'rb').read(); p = 0; b = {}
    while p + 28 <= len(d):
        n = d[p+1:p+1+d[p]].decode('latin1'); p += 24
        sz = struct.unpack('>i', d[p:p+4])[0]; b[n] = d[p+4:p+4+sz]; p += 4 + sz
    cp = struct.unpack('>h', b['curplan'])[0]
    r = b['tempplan'][(cp - 1) * 34:(cp - 1) * 34 + 34]
    if cp > 0 and r[1] == 0:
        stars.add((struct.unpack('>H', r[14:16])[0], r[5]))
if len(stars) != 1:
    print('FAIL fstars (stars in the dumps: %s)' % sorted(stars)); sys.exit(1)
seed, mode = stars.pop()
out = os.path.join(tempfile.gettempdir(), 'fstar_land.bin')
subprocess.check_call([exe, 'land', str(seed), str(mode), out])
ref = open(out, 'rb').read()
lo = min(ref)
lands = [f for f in sorted(glob.glob(os.path.join(C, 'LAND?.BIN')))
         if min(open(f, 'rb').read()[128:128 + 28800]) >= lo and max(open(f, 'rb').read()[128:128 + 28800]) <= lo + 6]
if len(lands) < 2:
    print('FAIL fstars (fewer than two star landforms among the LANDn.BIN)'); sys.exit(1)
bad = []
for f in (lands[0], lands[-1]):
    got = open(f, 'rb').read()[128:128 + 28800]
    n = sum(1 for a, c in zip(got, ref) if a != c)
    if n: bad.append('%s: %d bytes differ' % (os.path.basename(f), n))
print(('FAIL' if bad else 'PASS') + ' fstars (star seed %d mode %d, %s and %s vs tools/faststar.c%s)'
      % (seed, mode, os.path.basename(lands[0]), os.path.basename(lands[-1]), (': ' + '; '.join(bad)) if bad else ''))
sys.exit(1 if bad else 0)
