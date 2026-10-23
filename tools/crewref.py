#!/usr/bin/env python3
"""crewref.py - reference model of crewgen.pas's random-driven state (initcrew: systems and
planets; setstate), on fpcrand. Used to check the oracle and the ST port.

  crewref.py SYSSET.DTA(DOS) [--planets OUT] [--systems OUT]  (DOS layout output)"""
import struct, sys
from fpcrand import FpcRandom


def setstate(r, p, spot):
    if spot == 1:
        p['age'] = r.random(7)
        a = p['age']
        p['mode'] = 1 if a <= 3 else (2 if a <= 5 else 3)
        p['state'] = 7
        return
    p['state'] = st = r.random(7)
    if st == 0:
        a = p['age'] = r.random(5); p['mode'] = 1 if a <= 1 else (2 if a <= 3 else 3)
    elif st == 1:
        a = p['age'] = r.random(11); p['mode'] = 1 if a <= 4 else (2 if a <= 8 else 3)
    elif st == 2:
        a = p['age'] = r.random(64000) * 7812
        p['mode'] = 3 if a > 350000000 else (2 if a > 200000000 else 1)
    elif st == 3:
        a = p['age'] = r.random(15001) * 1000
        p['mode'] = 3 if a > 150005000 else (2 if a > 150000000 else 1)
    elif st == 4:
        a = p['age'] = r.random(5000); p['mode'] = 3 if a > 3000 else (2 if a > 2000 else 1)
    elif st == 5:
        a = p['age'] = r.random(5000); p['mode'] = 3 if a > 5500 else (2 if a > 1500 else 1)
    elif st == 6:
        a = p['age'] = r.random(100) * 1000
        if a > 100000: p['mode'] = 2
        elif r.random(2) == 0: p['mode'] = 3
        p['mode'] = 1
    p['age'] = r.random(2000)


def initcrew(r, oldsys):
    """returns engr timeleft, systems (250 dicts), planets (1000 dicts)"""
    timeleft = 22 * 70 + r.random(30)
    while True:
        planets = [dict(system=0, orbit=0, psize=0, water=0, state=0, mode=0, bots=0, notes=0, datem=0,
                        datey=0, visits=0, seed=0, cache=[0] * 7, age=0) for _ in range(1000)]
        systems = []
        curplan = 0
        err = False
        for j in range(1, 251):
            x, y, z = oldsys[j - 1][:3]
            s = dict(name='UNKNOWN     ', x=x, y=y, z=z, datey=0, visits=0, numplanets=r.random(3) + 3,
                     notes=0, datem=0, mode=0)
            if j == 145: s['numplanets'] = 3
            systems.append(s)
            radii = [0] * 8
            for i in range(1, s['numplanets'] + 1):
                curplan += 1
                if curplan > 1000: err = True; break
                p = planets[curplan - 1]
                if i == 1: p['orbit'] = 0
                else:
                    while True:
                        a = r.random(7) + 1
                        if radii[a] == 0: break
                    radii[a] = 1
                    p['orbit'] = a
                p['system'] = j
                p['water'] = r.random(50)
                p['seed'] = r.random(64000)
                p['psize'] = r.random(5)
                if j == 145 and i > 1:
                    if i == 2: p.update(state=5, mode=3, orbit=4, age=2000)
                    else: p.update(state=2, mode=3, orbit=2, age=2000)
                else:
                    setstate(r, p, i)
                if i == 1: s['mode'] = p['mode']
            if err: break
        if not err and 400 < curplan < 1001: break
        if err: continue  # planerror: until (curplan>400) and (curplan<1001) fails, repeat
    systems[144].update(name='OBAN        ', datey=3784, datem=2, visits=1)
    return timeleft, systems, planets


def pack_planets(planets):
    b = bytearray()
    for p in planets:
        b += struct.pack('<9B3H7Hi', p['system'], p['orbit'], p['psize'], p['water'], p['state'], p['mode'],
                         p['bots'], p['notes'], p['datem'], p['datey'], p['visits'], p['seed'], *p['cache'],
                         p['age'])
    return bytes(b)


def pack_systems(systems):
    b = bytearray()
    for s in systems:
        nm = s['name'].encode('latin-1')
        b += bytes([len(nm)]) + nm.ljust(12, b'\0') + struct.pack('<5h4B', s['x'], s['y'], s['z'], s['datey'],
                                                                   s['visits'], s['numplanets'], s['notes'],
                                                                   s['datem'], s['mode'])
    return bytes(b)


def read_oldsys(path):
    d = open(path, 'rb').read()
    return [struct.unpack_from('<6h', d, i * 12) for i in range(250)]


if __name__ == '__main__':
    r = FpcRandom(1994)
    tl, systems, planets = initcrew(r, read_oldsys(sys.argv[1]))
    print('timeleft', tl, 'random calls', r.calls)
    if '--planets' in sys.argv: open(sys.argv[sys.argv.index('--planets') + 1], 'wb').write(pack_planets(planets))
    if '--systems' in sys.argv: open(sys.argv[sys.argv.index('--systems') + 1], 'wb').write(pack_systems(systems))
