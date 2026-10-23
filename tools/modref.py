#!/usr/bin/env python3
"""modref.py - reference MOD player for the STE port: the exact integer algorithm the
68000 replay (kernel/mod.s + snd.s) implements, so its output can be compared byte for byte.

  modref.py SONG.MOD OUT.raw [--rate 12517|6258] [--seconds N] [--wav out.wav] [--ticks ticks.txt]

Output: signed 8-bit stereo pairs (left, right), as written to the STE DMA ring.

Model (both implementations):
- Formats: M.K./M!K!/FLT4 (4 ch), 6CHN, 8CHN; 31 samples; Amiga periods.
- Timing by sample count: tick length = rate*5/(2*bpm) in 16.16 fixed point, fraction carried.
- Effects: 0 arpeggio, 1/2 slide, 3 tone porta, 4 vibrato, 5/6 (3/4 + volume slide), 8 pan,
  9 offset, A volume slide, B jump, C volume, D break, F speed/bpm, E1/E2 fine slide,
  E9 retrigger, EA/EB fine volume, EC cut, ED delay; others ignored.
- Finetune ignored (periods used as stored). Periods clamped to 113..856 by slides.
- Panning: channel c -> side (0,1,1,0)[c%4] (L R R L); 8xx: xx < 128 left, else right.
- Mixer: per voice step = steptab[period] (16.16) = floor(3546895 * 65536 / rate / period);
  each output sample reads sample[pos] then advances pos by step; volume table
  vt[v][s] = floor(s * v / (64 * vps)) where vps = channels/2; per side the
  contributions are summed (no clipping needed by construction).
- Sample end: looped samples (looplen > 2) wrap pos -= looplen while pos >= loopstart+looplen;
  others go silent at pos >= length. A looped sample triggered (9xx) past its loop end starts at
  loopstart + (offset - loopstart) mod looplen.
"""
import argparse, struct, sys

CLOCK = 3546895
SINE = [0, 24, 49, 74, 97, 120, 141, 161, 180, 197, 212, 224, 235, 244, 250, 253,
        255, 253, 250, 244, 235, 224, 212, 197, 180, 161, 141, 120, 97, 74, 49, 24]
PERIODS = [856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
           428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
           214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113]


def steptab(rate):
    return [0] + [CLOCK * 65536 // rate // p for p in range(1, 1024)]


def voltab(vps):
    return [[(s if s < 128 else s - 256) * v // (64 * vps) for s in range(256)] for v in range(65)]


class Mod:
    def __init__(self, data):
        sig = data[1080:1084]
        self.ch = {b'M.K.': 4, b'M!K!': 4, b'FLT4': 4, b'6CHN': 6, b'8CHN': 8}.get(sig)
        if self.ch is None: raise ValueError('unsupported MOD signature %r' % sig)
        self.samples = []
        for i in range(31):
            o = 20 + i * 30
            ln, ft, vol, ls, ll = struct.unpack('>HBBHH', data[o + 22:o + 30])
            self.samples.append(dict(len=ln * 2, vol=min(vol, 64), ls=ls * 2, ll=ll * 2))
        self.npos = data[950]
        self.order = list(data[952:952 + 128])
        npat = max(self.order) + 1
        self.patsize = 64 * self.ch * 4
        self.pat = data[1084:1084 + npat * self.patsize]
        o = 1084 + npat * self.patsize
        for s in self.samples:
            s['data'] = data[o:o + s['len']]; o += s['len']
            if s['ll'] <= 2: s['ll'] = 0
            if s['ls'] + s['ll'] > s['len']: s['ll'] = max(0, s['len'] - s['ls'])

    def cell(self, pat, row, c):
        o = pat * self.patsize + (row * self.ch + c) * 4
        b = self.pat[o:o + 4]
        return (b[0] & 0xf0) | (b[2] >> 4), ((b[0] & 15) << 8) | b[1], b[2] & 15, b[3]


class Chan:
    def __init__(self, side):
        self.side = side; self.smp = None; self.period = 0; self.vol = 0
        self.pos = 0; self.frac = 0; self.on = False
        self.porta_target = 0; self.porta_speed = 0; self.vib_pos = 0; self.vib_speed = 0; self.vib_depth = 0
        self.eff = 0; self.prm = 0; self.offset = 0; self.out_period = 0
        self.note_smp = 0; self.note_per = 0; self.delay = 0


class Player:
    def __init__(self, mod, rate):
        self.m = mod; self.rate = rate
        self.step = steptab(rate); self.vt = voltab(mod.ch // 2)
        self.ch = [Chan((0, 1, 1, 0)[c % 4]) for c in range(mod.ch)]
        self.speed = 6; self.bpm = 125; self.tick = 0; self.row = 0; self.pos = 0
        self.tickacc = 0; self.tickleft = 0
        self.jump = -1; self.brk = -1
        self.log = []

    def trigger(self, c, offset=0):
        c.pos = offset; c.frac = 0
        c.on = c.smp is not None and c.smp['len'] > 0 and offset < c.smp['len']
        s = c.smp
        if c.on and s['ll'] and offset >= s['ls'] + s['ll']:  # started past the loop end: wrap into the loop
            c.pos = s['ls'] + (offset - s['ls']) % s['ll']

    def do_row(self):
        m = self.m; pat = m.order[self.pos]
        for i, c in enumerate(self.ch):
            smp, per, eff, prm = m.cell(pat, self.row, i)
            c.eff, c.prm = eff, prm
            if eff == 0xE and (prm >> 4) == 0xD and (prm & 15):  # note delay: everything at tick n
                c.note_smp, c.note_per, c.delay = smp, per, prm & 15
                continue
            self.apply_note(c, smp, per, eff, prm)
            # tick-0 effects
            if eff == 0xC: c.vol = min(prm, 64)
            elif eff == 0xF:
                if prm == 0: pass
                elif prm < 32: self.speed = prm
                else: self.bpm = prm
            elif eff == 0xD: self.brk = (prm >> 4) * 10 + (prm & 15)
            elif eff == 0xB: self.jump = prm
            elif eff == 0x8: c.side = 0 if prm < 128 else 1
            elif eff == 0xE:
                x, y = prm >> 4, prm & 15
                if x == 1: c.period = max(113, c.period - y)
                elif x == 2: c.period = min(856, c.period + y)
                elif x == 0xA: c.vol = min(64, c.vol + y)
                elif x == 0xB: c.vol = max(0, c.vol - y)
                elif x == 0xC and y == 0: c.vol = 0
            if eff == 4 or eff == 6:
                pass
            c.out_period = c.period

    def apply_note(self, c, smp, per, eff, prm):
        if smp and smp <= 31:
            c.smp = self.m.samples[smp - 1]; c.vol = c.smp['vol']
        if eff == 0x3 or eff == 0x5:
            if per: c.porta_target = per
            if eff == 3 and prm: c.porta_speed = prm
        elif per:
            c.period = per
            c.vib_pos = 0
            off = 0
            if eff == 9:
                if prm: c.offset = prm << 8
                off = c.offset
            self.trigger(c, off)
        if eff == 4:
            if prm >> 4: c.vib_speed = prm >> 4
            if prm & 15: c.vib_depth = prm & 15

    def do_ticks(self):
        for c in self.ch:
            eff, prm = c.eff, c.prm
            x, y = prm >> 4, prm & 15
            c.out_period = c.period
            if eff == 0 and prm:
                n = self.tick % 3
                if n:
                    add = x if n == 1 else y
                    if c.period in PERIODS:
                        k = PERIODS.index(c.period) + add
                        c.out_period = PERIODS[min(k, 35)]
            elif eff == 1: c.period = max(113, c.period - prm); c.out_period = c.period
            elif eff == 2: c.period = min(856, c.period + prm); c.out_period = c.period
            elif eff in (3, 5):
                if c.porta_target:
                    if c.period < c.porta_target: c.period = min(c.porta_target, c.period + c.porta_speed)
                    elif c.period > c.porta_target: c.period = max(c.porta_target, c.period - c.porta_speed)
                c.out_period = c.period
            if eff in (4, 6):
                d = SINE[c.vib_pos & 31] * c.vib_depth >> 7
                if c.vib_pos & 32: d = -d
                c.out_period = c.period + d
                c.vib_pos = (c.vib_pos + c.vib_speed) & 63
            if eff in (5, 6, 0xA):
                if x: c.vol = min(64, c.vol + x)
                else: c.vol = max(0, c.vol - y)
            if eff == 0xE:
                if x == 9 and y and self.tick % y == 0: self.trigger(c, 0)
                elif x == 0xC and self.tick == y: c.vol = 0
                elif x == 0xD and self.tick == c.delay:
                    self.apply_note(c, c.note_smp, c.note_per, 0, 0); c.out_period = c.period

    def next_tick(self):
        if self.tick == 0:
            self.do_row()
        else:
            self.do_ticks()
        if self.tick == 0:  # E9 also retriggers on tick 0 only via the note itself
            pass
        self.log.append((self.pos, self.row, self.tick, [(c.out_period, c.vol, c.on, c.side) for c in self.ch]))
        self.tick += 1
        if self.tick >= self.speed:
            self.tick = 0
            if self.brk >= 0 or self.jump >= 0:
                self.pos = self.jump if self.jump >= 0 else self.pos + 1
                self.row = self.brk if self.brk >= 0 else 0
                self.brk = self.jump = -1
            else:
                self.row += 1
                if self.row >= 64: self.row = 0; self.pos += 1
            if self.pos >= self.m.npos: self.pos = 0
            if self.row >= 64: self.row = 0
        # tick length in samples, 16.16 with the fraction carried
        self.tickacc += self.rate * 5 * 65536 // (2 * self.bpm)
        self.tickleft = self.tickacc >> 16
        self.tickacc &= 0xffff

    def mix(self, n):
        out = bytearray(2 * n)
        acc = [[0] * n, [0] * n]
        for c in self.ch:
            if not c.on or c.out_period == 0: continue
            st = self.step[min(c.out_period, 1023)]
            s = c.smp; d = s['data']; vt = self.vt[c.vol]; a = acc[c.side]
            pos, frac = c.pos, c.frac
            ln, ls, ll = s['len'], s['ls'], s['ll']
            for i in range(n):
                if pos >= ln and not ll:
                    c.on = False; break
                a[i] += vt[d[pos]]
                frac += st & 0xffff
                pos += (st >> 16) + (frac >> 16)
                frac &= 0xffff
                if ll:
                    while pos >= ls + ll: pos -= ll
            c.pos, c.frac = pos, frac
        for i in range(n):
            out[2 * i] = acc[0][i] & 255; out[2 * i + 1] = acc[1][i] & 255
        return out

    def render(self, pairs):
        out = bytearray()
        while pairs > 0:
            if self.tickleft == 0:
                self.next_tick()
                continue
            k = min(pairs, self.tickleft)
            out += self.mix(k)
            pairs -= k; self.tickleft -= k
        return bytes(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mod'); ap.add_argument('out')
    ap.add_argument('--rate', type=int, default=12517)
    ap.add_argument('--seconds', type=float, default=10)
    ap.add_argument('--wav'); ap.add_argument('--ticks')
    a = ap.parse_args()
    p = Player(Mod(open(a.mod, 'rb').read()), a.rate)
    data = p.render(int(a.rate * a.seconds))
    open(a.out, 'wb').write(data)
    if a.wav:
        import wave
        w = wave.open(a.wav, 'wb'); w.setnchannels(2); w.setsampwidth(1); w.setframerate(a.rate)
        w.writeframes(bytes((b + 128) & 255 for b in data)); w.close()
    if a.ticks:
        with open(a.ticks, 'w') as f:
            for pos, row, tick, chans in p.log:
                f.write('%3d %2d %2d  %s\n' % (pos, row, tick, ' '.join('%3d/%2d%s' % (pp, v, '*' if on else ' ') for pp, v, on, _ in chans)))
    print('%s: %d channels, %d pairs, %d ticks' % (a.mod, p.m.ch, len(data) // 2, len(p.log)))


if __name__ == '__main__':
    main()
