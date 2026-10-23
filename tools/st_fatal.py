#!/usr/bin/env python3
"""st_fatal.py FATAL.BIN PROG.s : where MAIN.PRG stopped with 'a data file is missing' (fatal):
the registers and the stack's longs that point into the program's text, as source lines
(a vasm listing of PROG.s is made; the text base is taken from the return addresses' range)."""
import os, re, struct, subprocess, sys, tempfile
d = open(sys.argv[1], 'rb').read()
regs = struct.unpack('>16I', d[:64]); stack = struct.unpack('>64I', d[64:320])
print(' '.join('d%d=%08x' % (i, regs[i]) for i in range(8)))
print(' '.join('a%d=%08x' % (i, regs[8 + i]) for i in range(8)))
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
lst = os.path.join(tempfile.mkdtemp(), 'p.lst')
subprocess.run([os.path.join(R, 'tools', 'st_listing.sh'), sys.argv[2], lst], stdout=subprocess.DEVNULL)
L = {}
cur = None
for line in open(lst, errors='replace'):
    m = re.match(r'^00:([0-9A-F]{8}) ', line)
    if m: L[int(m.group(1), 16)] = line.rstrip()
offs = sorted(L)
base = struct.unpack('>I', d[320:324])[0]
print('text base %08x' % base)
print('at a0:', d[324:388])
import bisect
for k, v in enumerate(stack):
    o = v - base
    if 0 <= o <= offs[-1]:
        i = bisect.bisect_right(offs, o) - 1
        prev = L[offs[i - 1]] if i > 0 else ''
        print('sp+%3d %08x -> %s' % (k * 4, v, prev[:110]))
