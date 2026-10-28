#!/usr/bin/env python3
"""projmodel.py [N] - host check of game/info.s if_projf (Phase 6j): the sector map's fast projection in
16.16 fixed point, modelled operation by operation, against the oracle's double arithmetic (round()
is banker's, as FPC's SSE cvtsd2si). Prints wrong decisions (must be 0) and the share of exact fallbacks."""
import struct, random
def fix(v):
    b=struct.unpack('>Q',struct.pack('>d',v))[0]
    hi=b>>32; lo=b&0xffffffff
    e=(hi>>20)&0x7ff
    if e==0: return 0
    t=1038-e
    if t<8: return None
    if t>=32: return 0
    m=((hi&0xfffff)|0x100000)<<11 | (lo>>21)
    r=m>>t
    return -r if hi>>31 else r
def q(xf,off,r16):
    a=abs(xf)
    qq=((a&0xffff)*r16>>16) + (a>>16)*r16
    if xf<0: qq=-qq
    v=(off<<16)+qq
    E=3*((a>>16)+1)+8
    fr=v&0xffff
    d=abs(fr-0x8000)
    if d<=E: return None
    return (v+0x8000)>>16
def proj(x,y,z):
    zf=fix(z)
    if zf is None: return None
    D=(500<<16)-zf
    if not (256<<16)<=D<(1024<<16): return None
    if D>=512<<16: Dk=D>>10; n=250<<22
    else: Dk=D>>9; n=250<<23
    r16=n//Dk
    xf=fix(x); yf=fix(y)
    if xf is None or yf is None: return None
    a=q(xf,85,r16); b=q(yf,70,r16)
    if a is None or b is None: return None
    return a,b
def exact(x,y,z):
    return round(85+(x*250/(500-z))), round(70+(y*250/(500-z)))
random.seed(1)
import sys
bad=slow=0;N=int(sys.argv[1]) if len(sys.argv)>1 else 200000
for i in range(N):
    x,y,z=[random.uniform(-110,110) for _ in range(3)]
    p=proj(x,y,z)
    if p is None: slow+=1; continue
    if p!=exact(x,y,z): bad+=1; print(x,y,z,p,exact(x,y,z)) if bad<5 else None
print('bad',bad,'slow',slow/N)
