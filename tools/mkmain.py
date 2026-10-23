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
    sphere_dat(out)
    cube_dat(out)


if __name__ == '__main__':
    main()
