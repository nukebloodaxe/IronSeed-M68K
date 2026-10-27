#!/usr/bin/env python3
"""curstat.py DBG.BIN : a CURSTAT build's cursor counts, one line per script shot for the stretch
since the shot before (kernel/scr.s tags 253 = frames with the cursor drawn, 252 = frames,
248 = soft hides the VBL ended (kbd.s KBD_SOFTV), 247 = ms_flush second passes, 246 = frames with
kbd_cur_on clear, 242/241 = MAIN's ms_verify: longs of the planar screen that differ from
the shadow converted again, the first one's offset). Tags 251/245 (who hid it, drawn / not drawn) and 244 (the main code's PC in a
frame without the cursor) are return addresses - map them with a listing (tools/st_listing.sh)."""
import struct, sys
d = open(sys.argv[1], 'rb').read()
n = struct.unpack('>I', d[:4])[0]
N = (len(d) - 4) // 4
ring = struct.unpack('>%dI' % N, d[4:4 + 4 * N])
cur, k, rows = {}, 0, []
for i in range(max(0, n - N), n):            # (each shot logs 253..246, then 242/241 from its own check)
    v = ring[i % N]; tag, c = v >> 24, v & 0xffffff
    if tag in (242, 241) and rows: rows[-1][tag] = c
    elif tag in (253, 252, 248, 247): cur[tag] = c
    elif tag == 246 and 252 in cur:
        cur[246] = c; rows.append(cur); cur = {}
for k, cur in enumerate(rows):
    if True:
        c = cur[246]
        f = max(cur[252], 1)
        print(f"shot {k}: cursor drawn in {cur.get(253, 0)} of {cur[252]} frames ({100 * cur.get(253, 0) / f:.0f} %),"
              f" off {c}, soft hides ended {cur.get(248, 0)}, second passes {cur.get(247, 0)}"
              + (f", debris {cur[242]} longs" + (f" (first at line {cur[241] // 160})" if cur[242] else "") if 242 in cur else ""))
