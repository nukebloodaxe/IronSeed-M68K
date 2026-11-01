#!/bin/bash
# flp_cg.sh [VBLS] (Phase 8): the s4 intro + crewgen session on test floppies (FLP_DISKS), compared
# with the Linux oracle as tests/check_crewgen.sh does (dumps, shots, the saved game from the save disk)
R=$(cd "$(dirname "$0")/../.." && pwd); cd "$R"; O=build/oracle_s4; fail=0
G=${FLP_GAME:-build/floppy_test}; D=${FLP_DISKS:-build/floppy_test_disks}
python3 tools/st_script.py oracle/scripts/s4.intro /tmp/INPUT.INT; python3 tools/st_script.py oracle/scripts/s4.crewgen /tmp/INPUT.CG
python3 tools/mkfloppy.py $G $D /tmp/INPUT.INT=1 /tmp/INPUT.CG=2 > /dev/null
rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/SAVE? hatari/c/SAVEGAME.DIR hatari/c/TEMP hatari/c/INPUT.*
cp $D/IRONSEED9.ST /tmp/save_orig.ST
python3 tests/floppy/flp_drive.py $D ${1:-16000} /tmp/cg_end.png
n=0; bad=0
for L in $O/crewgen_*.bin; do
  n=$((n+1)); k=$(basename $L | cut -d_ -f2)
  out=$(python3 tools/oracle_cmp.py build/layout.json $L hatari/c/D$k.BIN 2>&1 | grep -v '^colors\|^screen\|^tempplan')
  [ -n "$out" ] && { bad=$((bad+1)); echo "  dump $k: $(echo "$out" | head -2 | tr '\n' ' ')"; }
done
[ $n -gt 10 ] && [ $bad = 0 ] && echo "PASS crewgen state ($n dumps)" || { echo "FAIL crewgen state ($bad of $n)"; fail=1; }
SHOTS=$(sed -n 's/^shot //p' oracle/scripts/s4.crewgen | tr '\n' ' ')
python3 tests/check_cg.py $O hatari/c hatari/c/DATA/CGMODES.DAT $SHOTS > /tmp/cg.txt && echo "PASS crewgen screens" || { echo "FAIL crewgen screens"; grep -v ' 0 pixels' /tmp/cg.txt | head; fail=1; }
rm -rf /tmp/sv /tmp/st_save; python3 tools/fat12.py --extract $D/IRONSEED9.ST /tmp/sv
python3 tools/st2dos.py build/layout.json /tmp/sv/SAVE3 /tmp/st_save > /dev/null; python3 tools/st2dos.py build/layout.json /tmp/sv /tmp/st_save > /dev/null
bad=0; for f in $O/home/.ironseed/save3/* $O/home/.ironseed/savegame.dir; do
  b=$(basename $f | tr a-z A-Z); cmp -s $f /tmp/st_save/$b || { bad=1; echo "  $b differs"; }
done
[ $bad = 0 ] && echo "PASS crewgen saved game on the save disk" || { echo "FAIL saved game"; ls -R /tmp/sv | head; fail=1; }
rm -rf build/floppy_s4save; mkdir -p build/floppy_s4save; cp -r /tmp/sv/SAVE3 /tmp/sv/SAVEGAME.DIR build/floppy_s4save/ 2>/dev/null   # (flp_main.sh's start)
cp /tmp/save_orig.ST $D/IRONSEED9.ST    # (a fresh save disk for the next run)
exit $fail
