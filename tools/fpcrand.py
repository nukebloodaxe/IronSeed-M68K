#!/usr/bin/env python3
"""fpcrand.py - Free Pascal 3.2's random generator (rtl/inc/system.inc: MT19937, random(l) =
(u32 * l) >> 32), so host tools and tests can reproduce the oracle's random sequences
(the oracle build sets randseed := 1994)."""

N, M = 624, 397


class FpcRandom:
    def __init__(self, seed=1994):
        self.mt = [0] * N
        self.index = N + 1
        self.randseed = seed & 0xffffffff
        self.oldseed = None
        self.calls = 0

    def _init(self, seed):
        mt = self.mt
        mt[0] = seed
        for i in range(1, N):
            mt[i] = (1812433253 * (mt[i - 1] ^ (mt[i - 1] >> 30)) + i) & 0xffffffff
        self.index = N

    def _twist(self, u, v):
        mix = (u & 0x80000000) | (v & 0x7fffffff)
        return (mix >> 1) ^ (0x9908b0df if v & 1 else 0)

    def _update(self):
        mt = self.mt
        for k in range(0, N - M):
            mt[k] = mt[k + M] ^ self._twist(mt[k], mt[k + 1])
        for k in range(N - M, N - 1):
            mt[k] = mt[k + (M - N)] ^ self._twist(mt[k], mt[k + 1])
        mt[N - 1] = mt[M - 1] ^ self._twist(mt[N - 1], mt[0])
        self.index = 0

    def u32(self):
        self.calls += 1
        li = self.index
        self.index += 1
        if self.randseed != self.oldseed or li >= N + 1:
            self._init(self.randseed)
            self.randseed = (~self.randseed) & 0xffffffff
            self.oldseed = self.randseed
            li = N
        if li == N:
            self._update()
            li = 0
            self.index = 1
        y = self.mt[li]
        y ^= y >> 11
        y ^= (y << 7) & 0x9D2C5680
        y ^= (y << 15) & 0xEFC60000
        y ^= y >> 18
        return y

    def random64(self, l):
        """FPC's random(int64): what the x86-64 build calls for an arithmetic argument"""
        a = self.u32(); b = self.u32()
        return ((a | (b << 32)) & 0x7fffffffffffffff) % l if l else 0

    def random(self, l):
        if l < 0: l += 1
        v = (self.u32() * l) >> 32
        return v - (1 << 32) if l < 0 and v else v
