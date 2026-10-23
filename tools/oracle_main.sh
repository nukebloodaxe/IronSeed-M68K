#!/bin/bash
# oracle_main.sh SCRIPT OUTDIR SAVEHOME SLOT : one scripted MAIN session of the Linux reference build
# (see oracle_run.sh) in virtual time (IRONSEED_VTIME, c_utils.c), started directly as IS.PRG
# would after a save ("main /playseed SLOT"). SAVEHOME = a home dir with .ironseed/ (e.g. the
# home/ of an oracle_run.sh crewgen session). SCRIPT = path of the input script.
# OUTDIR gets the dumps (main_nnnn_*.bin), shot_*.raw and home/.
set -e
R=$(cd "$(dirname "$0")/.." && pwd); S=${IRONSEED_SRC:-/root/ironseed_fpc}
SCR=$(cd "$(dirname "$3")" && pwd)/$(basename "$3") ; SCR=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=$(mkdir -p "$2" && cd "$2" && pwd)
rm -rf "$OUT"/* ; mkdir -p "$OUT/home" ; cp -r "$3/.ironseed" "$OUT/home/"
mkdir -p "$OUT/in"; cp "$SCR" "$OUT/in/s.main"
cd "$S"
HOME="$OUT/home" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy IRONSEED_ORACLE="$OUT" IRONSEED_VTIME=1 \
  IRONSEED_INPUT="$OUT/in/s" timeout 600 ./main /playseed "$4" > "$OUT/main.log" 2>&1 || true
echo "oracle main: $(ls "$OUT"/main_*.bin 2>/dev/null | wc -l) dumps, $(ls "$OUT"/shot_*.raw 2>/dev/null | wc -l) shots in $OUT"
