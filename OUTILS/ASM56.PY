# -*- coding: utf-8 -*-
"""
ASM56.PY - small DSP 56001 assembler (subset) for RICK3D.

Written to do without a56 : it covers the instructions and addressing
modes used by CUBE3D.A56 (CubeDSP) and by R3D.A56 (RICK3D),
and it is checked byte by byte against CUBE3D.P56 (output of a56) :

    python ASM56.PY CUBE3D.A56 test.p56 --compare CUBE3D.P56

Output : .P56 block for Dsp_ExecProg / Simplet's loader
(type 0=P 1=X 2=Y, address, count, words... ; 3 bytes per word).

Syntax (like a56) : label in column 1, ';' comment,
'equ', 'org p:$adr', 'dc', '#' immediate ('#>' long, '#<' short),
'x:' / 'y:' memory, '$' hexadecimal.
"""
import sys, re

# registers : 6-bit code (move / movep / do), 5 bits = low bits
REG6 = {'x0': 0o04, 'x1': 0o05, 'y0': 0o06, 'y1': 0o07,
        'a0': 0o10, 'b0': 0o11, 'a2': 0o12, 'b2': 0o13,
        'a1': 0o14, 'b1': 0o15, 'a': 0o16, 'b': 0o17}
for i in range(8):
    REG6['r%d' % i] = 0o20 + i
    REG6['n%d' % i] = 0o30 + i
    REG6['m%d' % i] = 0o40 + i
REG6.update({'sr': 0o71, 'omr': 0o72, 'sp': 0o73, 'ssh': 0o74,
             'ssl': 0o75, 'la': 0o76, 'lc': 0o77})
CC = {'cc': 0, 'hs': 0, 'ge': 1, 'ne': 2, 'pl': 3, 'nn': 4, 'ec': 5,
      'lc': 6, 'gt': 7, 'cs': 8, 'lo': 8, 'lt': 9, 'eq': 10, 'mi': 11,
      'nr': 12, 'es': 13, 'ls': 14, 'le': 15}
PERIPH = 0xffc0


class Err(Exception):
    pass


class Asm:
    def __init__(self):
        self.sym = {}
        self.mem = {}          # P address -> word
        self.pc = 0
        self.lines = []        # (n, text)
        self.equs = set()

    # ---------------- expressions ----------------
    def val(self, e, final):
        e = e.strip()
        if e.startswith('>') or e.startswith('<'):
            e = e[1:]
        t = e
        t = re.sub(r'\$([0-9a-fA-F]+)', lambda m: str(int(m.group(1), 16)), t)
        t = re.sub(r'%([01]+)', lambda m: str(int(m.group(1), 2)), t)

        def rep(m):
            n = m.group(0)
            if n.lower() in self.sym:
                return str(self.sym[n.lower()])
            if final:
                raise Err('unknown symbol : ' + n)
            return '65535'                 # (long forms meanwhile)
        t = re.sub(r'[A-Za-z_][A-Za-z_0-9]*', rep, t)
        if not re.fullmatch(r'[0-9+\-*/()<> &|~^ ]*', t):
            raise Err('expression : ' + e)
        t = t.replace('/', '//')
        try:
            return int(eval(t))
        except Exception:
            raise Err('expression : ' + e)

    def force(self, e):
        e = e.strip()
        if e.startswith('>'):
            return 'long'
        if e.startswith('<'):
            return 'short'
        return None

    # ---------------- operands ----------------
    def ea(self, s):
        """memory mode -> (MMMRRR 6 bits, extension or None, is_absolute)"""
        s = s.strip().lower()
        m = re.fullmatch(r'\(r(\d)\)-n\1', s)
        if m: return (0o00 | int(m.group(1)), None)
        m = re.fullmatch(r'\(r(\d)\)\+n\1', s)
        if m: return (0o10 | int(m.group(1)), None)
        m = re.fullmatch(r'\(r(\d)\)-', s)
        if m: return (0o20 | int(m.group(1)), None)
        m = re.fullmatch(r'\(r(\d)\)\+', s)
        if m: return (0o30 | int(m.group(1)), None)
        m = re.fullmatch(r'\(r(\d)\)', s)
        if m: return (0o40 | int(m.group(1)), None)
        m = re.fullmatch(r'\(r(\d)\+n\1\)', s)
        if m: return (0o50 | int(m.group(1)), None)
        m = re.fullmatch(r'-\(r(\d)\)', s)
        if m: return (0o70 | int(m.group(1)), None)
        return None

    # ---------------- 1st pass / 2nd pass ----------------
    def run(self, text):
        self.lines = text.split('\n')
        for final in (False, False, False, True):
            self.pc = 0
            self.mem = {}
            self.final = final
            for n, l in enumerate(self.lines, 1):
                try:
                    self.line(l)
                except (ValueError, KeyError, IndexError) as e:
                    if final:
                        raise Err('line %d : %r\n  %s' % (n, e, l))
                except Err as e:
                    if final:
                        raise Err('line %d : %s\n  %s' % (n, e, l))

    def line(self, l):
        l = l.split(';')[0].rstrip()
        if not l.strip():
            return
        label = None
        if not l[0].isspace():
            p = l.split(None, 1)
            label = p[0].rstrip(':')
            l = p[1] if len(p) > 1 else ''
        t = l.split(None, 1)
        op = t[0].lower() if t else ''
        args = t[1].strip() if len(t) > 1 else ''
        if op == 'equ':
            self.sym[label.lower()] = self.val(args, self.final)
            self.equs.add(label.lower())
            return
        if label:
            if label.lower() in self.equs:      # (upper case = lower case)
                raise Err('symbol defined twice : ' + label)
            self.sym[label.lower()] = self.pc
        if not op:
            return
        if op == 'org':
            m = re.fullmatch(r'[pP]:(.*)', args)
            if not m:
                raise Err('org p: only')
            self.pc = self.val(m.group(1), self.final)
            return
        if op == 'dc':
            for a in args.split(','):
                self.emit(self.val(a, self.final) & 0xffffff)
            return
        words = self.instr(op, args)
        for w in words:
            self.emit(w)

    def emit(self, w):
        self.mem[self.pc] = w & 0xffffff
        self.pc += 1

    def v(self, e):
        return self.val(e, self.final)

    # ---------------- instructions ----------------
    def instr(self, op, args):
        f = self.final
        # without operand
        if op == 'nop': return [0x000000]
        if op == 'rts': return [0x00000c]
        if op == 'rti': return [0x000004]
        if op in ('jmp', 'jsr') or (op[0] == 'j' and op[1:] in CC):
            tgt = self.v(args)
            if op == 'jmp':
                if tgt < 0x1000: return [0x0c0000 | tgt]
                return [0x0af080, tgt]
            if op == 'jsr':
                if tgt < 0x1000: return [0x0d0000 | tgt]
                return [0x0bf080, tgt]
            c = CC[op[1:]]
            if tgt < 0x1000: return [0x0e0000 | (c << 12) | tgt]
            return [0x0af0a0 | c, tgt]
        if op in ('jclr', 'jset'):
            bit, mem, tgt = [x.strip() for x in args.split(',')]
            b = self.v(bit.lstrip('#'))
            sp, addr = mem.split(':')
            s = 0 if sp.lower() == 'x' else 1
            a = self.v(addr)
            if a < PERIPH and f:
                raise Err('jclr/jset : peripheral only')
            w = 0x0a8080 | ((a & 0x3f) << 8) | (s << 6) | (b & 0x1f)
            if op == 'jset': w |= 0x20
            return [w, self.v(tgt)]
        if op == 'andi' or op == 'ori':
            imm, dst = [x.strip() for x in args.split(',')]
            i = self.v(imm.lstrip('#')) & 0xff
            ee = {'mr': 0, 'ccr': 1, 'omr': 2}[dst.lower()]
            return [((i << 8) | (0xb8 if op == 'andi' else 0xf8) | ee)]
        if op == 'rep':
            a = args.strip()
            if a.startswith('#'):
                n = self.v(a[1:]) & 0xfff
                return [0x0600a0 | ((n & 0xff) << 8) | (n >> 8)]
            r = REG6[a.lower()]
            return [0x06c020 | (r << 8)]
        if op == 'do':
            src, end = [x.strip() for x in args.split(',')]
            la = (self.v(end) - 1) & 0xffff
            if src.startswith('#'):
                n = self.v(src[1:]) & 0xfff
                return [0x060080 | ((n & 0xff) << 8) | (n >> 8), la]
            r = REG6[src.lower()]
            return [0x06c000 | (r << 8), la]
        if op == 'lua':
            src, dst = [x.strip() for x in args.split(',')]
            e = self.ea(src)
            if e is None or (e[0] >> 3) > 3:
                raise Err('lua : mode')
            d = dst.lower()
            dd = int(d[1]) | (8 if d[0] == 'n' else 0)
            return [0x044010 | ((e[0] & 0o37) << 8) | dd]
        if op == 'movep':
            return self.movep(args)
        if op == 'div':                         # div S,D (S = x0 y0 x1 y1)
            s, d = [x.strip().lower() for x in args.split(',')]
            jj = {'x0': 0, 'y0': 1, 'x1': 2, 'y1': 3}[s]
            return [0x018040 | (jj << 4) | ((1 if d == 'b' else 0) << 3)]
        if op[0] == 't' and op[1:] in CC:      # Tcc
            s, d = [x.strip().lower() for x in args.split(',')]
            c = CC[op[1:]]
            if s in ('a', 'b'):
                jjj = 0
            else:
                jjj = {'x0': 4, 'y0': 5, 'x1': 6, 'y1': 7}[s]
            dd = 1 if d == 'b' else 0
            return [0x020000 | (c << 12) | (jjj << 4) | (dd << 3)]
        # ALU instructions (with an optional parallel move)
        alu = self.aluop(op, args)
        if alu is not None:
            code, rest = alu
            return self.pmove(rest, code)
        if op == 'move':
            return self.pmove(args, 0x00)
        raise Err('unknown instruction : ' + op)

    def aluop(self, op, args):
        """-> (ALU byte, parallel moves) or None"""
        A = {'a': 0, 'b': 1}
        toks = args.split(None, 1)
        ops = toks[0] if toks else ''
        rest = toks[1] if len(toks) > 1 else ''
        o = [x.strip().lower() for x in ops.split(',')] if ops else []

        def jjj(s, d):
            if s == ('b' if d == 'a' else 'a'): return 1
            return {'x': 2, 'y': 3, 'x0': 4, 'y0': 5, 'x1': 6, 'y1': 7}[s]

        def jj(s):
            return {'x0': 0, 'y0': 1, 'x1': 2, 'y1': 3}[s]
        try:
            if op in ('add', 'sub', 'tfr', 'cmp', 'cmpm'):
                s, d = o
                low = {'add': 0, 'tfr': 1, 'sub': 4, 'cmp': 5, 'cmpm': 7}[op]
                if op == 'tfr' or op.startswith('cmp'):
                    if s in ('a', 'b'):
                        j = 0
                    else:
                        j = {'x0': 4, 'y0': 5, 'x1': 6, 'y1': 7}[s]
                else:
                    j = jjj(s, d)
                return ((j << 4) | (A[d] << 3) | low, rest)
            if op in ('and', 'or', 'eor'):
                s, d = o
                low = {'or': 2, 'eor': 3, 'and': 6}[op]
                return (0x40 | (jj(s) << 4) | (A[d] << 3) | low, rest)
            one = {'tst': 0x03, 'clr': 0x13, 'asr': 0x22, 'lsr': 0x23,
                   'abs': 0x26, 'ror': 0x27, 'asl': 0x32, 'lsl': 0x33,
                   'neg': 0x36, 'rol': 0x37, 'rnd': 0x11, 'not': 0x17}
            if op in one:
                (d,) = o
                return (one[op] | (A[d] << 3), rest)
            if op in ('mpy', 'mac', 'mpyr', 'macr'):
                neg = False
                s1, s2, d = o
                if s1.startswith('-'):
                    neg = True
                    s1 = s1[1:]
                if s1.startswith('+'):
                    s1 = s1[1:]
                Q = {('x0', 'x0'): 0, ('y0', 'y0'): 1, ('x1', 'x0'): 2,
                     ('y1', 'y0'): 3, ('x0', 'y1'): 4, ('y0', 'x0'): 5,
                     ('x1', 'y0'): 6, ('y1', 'x1'): 7}
                q = Q.get((s1, s2), Q.get((s2, s1)))
                if q is None:
                    raise Err('mpy : registers')
                low = {'mpy': 0, 'mpyr': 1, 'mac': 2, 'macr': 3}[op]
                return (0x80 | (q << 4) | (A[d] << 3) | (int(neg) << 2) | low,
                        rest)
        except (KeyError, ValueError):
            raise Err('operands : ' + op + ' ' + args)
        return None

    # ---------------- moves (move / parallel) ----------------
    def pmove(self, s, alu):
        s = s.strip()
        if not s:
            return [0x200000 | alu]
        parts = s.split()
        if len(parts) == 1:
            return self.move1(parts[0], alu)
        if len(parts) == 2:
            return self.move2(parts[0], parts[1], alu)
        raise Err('moves : ' + s)

    def reg5(self, r):
        c = REG6.get(r.lower())
        if c is None or c >= 0o40 or c < 0o04:
            return None
        return c & 0o37

    def move1(self, s, alu):
        e = self.ea(s)
        if e is not None and ',' not in s:     # (Rn)+ ... : update
            if (e[0] >> 3) > 3:
                raise Err('update : mode')
            return [0x204000 | ((e[0] & 0o37) << 8) | alu]
        if ',' not in s:
            raise Err('move : ' + s)
        src, dst = [x.strip() for x in s.split(',', 1)]
        sl, dl = src.lower(), dst.lower()
        # (Rn)+ etc. alone : pointer update
        if dst == '' or (self.ea(src) and not ',' in s):
            pass
        # register -> register
        if sl in REG6 and dl in REG6 and not src.startswith('#'):
            e, d = self.reg5(sl), self.reg5(dl)
            return [0x200000 | (e << 13) | (d << 8) | alu]
        # immediate
        if src.startswith('#'):
            ex = src[1:]
            n = self.v(ex)
            fo = self.force(ex)
            d = self.reg5(dl)
            if d is None:
                raise Err('move # -> ' + dst)
            if fo != 'long' and (fo == 'short' or (0 <= n <= 0xff)):
                return [0x200000 | (1 << 21) | (d << 16) | ((n & 0xff) << 8) | alu]
            return [0x40f400 | ((d >> 3) << 20) | ((d & 7) << 16) | alu,
                    n & 0xffffff]
        # memory x: / y:
        for (mem, reg, w) in ((src, dst, 1), (dst, src, 0)):
            m = re.fullmatch(r'([xyXY]):(.*)', mem)
            if m and reg.lower() in REG6:
                sp = m.group(1).lower()
                return self.xymove(sp, m.group(2), reg.lower(), w, alu)
        raise Err('move : ' + s)

    def xymove(self, sp, addr, reg, w, alu):
        d = self.reg5(reg)
        e = self.ea(addr)
        base = 0x400000 if sp == 'x' else 0x480000
        if e is not None:
            mmm = e[0]
            return [base | ((d >> 3) << 20) | ((d & 7) << 16) | (w << 15)
                    | (1 << 14) | (mmm << 8) | alu]
        a = self.v(addr)
        fo = self.force(addr)
        if fo != 'long' and (fo == 'short' or 0 <= a < 0x40):
            return [base | ((d >> 3) << 20) | ((d & 7) << 16) | (w << 15)
                    | (a << 8) | alu]
        return [base | ((d >> 3) << 20) | ((d & 7) << 16) | (w << 15)
                | (1 << 14) | (0o60 << 8) | alu, a & 0xffffff]

    def move2(self, m1, m2, alu):
        # X: with R (e.g. "a,x:(r1)+" and nothing else) or two registers ->
        # here : a single X/Y memory move + ALU (X: / Y: format)
        # "S,x:ea  S2,D2" etc. not used ; only "ea_mem,reg" is accepted
        raise Err('two parallel moves not handled : %s %s' % (m1, m2))

    def movep(self, args):
        src, dst = [x.strip() for x in args.split(',', 1)]
        # peripheral side
        def per(x):
            m = re.fullmatch(r'([xyXY]):(.*)', x)
            if not m: return None
            if self.ea(m.group(2)) is not None:
                return None
            try:
                a = self.v(m.group(2))
            except Err:
                return None
            if a >= PERIPH or not self.final:
                return (0 if m.group(1).lower() == 'x' else 1, a & 0x3f)
            return None
        ps, pd = per(src), per(dst)
        if pd is not None and ps is None:
            other, W, (s, pp) = src, 1, pd
        elif ps is not None:
            other, W, (s, pp) = dst, 0, ps
        else:
            raise Err('movep : peripheral ?')
        o = other.lower()
        if o in REG6:
            return [0x084000 | (s << 16) | (W << 15) | (REG6[o] << 8) | pp]
        m = re.fullmatch(r'([xyXY]):(.*)', other)
        if m:
            sp = 0 if m.group(1).lower() == 'x' else 1
            e = self.ea(m.group(2))
            if e is None:
                a = self.v(m.group(2))
                return [0x084080 | (s << 16) | (W << 15) | (sp << 6) | (0o60 << 8) | pp, a]
            return [0x084080 | (s << 16) | (W << 15) | (sp << 6) | (e[0] << 8) | pp]
        raise Err('movep : ' + args)

    # ---------------- .P56 output ----------------
    def p56(self):
        ad = sorted(self.mem)
        out = []
        i = 0
        while i < len(ad):
            j = i
            while j + 1 < len(ad) and ad[j + 1] == ad[j] + 1:
                j += 1
            out += [0, ad[i], j - i + 1] + [self.mem[a] for a in ad[i:j + 1]]
            i = j + 1
        return b''.join((w & 0xffffff).to_bytes(3, 'big') for w in out)


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        print(__doc__)
        return 1
    src = open(a[0], encoding='latin-1').read()
    asm = Asm()
    try:
        asm.run(src)
    except Err as e:
        print('ERROR', e)
        return 1
    b = asm.p56()
    open(a[1], 'wb').write(b)
    print(a[1], len(b) // 3, 'DSP words')
    if '--compare' in a:
        ref = open(a[a.index('--compare') + 1], 'rb').read()
        rw = [int.from_bytes(ref[i:i + 3], 'big') for i in range(0, len(ref), 3)]
        ow = [int.from_bytes(b[i:i + 3], 'big') for i in range(0, len(b), 3)]
        if rw == ow:
            print('IDENTICAL to', a[a.index('--compare') + 1])
            return 0
        # address by address
        def tomem(w):
            m = {}; i = 0
            while i < len(w):
                t, ad, n = w[i:i + 3]
                for k in range(n): m[(t, ad + k)] = w[i + 3 + k]
                i += 3 + n
            return m
        mr, mo = tomem(rw), tomem(ow)
        bad = [k for k in sorted(set(mr) | set(mo)) if mr.get(k) != mo.get(k)]
        print(len(bad), 'differences')
        for k in bad[:40]:
            print('  P:%04x  expected %s  got %s' % (k[1],
                  '%06x' % mr[k] if k in mr else '-', '%06x' % mo[k] if k in mo else '-'))
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
