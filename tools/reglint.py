#!/usr/bin/env python3
"""reglint.py LISTING.lst [--abi] [--v] [--src DIR...] : interprocedural check of the scratch
registers (ABI: d0-d2/a0-a2) over a vasm listing (tools/st_listing.sh PROG.s OUT.lst: includes,
macros and conditional assembly already resolved; branch targets are decoded from the opcodes).
tools/reglint.sh runs it over every program.

Per routine (every call target and global label in the text section) it computes
  W = the scratch registers it may change (its own writes and its callees'; a register pushed and
      popped back is kept - the stack is followed symbolically),
  I = the scratch registers it reads before writing them on some path (its inputs, incl. callees'),
  R = its results: the registers after 'out:' in its header comment (`out: -` = none), else every
      register of W that at least half of its call sites go on to use (consensus).
Then a forward may-garbage analysis per routine: after `bsr C` the registers of W(C) - R(C) hold
garbage (with --abi: all of d0-d2/a0-a2 - R(C), what the ABI promises). Reported:
  read  - an instruction reads a garbage register (moving it to the stack is not a read: the value
          is followed through the push and the pop),
  pass  - a call passes a garbage register the callee reads as an input (David's Phase 6f crash:
          d0 kept across mousehide, then passed to dp_sysplanet),
  tail/falls - the same through a branch to, or falling into, another routine,
  ret   - a routine returns with garbage in one of its results.
Heuristic: indirect jumps/calls are not followed (an indirect jump ends the path; an indirect call
trashes everything but d0/a0). Review each hit."""
import re, sys, os
from collections import defaultdict

SCR = ['d0', 'd1', 'd2', 'a0', 'a1', 'a2']
SIDX = {r: i for i, r in enumerate(SCR)}
SBIT = {r: 1 << i for i, r in enumerate(SCR)}
ALL = 63
WHY = set()
ALLREGS = ['d%d' % i for i in range(8)] + ['a%d' % i for i in range(8)]


def bits(regs):
    v = 0
    for r in regs:
        v |= SBIT.get(r, 0)
    return v


def names(v):
    return ','.join(r for r in SCR if v & SBIT[r])


LINE = re.compile(r'^(\d\d):([0-9A-F]{8}) ([0-9A-F]+)\s*\t\s*(\d+)(?::|M) ?(.*)$')
NOADDR = re.compile(r'^\s+\t\s*(\d+)(?::|M) ?(.*)$')
LABEL = re.compile(r'^([A-Za-z_][\w]*|\.[\w]+)(?::|\s|$)')

NOWRITE = {'cmp', 'cmpi', 'cmpa', 'tst', 'btst', 'cmpm', 'pea', 'chk', 'tas'}
RMW = {'add', 'addq', 'addi', 'adda', 'sub', 'subq', 'subi', 'suba', 'and', 'andi', 'or', 'ori', 'eor',
       'eori', 'lsl', 'lsr', 'asl', 'asr', 'rol', 'ror', 'roxl', 'roxr', 'mulu', 'muls', 'divu', 'divs',
       'ext', 'neg', 'not', 'swap', 'bset', 'bclr', 'bchg', 'addx', 'subx', 'abcd', 'sbcd', 'negx', 'nbcd'}
PUREW = {'move', 'movea', 'moveq', 'lea', 'clr', 'movep'}
CC = 'hi|ls|cc|cs|ne|eq|vc|vs|pl|mi|ge|lt|gt|le|hs|lo|t|f|ra|sr'


def reglist(op):
    """all registers named in an operand (movem lists, ranges, sp = a7)"""
    op = op.lower().replace('sp', 'a7') if re.fullmatch(r'[ad0-7/\-sp]+', op.lower()) else op.lower()
    out = []
    for part in op.split('/'):
        m = re.fullmatch(r'([ad])([0-7])-([ad])([0-7])', part.strip())
        if m:
            a = ALLREGS.index(m.group(1) + m.group(2))
            b = ALLREGS.index(m.group(3) + m.group(4))
            out += ALLREGS[a:b + 1]
        elif re.fullmatch(r'[ad][0-7]', part.strip()):
            out.append(part.strip())
    return out


def regs_in(op):
    op = op.lower()
    out = set()
    for m in re.finditer(r'([ad])([0-7])-([ad])([0-7])', op):
        if m.group(1) == m.group(3):
            for i in range(int(m.group(2)), int(m.group(4)) + 1):
                out.add(m.group(1) + str(i))
    for r in SCR:
        if re.search(r'(?<![a-z0-9_.\\])' + r + r'(?![0-9a-z_])', op):
            out.add(r)
    return out & set(SCR)


def split_ops(s):
    ops, depth, cur, q = [], 0, '', False
    for ch in s:
        if ch in '"\'':
            q = not q
        if not q:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            if ch == ',' and depth == 0:
                ops.append(cur)
                cur = ''
                continue
        cur += ch
    if cur.strip():
        ops.append(cur)
    return [o.strip() for o in ops]


def num(s):
    s = s.strip().lstrip('#')
    try:
        if s.startswith('$'):
            return int(s[1:], 16)
        return int(s)
    except ValueError:
        return None


class Ins:
    __slots__ = ('addr', 'hexs', 'text', 'lst', 'mn', 'ops', 'kind', 'target', 'tname', 'rd', 'wr',
                 'stk', 'size', 'sz', 'xg')


def parse(fn):
    ins = {}
    labels = defaultdict(list)
    gl = {}
    comments = []
    headers = {}
    pend = []
    table = defaultdict(list)          # file-top tables: '; name   in: ... out: ...' (+ indented lines)
    tabname = [None]
    for n, raw in enumerate(open(fn, errors='replace')):
        raw = raw.rstrip('\n')
        m = LINE.match(raw)
        if m:
            sec, addr, hx, src = m.group(1), int(m.group(2), 16), m.group(3), m.group(5)
        else:
            m2 = NOADDR.match(raw)
            if not m2:
                continue
            sec, addr, hx, src = None, None, '', m2.group(2)
        code = src.split(';')[0] if '"' not in src and "'" not in src else src
        lm = LABEL.match(code) if code and not code[0].isspace() else None
        lab = None
        if lm:
            lab = lm.group(1)
            rest = code[lm.end():].lower()
            if re.match(r'^\s*(equ|=|set|macro|rept|endm|endr|reg)\b', rest) or re.match(r'^:?\s*(equ|set|=|macro)\b', rest):
                lab = None
        if lab:
            pend.append(lab)
            if not lab.startswith('.'):
                headers[lab] = list(comments) + ([src[src.index(';'):]] if ';' in src else [])
                comments = []
        elif src.strip().startswith(';'):
            tm = re.match(r'^\s*;\s*([A-Za-z_]\w*)\s+(?:in:|out:)', src)
            if tm:
                tabname[0] = tm.group(1)
            elif not re.match(r'^\s*;\s{2,}', src):
                tabname[0] = None
            if tabname[0]:
                table[tabname[0]].append(src)
            comments.append(src)
            if len(comments) > 12:
                comments.pop(0)
        else:
            comments = []             # a header is the comment block right above the label
        if sec is None:
            continue
        if sec != '00':
            pend = []
            continue
        body = code[lm.end():] if lm and lab else code
        body = body.strip()
        if body.startswith(':'):
            body = body[1:].strip()
        for lb in pend:
            labels[addr].append(lb)
            if not lb.startswith('.'):
                gl[lb] = addr
        pend = []
        if not body or not hx:
            continue
        t = body.split(None, 1)
        mn = t[0].lower()
        if mn.startswith(('dc', 'ds', 'dcb', 'even', 'cnop', 'align', 'incbin')):
            continue
        i = Ins()
        i.addr, i.hexs, i.text, i.lst = addr, hx, body, n + 1
        i.size = len(hx) // 2
        i.mn = mn.split('.')[0]
        i.sz = mn.split('.')[1] if '.' in mn else 'w'
        i.ops = split_ops(t[1].split(';')[0]) if len(t) > 1 else []
        ins[addr] = i
    for k, v in table.items():
        if k not in headers or not any('out:' in l for l in headers[k]):
            headers[k] = v
    return ins, labels, gl, headers


def SPP(o):
    return o.lower() in ('(sp)+', '(a7)+')


def SPM(o):
    return o.lower() in ('-(sp)', '-(a7)')


def decode(ins, labels):
    for a, i in list(ins.items()):
        h = i.hexs
        if len(h) < 4 or (int(h[:4], 16) & 0xF0FF) == 0x6000 and len(h) < 8:
            del ins[a]               # an assembler error line (e.g. a .s branch out of range)
            continue
        op = int(h[:4], 16)
        i.kind, i.target, i.tname, i.stk, i.xg = 'op', None, None, None, None
        mn = i.mn
        if (op & 0xF000) == 0x6000:
            d = op & 0xFF
            if d == 0:
                d = int(h[4:8], 16)
                d = d - 0x10000 if d & 0x8000 else d
            elif d == 0xFF:
                d = int(h[4:12], 16)
                d = d - (1 << 32) if d & 0x80000000 else d
            else:
                d = d - 0x100 if d & 0x80 else d
            i.target = a + 2 + d
            cond = (op >> 8) & 15
            i.kind = 'bsr' if cond == 1 else ('bra' if cond == 0 else 'bcc')
        elif (op & 0xF0F8) == 0x50C8:
            d = int(h[4:8], 16)
            i.target = a + 2 + (d - 0x10000 if d & 0x8000 else d)
            i.kind = 'dbcc'
        elif (op & 0xFFC0) in (0x4E80, 0x4EC0):
            call = (op & 0xFFC0) == 0x4E80
            mode = op & 0x3F
            if mode == 0x39:
                i.target = int(h[4:12], 16)
            elif mode == 0x3A:
                d = int(h[4:8], 16)
                i.target = a + 2 + (d - 0x10000 if d & 0x8000 else d)
            if i.target is None:
                i.kind = 'icall' if call else 'ijmp'
            else:
                i.kind = 'bsr' if call else 'bra'
        elif op in (0x4E75, 0x4E73, 0x4E77):
            i.kind = 'ret'
        elif (op & 0xFFF0) == 0x4E40:
            i.kind = 'trap'
            pv = ins.get(a - 4) or ins.get(a - 2)
            if (op & 15) == 1 and pv is not None and re.search(r'#(gd_pterm0?|\$4c|\$0+|0),-\(sp\)', pv.text.lower()):
                i.kind = 'halt'          # Pterm/Pterm0: GEMDOS does not return
        if i.target is not None:
            ls = [l for l in labels.get(i.target, []) if not l.startswith('.')]
            i.tname = ls[0] if ls else (labels.get(i.target, ['$%x' % i.target])[0])
        rd, wr = set(), set()
        ops = i.ops
        w = 4 if i.sz == 'l' else (1 if i.sz == 'b' else 2)
        if i.kind in ('bsr', 'bra', 'bcc', 'ret', 'trap', 'halt'):
            pass
        elif i.kind in ('icall', 'ijmp'):
            for o in ops:
                rd |= regs_in(o)
        elif i.kind == 'dbcc':
            if ops:
                rd |= regs_in(ops[0])
                wr |= regs_in(ops[0])
        elif mn == 'movem' and len(ops) == 2:
            src_regs = reglist(ops[0])
            if src_regs and '(' not in ops[0]:
                rl = src_regs
                if SPM(ops[1]):
                    i.stk = ('push', w * len(rl), [r for r in rl])
                else:
                    rd |= set(rl) & set(SCR)
                    rd |= regs_in(ops[1])
            else:
                rl = reglist(ops[1])
                rd |= regs_in(ops[0])
                if SPP(ops[0]):
                    i.stk = ('pop', w * len(rl), [r for r in rl])
                else:
                    wr |= set(rl) & set(SCR)
        elif mn == 'exg':
            rs = [o.lower() for o in ops]
            i.xg = rs
            i.kind = 'exg'
        elif mn == 'pea':
            rd |= regs_in(ops[0]) if ops else set()
            i.stk = ('push', 4, [])
        elif mn in ('link', 'unlk'):
            i.stk = ('unk', 0, [])
        elif ops:
            last = ops[-1].lower()
            # stack pointer arithmetic
            if last in ('sp', 'a7') and mn in ('addq', 'adda', 'add', 'subq', 'suba', 'sub', 'lea'):
                if mn == 'lea':
                    m = re.fullmatch(r'(-?\$?[0-9a-f]+)\((sp|a7)\)', ops[0].lower())
                    n = num(m.group(1).replace('-', '')) if m else None
                    if n is not None and m.group(1).startswith('-'):
                        n = -n
                else:
                    n = num(ops[0])
                    if n is not None and mn.startswith('sub'):
                        n = -n
                i.stk = ('drop', n, []) if n is not None else ('unk', 0, [])
                for o in ops[:-1]:
                    rd |= regs_in(o)
            elif mn == 'move' and len(ops) == 2 and SPM(ops[1]):
                src = ops[0].lower()
                if re.fullmatch(r'[ad][0-7]|sp', src):
                    i.stk = ('push', w, [src])
                else:
                    rd |= regs_in(ops[0])
                    i.stk = ('push', w, [])
            elif mn == 'move' and len(ops) == 2 and SPP(ops[0]):
                if re.fullmatch(r'[ad][0-7]', last):
                    i.stk = ('pop', w, [last])
                else:
                    rd |= regs_in(last)
                    i.stk = ('pop', w, [])
            else:
                for o in ops[:-1]:
                    rd |= regs_in(o)
                if mn in NOWRITE or mn.startswith('cmp'):
                    rd |= regs_in(ops[-1])
                elif re.fullmatch(r'[ad][0-7]', last):
                    if mn in ('sub', 'suba', 'eor', 'subx') and len(ops) == 2 and ops[0].lower() == last:
                        rd.discard(last)      # sub.l a2,a2 / eor d0,d0: zeroing, not a read
                    elif mn in RMW or (mn not in PUREW and not re.fullmatch('s(' + CC + ')', mn) and len(ops) == 1):
                        rd.add(last)
                    wr.add(last)
                else:
                    rd |= regs_in(ops[-1])
        i.rd, i.wr = bits(rd), bits(wr)


class Prog:
    def __init__(self, fn, abi):
        self.abi = abi
        self.ins, self.labels, self.gl, self.headers = parse(fn)
        decode(self.ins, self.labels)
        ins = self.ins
        self.glset = set(self.gl.values())
        self.entries = set(self.glset)
        for i in ins.values():
            if i.kind == 'bsr' and i.target in ins:
                self.entries.add(i.target)
        self.ename = {}
        for e in self.entries:
            ls = self.labels.get(e, [])
            g = [l for l in ls if not l.startswith('.')]
            self.ename[e] = g[0] if g else (ls[0] if ls else '$%x' % e)
        self.hres = {}
        for e in self.entries:
            hd = self.headers.get(self.ename[e])
            if not hd:
                continue
            txt = ' '.join(hd).lower()
            m = re.search(r'\bout:(.*?)(?:\btrashes\b|\bkeeps\b|$)', txt)
            if m:
                o = m.group(1)
                self.hres[e] = 0 if re.match(r'^\s*(-|nothing|none)', o) else bits(regs_in(o))
        self.W = {e: 0 for e in self.entries}
        self.I = {e: 0 for e in self.entries}
        self.R = {e: 0 for e in self.entries}
        self.RET = None               # routines that can return (None: all, while computing)

    def other_entry(self, n, e):
        return n != e and n in self.glset

    def flow(self, e, init, ana):
        """generic forward flow from entry e. state = (vals tuple[6], stack tuple of items),
        item = (size, ((regname, val) ...)). ana supplies: write(), join(a, b), read(addr, r, v),
        call(addr, callee, vals) -> vals, icall(vals), trap(vals), end(addr, vals, kind, target)"""
        ins = self.ins
        st = {e: (tuple(init), ())}
        todo = [e]
        while todo:
            a = todo.pop()
            if a not in ins:
                continue
            i = ins[a]
            vals, stack = st[a]
            vals = list(vals)
            stack = list(stack)
            for r in SCR:
                if i.rd & SBIT[r]:
                    vals[SIDX[r]] = ana.read(a, r, vals[SIDX[r]])
            if i.kind == 'exg' and i.xg:
                rs = i.xg
                if len(rs) == 2:
                    va = vals[SIDX[rs[0]]] if rs[0] in SIDX else ana.outside()
                    vb = vals[SIDX[rs[1]]] if rs[1] in SIDX else ana.outside()
                    if rs[0] in SIDX:
                        vals[SIDX[rs[0]]] = vb
                    if rs[1] in SIDX:
                        vals[SIDX[rs[1]]] = va
            for r in SCR:
                if i.wr & SBIT[r]:
                    vals[SIDX[r]] = ana.write()
            if i.stk:
                k, n, rl = i.stk
                if k == 'push':
                    stack.append((n, tuple((r, vals[SIDX[r]]) for r in rl if r in SIDX), tuple(rl)))
                elif k == 'pop':
                    item = stack.pop() if stack else None
                    sc = [r for r in rl if r in SIDX]
                    if item and list(item[2]) == list(rl):
                        for (r, v) in item[1]:
                            vals[SIDX[r]] = v
                    elif item and len(rl) == 1 and len(item[2]) == 1:
                        if sc:
                            src = item[2][0]
                            vv = dict(item[1])
                            vals[SIDX[sc[0]]] = ana.cross(sc[0], vv[src]) if src in vv else ana.outside()
                    else:
                        for r in sc:
                            vals[SIDX[r]] = ana.write()
                elif k == 'drop':
                    if n > 0:
                        while n > 0 and stack:
                            n -= stack.pop()[0]
                    else:
                        stack.append((-n, (), ()))
                else:
                    stack = []
            kind = i.kind
            nexts = []
            if kind == 'bsr':
                if i.target in self.W:
                    vals = ana.call(a, i.target, vals)
                nexts = [a + i.size]
                if self.RET is not None and i.target in self.W and i.target not in self.RET:
                    nexts = []                # a call that never returns (fatal, sys_exit)
            elif kind == 'icall':
                vals = ana.icall(vals)
                nexts = [a + i.size]
            elif kind == 'trap':
                if hasattr(ana, 'trapargs'):
                    ana.trapargs(a, stack)
                vals = ana.trap(vals)
                nexts = [a + i.size]
            elif kind in ('op', 'exg'):
                nexts = [a + i.size]
            elif kind in ('ret', 'ijmp'):
                ana.end(a, vals, kind, None)
            elif kind == 'halt':
                pass
            elif kind == 'bra':
                if self.other_entry(i.target, e):
                    if self.RET is None or i.target in self.RET:
                        ana.end(a, vals, 'tail', i.target)
                else:
                    nexts = [i.target]
            elif kind in ('bcc', 'dbcc'):
                if self.other_entry(i.target, e):
                    if self.RET is None or i.target in self.RET:
                        ana.end(a, vals, 'tail', i.target)
                else:
                    nexts = [i.target]
                nexts.append(a + i.size)
            for nx in nexts:
                if self.other_entry(nx, e):
                    if self.RET is None or nx in self.RET:
                        ana.end(a, vals, 'falls', nx)
                    continue
                if nx not in ins:
                    continue
                new = (tuple(vals), tuple(stack))
                if nx not in st:
                    st[nx] = new
                    todo.append(nx)
                else:
                    ov, os_ = st[nx]
                    jv = tuple(ana.join(x, y) for x, y in zip(ov, new[0]))
                    js = os_
                    if len(os_) == len(new[1]) and all(p[0] == q[0] and p[2] == q[2] for p, q in zip(os_, new[1])):
                        js = tuple((p[0], tuple((r, ana.join(v, w)) for (r, v), (_, w) in zip(p[1], q[1])), p[2])
                                   for p, q in zip(os_, new[1]))
                    if jv != ov or js != os_:
                        st[nx] = (jv, js)
                        todo.append(nx)
        return st


class Summary:
    """vals: (origin, own) per register - origin = None when written here, else the register whose
    entry value it holds (may-undefined: an input when read); own = still holds its own entry value
    on every path (else it is in W)"""
    def __init__(self, p, e):
        self.p, self.e = p, e
        self.w = 0
        self.inp = 0

    def cross(self, dst, v):          # a value moved from another register by a pop
        return (v[0], False)

    def outside(self):
        return (None, False)

    def write(self):
        return (None, False)

    def join(self, x, y):
        o = x[0] if x[0] == y[0] else (x[0] if y[0] is None else y[0])
        return (o, x[1] and y[1])

    def read(self, a, r, v):
        if v[0] is not None:
            self.inp |= SBIT[v[0]]
            if WHY:
                WHY.add((a, v[0], 'read'))
        return v

    def call(self, a, c, vals):
        p = self.p
        for r in SCR:
            v = vals[SIDX[r]]
            if p.I[c] & SBIT[r] and v[0] is not None:
                self.inp |= SBIT[v[0]]
                if WHY:
                    WHY.add((a, v[0], 'call'))
        return [(None, False) if p.W[c] & SBIT[r] else vals[SIDX[r]] for r in SCR]

    def icall(self, vals):
        return [(None, False)] * 6

    trap = icall

    def end(self, a, vals, kind, t):
        for r in SCR:
            if not vals[SIDX[r]][1]:
                self.w |= SBIT[r]
        if kind == 'ijmp':
            self.w |= ALL
        if t is not None:
            p = self.p
            for r in SCR:
                v = vals[SIDX[r]]
                if p.I[t] & SBIT[r] and v[0] is not None:
                    self.inp |= SBIT[v[0]]
            self.w |= p.W[t]


class Live:
    """vals: pending (the callee's value not overwritten yet)"""
    def cross(self, dst, v):
        return v

    def __init__(self, p):
        self.p = p
        self.used = 0

    def outside(self):
        return False

    def write(self):
        return False

    def join(self, x, y):
        return x or y

    def read(self, a, r, v):
        if v:
            self.used |= SBIT[r]
        return False

    def call(self, a, c, vals):
        p = self.p
        for r in SCR:
            if p.I[c] & SBIT[r] and vals[SIDX[r]]:
                self.used |= SBIT[r]
        return [False if p.W[c] & SBIT[r] else vals[SIDX[r]] for r in SCR]

    def icall(self, vals):
        return [False] * 6

    trap = icall

    def end(self, a, vals, kind, t):
        if t is not None:
            for r in SCR:
                if self.p.I[t] & SBIT[r] and vals[SIDX[r]]:
                    self.used |= SBIT[r]


class Garbage:
    """vals: '' (fine) or the name of the call that left garbage"""
    def __init__(self, p, e, out):
        self.p, self.e, self.out = p, e, out

    def cross(self, dst, v):
        return v

    def outside(self):
        return ''

    def write(self):
        return ''

    def join(self, x, y):
        return x or y

    def read(self, a, r, v):
        if v:
            self.out.append((self.e, a, 'read', r, v))
        return ''

    def call(self, a, c, vals):
        p = self.p
        for r in SCR:
            if p.I[c] & SBIT[r] and vals[SIDX[r]]:
                self.out.append((self.e, a, 'pass', r, vals[SIDX[r]]))
        wc = ALL if p.abi else p.W[c]
        nm = p.ename.get(c, '?')
        return [('%s' % nm if not p.R[c] & SBIT[r] else '') if wc & SBIT[r] else vals[SIDX[r]] for r in SCR]

    def trapargs(self, a, stack):
        # registers pushed as the trap's arguments (single pushes above the last movem save)
        for item in reversed(stack[-6:]):
            if len(item[2]) > 1:
                break
            for (r, v) in item[1]:
                if v:
                    self.out.append((self.e, a, 'arg', r, v))

    def icall(self, vals):
        return ['' if r in ('d0', 'a0') else 'jsr (an)' for r in SCR]

    def trap(self, vals):
        return ['' if r == 'd0' else 'trap' for r in SCR]

    def end(self, a, vals, kind, t):
        p = self.p
        if t is not None:
            for r in SCR:
                if p.I[t] & SBIT[r] and vals[SIDX[r]]:
                    self.out.append((self.e, a, kind, r, vals[SIDX[r]]))
        elif kind == 'ret':
            for r in SCR:
                if p.R[self.e] & SBIT[r] and vals[SIDX[r]] and self.e in p.hres:
                    self.out.append((self.e, a, 'ret', r, vals[SIDX[r]]))


def main():
    args = sys.argv[1:]
    abi = '--abi' in args
    verbose = '--v' in args
    srcdirs = []
    if '--src' in args:
        k = args.index('--src')
        srcdirs = args[k + 1:]
        args = args[:k]
    if '--why' in args:
        k = args.index('--why')
        args = args[:k] + args[k + 2:]
    args = [a for a in args if not a.startswith('--')]
    p = Prog(args[0], abi)
    ins = p.ins
    class Ret:
        def __init__(self):
            self.r = False
        cross = lambda self, d, v: v
        outside = write = lambda self: 0
        join = lambda self, x, y: 0
        read = lambda self, a, r, v: v
        call = lambda self, a, c, vals: vals
        icall = trap = lambda self, vals: vals

        def end(self, a, vals, kind, t):
            if kind in ('ret', 'ijmp') or t is not None and t in RET:
                self.r = True
    RET = set()
    p.RET = RET
    for it in range(80):
        ch = False
        for e in p.entries:
            if e in RET:
                continue
            q = Ret()
            p.flow(e, [0] * 6, q)
            if q.r:
                RET.add(e)
                ch = True
        if not ch:
            break
    for phase in ('W', 'I'):           # W first (it does not depend on I), then I with the final W
        for it in range(60):
            ch = False
            for e in p.entries:
                s = Summary(p, e)
                p.flow(e, [(r, True) for r in SCR], s)
                if phase == 'W' and (s.w | p.W[e]) != p.W[e]:
                    p.W[e] |= s.w
                    ch = True
                if phase == 'I' and (s.inp | p.I[e]) != p.I[e]:
                    p.I[e] |= s.inp
                    ch = True
            if not ch:
                break
    # call sites; results by header or consensus
    sites = defaultdict(list)
    calls_in = defaultdict(list)
    for e in p.entries:
        st = p.flow(e, [(r, True) for r in SCR], Summary(p, e))
        for a in st:
            i = ins.get(a)
            if i and i.kind == 'bsr' and i.target in p.W:
                sites[i.target].append((e, a))
    usecount = {}
    for c in p.entries:
        if c in p.hres:
            p.R[c] = p.hres[c]
            continue
        ss = sites.get(c, [])
        cnt = defaultdict(int)
        wc = ALL if abi else p.W[c]
        for (e, a) in ss:
            lv = Live(p)
            nxt = a + ins[a].size
            init = [bool(wc & SBIT[r]) for r in SCR]
            # run the flow from the instruction after the call, inside caller e
            p.flow_from(e, nxt, init, lv) if hasattr(p, 'flow_from') else None
            for r in SCR:
                if lv.used & SBIT[r]:
                    cnt[r] += 1
        usecount[c] = (cnt, len(ss))
        res = 0
        for r in SCR:
            if ss and cnt[r] * 4 >= len(ss):
                res |= SBIT[r]
        p.R[c] = res & wc
    if '--why' in sys.argv:
        nm = sys.argv[sys.argv.index('--why') + 1]
        e = p.gl[nm]
        WHY.add(None)
        p.flow(e, [(r, True) for r in SCR], Summary(p, e))
        for w in sorted(x for x in WHY if x):
            print('%s input %s at +$%x: %s' % (nm, w[1], w[0] - e, ins[w[0]].text))
        return
    out = []
    for e in p.entries:
        p.flow(e, [''] * 6, Garbage(p, e, out))
    srcmap = {}
    for d in srcdirs:
        for f in sorted(os.listdir(d)):
            if f.endswith(('.s', '.i')):
                for ln, l in enumerate(open(os.path.join(d, f), errors='replace')):
                    m = re.match(r'^([A-Za-z_]\w*):', l)
                    if m:
                        srcmap.setdefault(m.group(1), '%s:%d' % (f, ln + 1))
    rep = {}
    for (e, a, kind, r, cz) in out:
        k = (a, kind)
        if k not in rep:
            rep[k] = [e, set(), set()]
        rep[k][1].add(r)
        rep[k][2].add(cz)
    lines = []
    for (a, kind), (e, rs, cz) in sorted(rep.items()):
        i = ins[a]
        nm = p.ename[e]
        rr = ','.join(r for r in SCR if r in rs)
        if kind == 'pass':
            msg = '%s passed to %s' % (rr, i.tname)
        elif kind in ('tail', 'falls'):
            msg = '%s reaches %s by %s' % (rr, i.tname if kind == 'tail' else 'the next routine', 'a branch' if kind == 'tail' else 'falling through')
        elif kind == 'ret':
            msg = 'returns garbage in %s (a result)' % rr
        elif kind == 'arg':
            msg = '%s pushed as an argument of this trap' % rr
        else:
            msg = '%s read' % rr
        lines.append('%s+$%x %s [lst %d]: %s  <%s>  (after %s)' % (nm, a - e, srcmap.get(nm, ''), i.lst, msg, i.text, ', '.join(sorted(cz))))
    for l in lines:
        print(l)
    if verbose:
        for c in sorted(p.entries, key=lambda x: p.ename[x]):
            cnt, n = usecount.get(c, ({}, 0))
            print('# %-24s W=%-16s I=%-16s R=%-10s %s' % (p.ename[c], names(p.W[c]), names(p.I[c]), names(p.R[c]),
                  'hdr' if c in p.hres else ' '.join('%s:%d/%d' % (r, cnt[r], n) for r in SCR if cnt.get(r))))
    print('%d reports' % len(lines), file=sys.stderr)


def _flow_from(self, e, start, init, ana):
    """flow inside routine e starting at address start (after a call)"""
    saved = self.flow.__func__
    # reuse flow with a pseudo entry: other_entry tests use e
    ins = self.ins
    if start not in ins or self.other_entry(start, e):
        if self.other_entry(start, e):
            ana.end(start, init, 'falls', start)
        return
    orig = self.other_entry
    self.other_entry = lambda n, ee: orig(n, e)
    try:
        self.flow(start, init, ana)
    finally:
        self.other_entry = orig


Prog.flow_from = _flow_from

main()
