#!/usr/bin/env python3
"""mkload.py SRC_DATA OUT_DATA [preview.png] - LOADG: the band design of saveload.pas
loadgamedata(true) (MAIN.PRG started without a slot: IS.PRG's Continue): the load dialog over
cloud.cpr, which mainloop(true) scrolls by whole-screen rotations (k = 0..63999). Colours are
main.pal's (colors at that point). Training: the dialog (buttons 32-40, text 26 on 35/37, the
cursor's +3 fade) over the cloud at many offsets. LOADG.ISP/CHK are black (the stars come from
CLOUD.CHK at run time)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
import cpr2st as c, cgmodel as cm, bandfit as bf
from mkmain import save_mode, snap_to_reps, preview


def dialog(im, font, cursor):
    cm.button(im, 75, 40, 244, 140, 0)
    for a in range(1, 9):
        cm.button(im, 85, 40 + a * 10, 235, 48 + a * 10, 2)
    cm.button(im, 185, 130, 225, 138, 2)
    cm.printxy(im, 130, 41, 'Load Game', 26, 35, font)
    cm.printxy(im, 85, 131, 'v1.30.0001 STE 0.4  ', 26, 35, font)
    for a in range(1, 9):
        cm.printxy(im, 85, 41 + a * 10, ['Main', 'Test', 'Lost in space', ' ' * 20][a % 4].ljust(20), 26, 37, font)
        cm.printxy(im, 187, 41 + a * 10, '%2d/%5d' % (a, 3784 + a), 26, 37, font)
    cm.printxy(im, 187, 131, 'Cancel', 26, 37, font)
    if cursor:
        if cursor < 9:
            cm.plainfadearea(im, 85, 40 + cursor * 10, 235, 47 + cursor * 10, 3)
        else:
            cm.plainfadearea(im, 185, 130, 225, 138, 3)


def main():
    src, out = sys.argv[1:3]
    pal = np.frombuffer(open(os.path.join(src, 'main.pal'), 'rb').read()[:768], np.uint8).reshape(256, 3).astype(int)
    cloud = c.read_cpr(os.path.join(src, 'cloud.cpr'), pal)[2]
    font = cm.load_font()[0]
    rng = np.random.RandomState(5)
    stack, weights = [], []
    for k in range(16):
        im = np.roll(cloud.ravel(), rng.randint(64000)).reshape(200, 320).copy()
        dialog(im, font, k % 10)
        stack.append(im); weights.append(1.0)
    d = bf.fit(bf.hist_of(stack, weights), pal)
    snap_to_reps(d, pal)
    save_mode(out, 'LOADG', d, np.zeros((200, 320), np.uint8))
    if len(sys.argv) > 3:
        preview(sys.argv[3], d, stack[3])
    print('LOADG: splits', d.splits, 'err %.0f' % d.err)


if __name__ == '__main__':
    main()
