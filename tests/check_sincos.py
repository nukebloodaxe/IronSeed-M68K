#!/usr/bin/env python3
"""check_sincos.py [N] - kernel/fp.s's sin/cos (tests/ktfp.s in Hatari, ops 20/21 on extendeds)
against tools/sincos_model.py bit for bit (fast path) and against Free Pascal's x87 (tools/fp/fpref).
Arguments: the game's ranges (doubles in -2..60), near multiples of pi/2 (fallbacks), tiny and large
ones, full 64-bit mantissas; orders that use the kept pair (sin then cos, cos then sin, repeats)."""
import os, random, struct, subprocess, sys
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, os.path.join(R, 'tools'))
import sincos_model as M
N = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
rnd = random.Random(6)
def ext_from_double(x):
    b = struct.unpack('<Q', struct.pack('<d', x))[0]
    s = 0x8000 if b >> 63 else 0; e = (b >> 52) & 0x7ff; f = b & ((1 << 52) - 1)
    if e == 0: return 0, 0
    return s | (e - 1023 + 16383), ((1 << 52) | f) << 11
args = []
for _ in range(N):
    k = rnd.random()
    if k < 0.5: x = ext_from_double(rnd.uniform(-2, 60))
    elif k < 0.6: x = ext_from_double(rnd.uniform(-60, 60))
    elif k < 0.7:
        se, m = ext_from_double(rnd.uniform(-20, 20)); x = (se, m | rnd.getrandbits(11))
    elif k < 0.75: x = ext_from_double(rnd.choice([1, -1]) * rnd.uniform(1e-6, 1e-2))
    elif k < 0.8: x = ext_from_double(rnd.uniform(-1e5, 1e5))
    elif k < 0.9:                          # near k*pi/2: |r| tiny -> the series
        n = rnd.randint(-30, 30); x = ext_from_double(float(M.PM * n) / 2 ** 65 + rnd.choice([0, 1e-9, -1e-12, 3e-15]))
    else: x = ext_from_double(rnd.randint(-40, 40) / 4)
    args.append(x)
seq = []                                   # (op, arg)
for x in args:
    o = rnd.random()
    if o < 0.4: seq += [(20, x), (21, x)]
    elif o < 0.8: seq += [(21, x), (20, x)]
    else: seq += [(20, x), (20, x), (21, x)]
seq = seq[:11900]
le = b''.join(struct.pack('<4H', op, 0, 0, 0) + struct.pack('<QH', m, se) + bytes(2) + bytes(12) for op, (se, m) in seq)
be = b''.join(struct.pack('>4H', op, 0, 0, 0) + struct.pack('>HQ', se, m) + bytes(2) + bytes(12) for op, (se, m) in seq)
T = '/tmp/claude-0/sctest'; os.makedirs(T, exist_ok=True)
open(T + '/in.bin', 'wb').write(le)
subprocess.run([R + '/tools/fp/fpref', T + '/in.bin', T + '/ref.bin'], check=True)
C = R + '/hatari/c'
open(C + '/FPIN.BIN', 'wb').write(be)
if os.path.exists(C + '/FPOUT.BIN'): os.remove(C + '/FPOUT.BIN')
subprocess.run([R + '/tools/asm.sh', R + '/tests/ktfp.s', C + '/KTFP.PRG'], check=True, stdout=subprocess.DEVNULL)
subprocess.run([R + '/tools/run_hatari.sh', '9000', T + '/s.png', '--auto', 'C:\\KTFP.PRG'], stdout=subprocess.DEVNULL)
ref = open(T + '/ref.bin', 'rb').read(); got = open(C + '/FPOUT.BIN', 'rb').read()
fast = slow = mbad = 0
st = {'fast': [0, 0, 0, 0], 'series': [0, 0, 0, 0], 'series |x|>=2^14': [0, 0, 0, 0]}   # n, exact, <=64 ulp, double differs
def todbl(se, m):
    if m == 0: return 0.0
    mm = m >> 11; rem = m & 0x7ff
    if rem > 0x400 or (rem == 0x400 and mm & 1): mm += 1
    v = mm * 2.0 ** ((se & 0x7fff) - 16383 - 52)
    return -v if se >> 15 else v
bad = 0
for i, (op, (se, m)) in enumerate(seq):
    if len(got) < 16 * (i + 1): print('ST output short at', i); sys.exit(1)
    gse, gm = struct.unpack('>HQ', got[16 * i:16 * i + 10])
    rm, rse = struct.unpack('<QH', ref[16 * i:16 * i + 10])
    md = M.sincos(se, m)
    if md is not None:
        k = 'fast'
        if md[op - 20] != (gse, gm):
            mbad += 1
            if mbad <= 5: print('model differs: op %d x=(%04x,%016x) model=%r st=(%04x,%016x)' % (op, se, m, md[op - 20], gse, gm))
    else: k = 'series |x|>=2^14' if (se & 0x7fff) - 16383 >= 14 else 'series'
    s_ = st[k]; s_[0] += 1
    if (gse, gm) == (rse, rm): s_[1] += 1
    elif gse == rse and abs(gm - rm) <= 64: s_[2] += 1
    elif k != 'series |x|>=2^14':
        bad += 1
        if bad <= 5: print('x87 differs (%s): op %d x=(%04x,%016x) x87=(%04x,%016x) st=(%04x,%016x)' % (k, op, se, m, rse, rm, gse, gm))
    if todbl(gse, gm) != todbl(rse, rm): s_[3] += 1
for k, (n, e, u, d) in st.items():
    print('  %-17s %5d values: %5d bit-exact with the x87, %4d within 64 ulp, %4d beyond; %d differ as doubles' % (k, n, e, u, n - e - u, d))
print('sincos: %d values, %d differ from tools/sincos_model.py, %d beyond 64 ulp of the x87 below 2^14' % (len(seq), mbad, bad))
sys.exit(1 if mbad or bad else 0)
