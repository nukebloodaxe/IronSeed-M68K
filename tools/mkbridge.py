#!/usr/bin/env python3
"""mkbridge.py [train|fit|eval] - the bridge's viewscreen designs per kind of planet (Phase 6k).

MAIN.ISP's band 1 (lines 12-139: the viewscreen, the status panel, the status lights) is one fit
shared by every planet type, the gas giants, the asteroid fields and the gas clouds. Like the stars'
MAINS1-3 (Phase 6i), each kind of orbit gets its own band 1, fitted on what the original itself
draws there: Linux oracle sessions (tools/oracle_main.sh, virtual time) in orbit of planets of that
kind with several seeds, a shot every 0.7 s while the planet turns.

  train  run the Linux sessions -> build/bridge_train/KIND.npz (chunky shots; needs the oracle build)
  fit    band 1 per kind from the training shots -> assets/bridge/KIND.B1
         (16 STE colour words, 256-byte LUT, 16 rep indices = 304 bytes; tools/mkmain.py builds
         DATA\\MAINkind.ISP = MAIN with that band 1)
  eval   the held-out seeds' shots through MAIN and through the kind's design (band 1 lines only)

Kinds (utils2.pas readyplanet / game/utils2.s u2_design): P<state><mode> for the land spheres,
G1/G2 the gas giants' two colour sets (creategasplanet: 32/48/64 or 112/128/96), A asteroid fields
(state 6 mode 2), C gas clouds (state 0, mode 0/1), S1-S3 the stars (orbit 0, the star's mode:
replaces star_modes' synthetic MAINS1-3). `train KIND,KIND` runs only those."""
import glob, os, subprocess, sys
import numpy as np
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(R, 'tools'))
import cpr2st as c, bandfit as bf, medoids as md

SRC = os.environ.get('IRONSEED_SRC', '/root/ironseed_fpc')
TRAIN = os.path.join(R, 'build', 'bridge_train')
OUT = os.path.join(R, 'assets', 'bridge')
TRAIN_SEEDS = [1234, 4321, 777, 31337, 2026, 1994, 4242, 9001, 555, 12345, 23456, 3141]
TEST_SEEDS = [271, 8080, 16000, 60001]
GAS_SEEDS = [101, 202, 303, 404, 505, 606, 707, 808, 909, 1111, 2222, 3333, 4444, 5555]   # (more: two colour sets)
# (state, mode) of the land spheres the game makes (crewgen/starter: states 1-6, modes 1-3)
LAND = [(s, m) for s in range(1, 7) for m in (1, 2, 3) if not (s == 6 and m == 2)]


def kinds():
    k = {'P%d%d' % sm: ['planets[576].state=%d' % sm[0], 'planets[576].mode=%d' % sm[1]] for sm in LAND}
    k['GAS'] = ['planets[576].state=0', 'planets[576].mode=2']        # split into G1/G2 by colour
    k['A'] = ['planets[576].state=6', 'planets[576].mode=2']
    k['C'] = ['planets[576].state=0', 'planets[576].mode=1']
    for m in (1, 2, 3):                                   # the stars (orbit 0: planet 575 is the star)
        k['S%d' % m] = ['@orbit=0', 'planets[575].mode=%d' % m]
    return k


def script(path):
    lines = ['vtime', 'args /playseed 3', 'wait 3000', 'key #27', 'wait 9000']
    for i in range(1, 13):
        lines += ['shot T%02d' % i, 'wait 700']
    lines += ['key #291', 'wait 1500', 'key y', 'wait 3000', 'quit']
    open(path, 'w').write('\n'.join(lines) + '\n')


def run_one(edits, seed, tmp):
    pl = '575' if '@orbit=0' in edits else '576'
    """-> list of 12 chunky shots (200x320 uint8) of one Linux session"""
    h, o, st = os.path.join(tmp, 'h'), os.path.join(tmp, 'o'), os.path.join(tmp, 'st')
    for d in (h, o, st):
        subprocess.run(['rm', '-rf', d])
    os.makedirs(st)
    subprocess.run(['python3', os.path.join(R, 'tools/mksave.py'), os.path.join(R, 'build/layout.json'),
                    os.path.join(R, 'build/oracle_s4/home'), '3', h, '3', st] + edits +
                   ['planets[%s].seed=%d' % (pl, seed), 'ship.damages[6]=0'], check=True, stdout=subprocess.DEVNULL)
    pr = subprocess.Popen([os.path.join(R, 'tools/oracle_main.sh'), os.path.join(tmp, 't.main'), o, h, '3'],
                          stdout=subprocess.DEVNULL, start_new_session=True)
    try:
        pr.wait(90)
    except subprocess.TimeoutExpired:          # (a session that hangs after its shots: killed)
        os.killpg(pr.pid, 9); pr.wait()
    shots = []
    for f in sorted(glob.glob(os.path.join(o, 'shot_T*.raw'))):
        shots.append(np.frombuffer(open(f, 'rb').read()[:64000], np.uint8).reshape(200, 320).copy())
    return shots


def gas_set(shots):
    """creategasplanet's colour set: 1 = 32/48/64, 2 = 112/128/96"""
    v = np.concatenate([s[13:133, 28:148].ravel() for s in shots])
    a = ((v >= 32) & (v < 80)).sum(); b = ((v >= 96) & (v < 144)).sum()
    return 1 if a >= b else 2


def train():
    os.makedirs(TRAIN, exist_ok=True)
    tmp = '/tmp/mkbridge'
    os.makedirs(tmp, exist_ok=True)
    script(os.path.join(tmp, 't.main'))
    only = sys.argv[2].split(',') if len(sys.argv) > 2 else None
    for name, edits in kinds().items():
        if only and name not in only: continue
        res = {}
        for part, seeds in (('train', TRAIN_SEEDS + (GAS_SEEDS if name == 'GAS' else [])), ('test', TEST_SEEDS + ([6666, 7777] if name == 'GAS' else []))):
            for s in seeds:
                sh = run_one(edits, s, tmp)
                if len(sh) != 12:
                    print(name, s, 'only', len(sh), 'shots'); continue
                kn = name if name != 'GAS' else 'G%d' % gas_set(sh)
                res.setdefault((kn, part), []).append(np.stack(sh))
        for (kn, part), v in res.items():
            np.savez_compressed(os.path.join(TRAIN, '%s_%s.npz' % (kn, part)), shots=np.concatenate(v))
            print(kn, part, len(v), 'sessions')


def load_isp(fn):
    d = open(fn, 'rb').read()
    n = int.from_bytes(d[8:10], 'big')
    table = []
    for k in range(4):
        o = 10 + 34 * k
        table.append((int.from_bytes(d[o:o + 2], 'big'), [int.from_bytes(d[o + 2 + 2 * i:o + 4 + 2 * i], 'big') for i in range(16)]))
    luts = [np.frombuffer(d[146 + 256 * i:146 + 256 * (i + 1)], np.uint8).copy() for i in range(4)]
    reps = list(d[146 + 1024:146 + 1088])
    return bf.Design([t[0] for t in table[:n]], table[:n], luts, reps, 0)


def pal_main():
    return c.read_cpr(os.path.join(SRC, 'data', 'main.cpr'))[3]


def lights(main):
    """the status lights (x 300-313, lines 29-99) in the three alert colours (checkstats/colorarea)"""
    out = []
    for tc in (48, 80, 112):
        lit = main.copy()
        for y0 in (29, 49, 69, 89):
            reg = lit[y0:y0 + 11, 300:314]
            reg[reg != 0] = (reg[reg != 0].astype(int) + tc) & 255
        out.append(lit)
    return out


def hbox(shots, x0, x1, ya, yb):
    h = np.zeros((200, 256))
    for sh in shots:
        for y in range(ya, yb):
            h[y] += np.bincount(sh[y, x0:x1], minlength=256)
    return h


WL = float(os.environ.get('BRIDGE_WL', '5'))     # the status lights' box (x 296-317, lines 25-100)


def band1_hist(shots, main):
    """the training shots as they are, the status lights' box at weight WL, and the lights in
    their three alert colours (synthetic: the sessions show only the save's state)"""
    hist = bf.hist_of(list(shots))
    hist += (WL - 1) * hbox(shots, 296, 318, 25, 101)
    for lit in lights(main):
        hist += WL * len(shots) / 3 * hbox([lit], 296, 318, 25, 101) / 3
    return hist


def fit_band(shots, main, pal, dmain):
    """band 1 by medoids (tools/medoids.py: the reps chosen among the palette indices, scored on
    the colours the STE shows)"""
    hist = band1_hist(shots, main)
    y0, y1 = dmain.splits[1], dmain.splits[2]
    err, cent, lut, rp = md.band(hist[y0:y1], pal)
    words = [c.to_ste_word(x) for x in cent]
    return words, np.asarray(lut, np.uint8), [int(x) for x in rp]


def b1_bytes(words, lut, reps):
    return b''.join(int(w).to_bytes(2, 'big') for w in words) + bytes(lut) + bytes(reps)


def b1_read(fn):
    d = open(fn, 'rb').read()
    return [int.from_bytes(d[2 * i:2 * i + 2], 'big') for i in range(16)], np.frombuffer(d[32:288], np.uint8), list(d[288:304])


def main_chunky():
    return c.read_cpr(os.path.join(SRC, 'data', 'main.cpr'))[2]


def fit():
    os.makedirs(OUT, exist_ok=True)
    pal = pal_main()
    dmain = load_isp(os.path.join(R, 'build', 'data', 'MAIN.ISP'))
    main = main_chunky()
    for f in sorted(glob.glob(os.path.join(TRAIN, '*_train.npz'))):
        kn = os.path.basename(f)[:-10]
        shots = np.load(f)['shots']
        words, lut, reps = fit_band(shots, main, pal, dmain)
        open(os.path.join(OUT, kn + '.B1'), 'wb').write(b1_bytes(words, lut, reps))
        print(kn, len(shots), 'shots fitted')


def show_err(shots, lut, reps, pal, y0, y1, box=None):
    p6 = pal.astype(int)
    li = p6 * 255 // 63
    q = np.clip(np.round(p6 * 15 / 63), 0, 15).astype(int) * 17
    col = q[np.asarray(reps)[lut]]           # index -> shown colour
    e = []
    for s in shots:
        a = s[y0:y1] if box is None else s[box[1]:box[3], box[0]:box[2]]
        e.append(np.sqrt(((col[a] - li[a]) ** 2).sum(-1)).mean())
    return float(np.mean(e))


def evaluate():
    pal = pal_main()
    dmain = load_isp(os.path.join(R, 'build', 'data', 'MAIN.ISP'))
    y0, y1 = dmain.splits[1], dmain.splits[2]
    mlut, mreps = dmain.luts[1], dmain.reps[16:32]
    tot = [0, 0, 0]
    print('%-5s %6s %6s   %6s %6s   %6s %6s' % ('kind', 'band1', '', 'view', '', 'lights', ''))
    for f in sorted(glob.glob(os.path.join(TRAIN, '*_test.npz'))):
        kn = os.path.basename(f)[:-9]
        b1 = os.path.join(OUT, kn + '.B1')
        if not os.path.exists(b1): continue
        shots = np.load(f)['shots']
        _, lut, reps = b1_read(b1)
        r = []
        for L, P in ((mlut, mreps), (lut, reps)):
            r += [show_err(shots, L, P, pal, y0, y1), show_err(shots, L, P, pal, 0, 0, (28, 13, 148, 133)),
                  show_err(shots, L, P, pal, 0, 0, (300, 29, 314, 100))]
        print('%-5s %6.1f %6.1f   %6.1f %6.1f   %6.1f %6.1f' % (kn, r[0], r[3], r[1], r[4], r[2], r[5]))


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'fit'
    {'train': train, 'fit': fit, 'eval': evaluate}[cmd]()
