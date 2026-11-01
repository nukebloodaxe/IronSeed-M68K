#!/usr/bin/env python3
import sys, struct, numpy as np
from PIL import Image
T, S, N, OUT = sys.argv[1:5]
sys.path.insert(0, T + '/tools'); from stscreen import planar_to_slots
st = open('%s/build/st_shots/%s/%s.SCR' % (T, S, N), 'rb').read(); lx = open('%s/build/oracle_%s/shot_%s.raw' % (T, S, N), 'rb').read()
slots = planar_to_slots(st[:32000]); b = st[32000:]; n = struct.unpack('>H', b[:2])[0]
band = np.zeros(200, int); pal = []
for k in range(n):
    e = b[2 + 34 * k:2 + 34 * (k + 1)]; band[struct.unpack('>H', e[:2])[0]:] = k
    pal.append(np.array([[(((w >> sh & 15) & 7) << 1 | ((w >> sh & 15) >> 3)) * 17 for sh in (8, 4, 0)] for w in struct.unpack('>16H', e[2:34])], np.uint8))
A = [np.frombuffer(st[32138 + 256 * k:32138 + 256 * (k + 1)], np.uint8) for k in range(4)]
idx = np.frombuffer(lx[:64000], np.uint8).reshape(200, 320)
after = np.zeros((200, 320, 3), np.uint8); before = np.zeros_like(after)
for y in range(200):
    after[y] = pal[band[y]][slots[y]]; before[y] = pal[band[y]][A[band[y]][idx[y]]]
lin = (np.frombuffer(lx[64000:64768], np.uint8).reshape(256, 3).astype(int) * 255 // 63)[idx].astype(np.uint8)
Image.fromarray(np.concatenate([lin, before, after], 1)).resize((1920, 400), Image.NEAREST).save(OUT)
