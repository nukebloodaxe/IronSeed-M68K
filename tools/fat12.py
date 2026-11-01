#!/usr/bin/env python3
"""fat12.py - 720 KB Atari floppy images (FAT12, 9 sectors x 80 tracks x 2 sides), written from
scratch for the floppy version (Phase 8; no external tools).

    img = Floppy(serial=0x123456, label='IRONSEED1')
    img.add('DATA\\MAIN.CHK', data)      # folders are made as needed
    img.write('disk1.st')                 # a raw .ST image (Hatari, Steem, HxC, writing tools)

Layout as TOS formats a 720 KB disk: 1 boot sector, 2 FATs of 5 sectors, 7 root directory
sectors (112 entries), 2 sectors a cluster: 711 data clusters (711 KB)."""
import struct, sys

SECT = 512
NSECT = 1440
SPC = 2
RES = 1
NFATS = 2
SPF = 5
NDIRS = 112
DIRSECT = NDIRS * 32 // SECT
DATA0 = RES + NFATS * SPF + DIRSECT          # first data sector
NCLUST = (NSECT - DATA0) // SPC              # 711
CLUST = SPC * SECT


def name83(n):
    n = n.upper()
    base, _, ext = n.partition('.')
    assert 1 <= len(base) <= 8 and len(ext) <= 3, n
    return (base.ljust(8) + ext.ljust(3)).encode('ascii')


class Dir:
    def __init__(self):
        self.entries = {}          # NAME -> ('f', data) | ('d', Dir)


class Floppy:
    def __init__(self, serial=0x495301, label=None):
        self.root = Dir(); self.serial = serial; self.label = label

    def add(self, path, data):
        parts = path.replace('/', '\\').split('\\')
        d = self.root
        for p in parts[:-1]:
            e = d.entries.setdefault(p.upper(), ('d', Dir()))
            assert e[0] == 'd'
            d = e[1]
        d.entries[parts[-1].upper()] = ('f', bytes(data))

    def clusters_needed(self):
        def walk(d, top):
            n = 0
            if not top: n += max(1, -(-(len(d.entries) + 2) * 32 // CLUST))
            for k, (t, v) in d.entries.items():
                n += walk(v, False) if t == 'd' else -(-len(v) // CLUST)
            return n
        return walk(self.root, True)

    def free_bytes(self):
        return (NCLUST - self.clusters_needed()) * CLUST

    def write(self, fn):
        img = bytearray(NSECT * SECT)
        fat = [0] * (NCLUST + 2)
        fat[0] = 0xFF9; fat[1] = 0xFFF
        nxt = [2]

        def alloc(n):
            n = max(n, 1)
            first = nxt[0]
            assert first + n - 1 <= NCLUST + 1, 'disk full'
            for i in range(n):
                c = first + i
                fat[c] = c + 1 if i < n - 1 else 0xFFF
            nxt[0] += n
            return first

        def put(c, data):
            for i in range(0, len(data), CLUST):
                off = (DATA0 + (c - 2) * SPC) * SECT
                img[off:off + min(CLUST, len(data) - i)] = data[i:i + CLUST]
                c = fat[c] if i + CLUST < len(data) else c

        def entry(name, attr, clus, size):
            return name + bytes([attr]) + bytes(10) + struct.pack('<HHHI', 0, 0x5A21, clus, size)

        def build(d, parent_clus, self_clus):
            ents = []
            if self_clus is not None:
                ents.append(entry(b'.          ', 0x10, self_clus, 0))
                ents.append(entry(b'..         ', 0x10, parent_clus, 0))
            for k in sorted(d.entries):
                t, v = d.entries[k]
                if t == 'f':
                    c = alloc(-(-len(v) // CLUST)) if v else 0
                    if v: put(c, v)
                    ents.append(entry(name83(k), 0x00, c, len(v)))
                else:
                    n = max(1, -(-(len(v.entries) + 2) * 32 // CLUST))
                    c = alloc(n)
                    ents.append((name83(k), c, v, n))
            out = []
            for e in ents:
                if isinstance(e, tuple):
                    nm, c, sub, n = e
                    raw = build(sub, self_clus or 0, c)
                    raw = raw.ljust(n * CLUST, b'\0')
                    put(c, raw)
                    out.append(entry(nm, 0x10, c, 0))
                else:
                    out.append(e)
            return b''.join(out)

        root = b''
        if self.label:
            root += self.label.upper().ljust(11)[:11].encode('ascii') + bytes([0x08]) + bytes(10) + struct.pack('<HHHI', 0, 0x5A21, 0, 0)
        root += build(self.root, 0, None)
        assert len(root) <= NDIRS * 32, 'root directory full'
        img[(RES + NFATS * SPF) * SECT:(RES + NFATS * SPF) * SECT + len(root)] = root
        # FATs (12-bit entries, little-endian pairs)
        fb = bytearray(SPF * SECT)
        for i in range(0, len(fat), 2):
            a = fat[i]; b = fat[i + 1] if i + 1 < len(fat) else 0
            o = i // 2 * 3
            fb[o:o + 3] = bytes([a & 0xFF, ((a >> 8) & 0x0F) | ((b & 0x0F) << 4), (b >> 4) & 0xFF])
        for k in range(NFATS):
            o = (RES + k * SPF) * SECT
            img[o:o + len(fb)] = fb
        # boot sector: BRA, OEM, serial (TOS tells disks apart by it), BPB (little-endian)
        bs = bytearray(SECT)
        bs[0:2] = b'\x60\x38'
        bs[2:8] = b'IRONSD'
        bs[8:11] = struct.pack('<I', self.serial)[:3]
        struct.pack_into('<HBHBHHBHHHH', bs, 11, SECT, SPC, RES, NFATS, NDIRS, NSECT, 0xF9, SPF, 9, 2, 0)
        s = sum(struct.unpack('>256H', bs)) & 0xFFFF             # not bootable: checksum != $1234
        if s == 0x1234: bs[510] ^= 1
        img[0:SECT] = bs
        open(fn, 'wb').write(img)


def extract(fn, out):
    """every file of a FAT12 floppy image into folder out (tests: the save disk after a session)"""
    import os
    img = open(fn, 'rb').read()
    bps, spc, res, nf, nd, ns, _, spf = struct.unpack_from('<HBHBHHBH', img, 11)
    fat = img[res * bps:(res + spf) * bps]
    d0 = (res + nf * spf) * bps + nd * 32
    def nxt(c):
        o = c * 3 // 2
        v = fat[o] | fat[o + 1] << 8
        return v >> 4 if c & 1 else v & 0xFFF
    def chain(c):
        out = b''
        while 2 <= c < 0xFF8:
            o = d0 + (c - 2) * spc * bps
            out += img[o:o + spc * bps]; c = nxt(c)
        return out
    def walk(raw, path):
        for i in range(0, len(raw), 32):
            e = raw[i:i + 32]
            if e[0] == 0: break
            if e[0] in (0xE5, 0x2E) or e[11] & 0x08: continue
            nm = e[:8].decode('latin1').rstrip() + ('.' + e[8:11].decode('latin1').rstrip() if e[8:11].strip() else '')
            c, size = struct.unpack_from('<HI', e, 26)
            p = os.path.join(path, nm)
            if e[11] & 0x10:
                os.makedirs(p, exist_ok=True); walk(chain(c), p)
            else:
                open(p, 'wb').write(chain(c)[:size])
    os.makedirs(out, exist_ok=True)
    walk(img[(res + nf * spf) * bps:d0], out)


if __name__ == '__main__' and sys.argv[1] == '--extract':
    extract(sys.argv[2], sys.argv[3])
elif __name__ == '__main__':
    f = Floppy(label='TEST')
    for a in sys.argv[2:]:
        f.add(a.split('/')[-1], open(a, 'rb').read())
    f.write(sys.argv[1])
    print('%s: %d KB free' % (sys.argv[1], f.free_bytes() // 1024))
