#!/usr/bin/env python3
"""mkcomm.py SRC_DATA OUT_DATA [PREVIEW_DIR] - data for MAIN.PRG's communication screens
(comm.pas conversewithcrew / continuecontact, comm2.pas trade).

Pictures (chunky, as loadscreen leaves them; + the .cpr's 768-byte palette when it has one):
  CCOM.ISP/.CHK   charcom.cpr: the crew comm screen (mode, bands fitted on every portrait, the
                  crew names and the stress bars, the text box in its colours, the cursor lights)
  COM.CHK         com.cpr (the alien comm frame; 255 = where the background shows)
  BACK1..11.CHK   back*.cpr (alien backgrounds; loadbackground picks one half)
  ALIEN1..10.CHK  alien*.cpr (the alien pictures and their animation frames)
  TRADE.CHK       trade.cpr (rows 111-199 replace the text box while trading; no palette)
Band designs, header-only ISP2 (the screen is composed at run time like the original's):
  COMAn.ISP       race n = 1..11 (alien.conindex): com + its background + its alien and every
                  animation frame, the text box, the info panel, the trade panel
  COMGn.ISP       n = 30..33: the races without pictures (background random(19)+1, seed n)
  COMNR.ISP       "No response...": the static (indices 64-95 on even rows, 96-127 on odd
                  rows, recoloured every frame from colors[random(32)]: own slots)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
import cpr2st as c, cgmodel as cm, bandfit as bf, fpcrand

RACE_BACK = {1: 7, 2: 18, 3: 9, 4: 15, 5: 22, 6: 17, 7: 4, 8: 14, 9: 2, 10: 21, 11: 19}  # getcontactindex j


def rd(src, n, pal=None):
    return c.read_cpr(os.path.join(src, n + '.cpr'), pal)


def save_chk(out, name, img, pal=None):
    open(os.path.join(out, name + '.CHK'), 'wb').write(
        img.astype(np.uint8).tobytes() + (bytes(pal.astype(np.uint8).ravel()) if pal is not None else b''))


def snap_to_reps(d, pal):
    table = []
    for b, (line, cols) in enumerate(d.table):
        table.append((line, [c.to_ste_word(np.round(pal[d.reps[b * 16 + sl]] * 15 / 63).astype(int)) for sl in range(16)]))
    d.table = table


def printxy_c(img, x1, y1, s, m, n, o, font):
    """comm.pas printxy2 as it finally stands (second pass, bkcolor 0): rows t, t-1, t-3, t-4,
    t-6, t-7; chr(200) toggles bright (n) / normal (o). s: glyph codes"""
    bright = False
    x1 += 4
    for ch in s:
        if ch == 200:
            bright = not bright; continue
        t = n if bright else o
        g = font[ch - 1] if 1 <= ch <= 82 else (0, 0, 0)
        cols = [t, t - 1, t - 3, t - 4, t - 6, t - 7]
        for row in range(6):
            bits = (g[row // 2] >> (4 if row % 2 == 0 else 0)) & 15
            for k in range(4):
                img[y1 + 1 + row, x1 + 1 + k] = (cols[row] & 255) if bits & (8 >> k) else 0
        img[y1 + 1:y1 + 7, x1 + 5] = 0
        x1 += 5


def glyphs(s):
    return [cm.letter(ch) for ch in s]


SAMPLE = ['The quick brown fox jumps over the lazy dog and keeps', 'running far away into the dark forest where',
          'WE ARE AT WAR! Subject: TRADE GOODBYE WEAPONS', 'Give supplies? Cypher Acknowledged Awaiting']


def text_box(im, font, m, n, o, rng, rows=7):
    for r in range(1, rows):
        s = glyphs(SAMPLE[rng.randint(len(SAMPLE))])
        k = rng.randint(4, 40)
        s = s[:k] + [200] + s[k:k + 8] + [200] + s[k + 8:]
        printxy_c(im, 12, 135 + r * 6, s[:56], m, n, o, font)


# ---------------------------------------------------------------- the alien comm screens
def back_of(src, j):
    """loadbackground(j): back((j-1) div 2 + 1); the bottom half moved up for even j"""
    _, _, b, bp, _ = rd(src, 'back%d' % ((j - 1) // 2 + 1))
    if b.shape[0] < 200:                         # back11: 199 rows, the buffer's last row stays
        _, _, cl, _, _ = rd(src, 'cloud', bp)    # (backgr held cloud.cpr)
        b = np.vstack([b, cl[b.shape[0]:]])
    if (j - 1) % 2:
        b = b.copy(); b[:100] = b[100:]
    return b, bp


def anim_blits(n):
    """animatealien's blits for race n: (dst_y, dst_x, h, w, [(src_y, src_x), ...], opaque)"""
    L = []
    if n == 1:
        L.append((37, 85, 10, 33, [(a * 11, 220) for a in range(7)], False))
        L.append((88, 29, 19, 23, [(77, 9)] + [(((b - 1) % 7) * 20, ((b - 1) // 7) * 24 + 160) for b in range(1, 15)], False))
        L.append((89, 139, 22, 43, [(k * 23, 260) for k in range(8)], False))
    elif n == 2:
        L.append((16, 140, 55, 35, [((a % 3) * 59 + 2, (a // 3) * 38 + 164) for a in range(12)], False))
    elif n == 3:
        L.append((20, 90, 24, 24, [(b * 30, 170) for b in range(5)], False))
    elif n == 4:
        L.append((23, 91, 12, 57, [(a * 13, 170) for a in range(10)], False))
    elif n == 5:
        L.append((29, 94, 11, 49, [(a * 12, 170) for a in range(6)], True))
        L.append((41, 57, 28, 26, [(b * 28, 220) for b in range(5)], False))
        L.append((41, 155, 28, 26, [(b * 28, 250) for b in range(5)], False))
    elif n == 6:
        L.append((40, 81, 20, 38, [(a * 20, 170) for a in range(9)], False))
    elif n == 7:
        L.append((27, 88, 3, 21, [(a * 4, 180) for a in range(19)], True))
        L.append((77, 88, 34, 21, [(120, b * 21) for b in range(7)], False))
    elif n == 8:
        L.append((57, 77, 20, 53, [(a * 20, 250) for a in range(9)], False))
    elif n == 9:
        L.append((85, 53, 22, 33, [(74, 33)] + [(a * 25 - 24, 162) for a in range(1, 8)], False))
        L.append((62, 156, 23, 13, [(51, 136)] + [(b * 26 - 26, 200) for b in range(1, 6)], False))
    elif n == 10:
        L.append((51, 111, 9, 50, [(a * 10 + 101, 0) for a in range(9)], True))
    return L


def blit(im, aliens, backgr, b, k):
    y0, x0, h, w, srcs, opaque = b
    sy, sx = srcs[k]
    for i in range(h):
        for j in range(w):
            v = aliens[sy + i, sx + j]
            if opaque or v > 0:
                im[y0 + i, x0 + j] = v
            else:
                im[y0 + i, x0 + j] = backgr[y0 + i - 11, x0 + j]


def trade_panel(im, trade, font, rng, names):
    im[111:] = trade[111:]
    for y in range(1, 7):
        for x0, w in ((0, 24), (190, 20)):
            nm = names[rng.randint(len(names))]
            t = [26, 28, 31][rng.randint(3)]
            cm.printxy(im, x0, 140 + y * 6, ('%3d ' % rng.randint(1, 99) if x0 == 0 else '') + nm[:w], t, 6 if y == 3 else 0, font)
    cm.printxy(im, 93, 127, names[rng.randint(len(names))] + '(12)', 28, 0, font)
    num = rng.randint(1, 58)
    im[158:165, 131:131 + num] = [37, 47, 33][rng.randint(3)]


def info_panel(im, font, rng):
    for k, s in enumerate(['Sengzhac', 'Radio', 'Sol', 'Min Tech: 2.3', 'Max Tech: 4.5', 'Status:  Peace', 'Friendly']):
        cm.printxy(im, 217, 20 + 10 * k, s, 31, 255, font)


def read_cargo_names(path):
    d = open(path, 'rb').read()
    return [d[k + 1:k + 1 + d[k]].decode('latin-1') for k in range(0, len(d) - 24, 25)]


def com_base(src):
    _, _, com, cpal, _ = rd(src, 'com')
    return com, cpal


def scene(src, com, j, n):
    """the screen after loadbackground(j) [+ loadalienpic(n)]; the palette; backgr; aliens"""
    b, bp = back_of(src, j)
    im = com.copy()
    im[130:146, 20:36] = 0                       # (the cursor, taken from the picture)
    reg = im[11:111]; m = reg == 255; reg[m] = b[:100][m]
    pal = bp.copy(); aliens = None
    if n is not None and n < 11:
        _, _, aliens, ap, _ = rd(src, 'alien%d' % n)
        pal = ap.copy(); pal[:160] = bp[:160]
        if n != 10:
            sub = im[11:111, 20:180]; m = aliens[:100, :160] > 0; sub[m] = aliens[:100, :160][m]
    return im, pal, b, aliens


def fit_scene(src, out, name, com, j, n, font, names, trade, prev=None):
    rng = np.random.RandomState(100 + (n or 0) + j)
    base, pal, backgr, aliens = scene(src, com, j, n)
    stack, weights = [], []
    blits = anim_blits(n) if aliens is not None else []
    nfr = max([len(b[4]) for b in blits] + [1])
    for k in range(max(nfr, 12)):
        im = base.copy()
        for b in blits:
            blit(im, aliens, backgr, b, k % len(b[4]))
        if k % 3 == 0:
            info_panel(im, font, rng)
        if k % 4 == 3:
            trade_panel(im, trade, font, rng, names)
        else:
            text_box(im, font, 47, 55, 28, rng)
            cm.printxy(im, 12, 182, 'Subject:', 28, 0, font)
            cm.printxy(im, 57, 182, 'WEAPONS   ', 26, 0, font)
            if k % 4 == 1:
                cm.printxy(im, 146, 191, 'MORE', 47 - k % 6, 0, font)
        stack.append(im); weights.append(1.0)
    hist = bf.hist_of(stack, weights)
    d = bf.fit(hist, pal)
    snap_to_reps(d, pal)
    open(os.path.join(out, name + '.ISP'), 'wb').write(bytes(d.isp_header(w=0, h=0)))
    if prev:
        Image.fromarray(d.rgb(stack[0])).resize((640, 400), Image.NEAREST).save(os.path.join(prev, name + '.png'))
        Image.fromarray(d.rgb(stack[3])).resize((640, 400), Image.NEAREST).save(os.path.join(prev, name + 't.png'))
    print('%s: splits %s err %.0f' % (name, d.splits, d.err))


def fit_noresponse(src, out, com, cpal, font, prev=None):
    rng = np.random.RandomState(3)
    stack = []
    for k in range(4):
        im = com.copy()
        im[130:146, 20:36] = 0
        for i in range(10, 111):
            for jj in range(320):
                if im[i, jj] == 255:
                    im[i, jj] = rng.randint(32) + (64 if i % 2 == 0 else 96)
        cm.printxy(im, 12, 170, 'No response...', 28, 0, font)
        cm.printxy(im, 12, 135, 'Unintelligible Cypher', 28, 0, font)
        cm.printxy(im, 12, 145, 'Contact Failure', 28, 0, font)
        stack.append(im)
    hist = bf.hist_of(stack)
    d = bf.fit(hist, cpal, own=[(10, 111, list(range(64, 96)), 4), (10, 111, list(range(96, 128)), 4)])
    snap_to_reps(d, cpal)
    open(os.path.join(out, 'COMNR.ISP'), 'wb').write(bytes(d.isp_header(w=0, h=0)))
    if prev:
        pn = cpal.copy(); pn[64:96] = cpal[rng.randint(32, size=32)]; pn[96:128] = 0
        Image.fromarray(d.rgb(stack[0], pn)).resize((640, 400), Image.NEAREST).save(os.path.join(prev, 'COMNR.png'))
    print('COMNR: splits %s err %.0f' % (d.splits, d.err))


# ---------------------------------------------------------------- crew comm
def ccom_mode(src, out, font, prev=None):
    """CCOM: conversewithcrew: charcom.cpr; the names (tcolor 170), the stress bars
    (round(t1*b)+73), the portrait window (all 30 portraits), the text box (printxy2 95/42/170),
    the cursor lights (div 16 = 3 -> +32)"""
    w, h, base, pal, _ = rd(src, 'charcom')
    crew = cm.read_crew(os.path.join(src, 'crew.dta'))
    rng = np.random.RandomState(21)
    stack = []
    for n in range(30):
        im = base.copy()
        _, _, por, _, _ = rd(src, 'image%02d' % (n + 1))
        im[41:111, 126:196] = por
        for a in range(6):
            nm = crew[(n + a * 5) % 30]['name'].strip()
            first = nm.split(' ')[0]
            cm.printxy(im, (a // 3) * 230 + 17, (a % 3) * 30 + 37, first, 170, 0, font)
            jj = rng.randint(0, 37)
            for b in range(jj + 1):
                im[(a % 3) * 30 + 48:(a % 3) * 30 + 50, (a // 3) * 258 + b + 13] = round(22 / 36 * b) + 73
        a = n % 6
        reg = im[(a % 3) * 30 + 37:(a % 3) * 30 + 43, (a // 3) * 138 + 89:(a // 3) * 138 + 94]
        reg[reg // 16 == 3] += 32
        text_box(im, font, 95, 42, 170, rng)
        cm.printxy(im, 12, 182, 'Subject:', 170, 0, font)
        cm.printxy(im, 57, 182, 'HELLO', 31, 0, font)
        if n % 5 == 0:
            cm.printxy(im, 146, 191, 'MORE', 47 - n % 6, 0, font)
        stack.append(im)
    hist = bf.hist_of(stack)
    d = bf.fit(hist, pal)
    snap_to_reps(d, pal)
    slots = d.slots(base)
    open(os.path.join(out, 'CCOM.ISP'), 'wb').write(bytes(d.isp_header()) + c.planar(slots)[1])
    save_chk(out, 'CCOM', base, pal)
    if prev:
        Image.fromarray(d.rgb(stack[0])).resize((640, 400), Image.NEAREST).save(os.path.join(prev, 'CCOM.png'))
    print('CCOM: splits %s err %.0f' % (d.splits, d.err))


def main():
    src, out = sys.argv[1:3]
    prev = sys.argv[3] if len(sys.argv) > 3 else None
    font = cm.load_font()[0]
    ccom_mode(src, out, font, prev)
    com, cpal = com_base(src)
    save_chk(out, 'COM', com, cpal)
    for k in range(1, 12):
        _, _, b, bp, _ = rd(src, 'back%d' % k)
        save_chk(out, 'BACK%d' % k, b, bp)
    for k in range(1, 11):
        _, _, a, ap, _ = rd(src, 'alien%d' % k)
        save_chk(out, 'ALIEN%d' % k, a, ap)
    _, _, trade, _, _ = rd(src, 'trade', cpal)
    save_chk(out, 'TRADE', trade)
    names = read_cargo_names(os.path.join(src, 'cargo.dta'))
    for n in range(1, 12):
        fit_scene(src, out, 'COMA%d' % n, com, RACE_BACK[n], n, font, names, trade, prev)
    for n in range(30, 34):
        j = fpcrand.FpcRandom(n).random(19) + 1
        fit_scene(src, out, 'COMG%d' % n, com, j, None, font, names, trade, prev)
    fit_noresponse(src, out, com, cpal, font, prev)


if __name__ == '__main__':
    main()
