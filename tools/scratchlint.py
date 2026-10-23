#!/usr/bin/env python3
"""scratchlint.py FILE.s... : find scratch registers (ABI: d0-d2/a0-a2) read after a bsr/jsr
before being written again - the value did not survive the call. Linear scan from each call to
the next label, branch or rts. d0/a0 reads are reported only after calls that return nothing
(NORESULT below, or `; out: -` style headers are not parsed: extend the list as needed).
Heuristic: review each hit (some callees document that they keep a register)."""
import re, sys

NORESULT = {'mousehide', 'mouseshow', 'delay', 'ms_flush', 'ms_rect', 'ms_bar', 'ms_pset', 'ms_line',
            'ms_dirty', 'ms_dirty_all', 'ms_print', 'ms_fade', 'ms_color', 'ms_snap', 'ms_unsnap',
            'tim_delay', 'orc_dump', 'vid_set256', 'vid_setrgb', 'println', 'print'}
# callees that keep some scratch registers (documented in their headers)
KEEPS = {}
SCR = ['d0', 'd1', 'd2', 'a0', 'a1', 'a2']
NOWRITE = {'cmp', 'cmpi', 'cmpa', 'tst', 'btst', 'cmpm', 'pea', 'chk'}
RMW = {'add', 'addq', 'addi', 'adda', 'sub', 'subq', 'subi', 'suba', 'and', 'andi', 'or', 'ori', 'eor',
       'eori', 'lsl', 'lsr', 'asl', 'asr', 'rol', 'ror', 'roxl', 'roxr', 'mulu', 'muls', 'divu', 'divs',
       'ext', 'neg', 'not', 'swap', 'bset', 'bclr', 'bchg', 'addx', 'subx', 'abcd', 'sbcd', 'negx', 'dbf', 'dbra'}


def regs_in(op):
    op = op.lower()
    out = set()
    for r in SCR:
        if re.search(r'(?<![a-z0-9_.])' + r + r'(?![0-9a-z_])', op):
            out.add(r)
    m = re.search(r'([ad])([0-7])-([ad])([0-7])', op)   # movem ranges
    if m and m.group(1) == m.group(3):
        for i in range(int(m.group(2)), int(m.group(4)) + 1):
            if m.group(1) + str(i) in SCR:
                out.add(m.group(1) + str(i))
    return out


def split_ops(s):
    ops, depth, cur = [], 0, ''
    for ch in s:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            ops.append(cur)
            cur = ''
        else:
            cur += ch
    if cur:
        ops.append(cur)
    return [o.strip() for o in ops]


for fn in sys.argv[1:]:
    lines = open(fn, errors='replace').read().split('\n')
    for i, line in enumerate(lines):
        m = re.match(r'^(?:[.\w]+:)?\s+(bsr|jsr)(?:\.[sbwl])?\s+([.\w]+)', line)
        if not m:
            continue
        callee = m.group(2)
        dead = set(SCR) - KEEPS.get(callee, set())
        if callee not in NORESULT:
            dead -= {'d0', 'a0'}
        for j in range(i + 1, min(i + 40, len(lines))):
            l = lines[j].split(';')[0]
            if re.match(r'^\w+:', l):        # a global label ends the routine; local ones fall through
                break
            l = re.sub(r'^\.[\w]+:', '', l)
            t = l.split()
            if not t:
                continue
            mn = t[0].lower().split('.')[0]
            if mn in ('rts', 'rte', 'bra', 'jmp', 'bsr', 'jsr'):
                break
            if mn.startswith('b') and mn not in RMW and mn not in NOWRITE and len(mn) <= 4 and mn not in ('btst',):
                continue                      # a conditional branch: the fall-through path goes on
            if mn.startswith('db') or mn.startswith('s') and len(mn) <= 3:
                pass
            if mn in ('bsr', 'jsr'):
                break
            ops = split_ops(' '.join(t[1:]))
            if not ops:
                continue
            reads, writes = set(), set()
            if mn == 'movem':
                if re.match(r'^[ad]', ops[0].lower()) and '(' not in ops[0]:
                    reads |= regs_in(ops[0]); reads |= regs_in(ops[1])
                else:
                    reads |= regs_in(ops[0]); writes |= regs_in(ops[1])
            elif mn == 'exg':
                reads |= regs_in(ops[0]) | regs_in(ops[1])
            else:
                for o in ops[:-1]:
                    reads |= regs_in(o)
                last = ops[-1]
                if mn in NOWRITE:
                    reads |= regs_in(last)
                elif re.fullmatch(r'[ad][0-7]', last.lower()):
                    if mn in RMW or len(ops) == 1 and mn not in ('clr', 'seq', 'sne', 'st', 'sf', 'scs', 'scc', 'smi', 'spl'):
                        reads |= regs_in(last)
                    writes |= regs_in(last)
                    if mn == 'move' and '.' in t[0] and t[0].lower().endswith(('.b', '.w')) and last.lower()[0] == 'd':
                        pass   # partial write: treat as full (common in this code)
                else:
                    reads |= regs_in(last)   # an address mode reads its registers
            bad = reads & dead
            if bad:
                print('%s:%d: %s read after bsr %s (line %d): %s' % (fn, j + 1, ','.join(sorted(bad)), callee, i + 1, lines[j].strip()))
                dead -= bad
            dead -= writes

# pattern 2: arguments loaded, then a trashing call (mousehide...), then the call that wanted them
TRASH = {'mousehide', 'mouseshow', 'delay', 'ms_flush', 'tim_delay', 'ms_dirty_all'}
for fn in sys.argv[1:]:
    lines = open(fn, errors='replace').read().split('\n')
    code = [(k, l.split(';')[0].strip()) for k, l in enumerate(lines)]
    for idx, (k, l) in enumerate(code):
        m = re.match(r'^(?:[.\w]+:)?\s*(bsr|jsr)(?:\.[sbwl])?\s+([.\w]+)', l)
        if not m or m.group(2) not in TRASH:
            continue
        # next real instruction
        n = idx + 1
        while n < len(code) and not code[n][1]:
            n += 1
        if n >= len(code):
            continue
        m2 = re.match(r'^(?:[.\w]+:)?\s*(bsr|jsr)(?:\.[sbwl])?\s+([.\w]+)', code[n][1])
        if not m2 or m2.group(2) in TRASH:
            continue
        p = idx - 1
        while p >= 0 and not code[p][1]:
            p -= 1
        if p < 0 or re.match(r'^[.\w]+:', code[p][1]) and not code[p][1].split(':', 1)[1].strip():
            continue
        t = code[p][1].split()
        if t and re.match(r'^[.\w]+:$', t[0]):
            t = t[1:]
        if len(t) >= 2:
            ops = split_ops(' '.join(t[1:]))
            if ops and re.fullmatch(r'[ad][0-2]', ops[-1].lower()) and t[0].lower().split('.')[0] not in NOWRITE:
                print('%s:%d: %s set, then bsr %s before bsr %s' % (fn, k + 1, ops[-1], m.group(2), m2.group(2)))
