#!/usr/bin/env python3
"""pstrlint.py FILE.s ... - check Pascal-style strings 'dc.b N,"text"' (length byte = text length);
several per line are checked one by one. Prints mismatches; exit 1 if any."""
import re, sys
bad = 0
for fn in sys.argv[1:]:
    for ln, line in enumerate(open(fn), 1):
        code = line.split(';')[0] if '"' not in line.split(';')[0] else line
        for m in re.finditer(r'(?<![\w"])(\d+),"([^"]*)"', code):
            n, t = int(m.group(1)), m.group(2)
            if n != len(t) and n != 92:
                print('%s:%d: length %d, text %d: "%s"' % (fn, ln, n, len(t), t)); bad += 1
sys.exit(1 if bad else 0)
