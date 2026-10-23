#!/usr/bin/env python3
"""planetref.py - reference for intro.pas makeplanet (the rotating, lit planet), used to
generate the STE tables and to check the STE renderer pixel for pixel.

Same arithmetic as the Pascal: real = double, round() = round half to even (Python's
round on floats), integer div truncates toward zero.
"""
import math


def pdiv(a, b):  # Pascal integer div: truncate toward zero
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


def geometry(radius, c2):
    """per row: (i, m, [index for j = 1..]) - the pixels makeplanet writes, in order.
    planet^[ofsy, ofsx]: ofsy = i - 5, ofsx = m + j  (1-based)."""
    r2 = round(math.sqrt(radius))
    x = 2 * r2 + 10
    rows = []
    for i in range(6, 2 * r2 + 5):
        y = math.sqrt(radius - (i - r2 - 5) ** 2)
        m = round((r2 - y) * c2)
        part = r2 / y
        idx = []
        for j in range(1, x + 1):
            index = round(j * part)
            if index > x: break
            idx.append(index)
        rows.append((i, m, idx))
    return r2, x, rows


def colour_table(water, waterindex, spcindex):
    """F[alt][h] for alt 0..29 (alt >= 29 behaves as 29) and land height h 0..255"""
    part2 = 28 / (255 - water)
    F = []
    for alt in range(30):
        row = []
        for h in range(256):
            if alt < 6 and h < water: px = waterindex + 6 - alt
            elif h < water: px = waterindex
            else:
                z = round((h - water) * part2)
                if 6 <= z <= 31: z = z - alt if z > alt else 1
                elif 0 <= z <= 5: z = 1 if alt > spcindex[z] % 16 else spcindex[z] - alt
                px = z
            row.append(px & 255)
        F.append(row)
    return F


def alt_of(j, index, ecl, x):
    if ecl > 170:
        alt = 10 if j == 1 else pdiv(index - ecl + 186, 2)
    elif ecl < 171:
        alt = 10 if index == x else pdiv(ecl - index, 2)
    else:
        alt = 0
    return max(alt, 0)


def render(planet, land, c, ecl, geo, F):
    """one makeplanet frame into planet (dict or 2-D list [ofsy][ofsx], 1-based);
    land[j2][i] (1-based, 240 x 120)"""
    r2, x, rows = geo
    for i, m, idx in rows:
        ofsy = i - 5
        for j, index in enumerate(idx, 1):
            ofsx = m + j
            alt = min(alt_of(j, index, ecl, x), 29)
            j2 = index + c
            if j2 > 240: j2 -= 240
            planet[ofsy][ofsx] = F[alt][land[j2][i]]


def step(c, ecl, eclipse):
    """makeplanet's per-frame state update (before rendering)"""
    c += 1
    if c > 240: c -= 240
    if eclipse and c % 2 == 0:
        ecl += 1
        if ecl > 340: ecl -= 340
    return c, ecl


def load_land(fn):
    """plan1.dta: landtype = array[1..240, 1..120] of byte -> land[j2][i] (1-based)"""
    d = open(fn, 'rb').read()
    land = [[0] * 121 for _ in range(241)]
    for j2 in range(1, 241):
        for i in range(1, 121):
            land[j2][i] = d[(j2 - 1) * 120 + (i - 1)]
    return land
