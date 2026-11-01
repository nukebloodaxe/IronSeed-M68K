"""dithmock2.py TREE SESSION SHOT OUT.png : Linux | ST now | checkerboard | column stripes. A palette
index is dithered only when its nearest band colour is more than THR away and a pair halves that."""
import sys, struct, numpy as np
from PIL import Image
T, S, N, OUT = sys.argv[1:5]; THR = float(sys.argv[5]) if len(sys.argv) > 5 else 14
import os; FIXA = os.environ.get('FIXA') == '1'
st = open('%s/build/st_shots/%s/%s.SCR' % (T, S, N), 'rb').read()
lx = open('%s/build/oracle_%s/shot_%s.raw' % (T, S, N), 'rb').read()
idx = np.frombuffer(lx[:64000], np.uint8).reshape(200, 320)
lp = np.frombuffer(lx[64000:64768], np.uint8).reshape(256, 3).astype(float) * 255 / 63
b = st[32000:]; n = struct.unpack('>H', b[:2])[0]; band = np.zeros(200, int); pal = []
for k in range(n):
    e = b[2 + 34 * k:2 + 34 * (k + 1)]; band[struct.unpack('>H', e[:2])[0]:] = k
    pal.append(np.array([[(((w >> sh & 15) & 7) << 1 | ((w >> sh & 15) >> 3)) * 17 for sh in (8, 4, 0)] for w in struct.unpack('>16H', e[2:34])], float))
yy, xx = np.mgrid[0:200, 0:320]
true = lp[idx]; now = np.zeros_like(true); chk = np.zeros_like(true); col = np.zeros_like(true); nd = 0
for k in range(n):
    r = band == k; P = pal[k]
    L = np.frombuffer(st[32000 + 2 + 34 * n + 256 * k:32000 + 2 + 34 * n + 256 * (k + 1)], np.uint8)
    now[r] = P[L[idx[r]]]; chk[r] = now[r]; col[r] = now[r]
    avg = (P[:, None] + P[None, :]) / 2; con = ((P[:, None] - P[None, :]) ** 2).sum(-1)
    for i in np.unique(idx[r]):
        t = lp[i]; e1 = np.sqrt(((P[L[i]] - t) ** 2).sum())
        if e1 <= THR: continue
        cost = ((avg - t) ** 2).sum(-1) + 0.1 * con
        if FIXA:
            a = L[i]; c = int(np.argmin(cost[a]))
        else: a, c = np.unravel_index(np.argmin(cost), cost.shape)
        if np.sqrt(((avg[a, c] - t) ** 2).sum()) > e1 / 2: continue
        m = r[:, None] & (idx == i); nd += 1
        for img, par in ((chk, (xx + yy) & 1), (col, xx & 1)):
            img[m & (par == 0)] = P[a]; img[m & (par == 1)] = P[c]
def blur(x):
    y = x.copy(); y[:, 1:-1] = (x[:, :-2] + 2 * x[:, 1:-1] + x[:, 2:]) / 4
    z = y.copy(); z[1:-1] = (y[:-2] + 2 * y[1:-1] + y[2:]) / 4; return z
tb = np.stack([blur(true[..., c]) for c in range(3)], -1)
res = []
for name, img in (('now', now), ('checker', chk), ('columns', col)):
    ib = np.stack([blur(img[..., c]) for c in range(3)], -1); res.append('%s %.1f' % (name, np.sqrt(((ib - tb) ** 2).sum(-1)).mean()))
print('%s %s: %d indices dithered; blurred error %s' % (S, N, nd, ', '.join(res)))
Image.fromarray(np.concatenate([true, now, chk, col], 1).astype(np.uint8)).resize((2560, 400), Image.NEAREST).save(OUT)
