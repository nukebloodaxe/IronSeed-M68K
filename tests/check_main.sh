#!/bin/bash
# check_main.sh : MAIN.PRG against the Linux oracle on scripted sessions in virtual time
# (oracle/scripts/m*.main, "# mask NAME:x1,y1,x2,y2" lines exclude a rectangle; tools/oracle_main.sh on Linux, INPUT.MN on the ST). Both start from the
# game crewgen's s4 session saved in slot 3 (tests/check_crewgen.sh leaves the Linux save in
# build/oracle_s4/home and the ST one in hatari/c/SAVE3; they are identical after st2dos).
# Every state dump field by field, every screenshot pixel for pixel through the ST's LUTs.
# "# setup EDITS" in a script: the session starts from the s4 save changed by tools/mksave.py
# (both sides; the ST's SAVE3 is made again from the s4 save afterwards).
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
fail=0
[ -d build/oracle_s4/home/.ironseed/save3 ] && [ -f hatari/c/SAVE3/SHIP.DTA ] || { echo "FAIL main: no s4 save (run check_crewgen.sh first)"; exit 1; }
MODES="$(for m in LOG MAIN MAINS1 MAINS2 MAINS3 $(cd hatari/c/DATA && ls MAIN[GPCA]*.ISP 2>/dev/null | sed "s/.ISP//") LAND CHAR2 PSYCHE CARGO TECH1 CCOM COMNR COMA1 COMA2 COMA3 COMA4 COMA5 COMA6 COMA7 COMA8 COMA9 COMA10 COMA11 COMG30 COMG31 COMG32 COMG33 SECTOR FIGHT LOADG END1B END2B END3B END4B END5B INTRO2E CRED ENDS EGGN EGG3 EGG6; do printf "hatari/c/DATA/%s.ISP " $m; done)"
T=/tmp/cm_$(echo "$R" | tr / _); mkdir -p $T   # (per tree: two trees run at once)
cp hatari/c/SAVEGAME.DIR $T/sgdir.bak   # sessions that save get their slots compared, then undone
for S in ${@:-m1 m2 m3 m4 m5 m6 m7 m8 m9 m10 m11 m12 m13 m14 m15 m16 m17 m18 m19 m20 m21 m22 m23 m24 m25 m26 m27 m28 m29 m30 m31 m32 m33 m34 m35 m36 m37 m38 m39 m40 m41 m42 m43 m44 m45 m46 m47 m48 m49 m50 m51 m52 m53}; do
  O=build/oracle_$S; H=build/oracle_s4/home
  SETUP=$(sed -n 's/^# *setup //p' oracle/scripts/$S.main)   # a test position made from the s4 save
  if [ -n "$SETUP" ]; then
    H=build/setup_$S; python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 $H 3 hatari/c $SETUP > /dev/null || exit 1
  fi
  SL=3; grep -q "^# *noslot" oracle/scripts/$S.main && SL=; IS=/playseed; grep -q "^# *killseed" oracle/scripts/$S.main && { SL=; IS=/killseed; }
  PRN=$(grep -c "^# *prn" oracle/scripts/$S.main); rm -f hatari/c/TEMP/LPT1   # "# prn": compare the printed file
  ISEED=$IS tools/oracle_main.sh oracle/scripts/$S.main $O $H "$SL" > /dev/null
  [ "$PRN" != 0 ] && cp "$(find $O/tmp -name LPT1 | head -1)" $O/LPT1
  python3 tools/st_script.py oracle/scripts/$S.main hatari/c/INPUT.MN
  rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/TEMP hatari/c/STREAM.BIN
  V=$(awk '/^# *vbls /{print $3}' oracle/scripts/$S.main); tools/run_hatari.sh ${V:-30000} /tmp/main_$S.png --auto 'C:\MAIN.PRG' > /dev/null
  rm -f hatari/c/INPUT.MN
  n=0; bad=0
  for L in $O/main_*.bin; do
    n=$((n+1)); k=$(basename $L | cut -d_ -f2)
    out=$(python3 tools/oracle_cmp.py build/layout.json $L hatari/c/D$k.BIN 2>&1 | grep -v '^screen\|^identical')
    [ -n "$out" ] && { bad=$((bad+1)); echo "  $S dump $k: $(echo "$out" | head -2 | tr '\n' ' ')"; }
  done
  ST=""; if [ -f hatari/c/STREAM.BIN ]; then   # music streamed: the ring must never have run dry
    read sm su sn se <<< $(python3 -I -c "import struct; print('%d %d %d %d' % struct.unpack('>3LH', open('hatari/c/STREAM.BIN','rb').read()[:14]))")
    ST=", music stream: ring >= $((sm/1024)) KB"; [ "$su" != 0 -o "$se" != 0 ] && { echo "FAIL main $S music stream ($su underrun pairs, $se read errors)"; fail=1; }
    [ "$sm" = 2147483647 ] && { echo "FAIL main $S music stream (read but never played: the VBL is broken)"; fail=1; }
  fi
  [ $n -gt 0 ] && [ $bad = 0 ] && echo "PASS main $S state ($n dumps identical with Linux$ST)" || { echo "FAIL main $S state ($bad of $n dumps differ)"; fail=1; }
  for D in $O/home/.ironseed/save[0-9]; do      # games saved in the session (slot 3 is the start)
    N=${D##*save}; [ $N = 3 ] && continue
    rm -rf $T/st_save; python3 tools/st2dos.py build/layout.json hatari/c/SAVE$N $T/st_save > /dev/null
    python3 tools/st2dos.py build/layout.json hatari/c $T/st_save > /dev/null
    sb=0; for f in $D/* $O/home/.ironseed/savegame.dir; do
      b=$(basename $f | tr a-z A-Z); cmp -s $f $T/st_save/$b || { sb=1; echo "  $S SAVE$N: $b differs"; }
    done
    [ $sb = 0 ] && echo "PASS main $S saved game (SAVE$N + SAVEGAME.DIR byte-identical with Linux after st2dos)" || fail=1
    rm -rf hatari/c/SAVE$N
  done
  if [ "$PRN" != 0 ]; then
    if [ -f $O/LPT1 ] && cmp -s $O/LPT1 <(tr -d '\r' < hatari/c/TEMP/LPT1 2>/dev/null); then echo "PASS main $S printed file (TEMP\\LPT1 = Linux's, line ends aside)"
    else echo "FAIL main $S printed file"; fail=1; fi
  fi
  cp $T/sgdir.bak hatari/c/SAVEGAME.DIR
  [ -n "$SETUP" ] && python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 build/setup_none 3 hatari/c > /dev/null
  SHOTS=$(awk '/^shot /{n[++k]=$2} /^# *mask /{sub(/^# *mask /,""); split($0,a,":"); m[a[1]]=$0}
    END{for(i=1;i<=k;i++) printf "%s ", (n[i] in m) ? m[n[i]] : n[i]}' oracle/scripts/$S.main)
  python3 tests/check_shots.py $O hatari/c "$MODES" $SHOTS > /tmp/main_$S.txt \
    && echo "PASS main $S screens ($(echo $SHOTS | wc -w) shots pixel-exact with Linux through the ST LUTs)" \
    || { echo "FAIL main $S screens:"; grep -v ' 0 pixels' /tmp/main_$S.txt; fail=1; }
  mkdir -p build/st_shots/$S && cp hatari/c/*.SCR build/st_shots/$S/ 2>/dev/null   # kept (tools/looks.py)
done
exit $fail
