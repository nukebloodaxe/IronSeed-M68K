#!/usr/bin/env python3
"""check_intround.py - host proof for the integer replacements of FPC real expressions in
game/combat.s (Phase 6). For every input the game can give, the integer formula must equal the
doubles' result (FPC's SSE code: each operation rounded to double, round() = banker's), except
where the routine falls back to the software FPU (exact .5 cases):

  cb_b49   round(v/max*49), 1 <= max < 32768, 0 <= v <= max   (ties -> FPU)
  cb_e100  round(e/100*s), 0 <= e <= 6450, 0 <= s <= 100       (ties -> FPU)
  cb_move  round(dx/5), -32768 <= dx <= 32767                  (never a tie)
  cb_rdiv100 round(n/100), integer n                           (k.5 is exact in a double)
cb_mapc (round(v/range*m)) and cb_r2 (trunc/fraction of a double) follow from the same
argument and are covered by the oracle sessions (m32, m33, m47). Takes ~10 s."""
import numpy as np

bad = 0
for mx in range(1, 32768):                                   # cb_b49
    v = np.arange(0, mx + 1, dtype=np.int64)
    d = np.rint((v.astype(np.float64) / mx) * 49.0).astype(np.int64)
    num, den = v * 98 + mx, 2 * mx
    tie = num % den == 0
    bad += int(((d != num // den) & ~tie).sum())
print('cb_b49    mismatches outside ties:', bad)
bad = 0
for e in range(0, 6451):                                     # cb_e100
    s = np.arange(0, 101)
    d = np.rint((e / 100.0) * s.astype(np.float64)).astype(int)
    n = e * s
    bad += int(((d != n // 100 + (n % 100 > 50)) & (n % 100 != 50)).sum())
print('cb_e100   mismatches outside ties:', bad)
dx = np.arange(-32768, 32768)                                # cb_move
print('cb_move   mismatches:', int((np.rint(dx / 5.0).astype(int) != (2 * dx + 5 + 70000) // 10 - 7000).sum()))
n = np.arange(-6553600, 6553600)                             # cb_rdiv100
q, r = np.abs(n) // 100, np.abs(n) % 100
i = (q + ((r > 50) | ((r == 50) & (q % 2 == 1)))) * np.sign(n)
print('cb_rdiv100 mismatches:', int((np.rint(n / 100.0).astype(np.int64) != i).sum()))
