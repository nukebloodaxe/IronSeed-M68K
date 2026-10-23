#!/bin/bash
# run_stream.sh : the music stream test (tests/ktstream.s + check_stream.py): loop, ring wrap,
# an effect on top, play-once; prints PASS/FAIL lines. MEASURE=1 also prints the CPU cost.
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
S=${IRONSEED_SRC:-/root/ironseed_fpc}; fail=0
python3 tests/check_stream.py make "$S/sound" hatari/c
cp "$S/sound/EXPLODE3.SAM" hatari/c/SFX.SAM
for v in PLAIN SFX ONCE; do
  ASMDEFS="-DST_RING=65536 -D$v=1" tools/asm.sh tests/ktstream.s hatari/c/KTSTREAM.PRG > /dev/null || { echo "FAIL build ktstream $v"; fail=1; continue; }
  rm -f hatari/c/SND.*
  tools/run_hatari.sh 3400 /tmp/kst.png --auto 'C:\KTSTREAM.PRG' > /dev/null
  a=""; [ $v = SFX ] && a="--sfx hatari/c/SFX.SAM"; [ $v = ONCE ] && a="--once"
  if r=$(python3 tests/check_stream.py check hatari/c $a); then echo "PASS stream $v ($r)"; else echo "FAIL stream $v ($r)"; fail=1; fi
done
if [ -n "$MEASURE" ]; then
  for v in NOPLAY NOMUSIC PLAIN NOSTREAM; do
    ASMDEFS="-DST_RING=65536 -DMEASURE=1 -D$v=1" tools/asm.sh tests/ktstream.s hatari/c/KTSTREAM.PRG > /dev/null
    rm -f hatari/c/SND.*; tools/run_hatari.sh 3400 /tmp/kst.png --auto 'C:\KTSTREAM.PRG' > /dev/null
    python3 -I -c "import struct; r=struct.unpack('>5LHHL', open('hatari/c/SND.TXT','rb').read()); print('$v', r[7])"
  done | awk '{n[$1]=$2; o[NR]=$1} END {for(i=1;i<=NR;i++) printf "CPU %-8s %5.1f %%\n", o[i], 100*(1-n[o[i]]/n["NOPLAY"])}'
fi
rm -rf hatari/c/MUSIC/TEST.RAW hatari/c/SOUND/TEST.MOD
exit $fail
