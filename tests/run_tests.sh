#!/bin/bash
# run_tests.sh : build and run the kernel tests in Hatari headless; prints PASS/FAIL per test.
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
fail=0
tools/gen_layout.sh > /dev/null || { echo "FAIL gen_layout"; exit 1; }
for t in kt1 kt2 ktcrash; do tools/asm.sh tests/$t.s hatari/c/$(echo $t | tr a-z A-Z).PRG > /dev/null || { echo "FAIL build $t"; fail=1; }; done
cp build/pics/MAIN.ISP hatari/c/ 2>/dev/null || python3 -I tools/cpr2st.py "${IRONSEED_SRC:-/root/ironseed_fpc}/data/main.cpr" hatari/c/MAIN.ISP > /dev/null
rm -f hatari/c/KT1.TXT hatari/c/KT2SCR.BIN hatari/c/CRASH.TXT
tools/run_hatari.sh 2600 /tmp/kt1.png --auto 'C:\KT1.PRG' > /dev/null
grep -q ok hatari/c/KT1.TXT 2>/dev/null && echo "PASS kt1 (bands, fade, cursor, clean exit)" || { echo "FAIL kt1"; fail=1; }
tools/run_hatari.sh 1800 /tmp/kt2.png --auto 'C:\KT2.PRG' > /dev/null
python3 tests/check_kt2.py hatari/c/MAIN.ISP hatari/c/KT2SCR.BIN build/font.i > /tmp/kt2.txt && echo "PASS kt2 (picture, text, primitives pixel-exact)" || { echo "FAIL kt2: $(head -1 /tmp/kt2.txt)"; fail=1; }
tools/asm.sh tests/ktmask.s hatari/c/KTMASK.PRG > /dev/null || { echo "FAIL build ktmask"; fail=1; }
rm -f hatari/c/KTMASK.TXT
tools/run_hatari.sh 2000 /tmp/km.png --auto 'C:\KTMASK.PRG' > /dev/null
head -c 2 hatari/c/KTMASK.TXT 2>/dev/null | grep -q ok && echo "PASS ktmask (txt_mask/txt_mdraw pixel-exact with txt_print, 28 cases)" || { echo "FAIL ktmask"; fail=1; }
tools/asm.sh tests/ktmt.s hatari/c/KTMT.PRG > /dev/null; rm -f hatari/c/KTMT.BIN
tools/run_hatari.sh 1900 /tmp/kmt.png --auto 'C:\KTMT.PRG' > /dev/null
python3 tests/check_mt.py hatari/c/KTMT.BIN > /tmp/mt.txt && echo "PASS ktmt (Free Pascal's random: $(cat /tmp/mt.txt))" || { echo "FAIL ktmt: $(cat /tmp/mt.txt)"; fail=1; }
tools/run_hatari.sh 2300 /tmp/kc.png --auto 'C:\KTCRASH.PRG' > /dev/null
grep -q 'exception 3' hatari/c/CRASH.TXT 2>/dev/null && echo "PASS ktcrash (address error caught, machine restored)" || { echo "FAIL ktcrash"; fail=1; }
S=${IRONSEED_SRC:-/root/ironseed_fpc}
for spec in GAME:0:12517 INTRO1:1:6258; do
  IFS=: read song rate hz <<< "$spec"
  cp "$S/sound/$song.MOD" hatari/c/SONG.MOD; rm -f hatari/c/SND.RAW
  ASMDEFS="-DRATE=$rate" tools/asm.sh tests/kts.s hatari/c/KTS.PRG > /dev/null
  tools/run_hatari.sh 3000 /tmp/kts.png --auto 'C:\KTS.PRG' > /dev/null
  python3 -I tools/modref.py "$S/sound/$song.MOD" /tmp/ref.raw --rate $hz --seconds 6 > /dev/null
  if cmp -s <(head -c $((hz*12)) /tmp/ref.raw) <(head -c $((hz*12)) hatari/c/SND.RAW 2>/dev/null); then
    echo "PASS kts $song $hz Hz (6 s of mixer output bit-exact with tools/modref.py)"
  else echo "FAIL kts $song $hz Hz"; fail=1; fi
done
cp "$S/sound/INTRO1.MOD" hatari/c/SONG.MOD; cp "$S/sound/EXPLODE3.SAM" hatari/c/SFX.SAM; rm -f hatari/c/SND.*
ASMDEFS="-DSFX=1" tools/asm.sh tests/kts.s hatari/c/KTS.PRG > /dev/null
tools/run_hatari.sh 3000 /tmp/kts.png --auto 'C:\KTS.PRG' > /dev/null
ST=$(python3 -I -c "import struct; print(struct.unpack('>5I', open('hatari/c/SND.TXT','rb').read())[4])" 2>/dev/null)
python3 -I tools/modref.py "$S/sound/INTRO1.MOD" /tmp/ref.raw --rate 6258 --seconds 6 --sfx "$S/sound/EXPLODE3.SAM:9000:$ST" > /dev/null
if [ -n "$ST" ] && cmp -s <(head -c 75096 /tmp/ref.raw) <(head -c 75096 hatari/c/SND.RAW); then
  echo "PASS kts+sfx INTRO1 + EXPLODE3 6258 Hz (effect at pair $ST, bit-exact)"
else echo "FAIL kts+sfx"; fail=1; fi
# the music stream (snd.s): loop, ring wrap, an effect on top, play-once - byte-exact with the file
tests/run_stream.sh || fail=1
# --- the intro (game folder via tools/mkgame.sh): credits vs Linux, scripted menu, quit to desktop
tools/mkgame.sh > /dev/null
sed 's/$/\r/' tests/intro_input.txt > hatari/c/INPUT.INT; rm -f hatari/c/*.SCR
tools/run_hatari.sh 3000 /tmp/intro_end.png --auto 'C:\IS.PRG' > /dev/null
rm -f hatari/c/INPUT.INT
python3 tests/check_cred.py hatari/c/CRED.SCR hatari/c/DATA/CREDITS.ISL tests/ref/linux_credits.raw > /tmp/cred.txt \
  && echo "PASS intro credits ($(cat /tmp/cred.txt))" || { echo "FAIL intro credits: $(cat /tmp/cred.txt)"; fail=1; }
python3 tests/check_title.py hatari/c/DATA/TITLE.DAT hatari/c/TITLE.SCR > /tmp/title.txt \
  && echo "PASS title screen (cloud + logo pixel-exact: $(cat /tmp/title.txt))" || { echo "FAIL title screen: $(cat /tmp/title.txt)"; fail=1; }
if [ -s hatari/c/MENU4.SCR ] && python3 -I -c "
from PIL import Image; import sys
sys.exit(0 if Image.open('/tmp/intro_end.png').convert('RGB').getpixel((300,200))==(0,255,0) else 1)"; then
  echo "PASS intro title menu (keys select entries, Quit returns to the desktop)"
else echo "FAIL intro title menu"; fail=1; fi
# planet renderer: 4 frames pixel-exact against tools/planetref.py
tools/asm.sh tests/ktplan.s hatari/c/KTPLAN.PRG > /dev/null; rm -f hatari/c/PLAN*.BIN
tools/run_hatari.sh 2600 /tmp/kp.png --auto 'C:\KTPLAN.PRG' > /dev/null
python3 tests/check_plan.py hatari/c "$S/data" > /tmp/plan.txt
if [ "$(grep -c ' 0 pixels differ' /tmp/plan.txt)" = 4 ]; then echo "PASS planet renderer (4 frames pixel-exact, $(tail -1 /tmp/plan.txt | sed 's/.*= //'))"
else echo "FAIL planet renderer: $(head -4 /tmp/plan.txt | tr '\n' ' ')"; fail=1; fi
# the whole intro without a key: every scene, then the title (its bands = the title's)
cp hatari/c/TITLE.SCR /tmp/title_ref.scr 2>/dev/null
printf 'wait 170000\nshot FULL\nquit\n' | sed 's/$/\r/' > hatari/c/INPUT.INT; rm -f hatari/c/FULL.SCR hatari/c/CRASH.TXT hatari/c/STREAM.BIN
tools/run_hatari.sh 14500 /tmp/full.png --auto 'C:\IS.PRG' > /dev/null
rm -f hatari/c/INPUT.INT
if [ -s hatari/c/FULL.SCR ] && [ ! -e hatari/c/CRASH.TXT ] && cmp -s <(tail -c +32001 hatari/c/FULL.SCR) <(tail -c +32001 /tmp/title_ref.scr); then
  echo "PASS intro scenes (whole intro plays through to the title)"
else echo "FAIL intro scenes"; fail=1; fi
if [ -d hatari/c/MUSIC ]; then   # the intro streamed INTRO1/INTRO2 in real time: the ring must never run dry
  r=$(python3 -I -c "import struct; m,u,n,e=struct.unpack('>3LH', open('hatari/c/STREAM.BIN','rb').read()[:14]); print(m,u,n,e)" 2>/dev/null)
  read m u n e <<< "$r"
  [ -n "$r" ] && [ "$u" = 0 ] && [ "$e" = 0 ] && echo "PASS intro music stream ($n chunks read, ring never below $((m/1024)) KB, no underrun)" \
    || { echo "FAIL intro music stream ($r)"; fail=1; }
fi
# software floating point (kernel/fp.s) against Free Pascal's own arithmetic (tools/fp/fpref)
[ -x tools/fp/fpref ] || fpc -O1 tools/fp/fpref.pas -otools/fp/fpref > /dev/null
python3 tests/fptest.py 300 14000 > /tmp/fp.txt && echo "PASS fp ($(tail -1 /tmp/fp.txt): SSE/x87 arithmetic, rounding, str, sin/cos/arctan bit-exact with FPC)" || { echo "FAIL fp: $(tail -1 /tmp/fp.txt)"; fail=1; }
# crew generation against the Linux oracle (state dumps, screens, saved files)
tests/check_crewgen.sh || fail=1
# the port's own 1994 probes option (no oracle: tests/st/, ST only, from crewgen's save)
tests/st/run_st.sh p1 > /dev/null; python3 tests/st/check_p1.py build/layout.json hatari/c || fail=1
# the main game against the Linux oracle (virtual-time sessions from crewgen's save)
[ -n "$NOMAIN" ] || tests/check_main.sh || fail=1   # NOMAIN=1: stop after crewgen (split check_main over tree copies)
exit $fail
