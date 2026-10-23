#!/usr/bin/env python3
"""oracle_cmp.py - decode and compare state dumps field by field.

  oracle_cmp.py build/layout.json A.bin [B.bin]

A dump is a sequence of blocks: name (Pascal string[23] = 24 bytes), int32 size, data.
Dumps from the Linux oracle hold the DOS layout (little-endian, packed); dumps
written by the ST port hold the 68000 layout (big-endian, aligned) - detected by
the block size. With one file: print a summary. With two: list every differing
field as a path (ship.crew[3].xp: 120 != 121).
"""
import json, struct, sys

BOOLS = ('showplanet',)
INTF = {'u8': 'B', 's8': 'b', 's16': 'h', 'u16': 'H', 's32': 'i', 'u32': 'I', 'u64': 'Q', 's64': 'q', 'f64': 'd', 'f32': 'f'}


def read_blocks(fn):
    """blocks of a dump; read_blocks.st = True when the sizes are big-endian (written by the ST)"""
    d = open(fn, 'rb').read(); i = 0; out = {}; read_blocks.st = False
    while i < len(d):
        n = d[i + 1:i + 1 + d[i]].decode()
        sz = struct.unpack('<i', d[i + 24:i + 28])[0]
        if sz < 0 or sz > len(d):
            sz = struct.unpack('>i', d[i + 24:i + 28])[0]; read_blocks.st = True  # ST-written (big-endian)
        out[n] = d[i + 28:i + 28 + sz]; i += 28 + sz
    return out


def decode(desc, b, off, st):
    k = desc['kind']
    if k == 'base':
        if desc['type'] == 'ptr': return None
        f = ('>' if st else '<') + INTF[desc['type']]
        return struct.unpack_from(f, b, off)[0]
    if k == 'pointer': return None
    if k == 'string':
        n = b[off]; return b[off + 1:off + 1 + min(n, desc['len'])].decode('latin-1')
    if k == 'array':
        e = desc['elem']; es = e['size_st' if st else 'size_dos']; n = 1
        for lo, hi in desc['dims']: n *= hi - lo + 1
        if e['kind'] == 'base' and e['type'] in ('u8', 's8') and n > 64:
            return bytes(b[off:off + n])  # big byte arrays: compare as a blob
        return [decode(e, b, off + i * es, st) for i in range(n)]
    if k == 'record':
        return {f['name']: decode(f, b, off + f['off_st' if st else 'off_dos'], st) for f in desc['fields']}
    raise ValueError(k)


def diff(a, b, path, out, lo=0):
    if isinstance(a, dict):
        for k in a: diff(a[k], b.get(k), path + '.' + k, out)
    elif isinstance(a, list):
        for i, (x, y) in enumerate(zip(a, b)): diff(x, y, '%s[%d]' % (path, i), out)
    elif isinstance(a, bytes):
        if a != b:
            n = sum(1 for x, y in zip(a, b) if x != y)
            first = next(i for i, (x, y) in enumerate(zip(a, b)) if x != y)
            out.append('%s: %d bytes differ (first at %d)' % (path, n, first))
    elif a != b:
        out.append('%s: %r != %r' % (path, a, b))


def load(layout, fn):
    G = {g['name'].lower(): g for g in layout['globals']}
    blocks = read_blocks(fn); res = {}; st_file = read_blocks.st
    for n, data in blocks.items():
        desc = G.get(n.lower())
        if desc is not None and desc['kind'] == 'pointer' and data:
            desc = layout['types'].get(desc['to'])
        if desc is None or len(data) == 0:
            res[n] = data; continue
        st = st_file if desc['size_st'] == desc['size_dos'] else len(data) == desc['size_st']
        res[n] = decode(desc, data, 0, st)
        if n in BOOLS: res[n] = bool(res[n])   # Pascal true = 1; the ST's st = 255
    return res


def main():
    layout = json.load(open(sys.argv[1]))
    a = load(layout, sys.argv[2])
    if len(sys.argv) == 3:
        for k, v in a.items():
            print(k, type(v).__name__, (len(v) if hasattr(v, '__len__') else v))
        return
    b = load(layout, sys.argv[3]); out = []
    for k in a:
        if k not in b:
            if hasattr(a[k], '__len__') and len(a[k]) == 0: continue   # (an empty block: Linux's nil tempplan)
            out.append('%s: missing in second dump' % k); continue
        diff(a[k], b[k], k, out)
    print('\n'.join(out) if out else 'identical')
    sys.exit(1 if out else 0)


if __name__ == '__main__':
    main()
