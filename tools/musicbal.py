#!/usr/bin/env python3
"""musicbal.py DIR : left/right balance of every MUSIC\\*.RAW (tools/mkmusic.py) in DIR, over the
whole file: L/R energy in dB (+ = left louder), RMS per side, L-R correlation. Phase 6o: the
songs with 8xx were 100 % left before DMP's positions were read correctly."""
import glob, os, struct, sys
import numpy as np
for f in sorted(glob.glob(os.path.join(sys.argv[1], '*.RAW'))):
    d = open(f, 'rb').read()
    rate, ch, h = struct.unpack('>HHH', d[6:12])
    a = np.frombuffer(d[h:h + (len(d) - h) // 2 * 2], np.int8).astype(np.float64)
    L, R = a[0::2], a[1::2]; el, er = (L * L).mean(), (R * R).mean()
    c = np.corrcoef(L, R)[0, 1] if L.std() * R.std() > 0 else 0.0
    print('%-13s %5d Hz %d ch  L/R %+7.2f dB  rms L %5.1f R %5.1f  corr %.2f' % (
        os.path.basename(f), rate, ch, 10 * np.log10((el + 1e-9) / (er + 1e-9)), el ** .5, er ** .5, c))
