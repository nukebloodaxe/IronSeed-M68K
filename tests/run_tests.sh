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
exit $fail
