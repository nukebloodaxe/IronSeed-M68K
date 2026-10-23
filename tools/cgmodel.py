#!/usr/bin/env python3
"""cgmodel.py - chunky (256-colour index) models of the original drawing used by crewgen.pas
and saveload.pas, for the host tools (band training) and the tests (reference screens).

All functions draw on numpy uint8 arrays [200, 320] of palette indices, exactly as the DOS/SDL
build does: printxy (data.pas), line (c_utils.c), button (saveload.pas), graybutton (utils.pas),
plainfadearea (utils.pas)."""
import os, struct
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SHIPNAMES = ['Heavy', 'Light', 'Strategic', 'Shuttle', 'Assault', 'Storm', 'Transport', 'Frigate', 'Cruiser']
CREWTITLES = ['COMPUTER', 'PSYCHOMETRY', 'ENGINEERING', 'SCIENCE', 'SECURITY', 'ASTROGATION', 'MEDICAL']
LEVELTITLES = ['           ', 'Psychometry', 'Engineering', '  Science  ', ' Security  ', 'Navigation ', '  Medical  ']


def load_font(font_i=os.path.join(HERE, '..', 'build', 'font.i')):
    nums = [int(x) for line in open(font_i) if line.strip().startswith('dc.b')
            for x in line.split()[1].split(',')]
    return [[tuple(nums[(f * 82 + g) * 3:(f * 82 + g) * 3 + 3]) for g in range(82)] for f in range(3)]


def letter(ch):
    o = ord(ch)
    if 'a' <= ch <= 'z': return o - 40
    if 'A' <= ch <= 'Z': return o - 36
    if ' ' <= ch <= '"': return o - 31
    if "'" <= ch <= '?': return o - 35
    if ch == '%': return 55
    return 1


def printxy(img, x1, y1, s, tcolor, bkcolor, font):
    """data.pas printxy: glyph rows y1+1..y1+6, 5 pixels per char, row colour tcolor-2*row,
    bkcolor (<255) fills the empty glyph pixels and the gap column"""
    x1 += 4
    for ch in s:
        g = font[letter(ch) - 1]
        t = tcolor
        for row in range(6):
            bits = (g[row // 2] >> (4 if row % 2 == 0 else 0)) & 15
            y = y1 + 1 + row
            for k in range(4):
                x = x1 + 1 + k
                if bits & (8 >> k): img[y, x] = t & 255
                elif bkcolor < 255: img[y, x] = bkcolor
            t -= 2
        x1 += 5
        if bkcolor < 255:
            for i in range(1, 7): img[y1 + i, x1] = bkcolor


def line(img, x1, y1, x2, y2, c):
    """c_utils.c line()"""
    dx, dy = x2 - x1, y2 - y1
    dxa, dya = abs(dx), abs(dy)
    sdx = 1 if dx > 0 else -1
    sdy = 1 if dy > 0 else -1
    x, y = dya >> 1, dxa >> 1
    px, py = x1, y1
    img[py, px] = c
    if dxa >= dya:
        for _ in range(dxa):
            y += dya
            if y >= dxa: y -= dxa; py += sdy
            px += sdx
            img[py, px] = c
    else:
        for _ in range(dya):
            x += dxa
            if x >= dya: x -= dya; px += sdx
            py += sdy
            img[py, px] = c


def bar(img, x1, y1, x2, y2, c):
    img[min(y1, y2):max(y1, y2) + 1, min(x1, x2):max(x1, x2) + 1] = c


def button(img, x1, y1, x2, y2, alt):
    """saveload.pas button"""
    bar(img, x1, y1, x2, y2, (35 + alt) & 255)
    line(img, x2, y1, x2, y2, (32 + alt) & 255)
    line(img, x1, y2, x2, y2, (32 + alt) & 255)
    line(img, x1, y1, x2, y1, (38 + alt) & 255)
    line(img, x1, y1, x1, y2, (38 + alt) & 255)
    img[y1, x2] = (36 + alt) & 255
    img[y2, x1] = (36 + alt) & 255


def graybutton(img, x1, y1, x2, y2):
    img[y1:y2 + 1, x1:x2 + 1] = 5
    img[y2, x1:x2 + 1] = 2
    img[y1, x1:x2 + 1] = 10
    line(img, x2, y1, x2, y2, 2)
    line(img, x1, y1, x1, y2, 10)
    img[y1, x2] = 6
    img[y2, x1] = 6


def plainfadearea(img, x1, y1, x2, y2, alt):
    img[y1:y2 + 1, x1:x2 + 1] = (img[y1:y2 + 1, x1:x2 + 1].astype(int) + alt) & 255


def read_crew(path):
    """data/crew.dta (DOS layout): 30 x (name string[20], phy, men, emo, level, jobtype: integer,
    desc: 10 x string[52])"""
    d = open(path, 'rb').read()
    out = []
    for i in range(30):
        r = d[i * 561:(i + 1) * 561]
        name = r[1:1 + r[0]].decode('latin-1')
        phy, men, emo, level, job = struct.unpack_from('<5h', r, 21)
        desc = []
        for k in range(10):
            o = 31 + k * 53
            desc.append(r[o + 1:o + 1 + r[o]].decode('latin-1'))
        out.append(dict(name=name, phy=phy, men=men, emo=emo, level=level, jobtype=job, desc=desc))
    return out


def ship_pix(path):
    """data/shippix.dta: 9 x [0..57, 0..74] (column-major) -> 9 x [75, 58] row-major"""
    s = np.frombuffer(open(path, 'rb').read(), np.uint8).reshape(9, 58, 75)
    return np.ascontiguousarray(s.transpose(0, 2, 1))


def ani_frames(path):
    """data/charani.dta: 31 x [0..34, 0..48]; the game draws 48 of the 49 bytes per row"""
    return np.frombuffer(open(path, 'rb').read(), np.uint8).reshape(31, 35, 49)


def calculateship(st):
    """crewgen.pas calculateship: st = (heavyness, purpose, vessel) 1..3 each"""
    cargo = accel = 0
    h, p, v = st
    guns, mass, maxfuel, hullmax = {1: (2, 334, 200, 200), 2: (1, 334, 250, 150), 3: (3, 501, 200, 100)}[h]
    if h == 2: cargo += 50
    g, m, f, c, hm = {1: (3, 501, 350, 50, 700), 2: (4, 668, 300, 100, 600), 3: (5, 835, 300, 50, 600)}[p]
    guns += g; mass += m; maxfuel += f; cargo += c; hullmax += hm
    if v == 1: hullmax += 100; cargo += 100
    elif v == 2: guns += 1; mass += 167; hullmax += 100; cargo += 50
    else: guns += 2; mass += 330; cargo += 50
    accel = 270000 // mass
    return dict(guns=guns, mass=mass, maxfuel=maxfuel, hullmax=hullmax, cargo=cargo, accel=accel)


def pas_round(x):
    """Pascal round(): banker's rounding (x.5 to even), like FPC on x86"""
    f = np.floor(x); r = x - f
    if r > 0.5: return int(f) + 1
    if r < 0.5: return int(f)
    return int(f) + (int(f) & 1)


def drawship(img, st, font):
    """crewgen.pas drawship (tcolor 191, bkcolor 0)"""
    d = calculateship(st)
    img[122:128, 30:261] = 0
    s = SHIPNAMES[st[0] - 1] + ' ' + SHIPNAMES[st[1] + 2] + ' ' + SHIPNAMES[st[2] + 5]
    T, B = 191, 0
    printxy(img, 131 - pas_round(len(s) * 2.5), 122, s, T, B, font)
    rows = [(20, 132, 'Gun Emplacements', 230, '%2d' % d['guns']),
            (30, 143, 'Maximum Fuel', 205, '%4d Kg' % d['maxfuel']),
            (25, 154, 'Cargo Capacity', 190, '%4d Units' % d['cargo']),
            (35, 165, 'Ship Mass', 205, '%4d Mt' % d['mass']),
            (20, 176, 'Max Acceleration', 180, '%4d M/S Sqr' % d['accel']),
            (15, 187, 'Maximum Hull Points', 200, '%4d Pts' % d['hullmax'])]
    for x, y, a, x2, b in rows:
        printxy(img, x, y, a, T, B, font)
        printxy(img, x2, y, b, T, B, font)


def displayship2(img, pix, st, x1=121, y1=13):
    for part, idx in ((0, st[0] - 1), (1, 2 + st[1]), (2, 5 + st[2])):
        x2 = x1 + 58 * (idx // 3)
        img[y1:y1 + 75, x2:x2 + 58] = pix[idx]


def drawstats(img, a, b, c, rand):
    """crewgen.pas drawstats; rand(n) = Pascal random(n). Returns the 58 line end y values."""
    part = 36 / 100
    img[14:89, 121:296] = 0
    cx, cy = 121, 50
    ys = []
    j = 121
    while j <= 295:
        j += 2
        if j > 295: break
        col = (j - 16) % 32 + 128
        d = rand(6)
        v = [a, b, c][d % 3]
        i = pas_round(v * part)
        if d >= 3: i = -i
        line(img, cx, cy, j, i + 51, col)
        cx, cy = j, i + 51
        ys.append(i + 51)
        j += 1
    return ys


def crewscreen(base, ani0, crew, k, level, font, rand, portrait):
    """crew mode composite: char picture, ball, title, name + description, graph, portrait"""
    s = base.copy()
    s[131:147, 11:27] = 0
    s[81:116, 22:70] = ani0[:, :48]
    printxy(s, 141, 100, 'Crew Selection', 191, 0, font)
    printxy(s, 149, 106, LEVELTITLES[level], 191, 0, font)
    cr = crew[k]
    printxy(s, 0, 120, cr['name'], 191, 0, font)
    for a in range(10): printxy(s, 0, 130 + a * 6, cr['desc'][a], 191, 0, font)
    drawstats(s, cr['phy'], cr['men'], cr['emo'], rand)
    s[7:77, 13:83] = portrait
    return s
