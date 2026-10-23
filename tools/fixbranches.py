#!/usr/bin/env python3
"""fixbranches.py PROG.s - assemble repeatedly; for every 'branch destination out of range'
error, drop the .s size from that branch in the reported file/line. Prints what it changed."""
import re, subprocess, sys, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.abspath(sys.argv[1])
for _ in range(50):
    p = subprocess.run(['vasmm68k_mot', '-Ftos', '-m68000', '-nosym', '-quiet', '-I' + R + '/kernel',
                        '-I' + R + '/spikes', '-I' + R + '/build', '-I' + R + '/game', '-o', '/dev/null', src],
                       capture_output=True, text=True, cwd=os.path.dirname(src))
    errs = re.findall(r'error 2029 in line (\d+) of "([^"]+)"', p.stdout + p.stderr)
    if not errs: break
    for ln, fn in errs:
        if not os.path.isabs(fn):        # included files are reported by name: find them
            fn = next((os.path.join(d, fn) for d in (os.path.dirname(src), R + '/game', R + '/kernel', R + '/spikes')
                       if os.path.exists(os.path.join(d, fn))), fn)
        L = open(fn).read().split('\n'); i = int(ln) - 1
        new = re.sub(r'\b(b[a-z]{2,3}|bra|bsr)\.s\b', r'\1', L[i], count=1)
        if new != L[i]:
            print('%s:%s  %s' % (os.path.basename(fn), ln, new.strip())); L[i] = new
            open(fn, 'w').write('\n'.join(L))
