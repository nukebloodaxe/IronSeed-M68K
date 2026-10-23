#!/bin/bash
# check_crewgen.sh : CREWGEN.PRG against the Linux oracle on the same scripted session
# (oracle/scripts/s4.*): every state dump field by field (colours aside: the cycling palette is
# timing-dependent), every screenshot pixel for pixel through the ST's LUTs, and every saved
# file byte for byte after converting the ST's files back to the DOS layout (tools/st2dos.py).
# Needs the game folder in hatari/c (tools/mkgame.sh). Prints PASS/FAIL lines.
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
O=build/oracle_s4; fail=0
tools/oracle_run.sh s4 $O > /dev/null || { echo "FAIL crewgen: no oracle"; exit 1; }
python3 tools/st_script.py oracle/scripts/s4.intro hatari/c/INPUT.INT
python3 tools/st_script.py oracle/scripts/s4.crewgen hatari/c/INPUT.CG
rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/SAVE? hatari/c/SAVEGAME.DIR hatari/c/TEMP
tools/run_hatari.sh 9500 /tmp/cg_end.png --auto 'C:\IS.PRG' > /dev/null
rm -f hatari/c/INPUT.INT hatari/c/INPUT.CG
n=0; bad=0
for L in $O/crewgen_*.bin; do
  n=$((n+1)); k=$(basename $L | cut -d_ -f2)
  out=$(python3 tools/oracle_cmp.py build/layout.json $L hatari/c/D$k.BIN 2>&1 | grep -v '^colors\|^screen\|^tempplan')
  [ -n "$out" ] && { bad=$((bad+1)); echo "  dump $k: $(echo "$out" | head -2 | tr '\n' ' ')"; }
done
[ $n -gt 10 ] && [ $bad = 0 ] && echo "PASS crewgen state ($n dumps identical with Linux: ship, systems, events, ...)" || { echo "FAIL crewgen state ($bad of $n dumps differ)"; fail=1; }
SHOTS=$(sed -n 's/^shot //p' oracle/scripts/s4.crewgen | tr '\n' ' ')
python3 tests/check_cg.py $O hatari/c hatari/c/DATA/CGMODES.DAT $SHOTS > /tmp/cg.txt \
  && echo "PASS crewgen screens ($(echo $SHOTS | wc -w) shots pixel-exact with Linux through the ST LUTs)" || { echo "FAIL crewgen screens:"; grep -v ' 0 pixels' /tmp/cg.txt; fail=1; }
rm -rf /tmp/st_save; python3 tools/st2dos.py build/layout.json hatari/c/SAVE3 /tmp/st_save > /dev/null; python3 tools/st2dos.py build/layout.json hatari/c /tmp/st_save > /dev/null
bad=0; for f in $O/home/.ironseed/save3/* $O/home/.ironseed/savegame.dir; do
  b=$(basename $f | tr a-z A-Z); cmp -s $f /tmp/st_save/$b || { bad=1; echo "  $b differs"; }
done
[ $bad = 0 ] && echo "PASS crewgen saved game (SAVE3\\*.DTA + SAVEGAME.DIR byte-identical with Linux after st2dos)" || { echo "FAIL crewgen saved game"; fail=1; }
exit $fail
