#!/usr/bin/env python3
"""mkmain.py SRC_DATA OUT_DATA - data for MAIN.PRG (the main game), built from the original files.

Screens are drawn by MAIN.PRG into a chunky shadow (game palette indices, like the original's
screen[]) and flushed to the planar screen through the band LUTs, so each screen design ("mode")
ships as:
  <NAME>.ISP  ISP2 picture (bands, LUTs, reps, planar background) - shown at once with pic_show
  <NAME>.CHK  the same background as 64000 chunky indices (the shadow's starting content),
              followed by the picture's 768-byte palette when the .cpr carries one (loadscreen
              then sets colors)
The bands of a mode are fitted (bandfit.py) on every composite that screen can show.

Modes:
  LOG   computerlogs (comm2.pas): log.cpr with the text area cleared; training = every log page,
        the title list, the cursor frames everywhere, both states of the '?' light.
"""
import os, struct, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
import cpr2st as c, cgmodel as cm, bandfit as bf, mainmodel as mm


def save_mode(out, name, design, img, pal=None):
    """ISP2 header + planar slots of img; and the chunky .CHK (+ palette)"""
    slots = design.slots(img)
    open(os.path.join(out, name + '.ISP'), 'wb').write(bytes(design.isp_header()) + c.planar(slots)[1])
    open(os.path.join(out, name + '.CHK'), 'wb').write(img.astype(np.uint8).tobytes() +
                                                       (bytes(pal.astype(np.uint8).ravel()) if pal is not None else b''))


def preview(path, design, img):
    Image.fromarray(design.rgb(img)).resize((640, 400), Image.NEAREST).save(path)


def log_mode(src, out, font, prev=None):
    w, h, img, pal, _ = c.read_cpr(os.path.join(src, 'log.cpr'))
    titles = mm.read_titles(os.path.join(out, 'TITLES.DTA'))
    logs = mm.read_logs(os.path.join(out, 'LOG.DTA'))
    base = img.copy()
    cursors = [base[120:136, 9 + j * 17:25 + j * 17].copy() for j in range(7)]
    base[15:171, 8:254] = 0
    stack, weights = [], []
    for k, (tid, _) in enumerate(titles):          # every log page (read mode, light on)
        im = base.copy(); im[42:51, 311:313] = 63
        mm.printxy2.bright = False
        mm.getlog(im, titles, logs, tid, font)
        stack.append(im); weights.append(1.0)
    ids = [t for t, _ in titles]
    for li in (0, 10, 30, 58):                     # the title list (list mode, light off)
        im = base.copy(); im[42:51, 311:313] = 79
        mm.printxy2.bright = False
        mm.displaylist(im, titles, ids, li, font)
        stack.append(im); weights.append(3.0)
    hist = bf.hist_of(stack, weights)
    for cur in cursors:                            # the cursor can be on any line
        cnt = np.bincount(cur[cur != 255].ravel() if (cur == 255).any() else cur.ravel(), minlength=256)
        hist += cnt[None, :] * 0.5
    d = bf.fit(hist, pal)
    save_mode(out, 'LOG', d, base, pal)
    open(os.path.join(out, 'LOGCUR.DAT'), 'wb').write(b''.join(x.astype(np.uint8).tobytes() for x in cursors))
    if prev:
        im = base.copy(); im[42:51, 311:313] = 63
        mm.printxy2.bright = False
        mm.getlog(im, titles, logs, 10, font)
        preview(prev, d, im)
    print('LOG: splits', d.splits, 'err %.0f' % d.err)
    return d


def fake_planet(state, mode, psize, water, seed):
    return dict(system=1, orbit=1, psize=psize, water=water, state=state, mode=mode, bots=0, notes=0,
                datem=0, datey=0, visits=0, seed=seed, cache=[0] * 7, age=0)


def snap_to_reps(d, pal):
    """band colours := their rep index's colour on the 4-bit grid, so vid_set256(colors) (the
    original's set256colors) leaves them as they are"""
    table = []
    for b, (line, cols) in enumerate(d.table):
        new = []
        for sl in range(16):
            r = d.reps[b * 16 + sl]
            new.append(c.to_ste_word(np.round(pal[r] * 15 / 63).astype(int)))
        table.append((line, new))
    d.table = table


def main_mode(src, out, font, prev=None):
    """MAIN: the bridge (starter.pas initializedata, utils2.pas reloadbackground/readyplanet,
    usecode.pas readystatus, journey.pas text box and cube)"""
    import fpcrand
    w, h, main, pal, _ = c.read_cpr(os.path.join(src, 'main.cpr'))
    _, _, cloud, _, _ = c.read_cpr(os.path.join(src, 'cloud.cpr'), pal)
    icons = mm.read_icons(os.path.join(out, 'ICONS.VGA'))
    rng = np.random.RandomState(7)
    stack, weights = [], []
    planets = [(5, 3, 4, 46), (5, 3, 2, 30), (6, 1, 0, 10), (2, 3, 4, 40), (2, 3, 2, 60), (3, 1, 4, 50),
               (4, 2, 2, 45), (1, 1, 4, 30), (2, 1, 0, 70), (2, 2, 3, 20)]
    for k, (st, mo, ps, wa) in enumerate(planets):
        bgx, bgy = rng.randint(320), rng.randint(200)
        im = mm.bridge_base(main, cloud, bgx, bgy)
        tp = [fake_planet(st, mo, ps, wa, 1000 + 77 * k)]
        P = mm.Planet(tp, 1, fpcrand.FpcRandom(0))
        P.makesphere(im, rng.randint(240))
        mm.readystatus(im, font)
        mm.displaystatus(im, [(rng.randint(1, 1000), 1000), (rng.randint(1, 200), 200), (rng.randint(1, 32000), 32000), (rng.randint(0, 101), 100)], font)
        mm.showtime(im, [2, 3, 3784, 8, 75], font)
        cb = mm.cube_image(icons, k % 6)
        im[145:190, 215:266] = cb
        cm.printxy(im, 208, 128, ['Psychometry', 'Engineering', '  Science  ', ' Security  ', 'Astrogation', '  Medical  '][k % 6], 45, 0, font)
        for li, col in enumerate((31, 94, 63, 47, 45, 191)):
            cm.printxy(im, 9, 150 + 6 * li, 'SECURITY: Shield integrity ok', col, 3, font)
        stack.append(im); weights.append(1.0)
    # alert button and status lights in their three colours, research lights, the approach screen
    for tc in (48, 80, 112):                       # checkstats colorarea, setalertmode
        im = mm.bridge_base(main, cloud, 0, 0)
        im[184:200, 0:8] = (im[184:200, 0:8].astype(int) + tc - 80) & 255
        for y0 in (29, 49, 69, 89):
            reg = im[y0:y0 + 11, 300:314]
            reg[reg != 0] = (reg[reg != 0].astype(int) + tc) & 255
        stack.append(im); weights.append(0.5)
    ap = np.zeros((200, 320), np.uint8)
    cm.printxy(ap, 30, 160, 'Approaching planet...', 47, 0, font)
    cm.printxy(ap, 30, 170, 'ETA T Minus 123 hrs', 47, 0, font)
    stack.append(ap); weights.append(0.3)
    hist = bf.hist_of(stack, weights)
    for v in (63, 95):
        hist[150:190, v] += 4
    for tc in (48, 80, 112):                       # the status lights and the panic button matter
        lit = mm.bridge_base(main, cloud, 0, 0)
        for y0 in (29, 49, 69, 89):
            reg = lit[y0:y0 + 11, 300:314]
            reg[reg != 0] = (reg[reg != 0].astype(int) + tc) & 255
            for y in range(y0, y0 + 11):
                hist[y] += np.bincount(lit[y, 300:314], minlength=256) * 6
        pb = (main[184:200, 0:8].astype(int) + tc - 80) & 255
        for y in range(184, 200):
            hist[y] += np.bincount(pb[y - 184], minlength=256) * 6
    d = bf.fit(hist, pal)
    snap_to_reps(d, pal)
    # header-only ISP2 (the bridge is composed at run time) + main.cpr and cloud.cpr as chunky
    open(os.path.join(out, 'MAIN.ISP'), 'wb').write(bytes(d.isp_header(w=0, h=0)))
    open(os.path.join(out, 'MAIN.CHK'), 'wb').write(main.astype(np.uint8).tobytes() + bytes(pal.astype(np.uint8).ravel()))
    open(os.path.join(out, 'CLOUD.CHK'), 'wb').write(cloud.astype(np.uint8).tobytes())
    if prev:
        Image.fromarray(d.rgb(stack[0])).resize((640, 400), Image.NEAREST).save(prev)
        Image.fromarray(d.rgb(stack[3])).resize((640, 400), Image.NEAREST).save(prev.replace('.png', '2.png'))
    print('MAIN: splits', d.splits, 'err %.0f' % d.err)
    return d


EX_SETCOLORS = {1: (0, 144, 80, 50), 2: (0, 144, 33, 50), 3: (0, 144, 32, 50), 4: (0, 144, 32, 40),
                5: (0, 144, 32, 30), 6: (0, 144, 32, 0)}    # explore.pas setcolors: gindex g2index waterindex water


def ex_landlut(water, gi, g2, wi, spc):
    """explore.pas displaylandform per landform value (None: landcolors keeps its byte)"""
    part = 31 / (255 - water)
    part2 = 5 / water if water > 0 else 0
    lut = []
    for v in range(256):
        if v < water: lut.append(round(v * part2) + wi)
        elif v <= 246:
            i = round((v - water) * part)
            lut.append(i * 2 + g2 if i >= 16 else i * 2 + gi if i >= 6 else spc[i])
        else: lut.append(None)
    return lut


def ex_zoomlut(water, gi, g2, wi, spc):
    """explore.pas showzoom per zoomscr value"""
    part = 73 / (255 - water)
    part2 = 5 / water if water > 0 else 0
    lut = []
    for v in range(256):
        if v == 255: lut.append(95); continue
        if v < water: lut.append(wi + round(part2 * v)); continue
        i = round((v - water) * part)
        i = g2 + i - 10 if i >= 42 else gi + i - 10 if i >= 11 else spc[i // 2]
        lut.append(95 if i == 64 else i & 255)
    return lut


def land_mode(src, out, font, prev=None):
    """LAND: planet exploration (explore.pas): landform.cpr; training = the land map of each planet
    type, the zoom window, the probes' views, the summary page and the data pages, the scan
    buttons in their three colours; index 235 (the anomaly marker, pulsed green by the main loop)
    has its own slot over the map"""
    import fpcrand
    w, h, base, pal, _ = c.read_cpr(os.path.join(src, 'landform.cpr'))
    rng = np.random.RandomState(11)
    stack, weights = [], []
    msgs = [base[20:28, j * 20 + 10:j * 20 + 26].copy() for j in range(1, 8)]
    clean = base.copy()
    clean[13:134, 28:268] = 0
    planets = [(1, 1, 2, 30), (2, 3, 3, 40), (3, 1, 4, 50), (3, 2, 2, 20), (4, 2, 2, 45), (4, 1, 1, 60),
               (5, 1, 2, 30), (5, 3, 3, 10), (6, 1, 0, 10), (2, 2, 4, 60)]
    for k, (st, mo, ps, wa) in enumerate(planets):
        tp = [fake_planet(st, mo, ps, wa, 2000 + 131 * k)]
        P = mm.Planet(tp, 1, fpcrand.FpcRandom(0))
        gi, g2, wi, water = EX_SETCOLORS[st]
        if st == 5 and mo == 3: water = 0
        spc = P.spc
        lut = ex_landlut(water, gi, g2, wi, spc)
        zl = ex_zoomlut(water, gi, g2, wi, spc)
        im = clean.copy()
        L = P.land
        for y in range(1, 121):
            for x in range(1, 241):
                v = lut[L[x, y]]
                if v is not None: im[y + 12, x + 27] = v
        zx, zy = rng.randint(1, 170), rng.randint(1, 55)
        zoom = np.zeros((61, 61), np.uint8)
        for a in range(30):
            for b in range(30):
                l0 = int(L[zx + a, zy + b])
                zoom[a * 2 + 1, b * 2 + 1] = l0
                zoom[a * 2 + 2, b * 2 + 1] = (l0 + round((int(L[zx + a + 1, zy + b]) - l0) / 2)) & 255
                zoom[a * 2 + 1, b * 2 + 2] = (l0 + round((int(L[zx + a, zy + b + 1]) - l0) / 2)) & 255
                zoom[a * 2 + 2, b * 2 + 2] = (l0 + round((int(L[zx + a + 1, zy + b + 1]) - l0) / 2)) & 255
        for i in range(1, 61):
            for j in range(1, 61):
                im[i + 138, j + 205] = zl[zoom[j, i]]
        for r in (8, 16, 4, 8):
            mm_circle(im, 236, 169, r, 47)
        for j in range(1, 5):                       # probes' live views of the map
            px, py = rng.randint(30, 200), rng.randint(30, 80)
            im[j * 40 - 25:j * 40 + 1, 281:313] = im[py:py + 26, px + 11:px + 43]
        for i in range(1, 6):                       # scan buttons
            cc = [112, 80, 48][(i + k) % 3]
            reg = im[9 * i + 14:9 * i + 17, 2:21]
            reg[reg >= 32] = (reg[reg >= 32] & 15) | cc
        for ln in range(7):
            cm.printxy(im, 8, 155 + ln * 6, ['Hydrogen', 'Iron Oxide', 'Silicon', 'Nitrogen', 'Water', 'Methane', 'Gold'][ln], 207, 0, font)
        stack.append(im); weights.append(1.0)
    # the summary page
    im = clean.copy()
    for y, t in enumerate(['Seismic Activity', 'Atmospheric Activity', 'Atmospheric Pressure', 'Relative Gravity',
                           'Per Cent Hydro', 'Per Cent Bio', 'Life Forms', 'Population', 'Technology Level',
                           'Temperature', 'Surface Radiation', 'Planet State']):
        cm.printxy(im, 50, 21 + 6 * y, t, 192, 0, font)
        cm.printxy(im, 200, 21 + 6 * y, 'Moderate', 31, 0, font)
    cm.printxy(im, 113, 14, 'Planet Summary', 207, 0, font)
    cm.printxy(im, 95, 94, 'Most Common Compounds', 207, 0, font)
    yy, xx = np.mgrid[-20:21, -20:21]
    disc = xx * xx + yy * yy <= 400
    for k, cc in enumerate((95, 92, 89, 86, 80)):
        sub = im[94:135, 43:84]
        sub[disc & (xx > 10 - 8 * k)] = cc
        cm.printxy(im, 120, 101 + k * 6, '12.34% Iron', cc, 0, font)
    stack.append(im); weights.append(2.0)
    hist = bf.hist_of(stack, weights)
    for v in (90, 91, 92, 93, 94, 95, 235):        # probe dots, the anomaly
        hist[13:134, v] += 3
    d = bf.fit(hist, pal, own=[(13, 134, [235], 1)])
    snap_to_reps(d, pal)
    save_mode(out, 'LAND', d, base, pal)
    if prev:
        preview(prev, d, stack[1])
        preview(prev.replace('.png', '2.png'), d, stack[-1])
    print('LAND: splits', d.splits, 'err %.0f' % d.err)
    return d


def char2_mode(src, out, font, prev=None):
    """CHAR2: crew status (crewinfo.pas crewstats): char2.cpr with the lower text area cleared;
    training = every crew member's portrait, name, description, xp/level, the sanity bar, the
    stats graph (a polyline from (16,50) in the 32 colour-cycled indices 128-159: own slots)"""
    w, h, base, pal, _ = c.read_cpr(os.path.join(src, 'char2.cpr'))
    crew = cm.read_crew(os.path.join(src, 'crew.dta'))
    rng = np.random.RandomState(5)
    clean = base.copy()
    clean[130:197, 4:266] = 0
    holo = clean[35:64, 84:120].copy()
    stack, weights = [], []
    for n in range(30):
        im = clean.copy()
        im[14:89, 16:201] = 0
        im[35:64, 84:120] = holo
        px, py = 16, 50                             # lineto: a polyline (c_utils.c line moves the pen)
        for j in range(19, 200, 3):
            i = int(rng.randint(-36, 37))
            cm.line(im, px, py, j, i + 51, (j - 16) % 32 + 128)
            px, py = j, i + 51
        _, _, por, _, _ = c.read_cpr(os.path.join(src, 'image%02d.cpr' % (n + 1)))
        im[16:86, 220:290] = por
        cr = crew[n]
        im[103:109, 121:240] = 0
        cm.printxy(im, 121 + (120 - len(cr['name'].rstrip()) * 6) // 2, 103, cr['name'].rstrip(), 170, 0, font)
        for a in range(10):
            cm.printxy(im, 0, 130 + a * 6, cr['desc'][a], 170, 0, font)
        cm.printxy(im, 198, 120, '%010d' % rng.randint(0, 99999), 170, 0, font)
        cm.printxy(im, 154, 120, '%2d' % rng.randint(0, 20), 170, 0, font)
        jj = rng.randint(1, 101)
        t1 = 25 / (jj * 0.68)
        for i in range(26, 26 + round(jj * 0.68) + 1):
            im[i, 309:311] = round((i - 26) * t1) + 70
        stack.append(im); weights.append(1.0)
    hist = bf.hist_of(stack, weights)
    for v in (63, 104, 92, 124):                    # the cursor and the level lights
        hist[101:160, v] += 20
    d = bf.fit(hist, pal, own=[(14, 89, list(range(128, 160)), 6)])
    snap_to_reps(d, pal)
    save_mode(out, 'CHAR2', d, base, pal)
    if prev:
        preview(prev, d, stack[0])
    print('CHAR2: splits', d.splits, 'err %.0f' % d.err)
    return d


PSY_JOBS = ['Psychometry', 'Engineering', '  Science  ', ' Security ', 'Astrogation', '  Medical  ']


def psyche_mode(src, out, font, prev=None):
    """PSYCHE: psychometry (crew2.pas psyche): psyche.cpr; training = every portrait and the
    graph display, the stat bars, the jobs and names. Two colour groups change at run time and
    get own slots: 96-127 (the tank and the stat bars: recoloured per crew member by drawgraphs)
    and 128-159 (the graph and the bars: cycled by adjustgraph)"""
    w, h, base, pal, _ = c.read_cpr(os.path.join(src, 'psyche.cpr'))
    crew = cm.read_crew(os.path.join(src, 'crew.dta'))
    rng = np.random.RandomState(9)
    stack, weights = [], []
    for n in range(30):
        im = base.copy()
        _, _, por, _, _ = c.read_cpr(os.path.join(src, 'image%02d.cpr' % (n + 1)))
        if n % 3 == 2:                              # the graph display
            im[110:181, 145:286] = 0
            px, py = 145, 145
            for j in range(147, 286, 3):
                i = int(rng.randint(-34, 35))
                cm.line(im, px, py, j, i + 145, (j - 16) % 32 + 128)
                px, py = j, i + 145
        else:
            im[110:180, 210:280] = por
            nm = crew[n]['name'].split(' ')[0]
            cm.printxy(im, 241 - round(len(nm) * 2.5), 111, nm, 95, 255, font)
        im[81:89, 210:281] = 0
        jb = PSY_JOBS[n % 6]
        cm.printxy(im, 241 - round(len(jb) * 2.5), 81, jb, 191, 0, font)
        for k, y in enumerate((20, 28, 36)):          # gradientbar: 2 rows of 137+, 1 row of 105+
            for (yy, hh, c0) in ((y, 2, 137), (y + 2, 1, 105)):
                b = rng.randint(1, 100)
                m = max(0, min(b * 63 // 99, 63))
                for xx in range(63):
                    im[yy:yy + hh, 179 + xx] = (c0 + xx * 22 // max(m - 1, 1)) if xx < m else 0
        for x0, c0, r in ((297, 95, 23), (299, 63, 14), (301, 207, 14), (303, 31, 23)):
            v = rng.randint(1, 100)
            hgt = round(0.34 * v)
            for k2, y in enumerate(range(145 - hgt, 146)):
                im[y, x0] = round(c0 - k2 * r / max(hgt, 1))
        stack.append(im); weights.append(1.0)
    hist = bf.hist_of(stack, weights)
    g1, g2 = list(range(96, 128)), list(range(128, 160))
    d = bf.fit(hist, pal, own=[(20, 41, g1, 3), (94, 168, g1, 4), (20, 41, g2, 3), (110, 181, g2, 2)])
    snap_to_reps(d, pal)
    save_mode(out, 'PSYCHE', d, base, pal)
    if prev:
        preview(prev, d, stack[0])
        preview(prev.replace('.png', '2.png'), d, stack[2])
    print('PSYCHE: splits', d.splits, 'err %.0f' % d.err)
    return d


def read_cargo_names(path):
    """data/cargo.dta (DOS): records name string[20], size, index (25 bytes)"""
    d = open(path, 'rb').read()
    return [d[k + 1:k + 1 + d[k]].decode('latin-1') for k in range(0, len(d) - 24, 25)]


def cargo_mode(src, out, font, prev=None):
    """CARGO: the cargo hold (cargtool.pas inventory): cargo.cpr; training = the list and info
    views (shaded text 28 on 0 / 6), the filter lights, the request box; the ceiling light chase
    (indices 232-239 on row 17, setrgb256 per frame) has 8 own slots"""
    w, h, base, pal, _ = c.read_cpr(os.path.join(src, 'cargo.cpr'))
    names = read_cargo_names(os.path.join(src, 'cargo.dta'))
    rng = np.random.RandomState(13)
    stack, weights = [], []
    for k in range(12):
        im = base.copy()
        im[20:131, 90:234] = 0
        im[110:127, 92:228] = base[110:127, 92:228]
        if k % 2 == 0:
            for y in range(1, 14):
                nm = names[rng.randint(len(names))]
                cm.printxy(im, 86, 16 + y * 6, '%3d(%3d)%s' % (rng.randint(1, 99), 0, nm), 28, 6 if y == 7 else 0, font)
        else:
            for y in range(1, 5):
                nm = names[rng.randint(len(names))]
                cm.printxy(im, 92, 2 + y * 20, nm, 28, 6 if y == 1 else 0, font)
                cm.printxy(im, 100, 8 + y * 20, 'Type: Device   ', 28, 0, font)
                cm.printxy(im, 100, 14 + y * 20, 'Size:   47.0', 28, 0, font)
                cm.printxy(im, 175, 14 + y * 20, 'Num:  2', 28, 0, font)
        for a in (1, 2):
            for b in (0, 1):
                im[72 + a * 5:75 + a * 5, 269 + b * 9:277 + b * 9] = 48 + rng.randint(2) * 8
        if k % 4 == 3:                              # the request box
            cm.button(im, 75, 60, 245, 102, 0)
            for x0 in (78, 135, 192):
                cm.button(im, x0, 78, x0 + 50, 92, 2)
            cm.printxy(im, 100, 65, 'Jettison Probot?', 26, 35, font)
            for x0, t in ((92, 'All'), (146, 'Half'), (206, 'One')):
                cm.printxy(im, x0, 82, t, 26, 37, font)
        stack.append(im); weights.append(1.0)
    hist = bf.hist_of(stack, weights)
    d = bf.fit(hist, pal, own=[(17, 18, list(range(232, 240)), 8)])
    snap_to_reps(d, pal)
    save_mode(out, 'CARGO', d, base, pal)
    if prev:
        preview(prev, d, stack[0])
        preview(prev.replace('.png', '2.png'), d, stack[3])
    print('CARGO: splits', d.splits, 'err %.0f' % d.err)
    return d


def tech1_mode(src, out, font, prev=None):
    """TECH1: the creation screen (cargtool.pas creation): tech1.cpr; training = the lists in
    their colours, the parts, the item info, the weapon figures and icon, the team lights and
    progress bar, the stat lights"""
    w, h, base, pal, _ = c.read_cpr(os.path.join(src, 'tech1.cpr'))
    names = read_cargo_names(os.path.join(src, 'cargo.dta'))
    icons = open(os.path.join(src, 'weapicon.dta'), 'rb').read()
    rng = np.random.RandomState(17)
    stack, weights = [], []
    for k in range(16):
        im = base.copy()
        for y in range(1, 17):
            col = [47, 79, 143, 31, 16][rng.randint(5)]
            cm.printxy(im, 6, 16 + y * 6, names[rng.randint(len(names))], col, 6 if y == 8 else 0, font)
        for j in range(1, 4):
            col = [95, 63, 127, 26][rng.randint(4)]
            nm = names[rng.randint(len(names))].split(' ')
            cm.printxy(im, 140, j * 21 + 19, nm[0], col, 0, font)
            cm.printxy(im, 140, j * 21 + 25, ' '.join(nm[1:]).strip(), col, 0, font)
        nm = names[rng.randint(len(names))]
        cm.printxy(im, 230, 59, nm.split(' ')[0], 28, 0, font)
        cm.printxy(im, 1, 160, nm, 24, 165, font)
        for j in range(4):
            cm.printxy(im, 1, 169 + j * 6, 'Some information about it here', 18, 2, font)
        if k % 2:                                   # weapon figures, bars and icon
            im[3:30, 132:312] = 1
            cm.printxy(im, 127, 2, nm, 31, 1, font)
            for j, t in enumerate((' Range:  12 KKM', 'Energy:  45 GW', 'Damage:  30 GJ')):
                cm.printxy(im, 127, 11 + 6 * j, t, 95, 1, font)
            for j, t in enumerate(('PSION', 'PRTCL', 'INRTL', 'ENRGY')):
                cm.printxy(im, 230, 5 + 6 * j, t, 95, 1, font)
            for j in range(1, 5):
                xx = rng.randint(0, 51)
                for i in range(-1, 5):
                    yv = 100 - i if i > 0 else 100 + i
                    im[1 + i + j * 6, 260:260 + xx] = yv
                    im[1 + i + j * 6, 260 + xx:310] = 0
            n = rng.randint(0, 80)
            ic = np.frombuffer(icons[n * 400:(n + 1) * 400], np.uint8).reshape(20, 20)
            im[9:29, 210:230] = ic
        else:
            im[3:30, 132:312] = 1
        for a in range(1, 4):
            im[114 + a * 10, 204:208] = [60, 95][rng.randint(2)]
        b = rng.randint(1, 77)
        for j in range(b + 1):
            im[77:81, 222 + j] = round(15 / b * j + 48)
        for a in range(5):
            jj = rng.randint(0, 6)
            x = 31 - a
            for i in range(jj + 1):
                x -= 2
                im[134 - i, a * 3 + 219:a * 3 + 221] = x
        stack.append(im); weights.append(1.0)
    hist = bf.hist_of(stack, weights)
    for v in (60, 63, 95):
        hist[:, v] += 10
    d = bf.fit(hist, pal)
    snap_to_reps(d, pal)
    save_mode(out, 'TECH1', d, base, pal)
    if prev:
        preview(prev, d, stack[1])
    print('TECH1: splits', d.splits, 'err %.0f' % d.err)
    return d


def mm_circle(img, x, y, r, col):
    """c_utils.c circle (aspect 0.9)"""
    E = 0.9
    def px(a, b):
        if 0 <= b < 200 and 0 <= a < 320: img[b, a] = col
    xx, yy = 0, r
    for sx in (1, -1):
        for sy in (1, -1): px(x + sx * xx, int(y + sy * yy * E))
    while yy >= 1:
        yy -= 1
        if xx * xx + yy * yy < r * r: xx += 1
        if xx * xx + yy * yy < r * r: yy += 1
        for sx in (1, -1):
            for sy in (1, -1): px(x + sx * xx, int(y + sy * yy * E))


def portraits(src, out):
    """PORTRAIT.DAT: image01-30.cpr as 70x70 chunky (utils.pas showchar's portraits)"""
    b = bytearray()
    for n in range(1, 31):
        w, h, img, _, _ = c.read_cpr(os.path.join(src, 'image%02d.cpr' % n))
        assert (w, h) == (70, 70)
        b += img.astype(np.uint8).tobytes()
    open(os.path.join(out, 'PORTRAIT.DAT'), 'wb').write(b)


def sphere_dat(out):
    """SPHERE.DAT: per radius (900, 2000, 3025): radius r2 offset maxspherei spherei xw (words),
    then for rows 6..maxspherei: pm.w, n.w, the n texture columns of the row (bytes, padded to
    even) - what readyplanet/makesphere compute with reals (FPC doubles, banker's rounding).
    A word 0 ends the file."""
    b = bytearray()
    for radius in (900, 2000, 3025):
        g = mm.sphere_geometry(radius)
        b += struct.pack('>6h', radius, g['r2'], g['offset'], g['maxspherei'], g['spherei'], g['xw'])
        for i in range(6, g['maxspherei'] + 1):
            idx = mm.row_indices(g, i)
            b += struct.pack('>hh', g['pm'][i], len(idx)) + bytes(idx)
            if len(idx) & 1: b += b'\0'
    b += b'\0\0'
    open(os.path.join(out, 'SPHERE.DAT'), 'wb').write(b)


def cube_dat(out):
    """CUBE.DAT: the cube rotations' frames (journey.pas rotatecube2: horizontal, 21 frames over
    columns 202-278; rotatecube: vertical, 20 frames over rows 133-199). Per frame and column
    (row): source code.b, index.b - 0 keep, 1 cubetar, 2 cubesrc, 3 back3/back1, 4 back4/back2."""
    import math
    b = bytearray()
    for t in range(1, 22):
        m = round(10.5624 * math.sin(3 * t / 20)); q = round(math.sin(3 * t / 40) * 51)
        col = {}
        part = 51 / q
        for j in range(q):
            index = round(j * part)
            if index < 51: col[j + 215 - m] = (1, index)
        if 51 + 2 * m - q != 0:
            part = 51 / (51 + 2 * m - q)
            for j in range(215 - m + q, 266 + m + 1):
                index = round((j - 215 + m - q) * part)
                if index < 51: col[j] = (2, index)
        for j in range(266 + m, 279): col[j] = (4, j - 266)
        for j in range(202, 214 - m + 1): col[j] = (3, j - 202)
        for x in range(202, 279): b += bytes(col.get(x, (0, 0)))
    for t in range(1, 21):
        m = round(10.5624 * math.sin(3 * t / 20)); q = round(math.sin(3 * t / 40) * 45)
        row = {}
        part = 45 / q
        for j in range(q):
            index = round(j * part)
            if index < 46: row[j + 145 - m] = (1, index)
        if 45 + 2 * m - q != 0:
            part = 45 / (45 + 2 * m - q)
            for j in range(145 - m + q, 188 + m + 1):
                index = round((j - 145 + m - q) * part)
                if index < 46: row[j] = (2, index)
        for j in range(133, 145 - m + 1): row[j] = (3, j - 133)
        for j in range(190 + m, 200): row[j] = (4, j - 190)
        for y in range(133, 200): b += bytes(row.get(y, (0, 0)))
    open(os.path.join(out, 'CUBE.DAT'), 'wb').write(b)


def main():
    src, out = sys.argv[1:3]
    prev = sys.argv[3] if len(sys.argv) > 3 else None
    font = cm.load_font()[0]
    log_mode(src, out, font, prev and os.path.join(prev, 'log_preview.png'))
    main_mode(src, out, font, prev and os.path.join(prev, 'main_preview.png'))
    land_mode(src, out, font, prev and os.path.join(prev, 'land_preview.png'))
    char2_mode(src, out, font, prev and os.path.join(prev, 'char2_preview.png'))
    psyche_mode(src, out, font, prev and os.path.join(prev, 'psyche_preview.png'))
    cargo_mode(src, out, font, prev and os.path.join(prev, 'cargo_preview.png'))
    tech1_mode(src, out, font, prev and os.path.join(prev, 'tech1_preview.png'))
    portraits(src, out)
    sphere_dat(out)
    cube_dat(out)


if __name__ == '__main__':
    main()
