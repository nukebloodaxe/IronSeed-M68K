#!/usr/bin/env python3
"""mkfloppy.py GAMEDIR OUTDIR [FILE=DISK ...] (tests: FILE into the root of disk DISK) : the floppy version (Phase 8) - 720 KB disk images.

GAMEDIR is a game folder built by tools/mkgame.sh with NOMUSIC=1 (the floppies mix the MODs in
real time). Every file is packed (raw deflate, kernel fil.s/inflate.s; a MOD's samples as byte
deltas) except the files read by record (fil.s: they are opened and seeked directly); the
programs unpack themselves (tools/packprg.py, game/stub.s); IS.PRG stays as it is. The
files are grouped by the screen that loads them and the groups placed on disks:

  disk 1  AUTO\\IS.PRG (boot), IS.PRG, INTRO.PRG and the intro's data
  disk 2  CREWGEN.PRG and its data, combat
  disk 3  MAIN.PRG, what it loads at start-up, the bridge, cargo
  disk 4  the screens used most: exploration, logs, crew, creation, trade
  disk 5  the ending
  then    the other groups whole (each race with the contact screen's own files), largest
          first, on the first disk with room: disks 4+ before 1-3, a new disk when none has
  save    SAVEGAME.DIR, SAVEn\\ (the game folder's), ISSAVE.ID
A file in several groups goes on each of their disks; the prompt asks for the lowest.

Each game disk carries ISDISK.TAB (kernel flp.s): 'ISD1', w this disk, w file count, w save
disk number, then per file: w disk mask (bit n-1 = disk n), w flags (1 = keep in the RAM cache,
2 = music: never asks for a disk), the name (upper case, 0, padded to even). Boot sector
serials differ per disk (TOS notices the swap); the volume label is IRONSEED n."""
import os, re, sys, zlib, struct, fnmatch, shutil, subprocess, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fat12 import Floppy, CLUST, NCLUST
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

KEEP, MUSIC = 1, 2

# files the programs never open (checked against every session's GEMDOS trace and the sources)
DEAD = r'''DATA\\(ALIEN\d*\.ISP|BACK\d+\.ISP|IMAGE\d+\.ISP|DEMOSCR.*|WORLD\.ISP|BATTLE1\.ISP|CHANNEL7\.ISP
|SHIP1\.ISP|MAIN3\.ISP|INTRO[2356]\.ISP|SAVER\.ISP|CHAR\.ISP|LANDFORM\.ISP|PLAN1\.DTA|CHARANI\.DTA
|END[1-6]\.ISP|CLOUD\.ISP|COM\.ISP|WARICON\.ISP|TRADE\.ISP)|SOUND\\(GAME|SCANNER)\.MOD'''
DEAD = re.compile('^(' + DEAD.replace('\n', '') + ')$')
RECORD = {'DATA\\CONTACT0.DTA', 'DATA\\EVENT.DTA', 'DATA\\LOG.DTA', 'DATA\\PLANNAME.TXT'}

RACES = ['SENGZHAC', 'DPAK', 'AARD', 'ERMIGEN', 'TITARIAN', 'QUAI', 'SCAVENG', 'ICON', 'GUILD',
         'PHADOR', 'VOID']
BACKS = [7, 18, 9, 15, 22, 17, 4, 14, 2, 21, 19]             # contact.s .backs

# (group, disk / None: first fit / 0: only with groups that need it, [patterns]) in placement order; a file goes to the first group matching
GROUPS = [
    ('intro', 1, ['INTRO.PRG', 'DATA\\WEAPICON.DTA', 'DATA\\CREDITS.ISL', 'DATA\\PLANET.DAT',
                  'DATA\\C7.ISP', 'DATA\\TITLE.DAT', 'DATA\\MAINPAL.ISL', 'DATA\\NBLOGO.DAT',
                  'DATA\\MARS.DAT', 'DATA\\PLN1.ISP', 'DATA\\CHARCOM.ISP', 'DATA\\PLN2.ISP',
                  'DATA\\PLN2.PAL', 'DATA\\SHRINK.DAT', 'DATA\\ALIENS.DAT', 'DATA\\IS2.DAT',
                  'DATA\\PLN3.ISP', 'SOUND\\INTRO1.MOD', 'SOUND\\INTRO2.MOD', 'DATA\\MAIN.PAL']),
    ('crewgen', 2, ['CREWGEN.PRG', 'DATA\\CGMODES.DAT', 'DATA\\CGDATA.DAT', 'DATA\\CREW.DTA',
                    'DATA\\SYSSET.DTA', 'DATA\\CGANI.DAT', 'DATA\\CGSHIP.DAT', 'SOUND\\CHARGEN.MOD']),
    ('main', 3, ['MAIN.PRG', 'DATA\\MAIN.PAL', 'DATA\\SPHERE.DAT', 'DATA\\CUBE.DAT',
                 'DATA\\WEAPICON.DTA', 'DATA\\ICONS.VGA', 'DATA\\WEAPON.DTA', 'DATA\\CARGO.DTA',
                 'DATA\\ARTIFACT.DTA', 'DATA\\PLANICON.DTA', 'DATA\\CREATION.DTA', 'DATA\\PORTRAIT.DAT',
                 'DATA\\LOADG.*', 'DATA\\INTRO2E.*']),
    ('bridge', 3, ['DATA\\MAIN.ISP', 'DATA\\MAIN.CHK', 'DATA\\CLOUD.CHK', 'DATA\\MAIN?*.ISP',
                   'DATA\\CONTACT0.DTA', 'SOUND\\SECTOR.MOD', 'DATA\\SCAN.DTA', 'DATA\\SYSNAME.DTA',
                   'DATA\\SHIPPIX.DTA']),
    ('contact', 0, ['DATA\\COM.CHK', 'DATA\\COMNR.ISP', 'DATA\\EVENT.DTA', 'DATA\\PLANNAME.TXT']),
    ('log', 4, ['DATA\\LOG.*', 'DATA\\LOGCUR.DAT', 'DATA\\TITLES.DTA', 'SOUND\\CREWEVAL.MOD']),
    ('cargo', 3, ['DATA\\CARGO.ISP', 'DATA\\CARGO.CHK', 'SOUND\\CARGO.MOD']),
    ('tech', 4, ['DATA\\TECH1.*', 'DATA\\ITEMINFO.DTA', 'DATA\\CREATION.DTA', 'SOUND\\COMPONT.MOD']),
    ('crewcomm', 4, ['DATA\\CCOM.*', 'DATA\\CONV000?.*', 'SOUND\\CREWCOMM.MOD']),
    ('psyche', 4, ['DATA\\CHAR2.*', 'DATA\\PSYCHE.*', 'DATA\\CREW.DTA', 'SOUND\\PSYEVAL.MOD']),
    ('combat', 2, ['DATA\\FIGHT.*', 'DATA\\WARICON.CHK', 'DATA\\SHIPS.DTA', 'SOUND\\COMBAT.MOD', 'SOUND\\VICTORY.MOD',
                      'SOUND\\EXPLODE1.SAM', 'SOUND\\EXPLODE2.SAM', 'SOUND\\GUN?.SAM', 'SOUND\\LASER?.SAM']),
    ('sector', None, ['DATA\\SECTOR.*', 'DATA\\SYSSET.DTA', 'SOUND\\GENER1.MOD']),
    ('explore', 4, ['DATA\\LAND.*', 'DATA\\LAND?.ISP', 'DATA\\ELEMENTS.DTA', 'DATA\\SCAN.DTA',
                    'SOUND\\PROBE.MOD']),
    ('trade', 4, ['DATA\\TRADE.CHK', 'DATA\\COMA?*.ISP', 'DATA\\CREATION.DTA']),
    ('eggs', None, ['DATA\\EGG*', 'SOUND\\EXPLODE3.SAM']),
    ('ending', 5, ['DATA\\END*', 'DATA\\CRED.*', 'DATA\\MAIN.PAL', 'DATA\\INTRO2E.*', 'SOUND\\DIMENSIO.MOD', 'SOUND\\LOVE.MOD']),
    ('strangers', None, ['DATA\\BACK*.CHK', 'DATA\\COMG*.ISP', 'DATA\\CONV11??.*', 'DATA\\CONV1000.*']),
] + [('race%d' % (r + 1), None, ['SOUND\\%s.MOD' % m, 'DATA\\ALIEN%d.CHK' % (r + 1),
                                 'DATA\\CONV%d.*' % (1001 + r)]) for r, m in enumerate(RACES)]

# groups that also need another group on their disk (copied there: those files are on several disks)
NEEDS = {'race%d' % (r + 1): ['contact', 'trade', 'DATA\\BACK%d.CHK' % ((BACKS[r] - 1) // 2 + 1),
                              'DATA\\COMA%d.ISP' % (r + 1)] for r in range(11)}
NEEDS['strangers'] = ['contact', 'SOUND\\PROBE.MOD']
NEEDS['trade'] = ['DATA\\COM.CHK']
KEEPS = {'bridge', 'contact'}


def mod_dstart(b):
    if len(b) < 1084 or b[1080:1084] not in (b'M.K.', b'M!K!', b'FLT4', b'4CHN'):
        return 0
    return 1084 + 1024 * (max(b[952:952 + 128]) + 1)


def pack(name, b):
    """the file as it goes on the disk (packed unless that is no smaller or it is read by record)"""
    if name in RECORD or name.endswith('.PRG'):
        return b
    ds = mod_dstart(b) if name.endswith('.MOD') else 0
    src = bytearray(b)
    if ds:
        p = 0
        for i in range(ds, len(b)):
            src[i] = (b[i] - p) & 255; p = b[i]
    c = zlib.compressobj(9, zlib.DEFLATED, -15, 9)
    z = c.compress(bytes(src)) + c.flush()
    out = b'ISZ1' + struct.pack('>II', len(b), ds) + z
    return out if len(out) < len(b) else b


def unpack(b):
    if b[:4] != b'ISZ1':
        return b
    n, ds = struct.unpack('>II', b[4:12])
    u = bytearray(zlib.decompress(b[12:], -15))
    assert len(u) == n
    if ds:
        p = 0
        for i in range(ds, n):
            p = (p + u[i]) & 255; u[i] = p
    return bytes(u)


def clusters(n):
    return max(1, -(-n // CLUST)) if n else 0


def main():
    gd, out = sys.argv[1], sys.argv[2]
    extra = [a.split('=', 1) for a in sys.argv[3:] if '=' in a]     # (tests: FILE=DISK, a file in the root)
    os.makedirs(out, exist_ok=True)
    files = {}
    for d in ('DATA', 'SOUND'):
        for f in sorted(os.listdir(os.path.join(gd, d))):
            n = d + '\\' + f
            if not DEAD.match(n):
                files[n] = open(os.path.join(gd, d, f), 'rb').read()
    for f in ('INTRO.PRG', 'CREWGEN.PRG', 'MAIN.PRG'):
        files[f] = open(os.path.join(gd, f), 'rb').read()
    packed = {n: pack(n, b) for n, b in files.items()}
    for n, b in packed.items():
        assert n.endswith('.PRG') or unpack(b) == files[n], n
    tmp = tempfile.mkdtemp()
    for f in ('INTRO.PRG', 'CREWGEN.PRG', 'MAIN.PRG'):    # self-unpacking (tools/packprg.py)
        subprocess.run([sys.executable, '-I', os.path.join(R, 'tools', 'packprg.py'), os.path.join(gd, f),
                        os.path.join(tmp, f)], check=True, stdout=subprocess.DEVNULL)
        packed[f] = open(os.path.join(tmp, f), 'rb').read()
    shutil.rmtree(tmp)
    # groups
    member = {}
    gfiles = {g: [] for g, _, _ in GROUPS}
    for n in sorted(files):
        for g, _, pats in GROUPS:
            if any(fnmatch.fnmatchcase(n, p) for p in pats):
                member.setdefault(n, g)
                gfiles[g].append(n)
    loose = [n for n in files if n not in member]
    if loose:
        sys.exit('files in no group: ' + ' '.join(loose))

    def need(g):
        s = set(gfiles[g])
        for x in NEEDS.get(g, []):
            s |= set(gfiles[x]) if x in gfiles else {x}
        return s

    def kb(names):
        return sum(clusters(len(packed[n])) for n in names)

    budget = NCLUST - 16               # FAT12 data clusters less: DATA, SOUND, AUTO folders, ISDISK.TAB, tests
    disks = {d: set() for d in range(1, 6)}
    disks[1] |= {'IS.PRG', 'AUTO\\IS.PRG'}
    if os.path.exists(os.path.join(gd, 'README.TXT')):
        files['README.TXT'] = packed['README.TXT'] = open(os.path.join(gd, 'README.TXT'), 'rb').read()
        disks[1].add('README.TXT')
    files['IS.PRG'] = files['AUTO\\IS.PRG'] = open(os.path.join(gd, 'IS.PRG'), 'rb').read()
    packed['IS.PRG'] = packed['AUTO\\IS.PRG'] = files['IS.PRG']
    placed = {}
    free = [(g, d) for g, d, _ in GROUPS]
    for g, d in free:
        if d:                          # (0: only where another group needs it)
            disks[d] |= need(g); placed[g] = d
    rest = sorted([g for g, d in free if d is None], key=lambda g: -kb(need(g)))
    for g in rest:
        s = need(g)
        for d in sorted(disks, key=lambda d: (d < 4, d)):     # disks 4+ first, 1-3 when they are full
            if kb(disks[d] | s) <= budget:
                disks[d] |= s; placed[g] = d; break
        else:
            d = max(disks) + 1; disks[d] = set(s); placed[g] = d
    ngame = max(disks)
    for d in sorted(disks):
        assert kb(disks[d]) <= budget, (d, kb(disks[d]))
    where = {}
    for d, s in disks.items():
        for n in s:
            where.setdefault(n, set()).add(d)
    save = ngame + 1
    # tables and images
    for d in sorted(disks):
        ents = b''
        for f, k in extra:
            where.setdefault(os.path.basename(f).upper(), set()).add(int(k))
        names = sorted(n for n in where if not n.startswith('AUTO') and n != 'README.TXT')
        for n in names:
            mask = sum(1 << (k - 1) for k in where[n])
            fl = (KEEP if member.get(n) in KEEPS else 0) | (MUSIC if n.endswith('.MOD') else 0)
            nm = n.encode('ascii') + b'\0'
            if len(nm) & 1: nm += b'\0'
            ents += struct.pack('>HH', mask, fl) + nm
        tab = b'ISD1' + struct.pack('>HHH', d, len(names), save) + ents
        img = Floppy(serial=0x495300 + d * 0x1111 + 7, label='IRONSEED%d' % d)
        for n in sorted(disks[d]):
            img.add(n, packed[n])
        img.add('ISDISK.TAB', tab)
        for f, k in extra:
            if int(k) == d:
                img.add(os.path.basename(f).upper(), open(f, 'rb').read())
        fn = os.path.join(out, 'IRONSEED%d.ST' % d)
        img.write(fn)
        grp = sorted({member.get(n, 'is') for n in disks[d]} - {'is'})
        print('disk %d: %3d files, %3d KB free  %s' % (d, len(disks[d]), img.free_bytes() // 1024, ' '.join(
            g for g in grp if placed.get(g) == d or g in ('intro', 'main'))))
    img = Floppy(serial=0x495399, label='IS SAVE')
    img.add('ISSAVE.ID', b'Iron Seed save disk\r\n')
    for f in sorted(os.listdir(gd)):
        p = os.path.join(gd, f)
        if f == 'SAVEGAME.DIR':
            img.add(f, open(p, 'rb').read())
        elif re.match(r'SAVE\d$', f) and os.path.isdir(p):
            for g in sorted(os.listdir(p)):
                img.add(f + '\\' + g, open(os.path.join(p, g), 'rb').read())
    img.write(os.path.join(out, 'IRONSEED%d.ST' % save))
    print('disk %d: the save disk, %d KB free' % (save, img.free_bytes() // 1024))
    print('game data %d KB on %d disks (unpacked %d KB)' % (
        sum(kb(s) for s in disks.values()), ngame, sum(len(b) for b in files.values()) // 1024))


if __name__ == '__main__':
    main()
