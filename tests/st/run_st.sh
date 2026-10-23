#!/bin/bash
# run_st.sh SESSION : an ST-only MAIN session (tests/st/SESSION.main, no Linux oracle): the s4 save
# (+ "# setup" edits), INPUT.MN, Hatari; leaves the shots (*.SCR) and dumps (D*.BIN) in hatari/c.
# Look at them with tools/scr2png.py and tools/dumpship.py.
R=$(cd "$(dirname "$0")/../.." && pwd); cd "$R"
S=$1; F=tests/st/$S.main
SETUP=$(sed -n 's/^# *setup //p' $F)
python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 build/setup_st 3 hatari/c $SETUP > /dev/null || exit 1
python3 tools/st_script.py $F hatari/c/INPUT.MN
rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/TEMP hatari/c/STREAM.BIN
V=$(awk '/^# *vbls /{print $3}' $F); tools/run_hatari.sh ${V:-30000} /tmp/st_$S.png --auto 'C:\MAIN.PRG' > /dev/null
rm -f hatari/c/INPUT.MN
python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 build/setup_none 3 hatari/c > /dev/null
ls hatari/c/*.SCR hatari/c/D0*.BIN 2>/dev/null | wc -l; [ -f hatari/c/CRASH.TXT ] && { echo CRASH; python3 tools/st_fatal.py hatari/c/CRASH.TXT 2>/dev/null | head -20; }
exit 0
