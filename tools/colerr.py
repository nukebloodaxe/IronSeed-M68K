"""colerr.py TREE... : per kept shot, the pure colour error: Linux's own index image shown through the
ST's bands and LUTs (from the ST shot) against Linux's colours - layout and timing do not count.
Also the same with the mock checkerboard dither (lambda 0.1) for comparison."""
import sys, glob, os, struct, numpy as np
def blur(x):
    y = x.copy(); y[:, 1:-1] = (x[:, :-2] + 2 * x[:, 1:-1] + x[:, 2:]) / 4
    z = y.copy(); z[1:-1] = (y[:-2] + 2 * y[1:-1] + y[2:]) / 4
    return z
rows = []
yy, xx = np.mgrid[0:200, 0:320]; par = (xx + yy) & 1
for T in sys.argv[1:]:
    for f in sorted(glob.glob(T + '/build/st_shots/*/*.SCR')):
        S = f.split('/')[-2]; N = os.path.basename(f)[:-4]
        raw = '%s/build/oracle_%s/shot_%s.raw' % (T, S, N)
        st = open(f, 'rb').read()
        if not os.path.exists(raw) or len(st) < 32000 + 2: continue
        lx = open(raw, 'rb').read(); idx = np.frombuffer(lx[:64000], np.uint8).reshape(200, 320)
        lp = np.frombuffer(lx[64000:64768], np.uint8).reshape(256, 3).astype(float) * 255 / 63
        b = st[32000:]; n = struct.unpack('>H', b[:2])[0]
        if len(st) < 32000 + 2 + 34 * n + 1024: continue
        band = np.zeros(200, int); pal = []
        for k in range(n):
            e = b[2 + 34 * k:2 + 34 * (k + 1)]; band[struct.unpack('>H', e[:2])[0]:] = k
            pal.append(np.array([[(((w >> sh & 15) & 7) << 1 | ((w >> sh & 15) >> 3)) * 17 for sh in (8, 4, 0)] for w in struct.unpack('>16H', e[2:34])], float))
        true = lp[idx]; now = np.zeros_like(true); dit = np.zeros_like(true)
        for k in range(n):
            r = band == k; P = pal[k]
            L = np.frombuffer(st[32000 + 2 + 34 * n + 256 * k:32000 + 2 + 34 * n + 256 * (k + 1)], np.uint8)
            Lb = np.frombuffer(st[32000 + 2 + 34 * n + 1024 + 256 * k:32000 + 2 + 34 * n + 1024 + 256 * (k + 1)], np.uint8) if len(st) >= 32000 + 2 + 34 * n + 2048 else L
            m0 = r[:, None] & (par == 0); m1 = r[:, None] & (par == 1)
            now[m0] = P[L[idx[m0]]]; now[m1] = P[Lb[idx[m1]]]
            A = P[:, None, :]; B = P[None, :, :]; avg = (A + B) / 2; con = ((A - B) ** 2).sum(-1)
            for i in np.unique(idx[r]):
                cost = ((avg - lp[i]) ** 2).sum(-1) + 0.1 * con
                a, c = np.unravel_index(np.argmin(cost), cost.shape)
                m = r[:, None] & (idx == i); dit[m & (par == 0)] = P[a]; dit[m & (par == 1)] = P[c]
        tb = np.stack([blur(true[..., c]) for c in range(3)], -1)
        def e(img, bl):
            x = np.stack([blur(img[..., c]) for c in range(3)], -1) if bl else img
            return np.sqrt(((x - (tb if bl else true)) ** 2).sum(-1))
        en = e(now, 1); ed = e(dit, 1)
        bw = [en[band == k].mean() for k in range(n)]
        rows.append((en.mean(), ed.mean(), e(now, 0).mean(), S, N, int(np.argmax(bw)), max(bw)))
rows.sort(reverse=True)
print('%-5s %-8s %7s %7s %7s  worst band' % ('sess', 'shot', 'blur', 'dither', 'raw'))
for r in rows: print('%-5s %-8s %7.1f %7.1f %7.1f  band %d (%.1f)' % (r[3], r[4], r[0], r[1], r[2], r[5], r[6]))
a = np.array([r[:3] for r in rows]); print('mean over %d shots: blurred %.2f, dithered %.2f, raw %.2f' % (len(rows), *a.mean(0)))
