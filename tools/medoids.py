#!/usr/bin/env python3
"""medoids.py - a band's 16 slots chosen among the palette indices themselves (Phase 6k).

The STE shows a slot in its rep index's colour on the 4-bit grid (vid_set256: the original's
set256colors recolours every slot from its rep), so a band's design is really 15 rep indices
(slot 0 = black for the border). bandfit's k-means places centres anywhere and snaps them to reps
afterwards; this picks the reps directly, minimising the weighted squared error between each
used index's true colour and the shown colour of the slot it maps to (k-medoids: greedy build,
then swaps while one improves), the LUT mapping every index to its nearest shown colour.

  band(hist_rows, pal) -> (err, cent(16,3) 0..15, lut(256) uint8, reps(16) list)"""
import numpy as np


def shown(pal):
    """6-bit palette -> (true colour 0..255, shown colour 0..255 on the 4-bit grid)"""
    p6 = np.asarray(pal).astype(int)
    return (p6 * 255 // 63).astype(float), (np.clip(np.round(p6 * 15 / 63), 0, 15) * 17).astype(float)


def band(hist_rows, pal, k=16, fixed=(0,), swaps=40):
    w = np.asarray(hist_rows, float).sum(0)
    true, show = shown(pal)
    used = np.nonzero(w > 0)[0]
    # candidate reps: one per distinct shown colour among the used indices (the most used one)
    cand, seen = [], {}
    for i in sorted(used, key=lambda i: -w[i]):
        key = tuple(show[i])
        if key not in seen:
            seen[key] = i; cand.append(i)
    fixed = [f for f in fixed]
    cand = [i for i in cand if tuple(show[i]) not in {tuple(show[f]) for f in fixed}]
    D = ((true[used][:, None, :] - show[cand][None, :, :]) ** 2).sum(2)      # used x cand
    Df = ((true[used][:, None, :] - show[fixed][None, :, :]) ** 2).sum(2).min(1) if fixed else np.full(len(used), np.inf)
    ww = w[used]
    nfree = k - len(fixed)
    if len(cand) <= nfree:
        chosen = list(range(len(cand)))
    else:
        chosen = []
        best = Df.copy()
        for _ in range(nfree):                       # greedy build
            gain = (ww[:, None] * np.maximum(best[:, None] - D, 0)).sum(0)
            gain[chosen] = -1
            j = int(gain.argmax())
            chosen.append(j)
            best = np.minimum(best, D[:, j])
        for _ in range(swaps):                       # swaps (PAM)
            cur = (ww * best).sum()
            improved = False
            for a in range(nfree):
                rest = [c for t, c in enumerate(chosen) if t != a]
                base = np.minimum(Df, D[:, rest].min(1)) if rest else Df
                cost = (ww[:, None] * np.minimum(base[:, None], D)).sum(0)
                cost[chosen] = np.inf
                j = int(cost.argmin())
                if cost[j] < cur - 1e-6:
                    chosen[a] = j
                    best = np.minimum(base, D[:, j]); cur = cost[j]; improved = True
            if not improved:
                break
    reps = fixed + [cand[j] for j in chosen]
    while len(reps) < k:
        reps.append(fixed[0] if fixed else 0)
    sc = show[reps]
    lut = ((true[:, None, :] - sc[None, :, :]) ** 2).sum(2).argmin(1).astype(np.uint8)
    # a slot that repeats an earlier one's colour (padding) never gets an index
    err = float((w * ((true - sc[lut]) ** 2).sum(1)).sum())
    cent = (sc / 17).round().astype(int)
    return err, cent, lut, [int(r) for r in reps]
