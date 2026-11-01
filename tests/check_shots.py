#!/usr/bin/env python3
"""check_shots.py ORACLE_DIR ST_DIR 'MODE.ISP ...' NAME... - screens of a scripted session: each ST
shot (NAME.SCR) against the Linux shot (shot_NAME.raw). The Linux indices go through the LUTs of the
mode the ST was in - found by matching the band table in the .SCR (split lines and slot colours
that are not animated) against the given mode pictures (ISP2) - and the slots are compared.
Prints differing pixels per shot; exit 1 if any differ.
Options: NAME:x1,y1,x2,y2 excludes a rectangle from that shot (e.g. a version string)."""
import os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import numpy as np
from stscreen import planar_to_slots, read_isp
odir, sdir, isps = sys.argv[1], sys.argv[2], sys.argv[3].split()
modes = []
for fn in isps:
    d = open(fn, 'rb').read()
    tab = d[8:146]
    luts = [np.frombuffer(d[146 + i * 256:146 + (i + 1) * 256], np.uint8) for i in range(4)]
    modes.append((os.path.basename(fn), tab, luts))
lines = lambda t: [struct.unpack('>H', t[2 + 34 * k:4 + 34 * k])[0] for k in range(struct.unpack('>H', t[:2])[0])]
bad_total = 0
for arg in sys.argv[4:]:
    name, _, ex = arg.partition(':')
    s = open(os.path.join(sdir, name + '.SCR'), 'rb').read()
    st = planar_to_slots(s[:32000])
    tab = s[32000:32000 + 138]
    lin = np.frombuffer(open(os.path.join(odir, 'shot_%s.raw' % name), 'rb').read()[:64000], np.uint8).reshape(200, 320)
    cand = [m for m in modes if lines(m[1]) == lines(tab)]
    if len(s) >= 32000 + 138 + 1024:    # (Phase 6j: the shot carries the LUTs in use - a dialog's refit)
        cand.append(('(own)', tab, [np.frombuffer(s[32138 + i * 256:32138 + (i + 1) * 256], np.uint8) for i in range(4)]))
    lutb = None                         # (Phase 7: and the odd-pixel LUTs - the dithering)
    if len(s) >= 32000 + 138 + 2048:
        lutb = [np.frombuffer(s[33162 + i * 256:33162 + (i + 1) * 256], np.uint8) for i in range(4)]
    if not cand:
        print('%-6s no mode with split lines %s' % (name, lines(tab))); bad_total += 1; continue
    best = None
    for mname, t, luts in cand:
        lb = np.zeros(200, int)
        for k, y in enumerate(lines(t)): lb[y:] = k
        ref = np.array([luts[lb[y]][lin[y]] for y in range(200)], np.uint8)
        mask = np.ones((200, 320), bool)
        if ex:
            x1, y1, x2, y2 = map(int, ex.split(','))
            mask[y1:y2 + 1, x1:x2 + 1] = False
        diff = (ref != st) & mask
        if lutb is not None and mname == '(own)':   # B on odd (x+y); A there too (single pixels
            refb = np.array([lutb[lb[y]][lin[y]] for y in range(200)], np.uint8)   # set by LUT)
            odd = (np.add.outer(np.arange(200), np.arange(320)) & 1).astype(bool)
            diff = (((ref != st) & ~odd) | ((ref != st) & (refb != st) & odd)) & mask
        if best is None or diff.sum() < best[1].sum(): best = (mname, diff)
    mname, diff = best
    n = int(diff.sum()); bad_total += n
    ys, xs = np.nonzero(diff)
    print('%-6s %-8s %5d pixels differ%s' % (name, mname, n, (' (rows %d-%d, x %d-%d)' % (ys.min(), ys.max(), xs.min(), xs.max())) if n else ''))
sys.exit(1 if bad_total else 0)
