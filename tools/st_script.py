#!/usr/bin/env python3
"""st_script.py IN OUT - an oracle input script (Linux/SDL key codes) for the ST's scr.s:
key #273/#274/#276/#275 (SDL arrows) -> key ^72/^80/^75/^77, PgUp/PgDn, F1-F6, F10, @c (Alt-c), !#279/!#291 (Ctrl-End/Ctrl-F10); CR LF line ends."""
import sys
MAP = {'#273': '^72', '#274': '^80', '#276': '^75', '#275': '^77', '#277': '^82', '#127': '^83', '#280': '^73', '#281': '^81',
       '#282': '^59', '#283': '^60', '#284': '^61', '#285': '^62', '#286': '^63', '#287': '^64',
       '#291': '^16',                     # SDL F1-F6 -> scan codes 59-64; F10 = the original's Alt-Q (16)
       '!#279': '^117', '!#291': '^103'}  # Ctrl-End, Ctrl-F10 (c_utils.c spec_map)
ALT = {'q': 16, 'x': 45, '1': 120, '2': 121, '3': 122, '4': 123, '7': 126, '0': 129, 'n': 49,
       'p': 25, 'b': 48, 's': 31, 'u': 22, 'i': 23}   # key @c (Alt-c) -> the scan code (c_utils.c spec_map)
out = []
for line in open(sys.argv[1]):
    w = line.split()
    if len(w) == 2 and w[0] == 'key' and w[1] in MAP: line = 'key %s\n' % MAP[w[1]]
    if len(w) == 2 and w[0] == 'key' and w[1][0] == '@': line = 'key ^%d\n' % ALT[w[1][1].lower()]
    out.append(line.rstrip('\n') + '\r\n')
open(sys.argv[2], 'w', newline='').write(''.join(out))
