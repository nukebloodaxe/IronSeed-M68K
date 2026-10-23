#!/usr/bin/env python3
"""mainmodel.py - chunky (palette index) models of the original MAIN program's drawing, for the
host tools (band training) and tests: comm2.pas printxy2 (log text, glyph codes), the log screen
(computerlogs: displaylist/getlog), main data files."""
import os, struct
import numpy as np
import cgmodel as m
cm = m

HERE = os.path.dirname(os.path.abspath(__file__))


def printxy2(img, x1, y1, s, tcolor, bkcolor, font):
    """comm2.pas printxy2: s holds glyph codes (1..82); chr(200) toggles 'bright' (white, 31),
    the line is first cleared for 49 characters with bkcolor (255 = transparent)."""
    bright = printxy2.bright
    t = tcolor
    x1 += 4
    if bkcolor < 255:
        img[y1 + 1:y1 + 7, x1 + 1:x1 + 1 + 5 * 49] = bkcolor
    for ch in s:
        o = ord(ch) if isinstance(ch, str) else ch
        tc = 31 if bright else t
        if o == 200:
            bright = not bright
            continue
        g = font[o - 1] if 1 <= o <= 82 else (0, 0, 0)
        for row in range(6):
            bits = (g[row // 2] >> (4 if row % 2 == 0 else 0)) & 15
            y = y1 + 1 + row
            for k in range(4):
                x = x1 + 1 + k
                if bits & (8 >> k): img[y, x] = tc & 255
                elif bkcolor < 255: img[y, x] = bkcolor
            tc -= 2
        x1 += 5
        if bkcolor < 255:
            img[y1 + 1:y1 + 7, x1] = bkcolor
    printxy2.bright = bright


printxy2.bright = False


def pstr(b):
    return b[1:1 + b[0]]


def read_titles(path):
    d = open(path, 'rb').read()
    return [(struct.unpack('>h', d[i:i + 2])[0], pstr(d[i + 2:i + 52])) for i in range(0, len(d), 52)]


def read_logs(path):
    d = open(path, 'rb').read()
    return [[pstr(d[r + k * 50:r + k * 50 + 50]) for k in range(25)] for r in range(0, len(d), 1250)]


def logindex_of(titles, n):
    for i, (tid, _) in enumerate(titles):
        if tid == n: return i
    raise KeyError(n)


def getlog(img, titles, logs, n, font):
    """comm2.pas getlog for log id n (tcolor 79, bkcolor 0)"""
    k = logindex_of(titles, n)
    printxy2(img, 6, 15, titles[k][1], 79, 0, font)
    for j in range(25):
        printxy2(img, 6, 22 + j * 6, logs[k][j], 79, 0, font)


def displaylist(img, titles, loglist, logindex, font):
    """comm2.pas displaylist (loglist = logs[] up to the first -1)"""
    y = 13
    i = logindex - 1
    while i > -1:
        y -= 1
        printxy2(img, 6, 14 + y * 6, titles[logindex_of(titles, loglist[i])][1], 79, 0, font)
        i -= 1
        if i < 0 or y == 0: break
    if y > 0:
        img[14:y * 6 + 15, 8:254] = 0
    y = 12
    i = logindex
    while True:
        y += 1
        printxy2(img, 6, 14 + y * 6, titles[logindex_of(titles, loglist[i])][1], 79, 9 if i == logindex else 0, font)
        i += 1
        if i == 256 or y == 25 or i >= len(loglist): break
    if y < 25:
        img[y * 6 + 21:171, 8:254] = 0


# ---------------------------------------------------------------- planets (utils2.pas, journey.pas)
import math


def pdiv(a, b):
    """Pascal div (truncates toward zero)"""
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


RADIUS = {0: 900, 1: 900, 2: 2000, 3: 2000, 4: 3025}


def sphere_geometry(radius):
    """readyplanet/readystar: r2, offset, maxspherei, spherei, xw, pm[], ppart[] (as FPC computes:
    reals are IEEE doubles, round() is banker's)"""
    c2 = 1.20 if radius < 901 else (1.09 if radius > 2000 else 1.16)
    r2 = round(math.sqrt(radius))
    g = dict(radius=radius, c2=c2, r2=r2, offset=55 - r2, maxspherei=2 * r2 + 4,
             spherei=(2 * r2 + 4) // 2, xw=2 * r2 + 10, pm={}, ppart={})
    for i in range(6, 2 * r2 + 4 + 1):
        y = math.sqrt(radius - (i - r2 - 5) ** 2)
        g['pm'][i] = round((r2 - y) * c2)
        g['ppart'][i] = r2 / y
    return g


def row_indices(g, i):
    """index sequence of row i (part4 += ppart[i]; index := round(part4)) while index <= xw"""
    out, part4 = [], 0.0
    for j in range(1, g['xw'] + 1):
        part4 += g['ppart'][i]
        index = round(part4)
        if index > g['xw']: break
        out.append(index)
    return out


def tech_level(tp, plan, chevent):
    p = tp[plan - 1]
    if p['orbit'] == 0: return 0
    t = -2
    if p['system'] in (93, 138, 78, 191, 171, 221): return 6 * 256
    if p['system'] == 45: return 0 if chevent(27) else 6 * 256
    st, mo, age = p['state'], p['mode'], p['age']
    if st == 2:
        if mo == 2: t = -1
        elif mo == 3: t = pdiv(age, 15000000)
    elif st == 3:
        t = (mo - 1) * 256 + {1: pdiv(age, 1500000), 2: pdiv(age, 1000), 3: pdiv(age, 800)}.get(mo, 0)
    elif st == 4:
        t = (mo + 2) * 256 + {1: pdiv(age, 400), 2: pdiv(age, 200)}.get(mo, 0)
    elif st == 5:
        if mo == 1: t = t + min(pdiv(age, 100000000), 9)
        elif mo == 2: t = -1
    elif st == 6:
        if tp[plan - 1]['mode'] == 2: t = 6 * 256   # (the original tests tempplan^[curplan], = plan here)
    return t


class Planet:
    """readyplanet's ordinary branch (no gas giant, asteroid field or cloud) and makesphere"""

    def __init__(self, tp, curplan, rnd, chevent=lambda n: False):
        p = tp[curplan - 1]
        self.rnd = rnd
        rnd.randseed = p['seed']
        self.land = np.full((241, 121), (p['water'] + 20) & 255, np.uint8)   # [x 1..240, y 1..120]
        self.g = g = sphere_geometry(RADIUS[p['psize']])
        rnd.randseed = 1994                     # randomize (oracle build)
        k = rnd.random(4)
        self.ecl = [lambda: rnd.random(25) + 30, lambda: 80 - rnd.random(25),
                    lambda: 200 + rnd.random(25), lambda: 250 - rnd.random(25)][k]()
        self.water = None
        self.createplanet(tp, curplan, 200, 90, chevent)
        self.createplanet(tp, curplan, 30, 30, chevent)
        self.createplanet(tp, curplan, 120, 60, chevent)
        water, spc, wi = 50, [0] * 6, 0
        st, mo = p['state'], p['mode']
        if st == 1: wi, spc = 80, [83, 82, 81, 80, 82, 81]
        elif st == 2:
            wi = 32
            spc = {1: [1] * 6, 2: [1, 1, 1, 1, 48, 49], 3: [48, 49, 50, 51, 128, 130]}[mo]
        elif st == 3: wi, spc = 33, [48, 49, 50, 51, 128, 129]
        elif st == 4: wi, water, spc = 32, 40, [48, 49, 50, 51, 128, 129]
        elif st == 5: wi, spc, water = 32, [1] * 6, (0 if mo == 3 else 30)
        elif st == 6: wi, water, spc = 32, 0, [1] * 6
        self.waterindex, self.spc, self.spc2 = wi, spc, [x % 16 for x in spc]
        part2 = 28 / (255 - water)
        lk = [0] * 256
        for j in range(water): lk[j] = wi + 6
        for j in range(water, 247): lk[j] = round((j - water) * part2)
        for j in range(247, 256): lk[j] = j
        self.lookup = lk

    def createplanet(self, tp, curplan, xc, yc, chevent):
        rnd, L = self.rnd, self.land
        rnd.randseed = tp[curplan - 1]['seed']
        x1, y1 = xc, yc
        for _ in range(75000):
            x1 = x1 - 1 + rnd.random(3)
            y1 = y1 - 1 + rnd.random(3)
            if x1 > 240: x1 = 1
            elif x1 < 1: x1 = 240
            if y1 > 120: y1 = 1
            elif y1 < 1: y1 = 120
            if L[x1, y1] < 240: L[x1, y1] += 7
        tl = tech_level(tp, curplan, chevent)
        if tl > 0:
            tl = (tl >> 8) * 10 + (tl & 255)
            tl = tl * tl // 10
            for _ in range(tl):
                x1 = rnd.random(240); y1 = rnd.random(120)
                if L[x1, y1] > 50:               # water (utils2's unit variable, 50 before the first planet)
                    L[x1, y1] = 255

    def pixel(self, index, j, c):
        g, ecl = self.g, self.ecl
        if ecl > 170:
            alt = 10 if j == 1 else pdiv(index - ecl + 186, 2)
        elif ecl < 171:
            alt = 10 if index == g['xw'] else pdiv(ecl - index, 2)
        else:
            alt = 0
        if alt < 0: alt = 0
        return alt

    def render(self, planet, c, rows):
        """makesphere1/2 into planet [121, 121] (1-based) for rows (6..spherei / spherei+1..max)"""
        g, L, lk = self.g, self.land, self.lookup
        wi, spc, spc2 = self.waterindex, self.spc, self.spc2
        for i in rows:
            ii = pdiv(60 * i, g['spherei'])
            ofsy = i + g['offset']
            ofsx = g['pm'][i] + g['offset']
            for j, index in enumerate(row_indices(g, i), 1):
                ofsx += 1
                alt = self.pixel(index, j, c)
                j2 = index + c
                if j2 > 240: j2 -= 240
                z = lk[L[j2, ii]]
                if z == wi and alt < 6: v = wi + 6 - alt
                elif z == wi: v = wi
                elif z >= 247: v = 116
                else:
                    if z < 6:
                        z = 1 if alt > spc2[z] else spc[z] - alt
                    elif z < 32:
                        z = z - alt if z > alt else 1
                    v = z
                planet[ofsy, ofsx] = v & 255

    def makesphere(self, screen, c):
        """makesphere1+2+3 at rotation c onto a 320x200 screen whose planet area holds the background"""
        planet = np.zeros((121, 121), np.uint8)
        planet[1:121, 1:121] = screen[13:133, 28:148]
        g = self.g
        self.render(planet, c, range(6, g['spherei'] + 1))
        self.render(planet, c, range(g['spherei'] + 1, g['maxspherei'] + 1))
        screen[13:133, 28:148] = planet[1:121, 1:121]


# ---------------------------------------------------------------- the bridge (starter/journey/display)
def bridge_base(main, cloud, bgx, bgy):
    """utils2.pas reloadbackground: main.cpr with its transparent (255) pixels filled from cloud.cpr
    shifted by (backgrx, backgry)"""
    out = main.copy()
    ys, xs = np.nonzero(main == 255)
    out[ys, xs] = cloud[(ys + bgy) % 200, (xs + bgx) % 320]
    return out


def showtime(img, stardate, font):
    s = []
    for j in range(5):
        v = stardate[j]
        if j == 2: t = '%5d' % v; t = ('0' + t[1:]) if v < 10000 else t
        else: t = '%2d' % v; t = ('0' + t[1:]) if v < 10 else t
        s.append(t)
    cm.printxy(img, 42, 193, s[2] + '/' + s[0] + '/' + s[1] + ' ' + s[3] + ':' + s[4], 44, 0, font)


def revgraybutton(img, x1, y1, x2, y2):
    img[y2, x1:x2 + 1] = 10; img[y1, x1:x2 + 1] = 2
    img[y1:y2 + 1, x2] = 10; img[y1:y2 + 1, x1] = 2
    img[y1, x2] = 4; img[y2, x1] = 4


def readystatus(img, font):
    img[25:118, 165:280] = 5
    img[25:118, 279] = 2; img[117, 165:280] = 2; img[35, 165:279] = 2
    img[25, 165:280] = 10; img[25:118, 165] = 10; img[36, 165:280] = 10
    img[35, 165] = 6; img[25, 279] = 6; img[117, 165] = 6; img[36, 279] = 6
    cm.printxy(img, 192, 27, 'Ship Stats', 191, 5, font)
    for j in range(4): revgraybutton(img, 172, 45 + j * 20, 272, 55 + j * 20)
    for x, y, s in ((181, 38, 'Hull Integrity'), (184, 58, 'Primary Power'), (179, 78, 'Secondary Power'), (187, 98, 'Shield Level')):
        cm.printxy(img, x, y, s, 191, 5, font)


def displaystatus(img, vals, font):
    """vals: 4 (value, max) pairs"""
    for k, (v, mx) in enumerate(vals):
        y0 = 46 + 20 * k
        a = round(v / mx * 98)
        part = 0 if a == 0 else 31 / a
        for j in range(a + 1): img[y0:y0 + 9, j + 173] = round(j * part)
        if a < 98: img[y0:y0 + 9, 174 + a:174 + 98] = 0
        s = str(v)
        cm.printxy(img, 219 - round(len(s) * 2.5), y0 + 1, s, 191, 255, font)


def cube_image(icons, face):
    """setcube/getcube: 45x51 from icons.vga (17x15 icons stored column by column)"""
    out = np.zeros((45, 51), np.uint8)
    for a in range(3):
        for b in range(3):
            ic = icons[face * 9 + a * 3 + b]
            out[b * 15:b * 15 + 15, a * 17:a * 17 + 17] = ic.T
    return out


def read_icons(path):
    d = np.frombuffer(open(path, 'rb').read(), np.uint8)
    return d.reshape(-1, 17, 15)
