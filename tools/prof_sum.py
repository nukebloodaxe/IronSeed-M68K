#!/usr/bin/env python3
"""prof_sum.py [hatari/prof.log] [N] : cycles per symbol from a Hatari 'profile addresses' dump
(the symbol is the last 'name:' line above each address), top N, with the share of the total."""
import re, sys
fn = sys.argv[1] if len(sys.argv) > 1 else 'hatari/prof.log'
N = int(sys.argv[2]) if len(sys.argv) > 2 else 40
cyc, cur, on = {}, '?', False
for line in open(fn, errors='replace'):
    if 'profile addresses' in line: on = True; continue
    if not on: continue
    m = re.match(r'^([A-Za-z_.][\w.]*):\s*$', line)
    if m: cur = m.group(1); continue
    m = re.search(r'\((\d+), (\d+), \d+, \d+\)\s*$', line)
    if m: cyc[cur] = cyc.get(cur, 0) + int(m.group(2))
tot = sum(cyc.values())
print('total %.1f M cycles' % (tot / 1e6))
for k, v in sorted(cyc.items(), key=lambda kv: -kv[1])[:N]:
    print('%6.2f%%  %10d  %s' % (100.0 * v / tot, v, k))
