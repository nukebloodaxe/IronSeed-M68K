#!/bin/bash
# xstep.sh DEFS : exploration frame times (tag 47): mean before / after the probe launch (gap > 1 s)
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
ASMDEFS="-DPROFILE=1 -DSCR_DBGN=8192 $1" tools/asm.sh game/main.s hatari/c/MAIN.PRG >/dev/null || exit 1
tests/st/run_st.sh explore >/dev/null
python3 tools/dbgtimes.py hatari/c/DBG.BIN | awk '$2==47{print $4}' | python3 -c '
import sys
t=[int(x) for x in sys.stdin]; d=[b-a for a,b in zip(t,t[1:])]
g=[i for i,x in enumerate(d) if x>1000]
if not g: print("no gap", sum(d)/len(d)); sys.exit()
a=d[:g[0]]; b=d[g[0]+1:]
print("before %.1f ms (%d)  probes %.1f ms (%d)" % (sum(a)/len(a), len(a), sum(b)/len(b), len(b)))'
