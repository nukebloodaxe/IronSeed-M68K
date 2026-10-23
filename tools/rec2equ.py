#!/usr/bin/env python3
"""rec2equ.py - Pascal record/array layouts -> 68000 asm equates + JSON layout.

Parses the subset of Free Pascal (TP mode) used by Iron Seed's type sections:
records, arrays (multi-dimensional, constant bounds), string[n], pointers,
named types, integer constants. Computes two layouts for every type:

  dos : the original {$PACKRECORDS 1} little-endian layout (what data/*.dta
        files and the oracle dumps contain)
  st  : the 68000 layout - same field order, 16/32-bit fields (and records/arrays
        that contain them) at even offsets, such records' sizes rounded to even

Usage:
  rec2equ.py --pas data.pas [--pas utils_.pas ...] --globals data.pas \
             --equ build/layout.i --json build/layout.json [--check NAME=SIZE ...]
"""
import argparse, json, re, sys

BASE = {  # name: (size, align_st, kind)   kind used by converters
    'byte': (1, 1, 'u8'), 'char': (1, 1, 'u8'), 'boolean': (1, 1, 'u8'),
    'shortint': (1, 1, 's8'),
    'integer': (2, 2, 's16'), 'smallint': (2, 2, 's16'), 'word': (2, 2, 'u16'),
    'longint': (4, 2, 's32'), 'int32': (4, 2, 's32'), 'longword': (4, 2, 'u32'),
    'cardinal': (4, 2, 'u32'), 'dword': (4, 2, 'u32'),
    'real': (8, 2, 'f64'), 'double': (8, 2, 'f64'), 'single': (4, 2, 'f32'),
    'qword': (8, 2, 'u64'), 'int64': (8, 2, 's64'),
    'pointer': (4, 2, 'ptr'),  # ST pointer size; DOS/FPC size handled below
}


def strip_comments(s):
    s = re.sub(r'\{[^}]*\}', ' ', s, flags=re.S)
    s = re.sub(r'\(\*.*?\*\)', ' ', s, flags=re.S)
    s = re.sub(r'//[^\n]*', ' ', s)
    return s


def tokenize(s):
    return re.findall(r"\.\.|:=|'[^']*'|[A-Za-z_][A-Za-z0-9_]*|\$[0-9A-Fa-f]+|\d+|[^\s]", s)


class Parser:
    def __init__(self):
        self.consts = {}
        self.types = {}      # lower name -> typedef, visible everywhere (interface types)
        self.local = {}      # (unit, lower name) -> typedef (whole file, incl. implementation/program)
        self.unit = None
        self.skipped = []
        self.globals = []    # (name, typedef) in declaration order

    # ---- expressions (constant bounds)
    def value(self, toks):
        expr = ' '.join(toks)
        for k, v in sorted(self.consts.items(), key=lambda kv: -len(kv[0])):
            expr = re.sub(r'\b%s\b' % re.escape(k), str(v), expr, flags=re.I)
        expr = re.sub(r'\$([0-9A-Fa-f]+)', lambda m: str(int(m.group(1), 16)), expr)
        expr = re.sub(r'\bdiv\b', '//', expr, flags=re.I)
        if not re.fullmatch(r'[\d\s+\-*/()]+', expr):
            raise ValueError('cannot evaluate bound: ' + expr)
        return eval(expr)

    def parse_file(self, text, unit, want_globals):
        toks = tokenize(strip_comments(text))
        low = [t.lower() for t in toks]
        impl = low.index('implementation') if 'implementation' in low else (0 if low and low[0] == 'program' else len(toks))
        self.unit = unit
        i, section = 0, None
        while i < len(toks):
            t = low[i]
            self.in_impl = i >= impl
            if t == 'begin':
                section = None; i += 1; continue
            if t in ('const', 'type', 'var', 'uses', 'procedure', 'function', 'interface'):
                section = t
                if t == 'uses':
                    while toks[i] != ';': i += 1
                elif t in ('procedure', 'function'):
                    depth = 0
                    while not (toks[i] == ';' and depth == 0):
                        if toks[i] == '(': depth += 1
                        elif toks[i] == ')': depth -= 1
                        i += 1
                    # skip directives like cdecl; external;
                    while i + 1 < len(toks) and low[i + 1] in ('cdecl', 'external', 'overload', 'inline', 'forward'):
                        i += 1
                        while toks[i] != ';': i += 1
                i += 1
                continue
            try:
                if section == 'const':
                    i = self.parse_const(toks, low, i)
                elif section == 'type':
                    i = self.parse_typedecl(toks, low, i)
                elif section == 'var':
                    i = self.parse_var(toks, low, i, want_globals)
                else:
                    i += 1
            except (AssertionError, ValueError, IndexError, KeyError):
                # unsupported declaration (objects, procedural types...): skip it
                self.skipped.append((unit, ' '.join(toks[i:i + 4])))
                i += 1
                while i < len(toks) and toks[i] != ';': i += 1
                i += 1

    def parse_const(self, toks, low, i):
        name = toks[i]
        j = i + 1
        depth = 0
        while not (toks[j] == ';' and depth == 0):
            if toks[j] == '(': depth += 1
            if toks[j] == ')': depth -= 1
            j += 1
        if toks[i + 1] == '=':
            try:
                self.consts[name.lower()] = self.value(toks[i + 2:j])
            except Exception:
                pass
        return j + 1

    def parse_typedecl(self, toks, low, i):
        name = toks[i]
        assert toks[i + 1] == '=', (name, toks[i:i + 5])
        td, j = self.parse_type(toks, low, i + 2)
        assert toks[j] == ';', (name, toks[j:j + 5])
        td = dict(td, name=name, unit=self.unit)
        self.local[(self.unit, name.lower())] = td
        if not self.in_impl:
            self.types[name.lower()] = td
        return j + 1

    def parse_var(self, toks, low, i, want):
        names = []
        while toks[i] != ':':
            if toks[i] != ',': names.append(toks[i])
            i += 1
        td, j = self.parse_type(toks, low, i + 1)
        if toks[j] == '=':  # initialised var: skip value
            while toks[j] != ';': j += 1
        if want and not self.in_impl:
            for n in names: self.globals.append((n, td))
        return j + 1

    def parse_type(self, toks, low, i):
        t = low[i]
        if t == 'packed': return self.parse_type(toks, low, i + 1)
        if t == 'record':
            fields, i = [], i + 1
            while low[i] != 'end':
                names = []
                while toks[i] != ':':
                    if toks[i] != ',': names.append(toks[i])
                    i += 1
                ftd, i = self.parse_type(toks, low, i + 1)
                for n in names: fields.append((n, ftd))
                if toks[i] == ';': i += 1
            return {'kind': 'record', 'fields': fields}, i + 1
        if t == 'array':
            assert toks[i + 1] == '['
            j, dims, cur = i + 2, [], []
            while True:
                if toks[j] in (',', ']'):
                    k = cur.index('..')
                    dims.append((self.value(cur[:k]), self.value(cur[k + 1:])))
                    cur = []
                    if toks[j] == ']': break
                else:
                    cur.append(toks[j])
                j += 1
            assert low[j + 1] == 'of'
            el, j = self.parse_type(toks, low, j + 2)
            return {'kind': 'array', 'dims': dims, 'elem': el}, j
        if t == 'string':
            if toks[i + 1] == '[':
                n = self.value(toks[i + 2:toks.index(']', i)])
                return {'kind': 'string', 'len': n}, toks.index(']', i) + 1
            return {'kind': 'string', 'len': 255}, i + 1
        if toks[i] == '^':
            return {'kind': 'pointer', 'to': toks[i + 1], 'unit': self.unit}, i + 2
        if toks[i] == '(':  # enumeration
            j = toks.index(')', i)
            return {'kind': 'base', 'base': 'byte'}, j + 1
        return {'kind': 'named', 'ref': toks[i], 'unit': self.unit}, i + 1

    # ---- layout
    def resolve(self, td):
        while td['kind'] == 'named':
            r = td['ref'].lower()
            if r in BASE: return {'kind': 'base', 'base': r}
            nxt = self.local.get((td.get('unit'), r)) or self.types.get(r)
            if nxt is None: raise KeyError('unknown type ' + td['ref'])
            td = nxt
        return td

    def lookup(self, spec):
        """'unit:type' or 'type'"""
        if ':' in spec:
            u, n = spec.split(':')
            return self.local[(u, n.lower())]
        return self.types[spec.lower()]

    def layout(self, td, mode):
        """returns (size, align) ; align only matters for mode 'st'"""
        td = self.resolve(td)
        k = td['kind']
        if k == 'base':
            size, al, _ = BASE[td['base']]
            if td['base'] == 'pointer' and mode == 'dos': size = 8
            return size, (al if mode == 'st' else 1)
        if k == 'pointer':
            return (8, 1) if mode == 'dos' else (4, 2)
        if k == 'string':
            return td['len'] + 1, 1
        if k == 'array':
            es, ea = self.layout(td['elem'], mode)
            n = 1
            for lo, hi in td['dims']: n *= hi - lo + 1
            return es * n, ea
        if k == 'record':
            off, al = 0, 1
            for _, f in td['fields']:
                fs, fa = self.layout(f, mode)
                if mode == 'st' and fa == 2 and off & 1: off += 1
                al = max(al, fa)
                off += fs
            if mode == 'st' and al == 2 and off & 1: off += 1
            return off, al
        raise ValueError(k)

    def describe(self, td, mode_offsets=True):
        """JSON-able description with both layouts."""
        td = self.resolve(td)
        k = td['kind']
        d = {'kind': k, 'size_dos': self.layout(td, 'dos')[0], 'size_st': self.layout(td, 'st')[0]}
        if k == 'base': d['type'] = BASE[td['base']][2]
        elif k == 'pointer':
            d['type'] = 'ptr'; d['to'] = '%s:%s' % (td.get('unit', 'data'), td['to'])
        elif k == 'string': d['len'] = td['len']
        elif k == 'array':
            d['dims'] = td['dims']; d['elem'] = self.describe(td['elem'])
        elif k == 'record':
            fl, od, os_ = [], 0, 0
            for n, f in td['fields']:
                fsd, _ = self.layout(f, 'dos'); fss, fa = self.layout(f, 'st')
                if fa == 2 and os_ & 1: os_ += 1
                fl.append({'name': n, 'off_dos': od, 'off_st': os_, **self.describe(f)})
                od += fsd; os_ += fss
            d['fields'] = fl
        if 'name' in td: d['typename'] = td['name']
        return d


def short(name):
    n = name.upper()
    return n[:-4] if n.endswith('TYPE') and len(n) > 4 else n


def emit_equ(p, out, gnames):
    L = ['; layout.i - GENERATED by tools/rec2equ.py from the Pascal sources. Do not edit.',
         '; 68000 layout: fields in Pascal order, 16/32-bit data at even offsets.', '']
    for key, td in sorted(p.types.items()):
        try:
            d = p.describe(td)
        except (KeyError, ValueError):
            continue
        pre = short(td['name'])
        if d['kind'] == 'record':
            L.append('; %s (DOS %d bytes)' % (td['name'], d['size_dos']))
            for f in d['fields']:
                L.append('%s_%s\tequ\t%d' % (pre, f['name'].upper(), f['off_st']))
            L.append('%s_SIZEOF\tequ\t%d' % (pre, d['size_st']))
            L.append('')
        elif d['kind'] == 'array':
            L.append('%s_SIZEOF\tequ\t%d\t; array, DOS %d' % (pre, d['size_st'], d['size_dos']))
            L.append('%s_ELEM\tequ\t%d' % (pre, d['elem']['size_st']))
            L.append('%s_LO\tequ\t%d' % (pre, d['dims'][0][0]))
            L.append('')
    # global state block
    L.append('; ---- global state block (a6 = GS base)')
    off = 0
    for n, td in gnames:
        s, a = p.layout(td, 'st')
        if a == 2 and off & 1: off += 1
        L.append('GS_%s\tequ\t%d\t; %d bytes' % (n.upper(), off, s))
        off += s
    if off & 1: off += 1
    L.append('GS_SIZEOF\tequ\t%d' % off)
    open(out, 'w').write('\n'.join(L) + '\n')
    return off


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--pas', action='append', required=True, help='units to read types/consts from')
    ap.add_argument('--globals', help='unit whose interface vars form the global state block')
    ap.add_argument('--skip-global', action='append', default=[], help='global var names to leave out')
    ap.add_argument('--equ'); ap.add_argument('--json')
    ap.add_argument('--check', action='append', default=[], help='NAME=DOSSIZE (type or global)')
    a = ap.parse_args()
    p = Parser()
    for f in a.pas:
        unit = re.sub(r'\.pas$', '', f.split('/')[-1]).lower()
        p.parse_file(open(f, encoding='latin-1').read(), unit, want_globals=(a.globals == f))
    skip = {s.lower() for s in a.skip_global}
    gl = [(n, td) for n, td in p.globals if n.lower() not in skip]
    ok = True
    for c in a.check:
        n, want = c.split('='); want = int(want)
        td = (p.lookup(n) if ':' in n else p.types.get(n.lower())) or next((t for g, t in p.globals if g.lower() == n.lower()), None)
        got = p.layout(td, 'dos')[0] if td else None
        st = p.layout(td, 'st')[0] if td else None
        flag = 'ok' if got == want else 'MISMATCH'
        ok &= got == want
        print('check %-12s DOS %6s (oracle %6d) ST %6s  %s' % (n, got, want, st, flag))
    if a.json:
        J = {'types': {}, 'globals': []}
        for (u, key), td in p.local.items():
            try: J['types']['%s:%s' % (u, td['name'])] = p.describe(td)
            except (KeyError, ValueError): pass
        for n, td in gl:
            J['globals'].append({'name': n, **p.describe(td)})
        json.dump(J, open(a.json, 'w'), indent=1)
    if a.equ:
        size = emit_equ(p, a.equ, gl)
        print('global state block: %d bytes, %d variables' % (size, len(gl)))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
