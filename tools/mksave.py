#!/usr/bin/env python3
"""mksave.py build/layout.json SAVEHOME SLOT_IN OUTHOME SLOT_OUT STDIR [edits...]

A test position for oracle sessions: copies the Linux save SAVEHOME/.ironseed/save<SLOT_IN> to
OUTHOME/.ironseed/save<SLOT_OUT> (OUTHOME gets a copy of the whole .ironseed folder), applies the
edits, and writes the same game for the ST into STDIR/SAVE<SLOT_OUT> (+ STDIR/SAVEGAME.DIR), so
both sides start from the same state.

Edits (DOS layout, little-endian; paths follow data.pas):
  ship.damages[3]=0         a field of SHIP.DTA (records, arrays [i] or [i,j], strings)
  systems[93].visits=1      SYSTEMS.DTA (systemarray)
  planets[120].state=3      PLANETS.DTA (planarray, the save's tempplan)
  events[2]=255             EVENTS.DTA (events[1]|=8: event 11 set, the others kept)
  @system=93                put the ship at system 93 (posx/y/z := its x/y/z)
  @orbit=2                  ship.orbiting := 2
  @name=TEXT                the slot's name in savegame.dir
  @knowall=1                every system known (notes |= 1: the star maps show them all)
  @contact=N:ID             append contact0.dta record N with id ID to CONTACTS.DTA (an alien
                            race met; e.g. for a ship to hail: ship.wandering.alienid=ID)
Prints the planets of the target system (index, orbit, state, mode, age) to help pick one.
"""
import json, os, re, shutil, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from convdata import convert_file

FILES = {'ship': ('SHIP.DTA', 'data:shiptype'), 'systems': ('SYSTEMS.DTA', 'data:systemarray'),
         'planets': ('PLANETS.DTA', 'data:planarray'), 'events': ('EVENTS.DTA', 'data:eventarray'),
         'logs': ('LOGS.DTA', 'data:logarray'), 'pending': ('PENDING.DTA', 'data:logpendingarray')}
FMT = {'u8': '<B', 's8': '<b', 's16': '<h', 'u16': '<H', 's32': '<i', 'u32': '<I'}


def resolve(desc, path):
    """-> (dos offset, base desc) for a path like '.damages[3]' or '[93].visits'"""
    off = 0
    for m in re.finditer(r'\.(\w+)|\[([^\]]+)\]', path):
        if m.group(1):
            f = next(f for f in desc['fields'] if f['name'] == m.group(1))
            off += f['off_dos']; desc = f
        else:
            idx = [int(x) for x in m.group(2).split(',')]
            dims = desc['dims']; e = desc['elem']
            lin = 0
            for (lo, hi), i in zip(dims, idx):
                assert lo <= i <= hi, (path, i, lo, hi)
                lin = lin * (hi - lo + 1) + (i - lo)
            off += lin * e['size_dos']; desc = e
    return off, desc


def put(buf, off, desc, val):
    if desc['kind'] == 'string':
        s = val.encode('latin-1')[:desc['len']]
        buf[off] = len(s); buf[off + 1:off + 1 + len(s)] = s
    else:
        struct.pack_into(FMT[desc['type']], buf, off, int(val, 0))


def get(buf, off, desc):
    if desc['kind'] == 'string':
        return buf[off + 1:off + 1 + buf[off]].decode('latin-1')
    return struct.unpack_from(FMT[desc['type']], buf, off)[0]


def main():
    lay, home, sin, ohome, sout, stdir = sys.argv[1:7]
    T = json.load(open(lay))['types']
    src = os.path.join(home, '.ironseed')
    dst = os.path.join(ohome, '.ironseed')
    if os.path.abspath(src) != os.path.abspath(dst):
        shutil.rmtree(dst, ignore_errors=True); shutil.copytree(src, dst)
    sd = os.path.join(dst, 'save' + sin); od = os.path.join(dst, 'save' + sout)
    if sd != od:
        shutil.rmtree(od, ignore_errors=True); shutil.copytree(sd, od)
    data = {k: bytearray(open(os.path.join(od, fn), 'rb').read()) for k, (fn, _) in FILES.items()}
    name = None
    for e in sys.argv[7:]:
        lhs, val = e.split('=', 1)
        if lhs == '@system':
            n = int(val)
            for c in 'xyz':
                o, d = resolve(T['data:systemarray'], '[%d].%s' % (n, c))
                o2, d2 = resolve(T['data:shiptype'], '.pos' + c)
                put(data['ship'], o2, d2, str(get(data['systems'], o, d)))
            continue
        if lhs == '@orbit':
            o, d = resolve(T['data:shiptype'], '.orbiting'); put(data['ship'], o, d, val); continue
        if lhs == '@name':
            name = val; continue
        if lhs == '@knowall':                    # every system's notes |= 1 (known: star maps)
            for n in range(1, 251):
                o, d = resolve(T['data:systemarray'], '[%d].notes' % n)
                put(data['systems'], o, d, str(get(data['systems'], o, d) | 1))
            continue
        if lhs == '@contact':
            n, cid = (int(x) for x in val.split(':'))
            c0 = open(os.environ.get('IRONSEED_SRC', '/root/ironseed_fpc') + '/data/contact0.dta', 'rb').read()
            rec = bytearray(c0[(n - 1) * 31:n * 31])
            struct.pack_into('<h', rec, 26, cid)
            cf = os.path.join(od, 'CONTACTS.DTA')
            open(cf, 'ab').write(bytes(rec))
            continue
        orv = lhs.endswith('|')                  # 'path|=value': or the bits in
        m = re.match(r'(\w+)(.*)', lhs.rstrip('|'))
        f, t = FILES[m.group(1)]
        o, d = resolve(T[t], m.group(2))
        if orv:
            val = str(get(data[m.group(1)], o, d) | int(val, 0))
        put(data[m.group(1)], o, d, val)
    for k, (fn, _) in FILES.items():
        open(os.path.join(od, fn), 'wb').write(data[k])
    sg = os.path.join(dst, 'savegame.dir')
    sgd = bytearray(open(sg, 'rb').read())
    rec = T['saveload:namearray']
    if name is not None:
        o, d = resolve(rec, '[%s].name' % sout); put(sgd, o, d, name.ljust(20))
    else:
        o, d = resolve(rec, '[%s]' % sin); o2, _ = resolve(rec, '[%s]' % sout)
        sgd[o2:o2 + d['size_dos']] = sgd[o:o + d['size_dos']]
    open(sg, 'wb').write(sgd)
    # the ST copy
    st = os.path.join(stdir, 'SAVE' + sout)
    shutil.rmtree(st, ignore_errors=True); os.makedirs(st)
    for fn in os.listdir(od):
        t = {'SHIP.DTA': 'data:shiptype', 'SYSTEMS.DTA': 'data:systemarray', 'EVENTS.DTA': 'data:eventarray',
             'LOGS.DTA': 'data:logarray', 'PENDING.DTA': 'data:logpendingarray', 'PLANETS.DTA': 'data:planarray',
             'CONTACTS.DTA': 'data:alientype'}.get(fn.upper())
        if t:
            out, _ = convert_file(T[t], open(os.path.join(od, fn), 'rb').read())
            open(os.path.join(st, fn.upper()), 'wb').write(out)
    out, _ = convert_file(T['saveload:namearray'], bytes(sgd))
    open(os.path.join(stdir, 'SAVEGAME.DIR'), 'wb').write(out)
    # where are we
    sh = data['ship']
    pos = [get(sh, *resolve(T['data:shiptype'], '.pos' + c)) for c in 'xyz']
    orb = get(sh, *resolve(T['data:shiptype'], '.orbiting'))
    sysn = None
    for n in range(1, 251):
        if [get(data['systems'], *resolve(T['data:systemarray'], '[%d].%s' % (n, c))) for c in 'xyz'] == pos:
            sysn = n
    print('ship at system', sysn, 'orbit', orb)
    if sysn:
        for p in range(1, 1001):
            g = lambda f: get(data['planets'], *resolve(T['data:planarray'], '[%d].%s' % (p, f)))
            if g('system') == sysn:
                print('  planet %4d orbit %d state %d mode %d age %d psize %d notes %d' %
                      (p, g('orbit'), g('state'), g('mode'), g('age'), g('psize'), g('notes')))


if __name__ == '__main__':
    main()
