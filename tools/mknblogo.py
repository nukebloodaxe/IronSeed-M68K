#!/usr/bin/env python3
"""mknblogo.py LOGO.GIF MAIN.PAL OUT.DAT [--png sheet.png] - the Nuke Bloodaxe M68K Ports
scene (an addition of the STE port: shown after 'Destiny: Virtual', before Mars).

The GIF is David's spinning logo (60 frames, one turn per second, square pixels, transparent
background). It is scaled so the turning logo fits LOGO_H lines (pixel aspect 1:1.2 for a
320x200 picture on a 4:3 screen), quantised to 15 STE colours over all frames together and
stored as planar boxes that the VBL copies straight to the screen (intro.s nb_vbl).

Bands: band 0 (lines 0..SPLIT-1) = black + the 15 gold shades, shown through palette
entries 200-214 (reps), so the intro's fades work on them through GS_COLORS. Band 1 (from
SPLIT) = main.pal 0-31 exactly as MAINPAL.ISL (writestr2's grey trails, 31 turning red).

NBLOGO.DAT, big-endian:
  ISP2 palette header as tools/mkpal.py writes it (w = h = 0): bands, 4 LUTs, 64 reps
  'NBL1', frames.w, ms per turn.w, box byte offset in a line.w, first line.w, lines.w,
  groups.w (always 10), 15 x 3 bytes 6-bit VGA gold (entries 200-214), pad byte,
  frames x lines x 80 bytes planar (10 groups x 4 plane words)
"""
import argparse, os, struct, subprocess, sys, tempfile
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpr2st as c

LOGO_Y, LOGO_H = 12, 110      # logo box on screen
SPLIT = 125                   # band 1 (sub-text) starts here; text trails stay below
GROUPS = 10                   # 160 pixels wide box
ASPECT = 1.2                  # ST low-res pixels are ~1.2x taller than wide
FIRST_REP = 200


def load_frames(fn):
    im = Image.open(fn)
    frames = []
    for i in range(im.n_frames):
        im.seek(i)
        r = np.array(im.convert('RGBA')).astype(np.float64)
        frames.append(r[..., :3] * (r[..., 3:4] / 255.0))   # transparent -> black
    return frames


LUMA = np.array([0.299, 0.587, 0.114])
# hue-aware colour space: luma plus weighted R-G and G-B, so a brown pixel never picks a
# greener neighbour of the same brightness (the flat face of the logo stays one colour)
HUE_W = 2.0
TO_LCH = np.array([[0.299, HUE_W, 0], [0.587, -HUE_W, HUE_W], [0.114, 0, -HUE_W]])


def best_grid(mean):
    """the STE grid colour nearest to mean in the hue-aware space"""
    base = np.floor(mean).astype(int)
    cands = np.array([base + [i, j, k] for i in (0, 1) for j in (0, 1) for k in (0, 1)])
    cands = np.clip(cands, 0, 15)
    return cands[(((cands - mean) @ TO_LCH) ** 2).sum(1).argmin()]


def luma_ramp(cols, k):
    """1-D weighted k-means on luma; each centre's colour = the hue-aware grid colour nearest
    the mean of its members. More clusters are tried until k distinct grid colours come out;
    then the k most used are kept, ordered dark to bright."""
    lum = cols @ LUMA
    for kk in range(k, 3 * k):
        cent = np.quantile(lum, (np.arange(kk) + .5) / kk)
        for _ in range(60):
            lab = np.abs(lum[:, None] - cent[None]).argmin(1)
            for i in range(kk):
                if (lab == i).any(): cent[i] = lum[lab == i].mean()
        rgb = np.array([best_grid(cols[lab == i].mean(0)) for i in range(kk) if (lab == i).any()])
        rgb = np.unique(rgb, axis=0)
        rgb = rgb[rgb.sum(1) > 0]
        if len(rgb) >= k: break
    if len(rgb) > k:
        lab = ((((cols[:, None] - rgb[None]) @ TO_LCH) ** 2).sum(2)).argmin(1)
        use = np.bincount(lab, minlength=len(rgb))
        rgb = rgb[np.sort(np.argsort(-use)[:k])]
    rgb = rgb[np.argsort(rgb @ LUMA, kind='stable')]
    while len(rgb) < k: rgb = np.vstack([rgb, rgb[-1:]])      # (unused duplicate slots)
    return rgb, rgb @ LUMA


def kmeans_grid(cols, w, k):
    """weighted k-means (0..15 scale) whose rounded centres are k distinct, non-black STE colours"""
    for extra in range(0, 12):
        kk = k + extra
        order = np.argsort(cols.sum(1))
        cw = np.cumsum(w[order]); cw /= cw[-1]
        cent = np.array([cols[order[np.searchsorted(cw, (i + .5) / kk)]] for i in range(kk)], float)
        for _ in range(40):
            lab = ((cols[:, None] - cent[None]) ** 2).sum(2).argmin(1)
            for i in range(kk):
                m = lab == i
                if m.any(): cent[i] = np.average(cols[m], axis=0, weights=w[m])
        r = np.unique(np.clip(np.round(cent), 0, 15).astype(int), axis=0)
        r = r[r.sum(1) > 0]
        if len(r) >= k:
            # keep the k most used
            lab = ((cols[:, None] - r[None]) ** 2).sum(2).argmin(1)
            use = np.bincount(lab, weights=w, minlength=len(r))
            r = r[np.sort(np.argsort(-use)[:k])]
            return r[np.argsort(r.sum(1), kind='stable')]
    sys.exit('cannot find %d distinct colours' % k)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('gif'); ap.add_argument('pal'); ap.add_argument('out'); ap.add_argument('--png')
    a = ap.parse_args()
    frames = load_frames(a.gif)
    # union bounding box of the logo over all frames
    lit = np.zeros(frames[0].shape[:2], bool)
    for f in frames: lit |= f.max(2) > 4
    ys, xs = np.nonzero(lit)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    cx = (x0 + x1) / 2
    sy = LOGO_H / (y1 - y0)
    sx = sy * ASPECT
    W = int(round((x1 - x0) * sx)) | 1
    hw = (W / sx) / 2
    crop = (cx - hw, y0, cx + hw, y1)
    small = []
    for f in frames:
        img = Image.fromarray(np.clip(f, 0, 255).astype(np.uint8))
        s = img.resize((W, LOGO_H), Image.LANCZOS, box=crop)
        small.append(np.clip(np.array(s).astype(float), 0, 255))
    small = np.array(small)                                   # n, H, W, 3
    # 15 gold shades on the STE grid (all frames together)
    px = small.reshape(-1, 3)
    px = px[px.max(1) > 20]
    # 15 shades along the logo's brightness (1-D k-means on luma): a ramp keeps the warm
    # hue on every shade; 3-D clustering on the 4-bit grid made olive/grey patches
    gold4, lum_c = luma_ramp(px / 255 * 15, 15)
    cent = np.vstack([[0, 0, 0], gold4])
    v = small / 255 * 15
    d = ((((v[..., None, :] - cent[None, None, None, :, :])) @ TO_LCH) ** 2).sum(-1)
    slots = d.argmin(-1).astype(np.uint8)                     # nearest (black included)
    # place: centred on x = 160, box of GROUPS groups
    left = 160 - W // 2
    box_x = 160 - GROUPS * 8                                  # 80: groups 5-14
    if left < box_x or left + W > box_x + GROUPS * 16:
        sys.exit('logo too wide: %d px' % W)
    data = bytearray()
    for n in range(len(frames)):
        scr = np.zeros((LOGO_H, GROUPS * 16), np.uint8)
        scr[:, left - box_x:left - box_x + W] = slots[n]
        _, pl = c.planar(scr)
        data += pl
    # palette header: band 0 gold through reps 200-214, band 1 = MAINPAL.ISL
    with tempfile.TemporaryDirectory() as td:
        isl = os.path.join(td, 'm.isl')
        subprocess.run([sys.executable, '-I', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mkpal.py'),
                        a.pal, isl, '--use', '0-31', '--own', '31'], check=True, stdout=subprocess.DEVNULL)
        m = open(isl, 'rb').read()
    mcols = list(struct.unpack('>16H', m[10 + 2:10 + 34]))
    mlut = np.frombuffer(m[146:146 + 256], np.uint8)
    mreps = list(m[146 + 1024:146 + 1024 + 16])
    lut0 = np.zeros(256, np.uint8)
    for k in range(15): lut0[FIRST_REP + k] = k + 1
    table = [(0, [0] + [c.to_ste_word(x) for x in gold4]), (SPLIT, mcols)]
    hdr = bytearray(b'ISP2') + bytes(4) + struct.pack('>H', 2)
    for i in range(4):
        line, cols = table[i] if i < 2 else (0, [0] * 16)
        hdr += struct.pack('>H16H', line, *cols)
    hdr += bytes(lut0) + bytes(mlut) + bytes(mlut) + bytes(mlut)
    hdr += bytes([0] + list(range(FIRST_REP, FIRST_REP + 15))) + bytes(mreps) + bytes(mreps) + bytes(mreps)
    gold6 = [int(round(x * 63 / 15)) for x in gold4.ravel()]   # round(v*15/63) = x again
    out = hdr + b'NBL1' + struct.pack('>6H', len(frames), 1000, box_x // 2, LOGO_Y, LOGO_H, GROUPS)
    out += bytes(gold6) + b'\0' + bytes(data)
    open(a.out, 'wb').write(out)
    print('NBLOGO: %d frames, logo %dx%d at x %d, box x %d-%d, gold %s, %d bytes' % (
        len(frames), W, LOGO_H, left, box_x, box_x + GROUPS * 16 - 1, [tuple(x) for x in gold4], len(out)))
    if a.png:
        rgb = cent * 17
        sheet = Image.new('RGB', (6 * 320, 2 * 200))
        for k, n in enumerate(range(0, len(frames), max(1, len(frames) // 12))):
            if k >= 12: break
            scr = np.zeros((200, 320, 3), np.uint8)
            scr[LOGO_Y:LOGO_Y + LOGO_H, left:left + W] = rgb[slots[n]]
            sheet.paste(Image.fromarray(scr), ((k % 6) * 320, (k // 6) * 200))
        sheet.save(a.png)


if __name__ == '__main__':
    main()
