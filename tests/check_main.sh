#!/bin/bash
# check_main.sh : MAIN.PRG against the Linux oracle on scripted sessions in virtual time
# (oracle/scripts/m*.main; tools/oracle_main.sh on Linux, INPUT.MN on the ST). Both start from the
# game crewgen's s4 session saved in slot 3 (tests/check_crewgen.sh leaves the Linux save in
# build/oracle_s4/home and the ST one in hatari/c/SAVE3; they are identical after st2dos).
# Every state dump field by field, every screenshot pixel for pixel through the ST's LUTs.
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
fail=0
[ -d build/oracle_s4/home/.ironseed/save3 ] && [ -f hatari/c/SAVE3/SHIP.DTA ] || { echo "FAIL main: no s4 save (run check_crewgen.sh first)"; exit 1; }
MODES="hatari/c/DATA/LOG.ISP hatari/c/DATA/MAIN.ISP"
for S in m1 m2; do
  O=build/oracle_$S
  tools/oracle_main.sh oracle/scripts/$S.main $O build/oracle_s4/home 3 > /dev/null
  python3 tools/st_script.py oracle/scripts/$S.main hatari/c/INPUT.MN
  rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/TEMP
  tools/run_hatari.sh 30000 /tmp/main_$S.png --auto 'C:\MAIN.PRG' > /dev/null
  rm -f hatari/c/INPUT.MN
  n=0; bad=0
  for L in $O/main_*.bin; do
    n=$((n+1)); k=$(basename $L | cut -d_ -f2)
    out=$(python3 tools/oracle_cmp.py build/layout.json $L hatari/c/D$k.BIN 2>&1 | grep -v '^screen')
    [ -n "$out" ] && { bad=$((bad+1)); echo "  $S dump $k: $(echo "$out" | head -2 | tr '\n' ' ')"; }
  done
  [ $n -gt 5 ] && [ $bad = 0 ] && echo "PASS main $S state ($n dumps identical with Linux)" || { echo "FAIL main $S state ($bad of $n dumps differ)"; fail=1; }
  SHOTS=$(sed -n 's/^shot //p' oracle/scripts/$S.main | tr '\n' ' ')
  python3 tests/check_shots.py $O hatari/c "$MODES" $SHOTS > /tmp/main_$S.txt \
    && echo "PASS main $S screens ($(echo $SHOTS | wc -w) shots pixel-exact with Linux through the ST LUTs)" \
    || { echo "FAIL main $S screens:"; grep -v ' 0 pixels' /tmp/main_$S.txt; fail=1; }
done
exit $fail
