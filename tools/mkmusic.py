#!/usr/bin/env python3
"""mkmusic.py - pre-render the MODs for streaming from disk (Phase 6b).

  mkmusic.py SOUND_DIR OUT_DIR [--rate 6258|12517] [--wav WAVDIR] [--only NAME,...] [--check S]

Writes OUT_DIR/NAME.RAW for every NAME.MOD: a header and signed 8-bit stereo pairs, exactly
what kernel/mod.s + snd.s would mix (tools/modref.py's model, sfxroom 0 as in the game).

Header (big-endian, HDR bytes; HDR is chosen >= 32 so that the loop point lands on a 512-byte
file offset - the seek the player does at every wrap reads whole sectors):
  0  'ISMU'          4  w version (1)     6  w rate (Hz)      8  w MOD channels
 10  w header bytes 12  l total pairs    16  l loop pair      20  l first-pass end pair
 24  l flags (bit 0: the junction is exact)                    28  l reserved
The player plays pairs [0, total) and then [loop, total) forever. 'first-pass end' is where
the song's order first wraps (or jumps back): a play-once song (playmod(false, ...)) stops there.

Loop point: the replay's (order position, row) sequence is periodic once a row repeats
(at T1, first seen at T0). The output is not periodic from T1 on, because notes ringing over
the wrap differ from the silence at the start. So the render goes on after T1 until a row
start T1+d where the whole replay state equals the state at T0+d (the tails have died out):
from there pass 2 is pass 1, and the stream jumps back to T0+d. The 16.16 tick-length carry
is not compared (it differs by less than one sample per tick); sample positions of playing
voices may differ by that drift (a few bytes) - reported as 'max drift'.
"""
import argparse, os, struct, sys, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import modref  # noqa: E402

HDR_MIN = 32
DRIFT_MAX = 8        # sample bytes: a voice whose note started a sample earlier or later (tick carry)


class FastPlayer(modref.Player):
    """modref.Player with the mixer in numpy (same integers). interp=True: a better render the
    ST could never mix in real time - linear interpolation between sample bytes, the volume
    applied before rounding, and soft panning at DMP's positions (Phase 6o: a voice at 8xx
    position p goes (128-p)/128 left and p/128 right; L R R L voices stay hard on their side;
    the replay, timing and loop points are unchanged)."""

    def __init__(self, mod, rate, sfxroom=0, interp=False):
        super().__init__(mod, rate, sfxroom)
        self.interp = interp
        self.vps = mod.ch // 2 + sfxroom
        self.vtn = np.array(self.vt, dtype=np.int32)          # [vol][byte]
        for s in mod.samples:
            s['np'] = np.frombuffer(s['data'], dtype=np.uint8).astype(np.int32)
            s['idx'] = mod.samples.index(s)
        self.acc0 = np.zeros(0, np.int32)

    def mix(self, n):
        if self.interp: return self.mix_interp(n)
        acc = [np.zeros(n, np.int32), np.zeros(n, np.int32)]
        i = np.arange(n, dtype=np.int64)
        for c in self.ch:
            if not c.on or c.out_period == 0: continue
            st = self.step[min(c.out_period, 1023)]
            s = c.smp; d = s['np']
            ln, ls, ll = s['len'], s['ls'], s['ll']
            fr = c.frac + (st & 0xffff) * i            # frac before adding at sample i
            p = c.pos + (st >> 16) * i + (fr >> 16)    # pos at sample i (unwrapped)
            if ll:
                e = ls + ll
                pw = np.where(p >= e, ls + (p - ls) % ll, p)
                acc[c.side] += self.vtn[c.vol][d[pw]]
                fe = c.frac + (st & 0xffff) * n
                pn = c.pos + (st >> 16) * n + (fe >> 16)
                if pn >= e: pn = ls + (pn - ls) % ll
                c.pos, c.frac = int(pn), int(fe & 0xffff)
            else:
                ok = p < ln
                m = int(ok.sum()) if not ok.all() else n   # p is increasing: first n are ok
                if m < n:
                    acc[c.side][:m] += self.vtn[c.vol][d[p[:m]]]
                    c.on = False
                    fe = c.frac + (st & 0xffff) * m
                    c.pos = int(c.pos + (st >> 16) * m + (fe >> 16)); c.frac = int(fe & 0xffff)
                else:
                    acc[c.side] += self.vtn[c.vol][d[p]]
                    fe = c.frac + (st & 0xffff) * n
                    c.pos = int(c.pos + (st >> 16) * n + (fe >> 16)); c.frac = int(fe & 0xffff)
        out = np.empty(2 * n, np.uint8)
        out[0::2] = acc[0] & 255; out[1::2] = acc[1] & 255
        return out.tobytes()

    def mix_interp(self, n):
        acc = [np.zeros(n), np.zeros(n)]
        i = np.arange(n, dtype=np.int64)
        for c in self.ch:
            if not c.on or c.out_period == 0: continue
            st = self.step[min(c.out_period, 1023)]
            s = c.smp
            if 'sg' not in s:
                s['sg'] = np.append(np.frombuffer(s['data'], np.int8).astype(np.float64), 0.0)
            d = s['sg']
            ln, ls, ll = s['len'], s['ls'], s['ll']
            fr = c.frac + (st & 0xffff) * i
            p = c.pos + (st >> 16) * i + (fr >> 16)
            f = (fr & 0xffff) / 65536.0
            m = n
            if ll:
                e = ls + ll
                pw = np.where(p >= e, ls + (p - ls) % ll, p)
                nx = np.where(pw + 1 >= e, ls, pw + 1)
            else:
                ok = p < ln
                if not ok.all(): m = int(ok.sum())
                pw = p[:m]; nx = np.minimum(pw + 1, ln); f = f[:m]
            v = (d[pw] + (d[nx] - d[pw]) * f) * (c.vol / (64.0 * self.vps))
            if c.pan <= 0: acc[0][:m] += v
            elif c.pan >= 128: acc[1][:m] += v
            else:
                acc[0][:m] += v * ((128 - c.pan) / 128.0)
                acc[1][:m] += v * (c.pan / 128.0)
            fe = c.frac + (st & 0xffff) * m
            pn = c.pos + (st >> 16) * m + (fe >> 16)
            if ll and pn >= ls + ll: pn = ls + (pn - ls) % ll
            c.pos, c.frac = int(pn), int(fe & 0xffff)
            if m < n: c.on = False
        out = np.empty(2 * n, np.uint8)
        for k in (0, 1):
            out[k::2] = np.clip(np.rint(acc[k]), -128, 127).astype(np.int32) & 255
        return out.tobytes()

    def state(self):
        """Everything that decides the output from here on, except the tick-length carry and
        the playing voices' positions (returned separately)."""
        g = (self.speed, self.bpm, self.tick, self.row, self.pos, self.jump, self.brk)
        ch, pos = [], []
        for c in self.ch:
            sm = c.smp['idx'] if c.smp is not None else -1
            ch.append((sm, c.period, c.vol, c.on, c.side, c.pan, c.porta_target, c.porta_speed,
                       c.vib_pos, c.vib_speed, c.vib_depth, c.eff, c.prm, c.offset,
                       c.note_smp, c.note_per, c.delay))
            pos.append((c.pos, c.frac) if c.on else None)
        return (g, tuple(ch)), pos


FIELDS = ['smp', 'period', 'vol', 'on', 'side', 'pan', 'ptarget', 'pspeed', 'vibpos', 'vibspd', 'vibdep',
          'eff', 'prm', 'offset', 'nsmp', 'nper', 'delay']
ONDEP = {'smp', 'period', 'vol', 'side', 'pan'}         # live while the voice plays, whatever comes next
NEVER = {'eff', 'prm', 'nsmp', 'nper', 'delay'}  # set by every row before use (do_row)


def classify(cell):
    """Per field: 'W' the row writes it before any read, 'R' the row reads it, None neither.
    A note-delay row (EDx) counts as a read of everything (its timing is not modelled here)."""
    smp, per, eff, prm = cell
    x, y = prm >> 4, prm & 15
    if eff == 0xE and x == 0xD and y:
        return {f: 'R' for f in FIELDS}
    porta = eff in (3, 5)
    trig = per != 0 and not porta
    retrig = eff == 0xE and x == 9 and y != 0
    c = {}
    c['ptarget'] = ('W' if per else 'R') if porta else None
    c['pspeed'] = ('W' if prm else 'R') if eff == 3 else ('R' if eff == 5 else None)
    c['offset'] = ('W' if prm else 'R') if (trig and eff == 9) else None
    c['vibspd'] = ('W' if x else 'R') if eff == 4 else ('R' if eff == 6 else None)
    c['vibdep'] = ('W' if y else 'R') if eff == 4 else ('R' if eff == 6 else None)
    c['vibpos'] = 'W' if trig else ('R' if eff in (4, 6) else None)
    valid = 0 < smp <= 31
    c['smp'] = 'W' if valid else ('R' if (trig or retrig) else None)
    if valid or eff == 0xC: c['vol'] = 'W'
    elif trig or retrig or eff in (5, 6, 0xA) or (eff == 0xE and x in (0xA, 0xB, 0xC)): c['vol'] = 'R'
    else: c['vol'] = None
    if trig: c['period'] = 'W'
    elif porta or eff in (1, 2, 4, 6) or (eff == 0 and prm) or retrig or (eff == 0xE and x in (1, 2)): c['period'] = 'R'
    else: c['period'] = None
    c['side'] = c['pan'] = 'W' if eff == 8 else ('R' if (trig or retrig) else None)
    return c


def liveness(mod, seq):
    """seq: the period's row keys (pos,row) in play order. -> live[k][ch] = set of fields whose
    value at the start of row k can still reach the output (read before written, cyclically)."""
    n = len(seq)
    cls = [[classify(mod.cell(mod.order[pos], row, c)) for c in range(mod.ch)] for pos, row in seq]
    live = [[set() for _ in range(mod.ch)] for _ in range(n)]
    for c in range(mod.ch):
        for f in FIELDS:
            if f in NEVER or f == 'on': continue
            nxt = 'R'                             # unknown beyond two periods: assume read
            for i in range(2 * n - 1, -1, -1):
                k = cls[i % n][c].get(f)
                if k: nxt = k
                if i < n and nxt == 'R': live[i][c].add(f)
    return live


def same_state(a, b, live):
    (ga, cha), (gb, chb) = a, b
    if ga != gb: return False
    for c, (x, y) in enumerate(zip(cha, chb)):
        if x[3] != y[3]: return False            # on
        for i, f in enumerate(FIELDS):
            if f in NEVER or f == 'on' or x[i] == y[i]: continue
            if f in live[c] or (f in ONDEP and x[3]): return False
    return True


def render_song(data, rate, max_passes=4, max_minutes=40, interp=False):
    """-> (pcm bytes, loop pair, first-pass end pair, exact, max drift, info)
    At every row start after the first repeat, the state is compared with every earlier
    occurrence of the same row (pass 1, pass 2, ...); the earliest match is the loop target."""
    mod = modref.Mod(data)
    p = FastPlayer(mod, rate, interp=interp)
    out = bytearray()
    pairs = 0
    occ = {}             # (pos,row) -> [(pair index, state, positions)] in play order
    seq = []             # pass-1 row keys from the start
    T0 = T1 = None
    idx = live = None
    npass = 1
    limit = rate * 60 * max_minutes
    while True:
        if p.tickleft == 0:
            if p.tick == 0:                       # a row starts here
                key = (p.pos, p.row)
                st, ps = p.state()
                if T1 is None and key in occ:
                    T0, T1 = occ[key][0][0], pairs
                    per = seq[seq.index(key):]
                    idx = {k: i for i, k in enumerate(per)}
                    live = liveness(mod, per)
                if T1 is None:
                    seq.append(key)
                else:
                    if key == per[0]:
                        npass += 1
                        if npass > max_passes:
                            raise RuntimeError('no loop junction in %d passes' % max_passes)
                    lv = live[idx[key]]
                    for t, st1, ps1 in occ[key]:
                        if not same_state(st, st1, lv): continue
                        drift = 0
                        for x, y in zip(ps, ps1):
                            if x is not None and y is not None:
                                drift = max(drift, abs(x[0] - y[0]))
                        if drift <= DRIFT_MAX:
                            exact = drift == 0 and st == st1
                            return bytes(out), t, T1, exact, drift, 'pass %d at %d -> %d' % (npass, pairs, t)
                occ.setdefault(key, []).append((pairs, st, ps))
            p.next_tick()
            continue
        n = min(p.tickleft, 4096)
        out += p.mix(n)
        p.tickleft -= n
        pairs += n
        if pairs > limit:
            raise RuntimeError('song longer than %d minutes' % max_minutes)


def write_raw(path, pcm, rate, ch, loop, end1, exact):
    total = len(pcm) // 2
    h = HDR_MIN + ((512 - (HDR_MIN + 2 * loop) % 512) % 512)
    hdr = bytearray(h)
    hdr[0:4] = b'ISMU'
    struct.pack_into('>HHHH', hdr, 4, 1, rate, ch, h)
    struct.pack_into('>LLLL', hdr, 12, total, loop, end1, 1 if exact else 0)
    with open(path, 'wb') as f:
        f.write(hdr); f.write(pcm)
    return h


def read_raw(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'ISMU'
    ver, rate, ch, h = struct.unpack_from('>HHHH', b, 4)
    total, loop, end1, flags = struct.unpack_from('>LLLL', b, 12)
    return dict(rate=rate, ch=ch, hdr=h, total=total, loop=loop, end1=end1, flags=flags, pcm=b[h:])


def stream(info, pairs):
    """What the ST plays from the file: [0,total) then [loop,total) repeated."""
    pcm = info['pcm']; out = bytearray(pcm[:2 * pairs])
    while len(out) < 2 * pairs:
        out += pcm[2 * info['loop']:2 * info['loop'] + 2 * pairs - len(out)]
    return bytes(out)


def wav(path, pcm, rate):
    w = wave.open(path, 'wb'); w.setnchannels(2); w.setsampwidth(1); w.setframerate(rate)
    w.writeframes((np.frombuffer(pcm, np.uint8) ^ 0x80).astype(np.uint8).tobytes()); w.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sound'); ap.add_argument('out')
    ap.add_argument('--rate', type=int, default=6258)
    ap.add_argument('--wav', help='write a WAV preview per song (first pass + 10 s over the loop)')
    ap.add_argument('--only', help='comma-separated song names')
    ap.add_argument('--interp', action='store_true', help='interpolated render (not the ST mixer\'s sound)')
    ap.add_argument('--preview', type=float, help='with --wav: only the first N seconds')
    ap.add_argument('--check', type=float, default=0,
                    help='seconds: compare the file with tools/modref.py (plain) and the stream over the loop with a continued render')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    if a.wav: os.makedirs(a.wav, exist_ok=True)
    names = sorted(f[:-4] for f in os.listdir(a.sound) if f.upper().endswith('.MOD'))
    if a.only: names = [n for n in names if n.upper() in a.only.upper().split(',')]
    tot = 0; bad = 0
    for n in names:
        data = open(os.path.join(a.sound, n + '.MOD'), 'rb').read()
        pcm, loop, end1, exact, drift, why = render_song(data, a.rate, interp=a.interp)
        ch = modref.Mod(data).ch
        path = os.path.join(a.out, n.upper() + '.RAW')
        h = write_raw(path, pcm, a.rate, ch, loop, end1, exact)
        tot += os.path.getsize(path)
        msg = '%-9s %d ch  %6.1f s (first pass %6.1f s, loop to %6.1f s)  %5d KB  %-7s %s' % (
            n, ch, len(pcm) / 2 / a.rate, end1 / a.rate, loop / a.rate, os.path.getsize(path) // 1024,
            'exact' if exact else 'drift %d' % drift, why)
        if a.check and not a.interp:
            info = read_raw(path)
            np_ = int(a.rate * a.check)
            ref = modref.Player(modref.Mod(data), a.rate).render(min(np_, info['total']))
            same = ref == info['pcm'][:len(ref)]
            # over the junction: continued render vs the looped stream
            span = info['total'] + a.rate * 20
            cont = FastPlayer(modref.Mod(data), a.rate).render(span)
            st = stream(info, span)
            x = np.frombuffer(cont, np.int8).astype(np.int32); y = np.frombuffer(st, np.int8).astype(np.int32)
            j = 2 * info['total']
            diff = int((x[j:] != y[j:]).sum())
            rms = float(np.sqrt(np.mean((x[j:] - y[j:]) ** 2))) if diff else 0.0
            sig = float(np.sqrt(np.mean(x[j:] ** 2))) or 1.0
            msg += '  | modref %s, after the loop %d bytes differ (%.2f %% RMS)' % (
                'identical' if same else 'DIFFERS', diff, 100 * rms / sig)
            if not same: bad += 1
        print(msg, flush=True)
        if a.wav:
            info = read_raw(path)
            pv = int(a.preview * a.rate) if a.preview else info['total'] + 10 * a.rate
            wav(os.path.join(a.wav, n.upper() + '_%d%s.wav' % (a.rate, '_interp' if a.interp else '')), stream(info, pv), a.rate)
    print('%d songs, %.1f MB' % (len(names), tot / 1e6))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
