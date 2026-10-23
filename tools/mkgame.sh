#!/bin/bash
# mkgame.sh [OUTDIR] : build the game folder (default hatari/c): IS.PRG + ported programs (INTRO, CREWGEN, MAIN),
# DATA\ (converted data files, pictures, title assets, palettes), SOUND\ (MODs, SAMs).
set -e
R=$(cd "$(dirname "$0")/.." && pwd); S=${IRONSEED_SRC:-/root/ironseed_fpc}
OUT=${1:-$R/hatari/c}
mkdir -p "$OUT/DATA" "$OUT/SOUND"
"$R/tools/gen_layout.sh" > /dev/null
python3 -I "$R/tools/mkcrewgen.py" "$S/data" "$OUT/DATA" --equ "$R/build/cgdata.i" > "$R/build/mkcrewgen.log"
python3 -I "$R/tools/mkmain.py" "$S/data" "$R/build/data" > "$R/build/mkmain.log"   # (reads the converted .DTA)
python3 -I "$R/tools/mkcomm.py" "$S/data" "$R/build/data" > "$R/build/mkcomm.log"
python3 -I "$R/tools/mkload.py" "$S/data" "$R/build/data" > "$R/build/mkload.log"
python3 -I "$R/tools/mkprbar.py" "$R/build/prbar.i"
python3 -I "$R/tools/mkegg.py" "$S/data" "$R/build/data" > "$R/build/mkegg.log"
python3 -I "$R/tools/mkending.py" "$S/data" "$R/build/data" "$S/ending.pas" "$R/build/endtext.i" > "$R/build/mkending.log"
for p in is intro crewgen main; do
  python3 -I "$R/tools/fixbranches.py" "$R/game/$p.s" > /dev/null
  "$R/tools/asm.sh" "$R/game/$p.s" "$OUT/$(echo $p | tr a-z A-Z).PRG"
done
[ -d "$R/build/pics" ] && [ "$(ls "$R/build/pics" | wc -l)" -ge 80 ] || \
  python3 -I "$R/tools/cpr2st.py" --batch "$S/data" "$R/build/pics" --pal "$S/data/main.pal" > "$R/build/cpr2st.log"
cp "$R"/build/pics/*.ISP "$OUT/DATA/"
cp "$R"/build/data/* "$OUT/DATA/"   # after the pictures: MAIN's screen designs (LOG, MAIN, CARGO, CHAR2,
                                    # PSYCHE, TECH1, SECTOR, FIGHT) share their names with the .cpr pictures
python3 -I "$R/tools/mktitle.py" "$S/data" "$OUT/DATA/TITLE.DAT" --logo "$R/assets/intro5_tidy.png" > /dev/null
python3 -I "$R/tools/mkc7.py" "$S/data" "$OUT/DATA/C7.ISP" > /dev/null
python3 -I "$R/tools/mkpal.py" "$S/data/main.pal" "$OUT/DATA/CREDITS.ISL" --use 0,10-22 > /dev/null
python3 -I "$R/tools/mkpal.py" "$S/data/main.pal" "$OUT/DATA/MAINPAL.ISL" --use 0-31 --own 31 > /dev/null
python3 -I "$R/tools/mkmars.py" "$S/data" "$OUT/DATA/MARS.DAT" > /dev/null
python3 -I "$R/tools/mkplanets.py" "$S/data" "$OUT/DATA" > /dev/null
python3 -I "$R/tools/mkcharcom.py" "$S/data" "$OUT/DATA/CHARCOM.ISP" > /dev/null
python3 -I "$R/tools/mkalien.py" "$S/data" "$OUT/DATA" > /dev/null
python3 -I "$R/tools/mknblogo.py" "$R/assets/nblogo.gif" "$S/data/main.pal" "$OUT/DATA/NBLOGO.DAT" > /dev/null
python3 -I "$R/tools/mkis2.py" "$S/data" "$OUT/DATA/IS2.DAT" > /dev/null
cp "$S"/sound/*.MOD "$S"/sound/*.SAM "$OUT/SOUND/"
cp "$R/assets/README.TXT" "$OUT/"
echo "game folder: $OUT ($(du -sh "$OUT" | cut -f1))"
