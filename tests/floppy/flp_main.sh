#!/bin/bash
# flp_main.sh mN... (Phase 8): MAIN session mN on test floppies, started straight from disk 3
# Needs: FLP_GAME = a NOMUSIC game folder whose PRGs are -DFLPNF builds (see make_test.sh),
# FLP_S4 = the s4 save in ST layout (SAVE3\, SAVEGAME.DIR: hatari/c's after check_crewgen.sh),
# (Hatari --auto A:\MAIN.PRG, the script's own args), the s4 save (+ the session's setup) on the
# save disk; dumps, shots and saved games against the Linux oracle (ORA=dir of oracle_mN dirs)
R=$(cd "$(dirname "$0")/../.." && pwd); cd "$R"; fail=0; ORA=${ORA:-build}
G=${FLP_GAME:-build/floppy_test}; FD=${FLP_DISKS:-build/floppy_test_disks}; SV=${FLP_S4:-build/floppy_s4save}
MODES="$(for m in LOG MAIN MAINS1 MAINS2 MAINS3 $(cd $G/DATA && ls MAIN[GPCA]*.ISP 2>/dev/null | sed "s/.ISP//") LAND CHAR2 PSYCHE CARGO TECH1 CCOM COMNR COMA1 COMA2 COMA3 COMA4 COMA5 COMA6 COMA7 COMA8 COMA9 COMA10 COMA11 COMG30 COMG31 COMG32 COMG33 SECTOR FIGHT LOADG END1B END2B END3B END4B END5B INTRO2E CRED ENDS EGGN EGG3 EGG6; do printf "$G/DATA/%s.ISP " $m; done)"
for S in "$@"; do
  O=$ORA/oracle_$S
  [ -d $O ] || { echo "SKIP $S (no oracle)"; continue; }
  python3 tools/st_script.py oracle/scripts/$S.main /tmp/INPUT.MN
  python3 tools/mkfloppy.py $G $FD /tmp/INPUT.MN=3 > /dev/null
  rm -rf /tmp/svd; cp -r $SV /tmp/svd
  SETUP=$(sed -n 's/^# *setup //p' oracle/scripts/$S.main)
  [ -n "$SETUP" ] && { python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 /tmp/setup_h 3 /tmp/svd $SETUP > /dev/null || { echo "FAIL $S setup"; continue; }; }
  python3 - <<PY
import os, sys; sys.path.insert(0, 'tools'); from fat12 import Floppy
f = Floppy(serial=0x495399, label='IS SAVE'); f.add('ISSAVE.ID', b'Iron Seed save disk\r\n')
for r, ds, fs in os.walk('/tmp/svd'):
    for x in fs:
        p = os.path.join(r, x); f.add(os.path.relpath(p, '/tmp/svd').replace('/', '\\\\'), open(p, 'rb').read())
f.write('$FD/IRONSEED9.ST')
PY
  rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/INPUT.* hatari/c/TEMP
  V=$(awk '/^# *vbls /{print $3}' oracle/scripts/$S.main)
  FLP_START=3 python3 tests/floppy/flp_drive.py $FD $((3000 + ${V:-30000})) /tmp/flp_$S.png --auto 'A:\MAIN.PRG' | tail -30 > /tmp/flp_$S.drive
  echo "  $S: $(grep -c ' prompt ' /tmp/flp_$S.drive) prompts: $(grep ' prompt ' /tmp/flp_$S.drive | awk '{print $3":"$6}' | tr '\n' ' ')"
  [ -f hatari/c/CRASH.TXT ] && { echo "  CRASH: $(head -3 hatari/c/CRASH.TXT)"; }
  n=0; bad=0
  for L in $O/main_*.bin; do
    n=$((n+1)); k=$(basename $L | cut -d_ -f2)
    out=$(python3 tools/oracle_cmp.py build/layout.json $L hatari/c/D$k.BIN 2>&1 | grep -v '^screen\|^identical')
    [ -n "$out" ] && { bad=$((bad+1)); [ $bad -le 3 ] && echo "  $S dump $k: $(echo "$out" | head -2 | tr '\n' ' ')"; }
  done
  [ $n -gt 0 ] && [ $bad = 0 ] && echo "PASS flp $S state ($n dumps)" || { echo "FAIL flp $S state ($bad of $n dumps differ)"; fail=1; }
  rm -rf /tmp/sv; python3 tools/fat12.py --extract $FD/IRONSEED9.ST /tmp/sv
  for D in $O/home/.ironseed/save[0-9]; do
    N=${D##*save}; [ $N = 3 ] && continue
    rm -rf /tmp/st_save; python3 tools/st2dos.py build/layout.json /tmp/sv/SAVE$N /tmp/st_save > /dev/null; python3 tools/st2dos.py build/layout.json /tmp/sv /tmp/st_save > /dev/null
    sb=0; for f in $D/* $O/home/.ironseed/savegame.dir; do b=$(basename $f | tr a-z A-Z); cmp -s $f /tmp/st_save/$b || { sb=1; echo "  $S SAVE$N: $b differs"; }; done
    [ $sb = 0 ] && echo "PASS flp $S saved game SAVE$N on the save disk" || fail=1
  done
  SHOTS=$(awk '/^shot /{n[++k]=$2} /^# *mask /{sub(/^# *mask /,""); split($0,a,":"); m[a[1]]=$0} END{for(i=1;i<=k;i++) printf "%s ", (n[i] in m) ? m[n[i]] : n[i]}' oracle/scripts/$S.main)
  python3 tests/check_shots.py $O hatari/c "$MODES" $SHOTS > /tmp/flp_$S.txt && echo "PASS flp $S screens ($(echo $SHOTS | wc -w))" || { echo "FAIL flp $S screens"; grep -v ' 0 pixels' /tmp/flp_$S.txt | head -4; fail=1; }
done
exit $fail
