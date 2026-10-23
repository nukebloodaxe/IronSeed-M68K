#!/usr/bin/env python3
"""convdata.py - convert Iron Seed's DOS typed data files to the 68000 layout.

  convdata.py build/layout.json tools/datafiles.json SRC_DATA_DIR OUT_DIR

Each file is a sequence of records of the type named in datafiles.json (layouts
from rec2equ.py). Multibyte integers are byte-swapped to big-endian and fields
moved to their 68000 offsets; byte-only records are copied. Output names are
upper case 8.3. Also importable: convert_record(desc, src_bytes) for the oracle
comparator.
"""
import fnmatch, json, os, struct, sys

INT = {'u8': 1, 's8': 1, 's16': 2, 'u16': 2, 's32': 4, 'u32': 4, 'u64': 8, 's64': 8}


def bytes_only(d):
    k = d['kind']
    if k == 'base': return d['type'] in ('u8', 's8')
    if k == 'string': return True
    if k == 'array': return bytes_only(d['elem'])
    if k == 'record': return all(bytes_only(f) for f in d['fields'])
    return False


def conv(d, src, so, dst, do):
    """convert one value described by d from src[so:] (DOS) into dst[do:] (ST)"""
    k = d['kind']
    if bytes_only(d) and d['size_dos'] == d['size_st']:
        dst[do:do + d['size_st']] = src[so:so + d['size_dos']]
        return
    if k == 'base':
        t = d['type']
        if t in INT:
            n = INT[t]; dst[do:do + n] = src[so:so + n][::-1]
        elif t == 'f64':
            dst[do:do + 8] = struct.pack('>d', struct.unpack('<d', src[so:so + 8])[0])
        elif t == 'f32':
            dst[do:do + 4] = struct.pack('>f', struct.unpack('<f', src[so:so + 4])[0])
        elif t == 'ptr':
            pass  # pointers are meaningless in files: leave 0
        else:
            raise ValueError(t)
    elif k == 'pointer':
        pass
    elif k == 'array':
        e = d['elem']; n = 1
        for lo, hi in d['dims']: n *= hi - lo + 1
        for i in range(n):
            conv(e, src, so + i * e['size_dos'], dst, do + i * e['size_st'])
    elif k == 'record':
        for f in d['fields']:
            conv(f, src, so + f['off_dos'], dst, do + f['off_st'])
    else:
        raise ValueError(k)


def convert_file(desc, data):
    sd, ss = desc['size_dos'], desc['size_st']
    if len(data) % sd:
        raise ValueError('size %d is not a multiple of the record size %d' % (len(data), sd))
    n = len(data) // sd
    out = bytearray(n * ss)
    for r in range(n):
        conv(desc, data, r * sd, out, r * ss)
    return bytes(out), n


def main():
    layout, fmap, src, dst = sys.argv[1:5]
    T = json.load(open(layout))['types']
    M = {k: v for k, v in json.load(open(fmap)).items() if not k.startswith('_')}
    os.makedirs(dst, exist_ok=True)
    bad = 0
    for fn in sorted(os.listdir(src)):
        spec = next((v for k, v in M.items() if fnmatch.fnmatch(fn.lower(), k)), None)
        if spec is None:
            continue
        data = open(os.path.join(src, fn), 'rb').read()
        if spec == 'raw':  # byte data read partially by the game (e.g. planicon.dta)
            open(os.path.join(dst, fn.upper()), 'wb').write(data)
            print('%-14s %-24s %6d bytes  copied' % (fn, 'raw', len(data)))
            continue
        desc = T[spec]
        try:
            out, n = convert_file(desc, data)
        except ValueError as e:
            print('%-14s %-24s ERROR %s' % (fn, spec, e)); bad += 1; continue
        open(os.path.join(dst, fn.upper()), 'wb').write(out)
        how = 'copied' if bytes_only(desc) and desc['size_dos'] == desc['size_st'] else 'converted'
        print('%-14s %-24s %4d x %6d -> %6d bytes  %s' % (fn, spec, n, desc['size_dos'], desc['size_st'], how))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
