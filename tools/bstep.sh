#!/bin/bash
# bstep.sh DEFS [SESSION] : bridge step timing (tag 0 intervals between T0 and T1 ms)
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
ASMDEFS="-DPROFILE=1 -DSCR_DBGN=8192 $1" tools/asm.sh game/main.s hatari/c/MAIN.PRG >/dev/null || exit 1
tests/st/run_st.sh ${2:-bridge} >/dev/null
python3 tools/dbgtimes.py hatari/c/DBG.BIN 2>/dev/null | awk -v t0=${T0:-8000} -v t1=${T1:-26000} '$2==0{t=$4; if(p){d=t-p; if(t>t0 && t<t1 && d<1000){n++; s+=d; if(d>m)m=d}} p=t} END{printf "steps %d mean %.1f ms max %d\n", n, s/n, m}'
