#!/usr/bin/env python3
"""mkcrewgen.py DATA_DIR OUT_DIR [--preview DIR] - CREWGEN.PRG's data (crewgen.pas).

The crew-generation screen shows different things at different times, so it gets one band
design per "mode", each fitted (tools/bandfit.py) on every composite that mode can show
(tools/cgmodel.py draws them exactly like the original):
  SHIP  level 0: char picture (with the bird), 27 ship pictures, ship text, ball frames
  CREW  levels 1-6: 30 portraits, the stats graph (colours 128-159 cycle: 8 slots of their own
        in the graph's band), crew text
  SAVE  the save-game dialog over the crew screen (the graph is static then: no own slots;
        the ST re-maps 128-159 to the band's nearest colours when it enters the mode)
  EGG   the easter egg (noise in 200-215 / 216-231 flickers by palette: own slots)
Each mode's picture of char.cpr is stored too, so the ST can switch modes by copying the
background and redrawing what is on it.

Output CGMODES.DAT:
  'CGM1', modes.w (4), then per mode: ISP2 header (bands, LUTs, reps: 8+2+136+1024+64 bytes)
  + 32000 planar bytes (char.cpr in that mode, cursor area cleared; EGG: the egg screen
  without text) + 64-byte keep mask for vid_set_keep (1 = slot keeps its fitted colour,
  0 = own slot, coloured from the palette by vid_set256)
CGDATA.DAT (all chunky, game colour indices):
  'CGD1'
  cursor     16 x 16  (char.cpr 11-26 x 131-146)
  switch     7 x 6    (char.cpr 247-253 x 107-112, toggle off)
  ship       9 x 75 x 58 (shippix.dta transposed to rows)
  ani        31 x 35 x 48
  portraits  32 x 70 x 70 (image01-32.cpr)
  bird       70 x 70 (char.cpr 13-82 x 7-76)
"""
import os, struct, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c, cgmodel as m, bandfit as bf
from fpcrand import FpcRandom

data, out = sys.argv[1:3]
prev = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
D = lambda f: os.path.join(data, f)
font = m.load_font()[0]
_, _, char, pal, _ = c.read_cpr(D('char.cpr'))
ani = m.ani_frames(D('charani.dta'))[:, :, :48]
pix = m.ship_pix(D('shippix.dta'))
crew = m.read_crew(D('crew.dta'))
ports = [c.read_cpr(D('image%02d.cpr' % (i + 1)))[2] for i in range(32)]
rng = FpcRandom(7)

SHIPS = [(h, p, v) for h in (1, 2, 3) for p in (1, 2, 3) for v in (1, 2, 3)]
GRAPH = list(range(128, 160))

base = char.copy()
base[131:147, 11:27] = 0


def ball_hist(rows=range(81, 116)):
    """the 31 ball frames, as extra weights (each frame shown briefly)"""
    h = np.zeros((200, 256))
    for f in ani:
        for i, y in enumerate(range(81, 116)):
            h[y] += np.bincount(f[i], minlength=256) * (2.0 / 31)
    return h


def switch_hist(alt):
    h = np.zeros((200, 256))
    for y in range(107, 113):
        h[y] += np.bincount((char[y, 247:254].astype(int) + alt) & 255, minlength=256)
    return h


def cursor_hist():
    cur = char[131:147, 11:27]
    h = np.zeros((200, 256))
    v = cur[cur != 255]
    for y in range(200): h[y] += np.bincount(v, minlength=256) * 0.05
    return h


# ---- SHIP mode
imgs = []
for st in SHIPS:
    s = base.copy()
    s[81:116, 22:70] = ani[0]
    m.printxy(s, 141, 100, 'Ship Selection', 191, 0, font)
    m.printxy(s, 149, 106, m.LEVELTITLES[0], 191, 0, font)
    m.drawship(s, st, font)
    m.displayship2(s, pix, st)
    imgs.append(s)
H = bf.hist_of(imgs, [1.0 / len(imgs)] * len(imgs)) + ball_hist() + switch_hist(0) + switch_hist(-144) + cursor_hist()
ship = bf.fit(H, pal)
ship_imgs = imgs

# ---- CREW mode
imgs = []
for k in range(30):
    lv = next((l for l in range(1, 7) if crew[k]['jobtype'] & (1 << (7 - l))), 1)
    imgs.append(m.crewscreen(char, ani[0], crew, k, lv, font, rng.random, ports[k]))
H = bf.hist_of(imgs, [1.0 / len(imgs)] * len(imgs)) + ball_hist() + switch_hist(0) + switch_hist(-144) + cursor_hist()
crewd = bf.fit(H, pal, own=[(14, 89, GRAPH, int(os.environ.get("GK", 6)))])
crew_imgs = imgs


# ---- SAVE mode: dialog (saveload.pas savegamedata, alt 160, text 191) over the crew screens
def dialog(s, cursor=3, typing=False):
    alt, text = 160, 191
    m.button(s, 75, 40, 244, 140, alt)
    for a in range(1, 9): m.button(s, 85, 40 + a * 10, 235, 48 + a * 10, 2 + alt)
    m.button(s, 185, 130, 225, 138, 2 + alt)
    m.printxy(s, 130, 41, 'Save Game', text, 35 + alt, font)
    m.printxy(s, 85, 131, 'v1.30.0001 STE', text - 5, 255, font)
    for a in range(1, 9):
        m.printxy(s, 85, 41 + a * 10, ' ' * 20, text - 5, 37 + alt, font)
        m.printxy(s, 187, 41 + a * 10, ' 2/ 3784', text - 5, 37 + alt, font)
    m.printxy(s, 187, 131, 'Cancel', text - 5, 37 + alt, font)
    if cursor:
        m.plainfadearea(s, 85, 40 + cursor * 10, 235, 47 + cursor * 10, 3)
    if typing:
        m.printxy(s, 85, 41 + 10 * cursor, 'Nuke Bloodaxe      ', text - 5, 40 + alt, font)
        m.printxy(s, 80 + 5 * 14, 41 + 10 * cursor, ' ', text - 5, 82, font)
    return s


imgs = []
for k in range(0, 30, 3):
    imgs.append(dialog(crew_imgs[k].copy(), cursor=1 + k % 8, typing=(k % 2 == 0)))
H = bf.hist_of(imgs, [1.0 / len(imgs)] * len(imgs)) + ball_hist() + cursor_hist()
for y in range(15, 88):  # the frozen graph: some blue of every level
    for i in range(64, 128, 2): H[y, i] += 0.4
save = bf.fit(H, pal)
save_imgs = imgs


# ---- EGG mode (crewgen.pas easteregg1); the noise is fixed per pixel, colours flicker
def egg(rand):
    s = np.zeros((200, 320), np.uint8)
    for i in range(200):
        for j in range(320):
            s[i, j] = rand(16) + 200 + (i % 2) * 16
    m.graybutton(s, 5, 23, 315, 165)
    m.graybutton(s, 80, 158, 240, 172)
    return s


eg = egg(rng.random)
egt = eg.copy()
m.printxy(egt, 53, 142, 'Welcome to the Channel 7 Easter Egg Hunt!', 188, 3, font)
m.printxy(egt, 91, 162, "DON'T TOUCH THIS BUTTON!!!", 92, 3, font)
for y in range(26, 140, 6):
    m.printxy(egt, 7, y, 'SAMPLE NAME TEXT 50/50/50', 22, 3, font)
    m.printxy(egt, 160, y, 'SAMPLE NAME TEXT 50/50/50', 92, 3, font)
eg2 = egt.copy()
m.plainfadearea(eg2, 80, 158, 240, 172, 3)
H = bf.hist_of([egt, eg2], [0.5, 0.5])
NOISE = list(range(200, 216)), list(range(216, 232))
mainpal = np.frombuffer(open(D('main.pal'), 'rb').read()[:768], np.uint8).reshape(256, 3).astype(np.int32)
egg_d = bf.fit(H, mainpal, own=[(0, 200, NOISE[0], 4), (0, 200, NOISE[1], 4)])

designs = [('SHIP', ship, base), ('CREW', crewd, base), ('SAVE', save, base), ('EGG', egg_d, eg)]
for name, d, _ in designs:
    print('%-4s bands at %-16s err %.0f' % (name, ','.join(map(str, d.splits)), d.err))

b = bytearray(b'CGM1') + struct.pack('>H', len(designs))
for name, d, bg in designs:
    b += d.isp_header()
    b += c.planar(d.slots(bg))[1]
    keep = bytearray(64)
    for bi in range(len(d.table)):
        for sl in range(16):
            keep[bi * 16 + sl] = 0 if sl in d.own_slots.get(bi, []) else 1
    b += keep
open(os.path.join(out, 'CGMODES.DAT'), 'wb').write(b)

g = bytearray(b'CGD1')
parts = [('PALCHAR', pal.astype(np.uint8).tobytes()), ('PALMAIN', mainpal.astype(np.uint8).tobytes()),
         ('CURSOR', char[131:147, 11:27].tobytes()), ('SWITCH', char[107:113, 247:254].tobytes()),
         ('SHIP', pix.tobytes()), ('ANI', ani.tobytes()), ('PORT', b''.join(p.tobytes() for p in ports)),
         ('BIRD', char[7:77, 13:83].tobytes())]
equ = ['; cgdata.i - GENERATED by tools/mkcrewgen.py: offsets in DATA\\CGDATA.DAT']
for name, blob in parts:
    equ.append('CGD_%s\tequ\t%d' % (name, len(g)))
    g += blob
    if len(g) & 1: g += b'\0'
equ.append('CGD_SIZE\tequ\t%d' % len(g))
equ.append('CGM_MODE\tequ\t%d\t; one mode: ISP2 header, planar background, keep mask' % (8 + 2 + 136 + 1024 + 64 + 32000 + 64))
equ.append('CGM_SIZE\tequ\t%d' % (6 + 4 * (8 + 2 + 136 + 1024 + 64 + 32000 + 64)))
open(os.path.join(out, 'CGDATA.DAT'), 'wb').write(g)
if '--equ' in sys.argv: open(sys.argv[sys.argv.index('--equ') + 1], 'w').write('\n'.join(equ) + '\n')
print('CGMODES.DAT %d bytes, CGDATA.DAT %d bytes' % (len(b), len(g)))

# pre-rendered planar pieces (the ST copies them instead of mapping chunky pixels):
# CGANI.DAT: ball frames per mode SHIP, CREW, SAVE: 31 x 35 rows x groups 1-4 (x 16-79, 32 bytes)
# CGSHIP.DAT: the 27 ships (SHIP mode): 75 rows (13-87) x groups 7-18 (x 112-303, 96 bytes)
def piece(d, img, y0, y1, g0, g1):
    pl = c.planar(d.slots(img))[1]
    return b''.join(pl[y * 160 + g0 * 8:y * 160 + g1 * 8] for y in range(y0, y1))
ab = bytearray()
for d in (ship, crewd, save):
    for f in ani:
        im = base.copy(); im[81:116, 22:70] = f
        ab += piece(d, im, 81, 116, 1, 5)
open(os.path.join(out, 'CGANI.DAT'), 'wb').write(ab)
sb = bytearray()
for st in SHIPS:
    im = base.copy(); m.displayship2(im, pix, st)
    sb += piece(ship, im, 13, 88, 7, 19)
open(os.path.join(out, 'CGSHIP.DAT'), 'wb').write(sb)
if '--equ' in sys.argv:
    open(sys.argv[sys.argv.index('--equ') + 1], 'a').write('CGA_SIZE\tequ\t%d\nCGS_SIZE\tequ\t%d\n' % (len(ab), len(sb)))
print('CGANI.DAT %d bytes, CGSHIP.DAT %d bytes' % (len(ab), len(sb)))

if prev:
    from PIL import Image
    os.makedirs(prev, exist_ok=True)
    gp = pal.copy()
    for j in range(32): gp[128 + j] = (0, 0, 2 * j)
    def show(fn, d, img, p=pal):
        o = np.zeros((200, 640, 3), np.uint8)
        o[:, :320] = (p[img] * 255 // 63).astype(np.uint8)
        o[:, 320:] = d.rgb(img, p)
        Image.fromarray(o).resize((1280, 400), Image.NEAREST).save(os.path.join(prev, fn))
    show('ship.png', ship, ship_imgs[13])
    show('crew0.png', crewd, crew_imgs[0], gp)
    show('crew5.png', crewd, crew_imgs[5], gp)
    show('crew9.png', crewd, crew_imgs[9], gp)
    sv = bf.Design(save.splits, save.table, [l.copy() for l in save.luts], save.reps, 0); sv.own_slots = {}
    for b_ in range(len(sv.luts)):   # the ST's vid_lut_remap for 128-159 with the frozen graph colours
        cols = np.array([[(((w >> sh) & 7) << 1 | ((w >> sh) & 15) >> 3) for sh in (8, 4, 0)] for w in sv.table[b_][1]])
        for i in GRAPH:
            sv.luts[b_][i] = int(((cols - np.round(gp[i] * 15 / 63)) ** 2).sum(1).argmin())
    show('save.png', sv, save_imgs[2], gp)
    show('egg.png', egg_d, egt, mainpal)
