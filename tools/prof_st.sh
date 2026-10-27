#!/bin/bash
# prof_st.sh SESSION VBL0 VBL1 : CPU profile of MAIN.PRG between two frames of an ST-only session
# (tests/st/SESSION.main, as run_st.sh), like prof_session.sh for the oracle sessions; prints the
# per-symbol summary (tools/prof_sum.py). ASMDEFS passes through to the SYM=1 build.
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
S=$1; V0=$2; V1=$3; F=tests/st/$S.main
SETUP=$(sed -n 's/^# *setup //p' $F)
python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 build/setup_st 3 hatari/c $SETUP > /dev/null || exit 1
SYM=1 tools/asm.sh game/main.s hatari/c/MAIN.PRG || exit 1
python3 tools/st_script.py $F hatari/c/INPUT.MN
rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/TEMP hatari/c/STREAM.BIN
tools/hatari_prof.sh $V0 $V1 'C:\MAIN.PRG'
rm -f hatari/c/INPUT.MN
python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 build/setup_none 3 hatari/c > /dev/null
python3 tools/prof_sum.py hatari/prof.log ${N:-30}
