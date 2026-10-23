#!/usr/bin/env python3
"""mkegg.py SRC_DATA OUT_DATA [preview_dir] - the band designs of weird.pas's easter eggs in MAIN.PRG:

  EGGN  easteregg2/4/5: random(16)+200+(row mod 2)*16 noise over the whole screen (drawn at run
        time with the game's generator), the Channel 7 box, the buttons, egg 2's portraits.
        The noise flickers by palette (200-215 lit / 216-231 black, then the other way round):
        own slots for both halves in every band (the colours come from colors[random(22)] and
        colors[random(16)] each frame). ISP header only, CHK all zero (the code draws all of it).
  EGG3  easteregg3 (the song chooser): graybutton(0,0,319,199) is the mode's picture and shadow;
        the code draws the rest over it.
  EGG6  easteregg6: intro3.cpr with its palette (loadscreen sets colors).
  EGG.DAT  image31/image32 (70x70) already put through egg 2's index transform
        (<32: div 2, else (p-128) div 2 as a byte).
Colours are main.pal's (the bridge's colors when the eggs start), the bands snapped to their
reps so set256colors(colors) leaves the non-flickering slots alone."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import numpy as np
import cpr2st as c, cgmodel as cm, bandfit as bf, mainmodel as mm
from mkmain import save_mode, snap_to_reps, preview

NOISE = list(range(200, 216)), list(range(216, 232))
K_OWN = 4


def noise(rng):
    s = np.zeros((200, 320), np.uint8)
    for i in range(200):
        s[i] = rng.randint(0, 16, 320) + 200 + (i % 2) * 16
    return s


def portrait(src, n):
    p = c.read_cpr(os.path.join(src, 'image%02d.cpr' % n))[2][:70, :70].astype(int)
    q = np.where(p < 32, p // 2, np.trunc((p - 128) / 2).astype(int) % 256)
    return q.astype(np.uint8)


def chan7(im, font, title=True):
    cm.graybutton(im, 40, 53, 280, 153)
    cm.graybutton(im, 110, 25, 210, 61)
    cm.printxy(im, 134, 30, 'Channel 7', 47, 5, font)
    cm.printxy(im, 116, 50, 'Destiny: Virtual', 47, 5, font)


def egg2(im, font, p31, p32):
    chan7(im, font)
    for k, s in enumerate(('Welcome', 'To The', 'Channel 7', 'Easteregg', 'Hunt!')):
        cm.printxy(im, (139, 141, 134, 134, 144)[k], 70 + 10 * k, s, 188, 5, font)
    cm.graybutton(im, 80, 146, 240, 160)
    mm.revgraybutton(im, 49, 68, 120, 139)
    mm.revgraybutton(im, 200, 68, 271, 139)
    cm.printxy(im, 91, 150, "DON'T TOUCH THIS BUTTON!!!", 92, 5, font)
    im[69:139, 50:120] = p31
    im[69:139, 201:271] = p32


def egg45(im, font, labels):
    chan7(im, font)
    cm.printxy(im, 56, 130, 'Welcome To The Channel 7 Easteregg Hunt!', 188, 5, font)
    cm.graybutton(im, 80, 146, 240, 160)
    cm.printxy(im, 91, 150, "DON'T TOUCH THIS BUTTON!!!", 92, 5, font)
    for x1, y1, x2, y2 in ((56, 80, 156, 95), (163, 80, 263, 95), (56, 100, 156, 115), (163, 100, 263, 115)):
        cm.graybutton(im, x1, y1, x2, y2)
    for x, y, s in labels:
        cm.printxy(im, x, y, s, 92, 5, font)


EGG4 = ((57, 84, 'Repair Hull Damage'), (67, 104, 'Fill Fuel Tank'), (174, 84, 'Repair Damages'), (169, 104, 'Recharge Battery'))
EGG5 = ((77, 84, 'Add a Dirk'), (54, 104, 'Add Reflective Hull'), (177, 84, 'Add Component'), (179, 104, 'Add Material'))
SONGS = ((30, 38, 'Sengzhac'), (35, 72, "D'Pahk"), (40, 106, 'Aard'), (33, 140, 'Ermigen'), (134, 38, 'Titarian'),
         (125, 72, "Quai Pa'Loi"), (130, 106, 'Scavengers'), (144, 140, 'Icon'), (236, 38, 'The Guild'),
         (229, 72, 'Phaedor Moch'), (226, 106, 'Void Dwellers'), (241, 140, 'Generic'))


def egg3(font):
    im = np.zeros((200, 320), np.uint8)
    cm.graybutton(im, 0, 0, 319, 199)
    base = im.copy()
    cm.graybutton(im, 80, 166, 240, 180)
    cm.printxy(im, 91, 170, "DON'T TOUCH THIS BUTTON!!!", 92, 5, font)
    cm.printxy(im, 113, 5, 'Set Default Song', 92, 5, font)
    for j in range(4):
        for x in (5, 109, 213):
            cm.graybutton(im, x, 35 + j * 34, x + 100, 47 + j * 34)
    for x, y, s in SONGS:
        cm.printxy(im, x, y, s, 22, 5, font)
    cm.printxy(im, 56, 183, 'Welcome To The Channel 7 Easteregg Hunt!', 188, 5, font)
    cm.printxy(im, 130, 155, '/  ', 188, 5, font)
    cm.printxy(im, 175, 155, '/63', 188, 5, font)
    cm.printxy(im, 120, 155, '  ', 188, 5, font)
    cm.printxy(im, 165, 155, '  ', 188, 5, font)
    return base, im


def main():
    src, out = sys.argv[1:3]
    pv = sys.argv[3] if len(sys.argv) > 3 else None
    pal = np.frombuffer(open(os.path.join(src, 'main.pal'), 'rb').read()[:768], np.uint8).reshape(256, 3).astype(int)
    font = cm.load_font()[0]
    rng = np.random.RandomState(11)
    p31, p32 = portrait(src, 31), portrait(src, 32)
    # EGGN
    stack, weights = [], []
    for k in range(6):
        im = noise(rng)
        [lambda i: egg2(i, font, p31, p32), lambda i: egg45(i, font, EGG4), lambda i: egg45(i, font, EGG5)][k % 3](im)
        if k >= 3:
            cm.plainfadearea(im, 80, 146, 240, 160, 3)
        stack.append(im); weights.append(1.0)
    d = bf.fit(bf.hist_of(stack, weights), pal, own=[(0, 200, NOISE[0], K_OWN), (0, 200, NOISE[1], K_OWN)])
    snap_to_reps(d, pal)
    save_mode(out, 'EGGN', d, np.zeros((200, 320), np.uint8))
    open(os.path.join(out, 'EGGN.ISP'), 'wb').write(bytes(d.isp_header(w=0, h=0)))
    print('EGGN: splits', d.splits, 'err %.0f' % d.err)
    if pv:
        for k in range(3):
            pal_now = pal.copy()
            for i in NOISE[0]: pal_now[i] = pal[rng.randint(22)]
            for i in NOISE[1]: pal_now[i] = pal[0]
            Image.fromarray(d.rgb(stack[k], pal_now)).resize((640, 400), Image.NEAREST).save(os.path.join(pv, 'eggn%d.png' % k))
    # EGG3
    base, full = egg3(font)
    f2 = full.copy(); cm.plainfadearea(f2, 80, 166, 240, 180, 3)
    d3 = bf.fit(bf.hist_of([full, f2], [1.0, 1.0]), pal)
    snap_to_reps(d3, pal)
    save_mode(out, 'EGG3', d3, base)
    print('EGG3: splits', d3.splits, 'err %.0f' % d3.err)
    if pv: preview(os.path.join(pv, 'egg3.png'), d3, full)
    # EGG6
    w, h, i3, p3, _ = c.read_cpr(os.path.join(src, 'intro3.cpr'))
    d6 = bf.fit(bf.hist_of([i3]), p3)
    snap_to_reps(d6, p3)
    save_mode(out, 'EGG6', d6, i3, p3)
    print('EGG6: splits', d6.splits, 'err %.0f' % d6.err)
    if pv: preview(os.path.join(pv, 'egg6.png'), d6, i3)
    open(os.path.join(out, 'EGG.DAT'), 'wb').write(p31.tobytes() + p32.tobytes())


if __name__ == '__main__':
    from PIL import Image
    main()
