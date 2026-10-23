#!/usr/bin/env python3
"""check_stream.py - host side of tests/ktstream.s.
  check_stream.py make SOUND_DIR CDIR      write CDIR/MUSIC/TEST.RAW (8 s of INTRO1, loop at 3 s,
                                           first pass 6 s) and CDIR/SOUND/TEST.MOD (a copy)
  check_stream.py check CDIR [--once] [--sfx SAM]   compare C:\\SND.RAW with what the file says"""
import os, struct, sys, shutil
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
import mkmusic, modref  # noqa

RATE = 6258; LOOP = 3 * RATE + 1; END1 = 6 * RATE + 3; TOTAL = 8 * RATE + 5   # odd pair counts on purpose


def make(sound, cdir):
    data = open(os.path.join(sound, 'INTRO1.MOD'), 'rb').read()
    pcm = modref.Player(modref.Mod(data), RATE).render(TOTAL)
    os.makedirs(os.path.join(cdir, 'MUSIC'), exist_ok=True); os.makedirs(os.path.join(cdir, 'SOUND'), exist_ok=True)
    mkmusic.write_raw(os.path.join(cdir, 'MUSIC', 'TEST.RAW'), pcm, RATE, 8, LOOP, END1, False)
    shutil.copy(os.path.join(sound, 'INTRO1.MOD'), os.path.join(cdir, 'SOUND', 'TEST.MOD'))


def check(cdir, once, sfx):
    info = mkmusic.read_raw(os.path.join(cdir, 'MUSIC', 'TEST.RAW'))
    cap = open(os.path.join(cdir, 'SND.RAW'), 'rb').read()
    n, sfxat, under, reads, start, modon = struct.unpack('>5LH', open(os.path.join(cdir, 'SND.TXT'), 'rb').read()[:22])
    st = start // 2
    if once:
        exp = info['pcm'][:2 * END1]
    else:
        exp = mkmusic.stream(info, st + n)
    exp = exp[2 * st:2 * (st + n)]
    exp = exp + bytes(2 * n - len(exp))          # silence after a play-once end
    if sfx:
        exp = modref.add_sfx(exp, open(sfx, 'rb').read(), 9000, RATE, sfxat, 8 // 2)
    bad = sum(1 for a, b in zip(cap, exp) if a != b)
    ok = bad == 0 and len(cap) == len(exp) and under == 0 and (modon == 0) == once
    print('%d pairs from stream pair %d, %d bytes differ, %d underrun pairs, %d chunks read, mod_on %d%s' % (
        n, st, bad, under, reads, modon, ', effect at pair %d' % sfxat if sfx else ''))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    if sys.argv[1] == 'make': make(sys.argv[2], sys.argv[3])
    else: check(sys.argv[2], '--once' in sys.argv, sys.argv[sys.argv.index('--sfx') + 1] if '--sfx' in sys.argv else None)
