#!/usr/bin/env python3
"""check_mt.py KTMT.BIN - tests/ktmt.s output against tools/fpcrand.py (Free Pascal's random)"""
import os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
from fpcrand import FpcRandom
d = open(sys.argv[1], 'rb').read()
got = list(struct.unpack('>%dI' % (len(d) // 4), d))
r = FpcRandom(1994)
ref = [r.random(64000) for _ in range(5)] + [r.random(7) for _ in range(700)] + [r.random(1000) for _ in range(3)]
ref += [r.u32() for _ in range(2000)]
bad = sum(1 for a, b in zip(got, ref) if a != b) + abs(len(got) - len(ref))
print('mt: %d of %d values differ' % (bad, len(ref)))
sys.exit(1 if bad else 0)
