#!/bin/bash
# mkgame.sh [OUTDIR] : build the game folder (default hatari/c): IS.PRG + ported programs,
# DATA\ (converted data files, pictures, title assets, palettes), SOUND\ (MODs, SAMs).
set -e
R=$(cd "$(dirname "$0")/.." && pwd); S=${IRONSEED_SRC:-/root/ironseed_fpc}
OUT=${1:-$R/hatari/c}
mkdir -p "$OUT/DATA" "$OUT/SOUND"
"$R/tools/gen_layout.sh" > /dev/null
for p in is intro; do
  python3 -I "$R/tools/fixbranches.py" "$R/game/$p.s" > /dev/null
  "$R/tools/asm.sh" "$R/game/$p.s" "$OUT/$(echo $p | tr a-z A-Z).PRG"
done
cp "$R"/build/data/* "$OUT/DATA/"
[ -d "$R/build/pics" ] && [ "$(ls "$R/build/pics" | wc -l)" -ge 80 ] || \
  python3 -I "$R/tools/cpr2st.py" --batch "$S/data" "$R/build/pics" --pal "$S/data/main.pal" > "$R/build/cpr2st.log"
cp "$R"/build/pics/*.ISP "$OUT/DATA/"
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
echo "game folder: $OUT ($(du -sh "$OUT" | cut -f1))"
