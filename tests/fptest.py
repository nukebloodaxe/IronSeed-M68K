#!/usr/bin/env python3
"""fptest.py [N] - kernel/fp.s (tests/ktfp.s in Hatari) against Free Pascal (tools/fp/fpref).
Makes random and edge cases for every operation, runs both, compares bit for bit."""
import os, random, struct, subprocess, sys
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
N = int(sys.argv[1]) if len(sys.argv) > 1 else 300
rnd = random.Random(1994)

def d2b(x): return struct.pack('<d', x)
def ext_from_double(x):           # exact: double -> (se, mantissa)
    b = struct.unpack('<Q', struct.pack('<d', x))[0]
    s = 0x8000 if b >> 63 else 0; e = (b >> 52) & 0x7ff; f = b & ((1 << 52) - 1)
    if e == 0: return 0, 0
    return s | (e - 1023 + 16383), ((1 << 52) | f) << 11
def ext_le(se, m): return struct.pack('<QH', m, se)
def ext_be(se, m): return struct.pack('>HQ', se, m)
def rnd_ext():                    # an extended with a full 64-bit mantissa
    x = rnd_double()
    se, m = ext_from_double(x)
    if m: m |= rnd.getrandbits(11)
    return se, m
def rnd_double():
    k = rnd.random()
    if k < 0.3: x = rnd.uniform(-1000, 1000)
    elif k < 0.5: x = rnd.uniform(0, 10)
    elif k < 0.6: x = float(rnd.randint(-3000, 3000))
    elif k < 0.7: x = rnd.randint(-3000, 3000) / 10
    elif k < 0.8: x = rnd.uniform(-1e-3, 1e-3)
    elif k < 0.9: x = rnd.uniform(-1e6, 1e6)
    else: x = rnd.randint(-1000, 1000) + 0.5
    return x

cases = []                        # (op, w, d, a_le, a_be, b_le, b_be)
def add(op, a, b=None, w=0, d=0, ext=False):
    if b is None: b = (0, 0) if ext else 0.0
    if ext:
        al, ab = ext_le(*a), ext_be(*a); bl, bb = ext_le(*b), ext_be(*b)
    else:
        al, ab = d2b(a), struct.pack('>d', a); bl, bb = d2b(b), struct.pack('>d', b)
    cases.append((op, w, d, al, ab, bl, bb))
for _ in range(N):
    a, b = rnd_double(), rnd_double()
    for op in range(4): add(op, a, b)
    add(1, a, a * (1 + rnd.choice([0, 1e-16, -1e-16, 2e-16])))   # cancellation
    add(0, a, rnd.choice([1e-17, -1e-17, 3e-17]) * a)               # rounding edges
    add(4, abs(a))
    ea, eb = rnd_ext(), rnd_ext()
    for op in range(5, 9): add(op, ea, eb, ext=True)
    add(9, (ea[0] & 0x7fff, ea[1]), ext=True)
    add(10, ea, ext=True)
    add(11, a); add(12, a); add(13, ea, ext=True)
    add(13, ext_from_double(float(rnd.randint(-99, 99)) + 0.5), ext=True)
    t = rnd.uniform(-60, 60)
    add(14, t); add(15, t); add(16, rnd.uniform(-50, 50)); add(16, rnd.uniform(-0.5, 0.5))
    add(17, abs(a) % 2000 * rnd.choice([1, 1, -1]), w=rnd.randint(1, 8), d=rnd.randint(0, 2))
    add(17, rnd.randint(0, 9999) / 1000, w=6, d=2)            # x.xx5 style ties
    add(17, rnd.randint(0, 30000) / 10, w=5, d=1)
    i = rnd.randint(-40000, 40000)
    cases.append((18, 0, 0, struct.pack('<i', i) + bytes(4), struct.pack('>i', i) + bytes(4), d2b(0), d2b(0)))
    add(19, a, rnd.choice([a, b, -a]))
    add(20, ext_from_double(t), ext=True); add(21, ext_from_double(t), ext=True)
    add(22, ext_from_double(rnd.uniform(-50, 50)), ext=True)
for v in [0.125, 0.375, 1.005, 99.995, 2.5, 3.5, 12345.678, 0.0049999, -3.25, 123.45]:
    add(17, v, w=6, d=2); add(17, v, w=3, d=0); add(17, v, w=5, d=1)
le = b''.join(struct.pack('<4H', op, w, d, 0) + al.ljust(12, b'\0') + bl.ljust(12, b'\0') for op, w, d, al, ab, bl, bb in cases)
be = b''.join(struct.pack('>4H', op, w, d, 0) + ab.ljust(12, b'\0') + bb.ljust(12, b'\0') for op, w, d, al, ab, bl, bb in cases)
T = '/tmp/claude-0/fptest'; os.makedirs(T, exist_ok=True)
open(T + '/in.bin', 'wb').write(le)
subprocess.run([R + '/tools/fp/fpref', T + '/in.bin', T + '/ref.bin'], check=True)
C = R + '/hatari/c'
open(C + '/FPIN.BIN', 'wb').write(be)
if os.path.exists(C + '/FPOUT.BIN'): os.remove(C + '/FPOUT.BIN')
subprocess.run([R + '/tools/asm.sh', R + '/tests/ktfp.s', C + '/KTFP.PRG'], check=True, stdout=subprocess.DEVNULL)
subprocess.run([R + '/tools/run_hatari.sh', sys.argv[2] if len(sys.argv) > 2 else '9000', '/tmp/claude-0/fptest/s.png', '--auto', 'C:\\KTFP.PRG'], stdout=subprocess.DEVNULL)
ref = open(T + '/ref.bin', 'rb').read(); got = open(C + '/FPOUT.BIN', 'rb').read()
names = ['sse+', 'sse-', 'sse*', 'sse/', 'ssesqrt', 'x87+', 'x87-', 'x87*', 'x87/', 'x87sqrt', 'ext->dbl', 'round', 'trunc',
         'x87round', 'sin', 'cos', 'atan', 'str', 'int->dbl', 'cmp', 'xsin', 'xcos', 'xatan']
stats = {}
def norm(op, r, big):
    if op in (0, 1, 2, 3, 4, 10, 14, 15, 16, 18): return struct.unpack('<d' if not big else '>d', r[:8])[0], r[:8] if not big else r[:8][::-1]
    if op in (5, 6, 7, 8, 9, 20, 21, 22):
        if big: se, m = struct.unpack('>HQ', r[:10])
        else: m, se = struct.unpack('<QH', r[:10])
        return (se, m), None
    if op in (11, 12, 13): return struct.unpack('<i' if not big else '>i', r[:4])[0], None
    if op == 17: return r[1:1 + r[0]].decode('latin1'), None
    if op == 19: return struct.unpack('b', r[:1])[0], None
bad = 0
for k, c in enumerate(cases):
    op = c[0]
    if len(got) < 16 * (k + 1): print('ST output short at', k); bad += 1; break
    rv, rb = norm(op, ref[16 * k:16 * k + 16], False)
    gv, gb = norm(op, got[16 * k:16 * k + 16], True)
    st = stats.setdefault(names[op], [0, 0, 0])
    st[0] += 1
    ok = (rb == gb) if rb is not None else (rv == gv)
    if not ok and op in (20, 21, 22):          # extended transcendental: ulps
        d = abs(rv[1] - gv[1]) if rv[0] == gv[0] else 1 << 40
        if d <= 64: st[2] += 1; continue
    if not ok:
        st[1] += 1; bad += 1
        if st[1] <= 4:
            a = struct.unpack('<d', c[3][:8])[0] if op not in (5, 6, 7, 8, 9, 10, 13, 20, 21, 22) else c[3].hex()
            print('%-8s a=%r w=%d d=%d  fpc=%r  st=%r' % (names[op], a, c[1], c[2], rv, gv))
for n in names:
    if n in stats: print('%-9s %5d cases, %d differ%s' % (n, stats[n][0], stats[n][1], (', %d within 64 ulp(ext)' % stats[n][2]) if stats[n][2] else ''))
print('fp: %d of %d differ' % (bad, len(cases)))
sys.exit(1 if bad else 0)
