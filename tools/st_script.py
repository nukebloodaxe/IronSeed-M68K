#!/usr/bin/env python3
"""st_script.py IN OUT - an oracle input script (Linux/SDL key codes) for the ST's scr.s:
key #273/#274/#276/#275 (SDL arrows) -> key ^72/^80/^75/^77, F1-F6, F10; CR LF line ends."""
import sys
MAP = {'#273': '^72', '#274': '^80', '#276': '^75', '#275': '^77', '#277': '^82', '#127': '^83',
       '#282': '^59', '#283': '^60', '#284': '^61', '#285': '^62', '#286': '^63', '#287': '^64',
       '#291': '^16'}                   # SDL F1-F6 -> scan codes 59-64; F10 = the original's Alt-Q (16)
out = []
for line in open(sys.argv[1]):
    w = line.split()
    if len(w) == 2 and w[0] == 'key' and w[1] in MAP: line = 'key %s\n' % MAP[w[1]]
    out.append(line.rstrip('\n') + '\r\n')
open(sys.argv[2], 'w', newline='').write(''.join(out))
