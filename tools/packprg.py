#!/usr/bin/env python3
"""packprg.py IN.PRG OUT.PRG : a packed program for the floppy version (Phase 8): game/stub.s
(kernel inflate.s) + the program's text, data and relocation table as raw deflate. The stub
unpacks it at start and runs it as TOS would have (see stub.s). The input must have no symbols
(tools/asm.sh builds without them)."""
import os, struct, subprocess, sys, zlib
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src, dst = sys.argv[1], os.path.abspath(sys.argv[2])
b = open(src, 'rb').read()
magic, tlen, dlen, blen, slen = struct.unpack('>HIIII', b[:18])
assert magic == 0x601a and slen == 0, 'not a TOS program without symbols'
img = b[28:28 + tlen + dlen] + b[28 + tlen + dlen + slen:]     # text, data, relocation table
c = zlib.compressobj(9, zlib.DEFLATED, -15, 9)
z = c.compress(img) + c.flush()
os.makedirs(os.path.join(R, 'build'), exist_ok=True)
open(os.path.join(R, 'build', 'stub.pk'), 'wb').write(z)
env = dict(os.environ, ASMDEFS='-DP_TLEN=%d -DP_DLEN=%d -DP_BLEN=%d -DP_USIZE=%d' % (tlen, dlen, blen, len(img)))
subprocess.run([os.path.join(R, 'tools', 'asm.sh'), os.path.join(R, 'game', 'stub.s'), dst], env=env, check=True,
               stdout=subprocess.DEVNULL)
print('%s: %d -> %d bytes' % (os.path.basename(dst), len(b), os.path.getsize(dst)))
